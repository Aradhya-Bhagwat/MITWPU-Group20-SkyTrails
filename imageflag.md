# Image Flag Report
> Generated on Fri, 13 Feb 2026

This report lists any discrepancies between the image names used in `home_data.json` and the assets available in `Assets.xcassets`.

## Status: Action Required

*   Checked `hotspots` images: OK (`spot_bharatpur`, `spot_kaziranga`)
*   Checked `migration_sessions` bird images: OK (References `Bird` objects which use `staticImageName`)
*   Checked `community_observations` images: **Flagged** (Multiple missing assets)
*   Checked `birdCategories` icons: OK (Now uses existing bird images: `indian_roller`, `brown_headed_barbet`, `himalayan_monal`)
*   Checked `latestNews` images: OK (`spot_ranganathittu`, `pied_cuckoo`)

## Missing Assets (Critical)
The following images referenced in `home_data.json` (under `community_observations`) are missing from `Assets.xcassets`:
- `red_headed_bunting`
- `baya_weaver`
- `white_rumped_munia`
- `scaly_breasted_munia`

**Action Required:** Add these bird images to `Assets.xcassets` or update `home_data.json` to use existing assets (e.g., `house_sparrow` or `placeholder_image`).

## Resolved Flags
- The previous flags for `shorebirds_icon`, `forest_icon`, `raptors_icon`, and `songbirds_icon` are no longer applicable as the current `home_data.json` has updated `birdCategories` to use available bird images.
- `HomeManager.getBirdCategories()` has also been updated to use Emojis as a fallback, further reducing dependency on these specific icons.