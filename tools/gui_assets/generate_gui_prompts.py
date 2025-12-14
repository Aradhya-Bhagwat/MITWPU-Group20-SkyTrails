#!/usr/bin/env python3
"""Generate the required GUI Identification image asset list + optimized prompts.

Why this exists
- The GUI feature expects very specific asset naming conventions:
  - Base:    shape_<ShapeId>_base
  - Canvas:  canvas_<ShapeId>_<Area>_<Variant>
  - VarIcon: icon_<Area>_<Variant>
  - Category icons (bottom bar): bird_<area-lowercased>

- The GUI loads *all* variants for a selected Area from reference_data.field_marks,
  not just variants present in a bird record.

This script keeps the asset list reproducible and easy to expand.

Example:
  python tools/gui_assets/generate_gui_prompts.py \
	--shape Finch \
	--birds "Asian Koel" "Common Kingfisher" \
	--out-dir tools/gui_assets/out/finch_koel_kingfisher

Outputs:
- manifest.json : machine-readable list of assets + prompts
- prompts.txt   : copy/paste friendly

Tip (local generation):
- For canvas_* overlays, use image-to-image inpainting with shape_Finch_base as the reference.
	Text-only generation often re-centers parts and breaks alignment.
"""

from __future__ import annotations

import argparse
import json
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Tuple


DEFAULT_DB = (
	Path("SkyTrails")
	/ "SkyTrails"
	/ "Identification"
	/ "ViewModel"
	/ "bird_database.json"
)


def clean_for_filename(name: str) -> str:
	"""Mirror GUIViewController.cleanForFilename."""
	return name.replace(" ", "_").replace("-", "_")


def normalize_spaces(value: str) -> str:
	return " ".join(value.split())


def icase_equal(a: str, b: str) -> bool:
	return normalize_spaces(a).casefold() == normalize_spaces(b).casefold()


def find_bird_by_common_name(birds: List[Dict[str, Any]], query: str) -> Dict[str, Any]:
	for bird in birds:
		if icase_equal(str(bird.get("common_name", "")), query):
			return bird

	available = sorted({str(b.get("common_name", "")) for b in birds})
	sample = ", ".join([repr(x) for x in available[:20]])
	suffix = " ..." if len(available) > 20 else ""
	raise SystemExit(f"Bird not found: {query!r}. Available: {sample}{suffix}")


def build_area_to_variants(db: Dict[str, Any]) -> Dict[str, List[str]]:
	field_marks = db.get("reference_data", {}).get("field_marks", [])
	area_to_variants: Dict[str, List[str]] = {}
	for mark in field_marks:
		area = mark.get("area")
		variants = mark.get("variants")
		if not area or not isinstance(variants, list):
			continue
		area_to_variants[str(area)] = [str(v) for v in variants]
	return area_to_variants


def extract_areas_from_birds(birds: Iterable[Dict[str, Any]]) -> List[str]:
	areas: set[str] = set()
	for bird in birds:
		for mark in bird.get("field_marks", []) or []:
			area = mark.get("area")
			if area:
				areas.add(str(area))
	return sorted(areas)


@dataclass(frozen=True)
class AssetPrompt:
	asset_name: str
	kind: str  # base_shape | category_icon | variation_icon | canvas_layer
	shape_id: Optional[str] = None
	area: Optional[str] = None
	variant: Optional[str] = None
	prompt: str = ""
	notes: str = ""


KEY_BG = "#FF00FF"  # chroma key background (must not appear in subject)


GLOBAL_PREFIX = (
	"Style: clean flat 2D vector-like illustration, consistent line weight, "
	"no gradients, no shadows. "
	"Colors: bird fill #cdcdcd, outline/stroke #707070. "
	f"Background: fill entire canvas with solid chroma key {KEY_BG}. "
	f"Do NOT use {KEY_BG} anywhere in the bird/markings. "
	"Output: PNG, square 1024×1024 (or 2048×2048). "
	"Framing: do NOT crop, do NOT zoom, do NOT center the subject. Maintain absolute "
	"positioning in the full canvas. "
	"Negative/avoid: blurry, 3D, realistic, gradients, shadows, ghosting, faint outline "
	"of full bird, extra body parts, smoke, partial opacity, cropped, zoomed, centered."
)


