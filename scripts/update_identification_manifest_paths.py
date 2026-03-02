#!/usr/bin/env python3
"""
Rewrite Supabase identification_manifest.json image paths from flat canvas files
into shape subfolders.

Examples:
  export SUPABASE_URL="https://<project-ref>.supabase.co"
  export SUPABASE_SERVICE_ROLE_KEY="<service-role-key>"

  # Preview changes (auto-detect shape folders from filenames)
  python3 scripts/update_identification_manifest_paths.py --dry-run

  # Apply changes
  python3 scripts/update_identification_manifest_paths.py

  # Force all flat canvas files into one folder
  python3 scripts/update_identification_manifest_paths.py --shape finch
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

DEFAULT_BUCKET = "identification-assets"
DEFAULT_MANIFEST_PATH = "identification_manifest.json"

SHAPE_RE = re.compile(r"^(?:id_)?canvas_([a-z0-9]+)_", re.IGNORECASE)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Update identification manifest paths to canvas/<shape>/..."
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
        "--bucket",
        default=os.getenv("SUPABASE_BUCKET", DEFAULT_BUCKET),
        help=f"Storage bucket (default: {DEFAULT_BUCKET})",
    )
    parser.add_argument(
        "--manifest-path",
        default=os.getenv("SUPABASE_IDENTIFICATION_MANIFEST_PATH", DEFAULT_MANIFEST_PATH),
        help=f"Manifest object path in bucket (default: {DEFAULT_MANIFEST_PATH})",
    )
    parser.add_argument(
        "--shape",
        default="auto",
        help="Target shape folder name; use 'auto' to derive from file names (default: auto)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Preview updates only",
    )
    parser.add_argument(
        "--backup-file",
        default="",
        help="Write manifest backup to local file before upload",
    )
    return parser.parse_args()


def get_public_object_url(project_url: str, bucket: str, object_path: str) -> str:
    encoded_path = urllib.parse.quote(object_path.strip("/"), safe="/")
    return f"{project_url.rstrip('/')}/storage/v1/object/public/{bucket}/{encoded_path}"


def get_object_upload_url(project_url: str, bucket: str, object_path: str) -> str:
    encoded_path = urllib.parse.quote(object_path.strip("/"), safe="/")
    return f"{project_url.rstrip('/')}/storage/v1/object/{bucket}/{encoded_path}"


def fetch_manifest(project_url: str, bucket: str, object_path: str) -> dict:
    url = get_public_object_url(project_url, bucket, object_path)
    try:
        with urllib.request.urlopen(url) as resp:
            raw = resp.read().decode("utf-8")
            return json.loads(raw)
    except urllib.error.HTTPError as exc:
        details = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Failed to fetch manifest: HTTP {exc.code} - {details}") from exc


def upload_manifest(project_url: str, api_key: str, bucket: str, object_path: str, payload: dict) -> None:
    url = get_object_upload_url(project_url, bucket, object_path)
    body = json.dumps(payload, indent=2, ensure_ascii=False).encode("utf-8")
    req = urllib.request.Request(url, data=body, method="POST")
    req.add_header("apikey", api_key)
    req.add_header("Authorization", f"Bearer {api_key}")
    req.add_header("Content-Type", "application/json")
    req.add_header("x-upsert", "true")

    try:
        with urllib.request.urlopen(req) as resp:
            _ = resp.read()
            print(f"Uploaded manifest (status {resp.status})")
    except urllib.error.HTTPError as exc:
        details = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Failed to upload manifest: HTTP {exc.code} - {details}") from exc


def derive_shape(filename: str, forced_shape: str) -> str | None:
    if forced_shape and forced_shape.lower() != "auto":
        return forced_shape.lower()

    match = SHAPE_RE.match(filename)
    if not match:
        return None
    return match.group(1).lower()


def rewrite_canvas_path(path: str, forced_shape: str) -> tuple[str, bool, str]:
    cleaned = path.strip("/")
    if not cleaned.startswith("canvas/"):
        return path, False, "not_canvas"

    tail = cleaned[len("canvas/") :]
    # already nested: canvas/<folder>/<file>
    if "/" in tail:
        return path, False, "already_nested"

    filename = tail
    shape = derive_shape(filename, forced_shape)
    if not shape:
        return path, False, "shape_unknown"

    new_path = f"canvas/{shape}/{filename}"
    if new_path == cleaned:
        return path, False, "same"
    return new_path, True, "updated"


def write_backup(path: str, data: dict) -> None:
    target = Path(path).expanduser().resolve()
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Backup written: {target}")


def main() -> int:
    args = parse_args()

    if not args.project_url:
        print("Missing --project-url or SUPABASE_URL", file=sys.stderr)
        return 1

    if not args.dry_run and not args.api_key:
        print("Missing --api-key or SUPABASE_SERVICE_ROLE_KEY/SUPABASE_ANON_KEY", file=sys.stderr)
        return 1

    try:
        manifest = fetch_manifest(args.project_url, args.bucket, args.manifest_path)
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        return 1

    items = manifest.get("items")
    if not isinstance(items, dict):
        print("Manifest does not contain 'items' dictionary", file=sys.stderr)
        return 1

    changed = 0
    unchanged = 0
    reasons: dict[str, int] = {}
    samples: list[tuple[str, str]] = []

    for key, item in items.items():
        if not isinstance(item, dict):
            unchanged += 1
            continue
        path = item.get("path")
        if not isinstance(path, str) or not path:
            unchanged += 1
            reasons["missing_path"] = reasons.get("missing_path", 0) + 1
            continue

        new_path, did_change, reason = rewrite_canvas_path(path, args.shape)
        if did_change:
            item["path"] = new_path
            changed += 1
            if len(samples) < 20:
                samples.append((path, new_path))
        else:
            unchanged += 1
            reasons[reason] = reasons.get(reason, 0) + 1

    if "updatedAt" in manifest:
        manifest["updatedAt"] = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

    print(f"Manifest scan complete: changed={changed}, unchanged={unchanged}, total={changed + unchanged}")
    if samples:
        print("Sample updates:")
        for old, new in samples:
            print(f"  {old} -> {new}")

    if reasons:
        print("Unchanged reasons:")
        for reason, count in sorted(reasons.items()):
            print(f"  {reason}: {count}")

    if args.dry_run:
        print("Dry-run complete. Manifest not uploaded.")
        return 0

    if args.backup_file:
        write_backup(args.backup_file, manifest)

    try:
        upload_manifest(args.project_url, args.api_key, args.bucket, args.manifest_path, manifest)
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        return 1

    print("Manifest update complete.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
