# 🏠 Home Tab Feature Documentation

The Home module serves as the primary entry point for SkyTrails users, providing a dynamic and personalized dashboard of birding insights based on their current location and interests.

---

## 🧩 Architecture & Logic

The Home tab is powered by the `HomeManager`, which coordinates multiple data streams to build a comprehensive `HomeScreenData` object.

### 1. Data Orchestration (`HomeManager`)
*   **Location-Aware Fetching:** Automatically resolves the user's current GPS coordinates or uses a preferred home location to filter hotspots and sightings.
*   **Multi-Source Integration:** Combines migration trajectory data, community observations, and ornithology news into a unified stream.
*   **Asynchronous Loading:** Uses Swift's `async/await` to perform network and database queries in parallel, ensuring a responsive UI.

### 2. UI Components (`HomeViewController`)
*   **Compositional Layout:** Utilizes a complex `UICollectionViewCompositionalLayout` to manage multiple distinct sections (Carousels, Grids, and Lists).
*   **Smooth Transitions:** Implements `UIView.transition` with cross-dissolve effects and custom cell animations (`willDisplay`) for a premium "production-ready" feel.
*   **Dynamic Theming:** Supports full semantic appearance, adapting automatically to Light and Dark modes with specialized shadow and background handling.

---

## ✨ Key Functional Sections

### 🗺️ Migration Forecast (Section 0)
*   **Feature:** A high-impact carousel featuring active bird migrations.
*   **Technical Detail:** Uses `NewMigrationCollectionViewCell` which integrates an interactive `MKMapView`.
*   **Smooth Maps:** Features a custom "zoom from space" animation when selecting different species in the migration path.

### 🔭 Birding Highlights (Section 1)
*   **Feature:** Displays upcoming sightings from the user's watchlist and recommended species for the current season.
*   **Logic:** Prioritizes species the user has marked as "To Observe" that are currently active in their vicinity.

### 📍 Top Birding Spots (Section 2)
*   **Feature:** A curated list of nearby hotspots.
*   **Interaction:** Tapping a spot triggers a live prediction engine to show which birds are most likely to be seen there today.

### 🤝 Community Sightings (Section 3)
*   **Feature:** A social feed of observations shared by other birders in the region.
*   **Technical Detail:** Includes page-control indicators and optimized image loading for a smooth scrolling experience.

### 📰 Ornithology News (Section 4)
*   **Feature:** Aggregates the latest research and news from the avian world.
*   **Interaction:** Links directly to high-quality external resources via a native in-app browser experience.
