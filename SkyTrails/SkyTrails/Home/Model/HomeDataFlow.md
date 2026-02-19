# SkyTrails Home Module Dataflow

<!-- PERSISTENT SUMMARY: AGENTS MUST UPDATE THIS FILE WHEN MODIFYING HOME MODULE FILES -->
> **Note to Agents:** This file serves as the source of truth for the Home module's data architecture. If you add new models, change data flow, or modify how view controllers consume data, you **MUST** update this file to reflect those changes.

## Overview
The Home module has been migrated to **SwiftData** for persistence and data management. It uses a centralized `HomeManager` (which now includes `HotspotManager`, `MigrationManager`, and `CommunityObservationManager` logic) to coordinate data. Models for hotspots, migrations, and observations are consolidated in `HomeModels.swift`. Initial data is seeded from `home_data.json` via the `HomeDataSeeder`.

## Data Flow Architecture

### 1. Seeding & Persistence (`HomeDataSeeder.swift`)
1.  **JSON Source:** On launch (or when needed), `home_data.json` is loaded from the App Bundle.
2.  **SwiftData Injection:** `HomeDataSeeder` parses the JSON and inserts/updates models in the `ModelContext`.
3.  **Relationships:** The seeder ensures relationships between `Bird`, `Hotspot`, `MigrationSession`, and `CommunityObservation` are correctly established.

### 2. Specialized Managers
*   **HotspotManager:** (Merged into `HomeManager.swift`) Manages `Hotspot` and `HotspotSpeciesPresence`.
*   **MigrationManager:** (Merged into `HomeManager.swift`) Manages `MigrationSession` and `TrajectoryPath`.
*   **CommunityObservationManager:** (Merged into `HomeManager.swift`) Manages `CommunityObservation`.
*   **WatchlistManager:** Manages `Watchlist` and `WatchlistEntry`. Central source for user-tracked species and spots.

### 3. Home Management (`HomeManager.swift`)
The `HomeManager` is a singleton that provides a high-level API for the Home screen and now contains the logic for Hotspots, Migrations, and Community Observations to reduce file count.
*   **HomeScreenData:** A combined struct containing all data needed for the `HomeViewController`.
*   **Active Migrations:** Provides `MigrationCardResult` objects (used for the "Prediction" carousel).
*   **Upcoming Birds:** Intersects user watchlist with local species presence.
*   **Popular Spots:** Combines user-tracked spots with recommended nearby hotspots.
*   **Relevant Sightings:** Builds trajectory points for the bird prediction map from migration sessions.

### 4. Data Consumption (`HomeViewController.swift`)
*   The `HomeViewController` uses `HomeManager.shared.getHomeScreenData()` to fetch a unified data snapshot.
*   It maps these domain models to UI-specific models (`UpcomingBirdUI`, `PopularSpotUI`).
*   It organizes data into 5 collection view sections:
    1.  **Prediction (Section 0):** Active migration paths and nearby hotspot predictions.
    2.  **Upcoming Birds (Section 1):** Watchlist birds and local recommendations.
    3.  **Spots to Visit (Section 2):** Watchlist spots and local recommendations.
    4.  **Community Observations (Section 3):** Recent sightings from other users.
    5.  **Latest News (Section 4):** News items loaded directly from `home_data.json`.

## View Controller & View Usage

| View Controller / View | File Path | Consumed Models / Data Sources | Key Functions Used |
| :--- | :--- | :--- | :--- |
| **HomeViewController** | `SkyTrails/SkyTrails/Home/Controller/HomeViewController.swift` | `HomeScreenData`, `HomeManager`, `HomeJSONData` | `getHomeScreenData()`, `getDynamicMapCards()`, `loadNews()` |
| **AllSpotsViewController** | `SkyTrails/SkyTrails/Home/Controller/AllSpotsViewController.swift` | `PopularSpotResult` | Displays watchlist and recommended spots. |
| **AllUpcomingBirdsVC** | `SkyTrails/SkyTrails/Home/Controller/AllUpcomingBirdsViewController.swift` | `UpcomingBirdResult`, `RecommendedBirdResult` | Displays watchlist and recommended birds. |
| **CommunityObservationVC** | `SkyTrails/SkyTrails/Home/Controller/CommunityObservationViewController.swift` | `CommunityObservation` | Displays detailed observation data. |
| **PredictMapVC** | `SkyTrails/SkyTrails/Home/Controller/PredictMapViewController.swift` | `PredictionInputData`, `FinalPredictionResult` | Map visualization for bird predictions. |
| **BirdspredVC** | `SkyTrails/SkyTrails/Home/Controller/birdspredViewController.swift` | `BirdDateInput` | Migration path visualization. |
| **newMigrationCell** | `SkyTrails/SkyTrails/Home/Controller/cells/newMigrationCollectionViewCell.swift` | `MigrationPrediction`, `HotspotPrediction` | Configures the combined migration/hotspot card. |

## JSON Structure & Model Mapping (`home_data.json`)

The JSON serves as the primary seed for SwiftData.

| JSON Key | Swift Type | Description |
| :--- | :--- | :--- |
| `hotspots` | `[HotspotData]` | Seed for `Hotspot` and `HotspotSpeciesPresence`. |
| `migration_sessions` | `[MigrationSessionData]` | Seed for `MigrationSession` and `TrajectoryPath`. |
| `community_observations`| `[CommunityObservationData]`| Seed for `CommunityObservation`. |
| `birdCategories` | `[BirdCategory]` | Categories used for filtering (often emoji-based in code). |
| `latestNews` | `[NewsItem]` | Static news feed items. |

