#!/usr/bin/env python3
"""
Upload required finch canvas assets from Xcode Assets.xcassets to Supabase Storage.

Default destination:
  bucket: identification-assets
  prefix: canvas/finch

Usage:
  export SUPABASE_URL="https://<project-ref>.supabase.co"
  export SUPABASE_SERVICE_ROLE_KEY="<service-role-key>"
  python3 scripts/upload_finch_canvas_assets.py --dry-run
  python3 scripts/upload_finch_canvas_assets.py
  python3 scripts/upload_finch_canvas_assets.py --move-existing-canvas-to-finch --skip-upload
"""

from __future__ import annotations

import argparse
import json
import mimetypes
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

DEFAULT_BUCKET = "identification-assets"
DEFAULT_PREFIX = "canvas/finch"

# target_filename -> imageset_name
REQUIRED_ASSETS = {
    "id_canvas_finch_beak_default.png": "id_canvas_finch_beak_default",
    "id_canvas_finch_head_default.png": "id_canvas_finch_head_default",
    "id_canvas_finch_leg_default.png": "id_canvas_finch_leg_default",
    "id_canvas_finch_tail_default.png": "id_canvas_finch_tail_default",
    "canvas_finch_beak_color.png": "canvas_finch_beak_color",
    "canvas_finch_crown_color.png": "canvas_finch_crown_color",
    "canvas_finch_eye_color.png": "canvas_finch_eye_color",
    "canvas_finch_facemask_color.png": "canvas_finch_facemask_color",
    "canvas_finch_head_color.png": "canvas_finch_head_color",
    "canvas_finch_neck_color.png": "canvas_finch_neck_color",
    "canvas_finch_tail_color.png": "canvas_finch_tail_color",
    "canvas_finch_throat_color.png": "canvas_finch_throat_color",
    "canvas_finch_underparts_color.png": "canvas_finch_underparts_color",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Upload finch canvas assets to Supabase Storage"
    )
    parser.add_argument(
        "--assets-root",
        default="SkyTrails/SkyTrails/Assets.xcassets",
        help="Path to Assets.xcassets root",
    )
    parser.add_argument(
        "--bucket",
        default=os.getenv("SUPABASE_BUCKET", DEFAULT_BUCKET),
        help=f"Supabase storage bucket (default: {DEFAULT_BUCKET})",
    )
    parser.add_argument(
        "--prefix",
        default=os.getenv("SUPABASE_PREFIX", DEFAULT_PREFIX),
        help=f"Object prefix/folder in bucket (default: {DEFAULT_PREFIX})",
    )
    parser.add_argument(
        "--project-url",
        default=os.getenv("SUPABASE_URL", "").strip(),
        help="Supabase project URL, e.g. https://<ref>.supabase.co",
    )
    parser.add_argument(
        "--api-key",
        default=(
            os.getenv("SUPABASE_SERVICE_ROLE_KEY", "").strip()
            or os.getenv("SUPABASE_ANON_KEY", "").strip()
        ),
        help="Supabase API key (service role recommended)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print upload plan only, do not upload",
    )
    parser.add_argument(
        "--upsert",
        action="store_true",
        default=True,
        help="Overwrite files if they already exist (default: true)",
    )
    parser.add_argument(
        "--skip-upload",
        action="store_true",
        help="Skip local assets upload and run move operation only",
    )
    parser.add_argument(
        "--move-existing-canvas-to-finch",
        action="store_true",
        help="Move all existing objects in canvas/ to canvas/finch/ in Supabase",
    )
    parser.add_argument(
        "--canvas-prefix",
        default="canvas",
        help="Canvas root folder in bucket (default: canvas)",
    )
    parser.add_argument(
        "--move-conflict",
        choices=["overwrite", "skip", "fail"],
        default="overwrite",
        help="When destination exists during move: overwrite, skip, or fail (default: overwrite)",
    )
    return parser.parse_args()


