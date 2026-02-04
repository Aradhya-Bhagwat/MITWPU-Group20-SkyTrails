# Home Module Summary

> **ATTENTION AGENTS:** If you modify any files within the Home module, you **MUST** update this summary to reflect your changes. This ensures subsequent agents have accurate architectural and functional context.

This document provides a summary of the files in the `SkyTrails/SkyTrails/Home` directory to assist coding agents in understanding the structure and functionality of the Home/Dashboard feature.

## Directory Structure

### Model
Data structures and business logic for the Dashboard and Prediction features.

- **`HomeModels.swift`**: Defines the data structures and the `HomeModels` view-model wrapper.
    - **`CoreHomeData`**: Top-level wrapper for `home_data.json`.
    - **UI Models**: `PredictedMigration`, `UpcomingBird`, `PopularSpot`, `CommunityObservation`, `NewsItem`, `DynamicCard`.
    - **Prediction Models**: `PredictionInputData`, `SpeciesData`, `Sighting`, `FinalPredictionResult`, `PredictionDataWrapper`.
    - **`HomeModels` (Class)**: Acts as a ViewModel/Data Provider for `HomeViewController`, exposing arrays like `predictedMigrations`, `watchlistBirds`, `recommendedSpots`, etc.

- **`HomeManager.swift`**: Singleton (`HomeManager.shared`) for data persistence and logic.
    - Loads `home_data.json` from the Bundle or Documents directory.
    - **`predictBirds(...)`**: Core logic for the Bird Migration Prediction feature ("Waterfall Matching" algorithm based on week, location buffer, and probability).
    - `getLivePredictions(...)`: Helper for real-time predictions for a specific spot.
    - `getDynamicMapCards()`: Converts raw `DynamicCard` data into UI-ready enums (`MigrationPrediction`, `HotspotPrediction`).
    - `precalculateSpotSpeciesCounts()`: Optimizes performance by pre-calculating active species counts for spots.

### Controller
View Controllers managing the Home Dashboard and Prediction features.

- **`HomeViewController.swift`**: The main Dashboard.
    - Uses `UICollectionViewCompositionalLayout` with 5 sections:
        1.  **Migration/Prediction Carousel** (`newMigrationCollectionViewCell`)
        2.  **Upcoming Birds** (`UpcomingBirdsCollectionViewCell`)
        3.  **Spots to Visit** (`SpotsToVisitCollectionViewCell`)
        4.  **Community Observations** (`CommunityObservationsCollectionViewCell`)
        5.  **Latest News** (`NewsCollectionViewCell`)
    - Navigation:
        - Tapping a Migration/Bird card -> `birdspredViewController` (Migration Map).
        - Tapping a Spot -> `PredictMapViewController` (Spot Detail/Prediction).
        - Tapping an Observation -> `CommunityObservationViewController`.
        - Tapping News -> Opens Safari.

- **`PredictMapViewController.swift`**: Detail view for a "Spot to Visit". Runs a live prediction for that location and displays active birds on a map.
- **`AllSpotsViewController.swift`**: "See All" screen for spots.
- **`AllUpcomingBirdsViewController.swift`**: "See All" screen for upcoming birds.
- **`CommunityObservationViewController.swift`**: Detail view for a community post.
- **`birdspredViewController.swift`**: (Located in `birdspred.storyboard`) Displays the migration path and prediction for a specific bird.

- **Cells**:
    - `newMigrationCollectionViewCell.swift`: Complex card showing migration map or hotspot info.
    - `UpcomingBirdsCollectionViewCell.swift`, `SpotsToVisitCollectionViewCell.swift`: Standard content cards.
    - `CommunityObservationsCollectionViewCell.swift`: User post summary.
    - `NewsCollectionViewCell.swift`: News item.
    - `SectionHeaderCollectionReusableView.swift`: Standard header.

### View
- **`Home.storyboard`**: Main dashboard layout and navigation to Spot/Community details.
- **`birdspred.storyboard`**: Layout for the Bird Migration Prediction visualization.

## Key Workflows

1.  **Dashboard Load**: `HomeManager` loads `home_data.json`. `HomeViewController` initializes `HomeModels` to populate its data arrays.
2.  **Spot Prediction**:
    - User taps a "Spot to Visit".
    - `HomeViewController.navigateToSpotDetails` calls `HomeManager.getLivePredictions` for the spot's coordinates.
    - `PredictMapViewController` displays the map and list of likely birds.
3.  **Bird Migration**:
    - User taps a "Migration" card or "Upcoming Bird".
    - The App looks up the species in `PredictionEngine.shared.allSpecies`.
    - `birdspredViewController` (BirdMapResult) is pushed, showing the species' migration path and seasonal probability.
