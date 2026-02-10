# Home Module Technical Summary

> **PURPOSE:** This document details the technical state of the Home module's data models, persistence mechanisms, and data flows. It is intended to serve as a context reference for Large Language Models (LLMs) planning a migration to SwiftData.

## 1. Data Models (`HomeModels.swift`)

The current data model is built around a monolithic JSON structure (`CoreHomeData`) which acts as the single source of truth. All models conform to `Codable`.

### Core Wrapper
*   **`CoreHomeData`**: The root object decoding `home_data.json`.
    *   Contains arrays of: `PredictedMigration`, `UpcomingBird`, `BirdCategory`, `PopularSpot`, `DynamicCard`, `CommunityObservation`, `NewsItem`, `SpeciesData`.

### Entity Models

#### 1. Spots & Recommendations
*   **`PopularSpot`**: Represents a birding location.
    *   **Properties**: `title`, `location`, `latitude`, `longitude`, `radius`, `imageName`.
    *   **Relationships**: Contains an array of `SpotBird`.
*   **`SpotBird`**: Simple wrapper for a bird found at a spot (`name`, `imageName`, `lat`, `lon`).
*   **`UpcomingBird`**: Simple display model for "Upcoming Birds" list (`title`, `date`, `imageName`).

#### 2. Prediction Engine Models
*   **`SpeciesData`**: Represents a bird species.
    *   **Properties**: `id`, `name`, `imageName`.
    *   **Relationships**: Contains a large array of `Sighting`.
*   **`Sighting`**: Spatio-temporal data point.
    *   **Properties**: `week` (Int), `lat` (Double), `lon` (Double), `locationName` (String), `probability` (Int?).
    *   **Note**: This is the primary dataset for the prediction algorithm.

#### 3. Dynamic UI Cards
*   **`DynamicCard`**: A flexible model used for the top carousel.
    *   **Nature**: "Schema-on-read". It contains optional fields for both *Migration* (start/end loc, progress) and *Hotspot* (species count, hotspots list) types.
    *   **Runtime**: Converted to `MapCardType` enum (e.g., `.combined`) by `HomeManager` before display.
    *   **Complex Fields**: Contains nested `RawCoordinate` and `RawHotspotPin`.

#### 4. Community & News
*   **`CommunityObservation`**: User generated content.
    *   **Properties**: `observationId`, `username`, `userAvatar`, `observationTitle`, `location`, `likesCount`, etc.
    *   **Legacy Support**: Contains `User` object (legacy) and computed compatibility properties (`displayBirdName`, `displayUser`).
*   **`NewsItem`**: Simple news data (`title`, `description`, `link`, `imageName`).

#### 5. View Models (Non-Persisted)
*   **`HomeModels`**: A class initialized by `HomeViewController`.
    *   **Role**: Acts as a ViewModel, flattening `CoreHomeData` into distinct arrays (`watchlistBirds`, `recommendedSpots`) for easy consumption by the UI.
    *   **Logic**: Contains computed properties like `homeScreenSpots` which toggle between "watchlist" and "recommended" data.

## 2. Persistence & Data Management (`HomeManager.swift`)

The `HomeManager` singleton (`shared`) is responsible for the lifecycle of the data.

### Persistence Strategy
*   **File-Based**: Reads/Writes to a single `home_data.json` file.
*   **Load Priority**:
    1.  **Documents Directory**: Checks for a user-modified version first.
    2.  **App Bundle**: Falls back to the shipped `home_data.json`.
*   **Write Back**: If data is loaded from the Bundle, it is immediately saved to the Documents directory to ensure a writable copy exists.
*   **Serialization**: Uses standard `JSONDecoder` and `JSONEncoder`.

### Derived Data & Caching
*   **`spotSpeciesCountCache`**: A dictionary `[String: Int]` mapping Spot Titles to the count of active species.
    *   **Calculation**: `precalculateSpotSpeciesCounts()` iterates `watchlistSpots` + `recommendedSpots` against *all* `SpeciesData`. It filters sightings by **distance** (within spot radius) and **time** (current week).