def make_base_prompt(shape_id: str) -> str:
	return (
		f"{GLOBAL_PREFIX}\n"
		f"Create the {shape_id} base silhouette/outline for a compositing canvas: "
		"body fill color #cdcdcd and outline color #707070. Side profile facing right, "
		"perched pose, wings folded. Full body visible. This is the anchor layer. "
		f"Background must be solid chroma key {KEY_BG}."
	)


def make_category_icon_prompt(area: str) -> str:
	return (
		f"{GLOBAL_PREFIX}\n"
		f"Create a simple monochrome UI category icon representing '{area}' (bird field mark category). "
		f"Minimal, bold outline, centered, readable at small size. Background must be solid chroma key {KEY_BG}."
	)


def make_variation_icon_prompt(area: str, variant: str) -> str:
	extra = ""
	if area == "Beak" and variant == "Pale":
		extra = " Use off-white creamy ivory tone (similar to #F3E9D2), NOT pure white."
	if area == "Belly" and variant == "White":
		extra = " Use pure stark white (#FFFFFF)."
	if area == "Back" and variant == "Streaked":
		extra = " Show a close-up feather patch with high-contrast streaks (clean repeated lines)."

	return (
		f"{GLOBAL_PREFIX}\n"
		f"Create a small UI variation icon for {area} = {variant}. Simple, bold, centered, readable at 60×60. "
		f"Flat colors only.{extra} Background must be solid chroma key {KEY_BG}."
	)


def make_canvas_prompt(shape_id: str, area: str, variant: str) -> str:
	extra = ""
	if area == "Beak" and variant == "Pale":
		extra = " Color must be off-white creamy ivory (similar to #F3E9D2), not pure white."
	if area == "Belly" and variant == "White":
		extra = " Color must be pure stark white (#FFFFFF), not ivory/pale."

	wings_rule = ""
	if area == "Back":
		wings_rule = (
			"Wings rule: this is Back (upper torso) ONLY. Do NOT draw or modify Wings/feather groups; "
			"do NOT place patterns on the wing feathers. Keep all wing areas exactly as the base fill (#cdcdcd) "
			f"or the chroma key background ({KEY_BG}) if outside the bird silhouette. "
		)

	return (
		f"{GLOBAL_PREFIX}\n"
		"REFERENCE IMAGE PROVIDED: Use the attached finch base as the fixed coordinate frame.\n"
		f"Task: generate a canvas layer ONLY for {area} = {variant}.{extra}\n"
		"Placement: keep the changed pixels positioned exactly where they belong on the reference bird. "
		"Do not move them, do not center them, do not zoom.\n"
		f"Background handling: every pixel NOT part of the intended {area} layer must remain solid chroma key {KEY_BG} "
		f"(no partial transparency). Do not draw faint outlines/ghosting of the rest of the bird.\n"
		+ wings_rule
	)


def generate_assets(
	db: Dict[str, Any],
	shape: str,
	birds: List[str],
	areas_override: Optional[List[str]] = None,
) -> Tuple[List[AssetPrompt], Dict[str, Any]]:
	all_birds: List[Dict[str, Any]] = db.get("birds", [])
	selected_birds = [find_bird_by_common_name(all_birds, b) for b in birds]

	area_to_variants = build_area_to_variants(db)

	if areas_override:
		areas = list(areas_override)
	else:
		areas = extract_areas_from_birds(selected_birds)

	missing_areas = [a for a in areas if a not in area_to_variants]
	areas = [a for a in areas if a in area_to_variants]

	shape_clean = clean_for_filename(shape)
	assets: List[AssetPrompt] = []

	# Base shape
	assets.append(
		AssetPrompt(
			asset_name=f"shape_{shape_clean}_base",
			kind="base_shape",
			shape_id=shape,
			prompt=make_base_prompt(shape),
			notes="Generate once; use as reference for all canvas layers.",
		)
	)

	# Category icons (bottom bar). In this app they are bird_<area.lowercased>
	for area in areas:
		assets.append(
			AssetPrompt(
				asset_name=f"bird_{area.lower()}",
				kind="category_icon",
				area=area,
				prompt=make_category_icon_prompt(area),
				notes="Used by ChooseFieldMark.imageView (bird_<area.lowercased>).",
			)
		)

	# Variation icons + Canvas layers
	for area in areas:
		for variant in area_to_variants.get(area, []):
			area_clean = clean_for_filename(area)
			variant_clean = clean_for_filename(variant)

			assets.append(
				AssetPrompt(
					asset_name=f"icon_{area_clean}_{variant_clean}",
					kind="variation_icon",
					area=area,
					variant=variant,
					prompt=make_variation_icon_prompt(area, variant),
					notes="Centered is OK; shown in variationsCollectionView.",
				)
			)

			assets.append(
				AssetPrompt(
					asset_name=f"canvas_{shape_clean}_{area_clean}_{variant_clean}",
					kind="canvas_layer",
					shape_id=shape,
					area=area,
					variant=variant,
					prompt=make_canvas_prompt(shape, area, variant),
					notes="Must align to base; use inpainting/reference image.",
				)
			)

	summary = {
		"shape": shape,
		"shape_clean": shape_clean,
		"birds": [str(b.get("common_name")) for b in selected_birds],
		"areas": areas,
		"missing_areas_not_in_reference": missing_areas,
		"counts": {
			"base_shape": 1,
			"category_icons": len(areas),
			"variation_icons": sum(len(area_to_variants[a]) for a in areas),
			"canvas_layers": sum(len(area_to_variants[a]) for a in areas),
			"total": len(assets),
		},
	}

	return assets, summary


