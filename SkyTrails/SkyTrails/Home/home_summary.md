# Home Module Technical Summary

> **PURPOSE:** This document details the technical state of the Home module's data models, persistence mechanisms, and data flows. It reflects the post-migration state using SwiftData.

## 0. Build Mandate (For Agents)

To build this project for debugging on the target simulator, use the following command:
```bash
xcodebuild -project SkyTrails/SkyTrails.xcodeproj -scheme SkyTrails -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M3),OS=26.2' build
```

## 1. Data Models

The Home module uses a mix of SwiftData entities and lightweight UI-specific structs.

### UI Models (`HomeModels.swift` & `HomeViewController.swift`)
These models are used for display in collection views and are not persisted directly.
*   **`UpcomingBirdUI`**: Displays upcoming bird sightings (`title`, `date`, `imageName`).
*   **`PopularSpotUI`**: Displays birding locations (`title`, `location`, `speciesCount`, `imageName`).
*   **`BirdCategory`**: Static categories for filtering (`icon`, `title`).
*   **`NewsItem`**: Displays external news links.
*   **`HomeScreenData`**: A container struct for the complete home screen state, populated by `HomeManager`.

### SwiftData Entities (Integrated via Managers)
The module consumes data from the following core entities:
*   **`Bird`**: Core species data.
*   **`Hotspot`**: Location data with associated species.
*   **`MigrationSession`**: Active migration events.
*   **`CommunityObservation`**: User-contributed sightings.

## 2. Persistence & Data Management (`HomeManager.swift`)

`HomeManager` is a singleton facade that integrates multiple specialized managers to provide a unified data source for the Home screen.

### Dependency Injection (Internal)
It delegates complex logic to:
*   **`WatchlistManager`**: For user-specific birds and locations.
*   **`HotspotManager`**: For location-based bird presence predictions.
*   **`MigrationManager`**: For tracking active migration trajectories.
*   **`CommunityObservationManager`**: For fetching and filtering user sightings.

### Key Logic
*   **SwiftData Integration**: Uses `WatchlistManager.shared.context` to ensure consistency across the app.
*   **Location Awareness**: Prioritizes `LocationPreferences.shared.homeLocation` or real-time GPS coordinates to filter content.
*   **Caching**: Maintains a `spotSpeciesCountCache` for performance during collection view scrolling.

## 3. Key Data Flows

### A. Dashboard Initialization
1.  **View Load**: `HomeViewController` calls `homeManager.getHomeScreenData(userLocation:)`.
2.  **Aggregation**: `HomeManager` executes parallel requests to its internal managers.
3.  **Filtering**:
    *   `getUpcomingBirds()`: Checks the next 4 weeks of probability data for watchlist birds.
    *   `getRecommendedSpots()`: Finds `Hotspot` entities within a 100km radius of the user.
    *   `getActiveMigrations()`: Filters `MigrationSession` entities active in the current week.
4.  **Binding**: Data is converted to UI models (`UpcomingBirdUI`, etc.) and loaded into the `UICollectionView`.

### B. Navigation & Detail Flows
*   **Spot Selection**: Tapping a spot triggers `getLivePredictions(for:lon:radiusKm:)` to fetch real-time data for that specific location.
*   **Bird Selection**: Tapping an upcoming bird navigates to the prediction map for that species.
*   **Migration Cards**: Uses `getDynamicMapCards()` to create a hybrid view showing both the bird's path and nearby hotspots.

## 4. Architectural Considerations

*   **Concurrency**: Data loading is performed in `Task { @MainActor in ... }` blocks to keep the UI responsive.
*   **State Management**: The `HomeScreenData` struct acts as a snapshot. Refreshing the home screen (e.g., in `viewWillAppear`) re-fetches this entire snapshot from the SwiftData store.
*   **Legacy Support**: `HomeManager` maintains bridge methods (`predictBirds`, `getRelevantSightings`) to support older view controllers that haven't been fully refactored to the new architecture.