def load_imageset_png(imageset_dir: Path) -> Path:
    contents_path = imageset_dir / "Contents.json"
    if not contents_path.exists():
        raise FileNotFoundError(f"Missing Contents.json in {imageset_dir}")

    data = json.loads(contents_path.read_text(encoding="utf-8"))
    images = data.get("images", [])
    for item in images:
        filename = item.get("filename")
        if not filename:
            continue
        candidate = imageset_dir / filename
        if candidate.exists() and candidate.suffix.lower() == ".png":
            return candidate

    raise FileNotFoundError(
        f"No PNG file reference found in {contents_path}"
    )


def resolve_source_files(assets_root: Path) -> list[tuple[Path, str]]:
    resolved: list[tuple[Path, str]] = []

    for target_name, imageset_name in REQUIRED_ASSETS.items():
        imageset_dir = assets_root / f"{imageset_name}.imageset"
        if not imageset_dir.exists():
            raise FileNotFoundError(f"Missing imageset: {imageset_dir}")

        source_file = load_imageset_png(imageset_dir)
        resolved.append((source_file, target_name))

    return resolved


def build_upload_url(project_url: str, bucket: str, object_path: str) -> str:
    base = project_url.rstrip("/")
    encoded_object = urllib.parse.quote(object_path, safe="/")
    return f"{base}/storage/v1/object/{bucket}/{encoded_object}"


def upload_file(
    project_url: str,
    api_key: str,
    bucket: str,
    object_path: str,
    source_file: Path,
    upsert: bool,
) -> None:
    url = build_upload_url(project_url, bucket, object_path)
    body = source_file.read_bytes()
    content_type = mimetypes.guess_type(source_file.name)[0] or "application/octet-stream"

    req = urllib.request.Request(url, data=body, method="POST")
    req.add_header("apikey", api_key)
    req.add_header("Authorization", f"Bearer {api_key}")
    req.add_header("Content-Type", content_type)
    req.add_header("x-upsert", "true" if upsert else "false")

    try:
        with urllib.request.urlopen(req) as resp:
            _ = resp.read()
            print(f"Uploaded: {object_path} (status {resp.status})")
    except urllib.error.HTTPError as exc:
        details = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(
            f"Upload failed for {object_path}: HTTP {exc.code} - {details}"
        ) from exc


def request_json(
    project_url: str,
    api_key: str,
    path: str,
    payload: dict,
) -> list[dict]:
    url = f"{project_url.rstrip('/')}{path}"
    body = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=body, method="POST")
    req.add_header("apikey", api_key)
    req.add_header("Authorization", f"Bearer {api_key}")
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        details = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {exc.code} for {path}: {details}") from exc


def delete_object(
    project_url: str,
    api_key: str,
    bucket: str,
    object_key: str,
) -> None:
    encoded_key = urllib.parse.quote(object_key, safe="/")
    url = f"{project_url.rstrip('/')}/storage/v1/object/{bucket}/{encoded_key}"
    req = urllib.request.Request(url, method="DELETE")
    req.add_header("apikey", api_key)
    req.add_header("Authorization", f"Bearer {api_key}")
    with urllib.request.urlopen(req) as _:
        return


def list_objects_recursive(
    project_url: str,
    api_key: str,
    bucket: str,
    prefix: str,
) -> list[str]:
    files: list[str] = []
    stack = [prefix.strip("/")]
    list_path = f"/storage/v1/object/list/{bucket}"

    while stack:
        current_prefix = stack.pop()
        page = request_json(
            project_url=project_url,
            api_key=api_key,
            path=list_path,
            payload={
                "prefix": current_prefix,
                "limit": 1000,
                "offset": 0,
                "sortBy": {"column": "name", "order": "asc"},
            },
        )

        for item in page:
            name = item.get("name")
            if not isinstance(name, str) or not name:
                continue
            is_file = item.get("id") is not None
            object_key = f"{current_prefix}/{name}" if current_prefix else name
            if is_file:
                files.append(object_key)
            else:
                stack.append(object_key)

    return files


def move_object(
    project_url: str,
    api_key: str,
    bucket: str,
    source_key: str,
    destination_key: str,
) -> None:
    _ = request_json(
        project_url=project_url,
        api_key=api_key,
        path="/storage/v1/object/move",
        payload={
            "bucketId": bucket,
            "sourceKey": source_key,
            "destinationKey": destination_key,
        },
    )


