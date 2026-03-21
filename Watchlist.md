# 📋 Watchlist Tab Feature Documentation

The Watchlist module is a comprehensive system for organizing and tracking bird species, providing users with both individual and collaborative tools to manage their birding discoveries.

---

## 1. Overview

Accessible via the **Watchlist** tab, this feature allows users to maintain detailed records of their sightings and plan future encounters. It distinguishes between birds the user wants **to observe** and birds they **have observed**.

Key capabilities include personal collections, shared watchlists for community collaboration, and a powerful **automated filter engine** that populates lists based on location, timeframe, or species morphology.

---

## 2. Core Architecture

The module follows a service-oriented pattern coordinated by the `WatchlistManager`.

### 💾 Persistence Layer (`WatchlistPersistenceService`)
Handles all CRUD (Create, Read, Update, Delete) operations using **SwiftData**. This layer is responsible for the atomic storage of `Watchlist` and `WatchlistEntry` models.

### 🔍 Query Engine (`WatchlistQueryService`)
Processes complex data requests, including:
*   **Virtual Aggregation:** Generates the "Your Favorites" (My Watchlist) view by aggregating unique species from across all collections.
*   **Search & Filtering:** Provides high-performance searching across thousands of species and entries.

### ⚙️ Rule Engine (`WatchlistRuleService`)
The "Smart Filter" backend. It evaluates user-defined rules (e.g., "Add all Raptor-shaped birds within 50km") and automatically updates watchlists.

### 🖼️ Media Service (`WatchlistPhotoService`)
Manages high-resolution photo attachments for sightings, handling local file system storage and linking them to SwiftData records.

---

## 3. User Interface & Flow

### 📋 Watchlist Dashboard (`WatchlistHomeViewController`)
The primary hub of the tab. It features:
*   **Aggregated Favorites:** A high-level overview of the user's entire collection.
*   **Action Hub:** Quick access to "Log Observation" and "Track New Bird."
*   **Collection Carousel:** A visual list of personal and shared collections.

### 🔭 Collection Details (`SmartWatchlistViewController`)
A versatile list view for any collection.
*   **Segmented Tracking:** Toggle between "Sightings" (observed) and "To Discover" (unobserved).
*   **Rich Bird Cells:** Displays bird images, precision timestamps, and GPS-tagged locations.

### ⚙️ Collection Settings (`EditWatchlistDetailViewController`)
A comprehensive form for creating and configuring collections.
*   **Smart Filters:** A dedicated UI for setting up automatic inclusion rules based on Region Boundaries, Temporal Bounds, and Species Inclusion.

### 📸 Precision Logging (`ObservedDetail` & `UnobservedDetail`)
Specialized forms for capturing sighting details.
*   **Observed:** Fields for exact date/time, GPS coordinates (via interactive map), field notes, and photo uploads.
*   **To Discover:** Planning tools for setting target discovery windows and locations.