*   **`newsResponse`** & **`predictionData`**: Wrappers extracted from `CoreHomeData` for easier access to specific subsections.

## 3. Key Data Flows

### A. Dashboard Initialization
1.  **App Launch**: `HomeManager.shared` initializes and calls `loadData()`.
2.  **Decoding**: `home_data.json` is parsed into `CoreHomeData`.
3.  **Pre-calculation**: `precalculateSpotSpeciesCounts()` runs immediately to populate the cache.
4.  **View Load**: `HomeViewController` initializes `HomeModels`.
5.  **Binding**: `HomeModels` grabs references to the arrays in `HomeManager.shared.coreHomeData`.

### B. Prediction "Waterfall" (Algorithm)
*   **Trigger**: Used when visualizing migration maps or checking specific spots.
*   **Input**: `PredictionInputData` (Location, Date Range).
*   **Process**:
    1.  Access global `predictionData.speciesData`.
    2.  Iterate all species.
    3.  Filter `sightings` based on:
        *   **Week**: Matches input week range (handles year wrap-around).
        *   **Location**: Matches input Lat/Lon within a calculated buffer.
*   **Output**: `FinalPredictionResult` (Bird Name, Probability, Matched Location).

### C. Live Spot Detail
*   **Trigger**: User taps a "Spot to Visit".
*   **Flow**: `HomeViewController` calls `HomeManager.shared.getLivePredictions(lat, lon, radius)`.
*   **Action**: Performs a real-time filter of `allSpecies` for the *current week* and *target location* to populate the detail map.

## 4. Considerations for Migration

*   **Relationships**: The current model nests heavy data (`sightings`) inside parent objects (`SpeciesData`). SwiftData would likely benefit from normalized relationships (`Species` <->> `Sighting`).
*   **Dates**: Current models use String representations for many dates. SwiftData migration should standardize on `Date` objects.
*   **Dynamic Types**: `DynamicCard` combines multiple logical entities. This should likely be split into distinct `Migration` and `Hotspot` entities.
*   **Computed/Cached Data**: The `spotSpeciesCountCache` is a runtime calculation. In SwiftData, this could potentially be a complex predicate query or a persisted property updated via triggers.

## 5. Feature & Data Logic (Inferred for Database Design)

Based on architectural clarification, the database design must support the following distinct behaviors:

### A. Data Classification
1.  **Reference Data (Read-Only)**
    *   **Content**: Bird Species taxonomy, images, and the massive dataset of "base sightings" (probability maps).
    *   **Usage**: The *Prediction Engine* uses this exclusively.
    *   **Constraint**: User observations are **never** fed back into this dataset. It is a static (or OTA updated) source of truth.

2.  **User Data (Read/Write)**
    *   **Content**: Watchlists, personal observations, settings.
    *   **Storage**: Local persistent store (SwiftData), potentially synced.

### B. Feature Mechanics
*   **Hotspots (Location-Centric)**
    *   **Query**: "At *Coordinate X*, during *Week Y*, which birds are present?"
    *   **Input**: Location + Time.
    *   **Output**: List of Birds.
*   **Migration (Species-Centric)**
    *   **Query**: "Where is *Bird Z* migrating during *Week Y*?"
    *   **Input**: Species + Time.
    *   **Output**: Path/Coordinates.
*   **Community Observations**
    *   **Source**: Fetched from a remote server.
    *   **Local Strategy**: The local database acts as a **cache** or temporary store for offline viewing, not the master record.
*   **Watchlist & Notifications**
    *   **Behavior**: Items in the watchlist have specific settings (e.g., `notify_upcoming`).
    *   **Architecture**: A rich SwiftData model already exists in `@Watchlist/Model/` (containing Rules, Entries, Status). The Home module's "Upcoming Birds" should eventually query this rich data source rather than the static `home_data.json`.