def write_outputs(out_dir: Path, assets: List[AssetPrompt], summary: Dict[str, Any]) -> None:
	out_dir.mkdir(parents=True, exist_ok=True)

	manifest_path = out_dir / "manifest.json"
	prompts_path = out_dir / "prompts.txt"

	manifest = {
		"summary": summary,
		"assets": [asdict(a) for a in assets],
	}
	manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

	lines: List[str] = []
	lines.append("# GUI Asset Prompts")
	lines.append("# NOTE: icon prompts omitted (category_icon, variation_icon)")
	lines.append(f"# Shape: {summary['shape']} | Birds: {', '.join(summary['birds'])}")
	lines.append(f"# Areas: {', '.join(summary['areas'])}")
	if summary.get("missing_areas_not_in_reference"):
		lines.append(
			f"# WARNING: areas missing in reference_data.field_marks: {summary['missing_areas_not_in_reference']}"
		)
	lines.append("")

	for asset in assets:
		if asset.kind in {"category_icon", "variation_icon"}:
			continue
		lines.append(f"== {asset.asset_name} ==")
		lines.append(f"kind: {asset.kind}")
		if asset.area:
			lines.append(f"area: {asset.area}")
		if asset.variant:
			lines.append(f"variant: {asset.variant}")
		lines.append("")
		lines.append(asset.prompt)
		if asset.notes:
			lines.append("")
			lines.append(f"notes: {asset.notes}")
		lines.append("\n" + ("-" * 60) + "\n")

	prompts_path.write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
	parser = argparse.ArgumentParser(
		description="Generate GUI asset list + prompts from bird_database.json"
	)
	parser.add_argument("--db", default=str(DEFAULT_DB), help="Path to bird_database.json")
	parser.add_argument("--shape", default="Finch", help="Shape id (e.g., Finch)")
	parser.add_argument(
		"--birds", nargs="+", required=True, help="Bird common names (case-insensitive)"
	)
	parser.add_argument(
		"--areas",
		nargs="+",
		default=None,
		help="Optional override list of areas (e.g., Eye Beak Back Belly). If omitted, derived from birds.",
	)
	parser.add_argument("--out-dir", default="tools/gui_assets/out", help="Output directory")
	args = parser.parse_args()

	db_path = Path(args.db)
	if not db_path.exists():
		raise SystemExit(f"DB not found: {db_path}")

	db = json.loads(db_path.read_text(encoding="utf-8"))

	assets, summary = generate_assets(
		db=db,
		shape=args.shape,
		birds=args.birds,
		areas_override=args.areas,
	)

	write_outputs(Path(args.out_dir), assets, summary)

	print("✅ Generated GUI prompts")
	print(json.dumps(summary["counts"], indent=2))
	if summary.get("missing_areas_not_in_reference"):
		print("⚠️ Missing areas not in reference_data.field_marks:")
		for a in summary["missing_areas_not_in_reference"]:
			print(f" - {a}")


if __name__ == "__main__":
	main()