## Logic & Relationships

### Migration Progress Logic
`HomeManager.getActiveMigrations()` calculates progress based on the current week relative to `startWeek` and `endWeek` of a `MigrationSession`.

### Spot Species Counting
`HotspotManager` calculates the number of species present at a hotspot for a given week by checking the `validWeeks` in `HotspotSpeciesPresence`.

### Prediction Logic
`HomeManager.getLivePredictions()` queries the `HotspotManager` for species present at a specific coordinate and radius during the current week.

### Dynamic Map Card Pin Logic
`HomeManager.getDynamicMapCards()` now computes one map pin per migrating bird for the selected top hotspot by:
1. Taking the hotspot center coordinate.
2. Finding each bird's nearest migration trajectory coordinate to that center.
3. Keeping only points within a 5km radius.
These pins are passed to `HotspotPrediction.hotspots`, while `HotspotPrediction.centerCoordinate` and `HotspotPrediction.pinRadiusKm` are used by `NewMigrationCollectionViewCell` to render the 5km radius overlay and fit map bounds.

### Relevant Sightings Logic
`HomeManager.getRelevantSightings()` returns trajectory points for the selected bird by week range (with year wrap handling) so `birdspredViewController` can draw the migration path.

## Available Bird Assets

The following is a list of bird species that have corresponding image assets in `Assets.xcassets`. These keys can be used in `home_data.json` for the `imageName` or `staticImageName` property.

*   Amur Falcon (`amur_falcon`)
*   Arctic Tern (`arctic_tern`)
*   Asian Fairy Bluebird (`asian_fairy_bluebird`)
*   Asian Koel (`asian_koel`)
*   Bar Headed Goose (`bar_headed_goose`)
*   Black Drongo (`black_drongo`)
*   Black Kite (`black_kite`)
*   Black Winged Stilt (`black_winged_stilt`)
*   Blue Grosbeak (`blue_grosbeak`)
*   Blue Tailed Bee Eater (`blue_tailed_bee_eater`)
*   Blue Throated Barbet (`blue_throated_barbet`)
*   Brown Headed Barbet (`brown_headed_barbet`)
*   Brown Headed Barbet Alt (`brown_headed_barbet_alt`)
*   Common Kingfisher (`common_kingfisher`)
*   Common Rosefinch (`common_rosefinch`)
*   Coppersmith Barbet (`coppersmith_barbet`)
*   Crow (`crow`)
*   Demoiselle Crane (`demoiselle_crane`)
*   Eurasian Tree Sparrow (`eurasian_tree_sparrow`)
*   Eurasian Wigeon (`eurasian_wigeon`)
*   European Goldfinch (`european_goldfinch`)
*   Flamingo (`flamingo`)
*   Great Hornbill (`great_hornbill`)
*   Great Indian Bustard (`great_indian_bustard`)
*   Greater Coucal (`greater_coucal`)
*   Greater Flameback (`greater_flameback`)
*   Grosbeak (`grosbeak`)
*   Himalayan Monal (`himalayan_monal`)
*   Honey Buzzard (`honey_buzzard`)
*   Hoopoe (`hoopoe`)
*   House Sparrow (`house_sparrow`)
*   Indian Grey Hornbill (`indian_grey_hornbill`)
*   Indian Peafowl (`indian_peafowl`)
*   Indian Pitta (`indian_pitta`)
*   Indian Robin (`indian_robin`)
*   Indian Roller (`indian_roller`)
*   Indian Scops Owl (`indian_scops_owl`)
*   Indigo Bunting (`indigo_bunting`)
*   Kingfisher (`kingfisher`)
*   Laughing Dove (`laughing_dove`)
*   Lazuli Bunting (`lazuli_bunting`)
*   Little Bittern (`little_bittern`)
*   Malabar Trogon (`malabar_trogon`)
*   Mountain Bluebird (`mountain_bluebird`)
*   Northern Pintail (`northern_pintail`)
*   Oriental Magpie Robin (`oriental_magpie_robin`)
*   Painted Stork (`painted_stork`)
*   Paradise Flycatcher (`paradise_flycatcher`)
*   Pied Bushcat (`pied_bushcat`)
*   Pied Cuckoo (`pied_cuckoo`)
*   Pink Browed Rosefinch (`pink_browed_rosefinch`)
*   Purple Rumped Sunbird (`purple_rumped_sunbird`)
*   Purple Sunbird (`purple_sunbird`)
*   Red Vented Bulbul (`red_vented_bulbul`)
*   Red Whiskered Bulbul (`red_whiskered_bulbul`)
*   Rose Ringed Parakeet (`rose_ringed_parakeet`)
*   Rosy Starling (`rosy_starling`)
*   Russet Sparrow (`russet_sparrow`)
*   Sarus Crane (`sarus_crane`)
*   Shikra (`shikra`)
*   Siberian Crane (`siberian_crane`)
*   Spectacled Finch (`spectacled_finch`)
*   Spoonbill (`spoonbill`)
*   Spotted Dove (`spotted_dove`)
*   Striated Heron (`striated_heron`)
*   White Throated Kingfisher (`white_throated_kingfisher`)
*   White Wagtail (`white_wagtail`)
*   Wire Tailed Swallow (`wire_tailed_swallow`)
*   Yellow Throated Sparrow (`yellow_throated_sparrow`)
