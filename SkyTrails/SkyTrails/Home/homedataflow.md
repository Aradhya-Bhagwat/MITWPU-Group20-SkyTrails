# SkyTrails Home Module Data Flow

This document outlines the architecture and data flow of the Home module in the SkyTrails application.

## 1. Data Layer (Persistence & Seeding)

### Source: `home_data.json`
*   Acts as the initial seed and fallback for the module.
*   Contains: `hotspots`, `migration_sessions`, `community_observations`, `birdCategories`, and `latestNews`.

### Seeder: `HomeDataSeeder.swift`
*   **Logic:** Decodes JSON into intermediate structs (`HomeJSONData`).
*   **Action:** Maps JSON data to `SwiftData` entities (`Hotspot`, `MigrationSession`, `CommunityObservation`).
*   **Integrity:** Uses UUID-based predicates to prevent duplicates (Insert or Update).
*   **Relational Mapping:** Links hotspots and migrations to the global `Bird` database.

## 2. Logic Layer (Data Orchestration)

### Manager: `HomeManager.swift`
The central hub for data retrieval, integrating multiple sub-managers:
*   **HotspotManager:** Fetches nearby birding locations and active species.
*   **MigrationManager:** Tracks bird movement and progress.
*   **WatchlistManager:** Prioritizes user-tracked birds and spots.
*   **CommunityObservationManager:** Retrieves recent user-shared sightings.

**Key Methods:**
*   `getHomeScreenData()`: The primary async method returning a unified `HomeScreenData` object.
*   `getDynamicMapCards()`: Bridges complex migration and hotspot data for the "Prediction" carousel.
*   `getLivePredictions()`: Calculates real-time spotting probabilities for specific locations.

## 3. Presentation Layer (UI & Interaction)

### Controller: `HomeViewController.swift`
Uses `UICollectionViewCompositionalLayout` to manage five distinct sections:

| Section | Title | Cell Type | Data Input |
| :--- | :--- | :--- | :--- |
| **0** | Prediction | `newMigrationCollectionViewCell` | `MigrationPrediction`, `HotspotPrediction` |
| **1** | Upcoming Birds | `UpcomingBirdsCollectionViewCell` | `UpcomingBirdUI` (from `Bird`) |
| **2** | Spots to Visit | `SpotsToVisitCollectionViewCell` | `PopularSpotUI` (from `Hotspot`) |
| **3** | Community | `CommunityObservationsCollectionViewCell` | `CommunityObservation` |
| **4** | Latest News | `NewsCollectionViewCell` | `NewsItem` |

### Layout & Lifecycle
*   **Dynamic Layout:** Adjusts card widths based on screen size (portrait/landscape).
*   **Lifecycle:** `loadHomeData()` initializes the screen; `refreshHomeData()` updates it on `viewWillAppear`.

## 4. Asset Analysis (XCassets)

The following assets are identified from `Assets.xcassets` and used throughout the Home and identification modules.

### Spot Assets (Hotspot Images)
*   `spot_bharatpur`
*   `spot_chilika`
*   `spot_kashmir`
*   `spot_kaziranga`
*   `spot_khadakwasla`
*   `spot_kumarakom`
*   `spot_nalsarovar`
*   `spot_ranganathittu`
*   `spot_salimali`
*   `spot_sundarbans`
*   `spot_thattekkad`

### Bird Assets (Species Images)
*   `amur_falcon`
*   `arctic_tern`
*   `asian_fairy_bluebird`
*   `asian_koel`
*   `bar_headed_goose`
*   `black_drongo`
*   `black_headed_greenfinch`
*   `black_kite`
*   `black_winged_stilt`
*   `blue_grosbeak`
*   `blue_tailed_bee_eater`
*   `blue_throated_barbet`
*   `brown_headed_barbet`
*   `common_kingfisher`
*   `common_rosefinch`
*   `coppersmith_barbet`
*   `crow`
*   `demoiselle_crane`
*   `eurasian_tree_sparrow`
*   `eurasian_wigeon`
*   `european_goldfinch`
*   `flamingo`
*   `great_hornbill`
*   `great_indian_bustard`
*   `greater_coucal`
*   `greater_flameback`
*   `Grosbeak`
*   `himalayan_monal`
*   `honey_buzzard`
*   `hoopoe`
*   `house_sparrow`
*   `indian_grey_hornbill`
*   `indian_peafowl`
*   `indian_pitta`
*   `indian_robin`
*   `indian_roller`
*   `indian_scops_owl`
*   `indigo_bunting`
*   `kingfisher`
*   `laughing_dove`
*   `lazuli_bunting`
*   `little_bittern`
*   `malabar_trogon`
*   `mountain_bluebird`
*   `northern_pintail`
*   `oriental_magpie_robin`
*   `painted_stork`
*   `paradise_flycatcher`
*   `pied_bushcat`
*   `pied_cuckoo`
*   `pink_browed_rosefinch`
*   `purple_rumped_sunbird`
*   `purple_sunbird`
*   `red_vented_bulbul`
*   `red_whiskered_bulbul`
*   `rose_ringed_parakeet`
*   `rosy_starling`
*   `russet_sparrow`
*   `sarus_crane`
*   `shikra`
*   `siberian_crane`
*   `spectacled_finch`
*   `spoonbill`
*   `spotted_dove`
*   `striated_heron`
*   `white_throated_kingfisher`
*   `white_wagtail`
*   `wire_tailed_swallow`
*   `yellow_throated_sparrow`

## 5. Navigation Flow
*   **Migration/Bird Tap:** Navigates to `birdspredViewController` for detailed movement analysis.
*   **Spot Tap:** Routes to `PredictMapViewController` with live species predictions.
*   **Observation Tap:** Opens the `CommunityObservationViewController` for sighting details.
*   **News Tap:** Opens external URLs in the system browser.

---
*Created on: February 12, 2026*
