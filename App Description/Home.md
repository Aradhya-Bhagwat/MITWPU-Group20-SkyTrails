# 🏠 Home Tab Feature Documentation

![Status](https://img.shields.io/badge/Status-Implemented-brightgreen)

The Home module serves as the primary entry point for SkyTrails users, providing a dynamic and personalized dashboard of birding insights based on their current location and interests.

---

## 🧩 Architecture & Logic

The Home tab is powered by the `HomeManager`, which coordinates multiple data streams to build a comprehensive `HomeScreenData` object.

### 1. Data Orchestration (`HomeManager`)
*   **Location-Aware Fetching:** Automatically resolves the user's current GPS coordinates using `LocationService` or falls back to `LocationPreferences` if GPS is unavailable.
*   **Multi-Source Integration:** Combines migration trajectory data, curated hotspots, and ornithology news into a unified data structure.
*   **Asynchronous Loading:** Uses Swift's `async/await` and `Task` blocks to perform network and database queries in parallel, ensuring the UI remains responsive.
*   **ML Data Integration:** Integrates local machine learning snapshots from `MLdata.json` to provide specific migration predictions for featured species.

### 2. UI Components (`HomeViewController`)
*   **Compositional Layout:** Utilizes a highly customized `UICollectionViewCompositionalLayout` with four distinct sections, each with its own scrolling behavior and item sizing.
*   **Interactive Transitions:** Implements smooth `UIView.transition` with cross-dissolve effects when data updates, and spring-based animations for cell presentation.
*   **Semantic Design:** Automatically adapts to Light and Dark modes using `registerForTraitChanges`, with specialized shadow handling and background colors.

---

## ✨ Key Functional Sections

### 🗺️ Your Area - Migration Carousel (Section 0)
*   **Feature:** A high-impact carousel showing active bird migrations and hotspots in the user's immediate vicinity.
*   **Technical Detail:** Uses `NewMigrationCollectionViewCell` which integrates an interactive `MKMapView` to display trajectory paths and pinpoint hotspots.
*   **Deep Linking:** Tapping a card opens the `PredictMapViewController` for detailed spot analysis.

### 🦅 Migrations Near You (Section 1)
*   **Feature:** Displays upcoming bird migrations tailored to the user's location, along with a "Predict Migrations" action button.
*   **Logic:** Uses `UpcomingBirdsCollectionViewCell` to show species names and their expected week ranges (e.g., "Week 42 - Week 46").
*   **Interaction:** Tapping a bird card navigates to the `birdspredViewController` (Bird Map Result) for visual migration forecasting.

### 📍 Top Birding Spots (Section 2)
*   **Feature:** A curated list of nearby birding hotspots with a "Find Your Spots" search action.
*   **Technical Detail:** Uses `SpotsToVisitCollectionViewCell` to show the spot's image, name, and the number of species likely to be present.
*   **Predictive Engine:** Tapping a spot triggers a navigation to `PredictMapViewController` with pre-calculated species probabilities.

### 📰 Birders' Gossip (Section 3)
*   **Feature:** A horizontally paging news feed aggregating the latest ornithology research and community updates.
*   **Technical Detail:** Implements a group-paging-centered layout with a custom `PageControlReusableViewCollectionReusableView` footer.
*   **Experience:** Links to external content via a native `InAppBrowserViewController` for a seamless reading experience.