def move_existing_canvas_objects(
    project_url: str,
    api_key: str,
    bucket: str,
    canvas_prefix: str,
    finch_prefix: str,
    dry_run: bool,
    move_conflict: str,
) -> None:
    source_root = canvas_prefix.strip("/")
    target_root = finch_prefix.strip("/")

    if not target_root.startswith(f"{source_root}/"):
        raise ValueError(
            f"Target prefix '{target_root}' must be under source prefix '{source_root}/...'"
        )

    all_canvas_files = list_objects_recursive(
        project_url=project_url,
        api_key=api_key,
        bucket=bucket,
        prefix=source_root,
    )
    to_move: list[tuple[str, str]] = []
    for source_key in all_canvas_files:
        if source_key.startswith(f"{target_root}/"):
            continue
        relative = source_key[len(source_root):].lstrip("/")
        destination_key = f"{target_root}/{relative}" if relative else target_root
        to_move.append((source_key, destination_key))

    print(f"Move plan ({len(to_move)} objects):")
    for source_key, destination_key in to_move:
        print(f"  {bucket}/{source_key} -> {bucket}/{destination_key}")

    if dry_run:
        print("Dry-run complete. No objects moved.")
        return

    moved_count = 0
    skipped_count = 0
    for source_key, destination_key in to_move:
        try:
            move_object(
                project_url=project_url,
                api_key=api_key,
                bucket=bucket,
                source_key=source_key,
                destination_key=destination_key,
            )
            print(f"Moved: {source_key} -> {destination_key}")
            moved_count += 1
            continue
        except RuntimeError as exc:
            message = str(exc).lower()
            conflict = ("already exists" in message) or ("duplicate" in message)
            if not conflict:
                raise

            if move_conflict == "skip":
                print(f"Skipped (destination exists): {source_key}")
                skipped_count += 1
                continue

            if move_conflict == "fail":
                raise RuntimeError(
                    f"Conflict while moving {source_key} -> {destination_key}: {exc}"
                ) from exc

            # overwrite
            delete_object(
                project_url=project_url,
                api_key=api_key,
                bucket=bucket,
                object_key=destination_key,
            )
            move_object(
                project_url=project_url,
                api_key=api_key,
                bucket=bucket,
                source_key=source_key,
                destination_key=destination_key,
            )
            print(f"Moved (overwrite): {source_key} -> {destination_key}")
            moved_count += 1

    print(
        f"Move complete. moved={moved_count}, skipped={skipped_count}, total={len(to_move)}"
    )


def main() -> int:
    args = parse_args()

    assets_root = Path(args.assets_root).resolve()
    if not args.skip_upload and not assets_root.exists():
        print(f"Assets root not found: {assets_root}", file=sys.stderr)
        return 1

    if not args.project_url:
        print("Missing --project-url or SUPABASE_URL", file=sys.stderr)
        return 1

    if not args.api_key:
        print(
            "Missing --api-key or SUPABASE_SERVICE_ROLE_KEY/SUPABASE_ANON_KEY",
            file=sys.stderr,
        )
        return 1

    prefix = args.prefix.strip("/")

    if not args.skip_upload:
        try:
            source_map = resolve_source_files(assets_root)
        except Exception as exc:
            print(f"Error resolving source files: {exc}", file=sys.stderr)
            return 1

        print("Upload plan:")
        for src, target_name in source_map:
            object_path = f"{prefix}/{target_name}" if prefix else target_name
            print(f"  {src} -> {args.bucket}/{object_path}")

        if not args.dry_run:
            for src, target_name in source_map:
                object_path = f"{prefix}/{target_name}" if prefix else target_name
                upload_file(
                    project_url=args.project_url,
                    api_key=args.api_key,
                    bucket=args.bucket,
                    object_path=object_path,
                    source_file=src,
                    upsert=args.upsert,
                )
            print("Required finch files uploaded successfully.")

    if args.move_existing_canvas_to_finch:
        move_existing_canvas_objects(
            project_url=args.project_url,
            api_key=args.api_key,
            bucket=args.bucket,
            canvas_prefix=args.canvas_prefix,
            finch_prefix=prefix,
            dry_run=args.dry_run,
            move_conflict=args.move_conflict,
        )

    if args.dry_run:
        print("Dry-run complete.")
    else:
        print("Done.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
