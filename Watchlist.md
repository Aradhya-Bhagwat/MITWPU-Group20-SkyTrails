# SkyTrails Watchlist Feature Documentation

This document provides a comprehensive overview of the Watchlist feature in the SkyTrails application. It details the architecture, data models, user interface flow, and core functionalities that allow users to create, manage, and track lists of birds.

---

## 1. Overview

The Watchlist feature is a powerful tool for bird enthusiasts to organize and track bird species. Users can create multiple watchlists, such as "Backyard Birds," "Himalayan Expedition," or "Jungle Safari."

A key feature is the separation between birds the user wants **to observe** and birds they **have observed**. The system supports personal watchlists, shared watchlists for collaborative tracking with friends, and powerful **auto-assignment rules** that can automatically populate a watchlist based on criteria like location, date, or species type.

The entire feature is built on a robust, service-oriented architecture using SwiftData for persistence.

---

## 2. Core Components & Architecture

The feature's backend logic is organized into a clean, service-oriented architecture coordinated by a central manager. This separates data persistence, complex queries, and business logic from the UI layer.

### 2.1. The Coordinator: `WatchlistManager`

This singleton class is the central point of contact for the UI. It doesn't perform tasks itself but rather **delegates** work to specialized services. Its main roles are:
- **Service Initialization:** It creates and holds instances of all other model-layer services (`Persistence`, `Query`, `Rule`, `Photo`).
- **Public API:** It exposes a unified API for the view controllers (e.g., `loadDashboardData`, `deleteWatchlist`).
- **Seeding Orchestration:** It triggers the initial database population by calling the necessary seeder services.

### 2.2. Services

- **`WatchlistPersistenceService`:** This service is the single source of truth for all direct database interactions. It handles all Create, Read, Update, and Delete (CRUD) operations on the SwiftData models. It contains no business logic, only raw data manipulation.

- **`WatchlistQueryService`:** This service is responsible for complex data fetching, filtering, and aggregation.
    - It builds the Data Transfer Objects (DTOs) that the UI uses, decoupling the view from the raw data models.
    - It handles searching and sorting lists of birds.
    - A key function is creating the **virtual "My Watchlist"**, which is not a separate list in the database but a dynamic aggregation of all unique birds from every other watchlist.

- **`WatchlistRuleService`:** This is the "rule engine" of the feature.
    - It processes the auto-assignment rules that users can define for their custom watchlists.
    - When a rule is applied, it queries the entire bird database and automatically adds any matching birds to the specified watchlist as "to-observe" entries.

- **`WatchlistPhotoService`:** This service manages all aspects of user-uploaded photos for observed birds. It handles saving images to the device's file system and linking the file path to the corresponding `WatchlistEntry` in the database.

### 2.3. Data Models (`WatchlistModel.swift` & `WatchlistDomainModels.swift`)

The feature uses two layers of models:
- **Core Data Models (SwiftData):** These define the database schema.
    - `Watchlist`: Represents a single list (e.g., "Jungle Safari"). It stores the title, type (custom/shared), and its rules.
    - `WatchlistEntry`: A single bird within a `Watchlist`. It links to a `Bird` and stores its status (`observed` or `to_observe`), observation date, notes, and photos.
    - `WatchlistRule`: Defines an automated rule for a watchlist (e.g., "add all birds of the 'Raptor' family").
    - `ObservedBirdPhoto`: A record linking a `WatchlistEntry` to a specific photo file path on disk.
- **Domain Models / DTOs:** These are lightweight, immutable structs (e.g., `WatchlistSummaryDTO`, `WatchlistEntryDTO`) used to pass data to the UI. This prevents the UI from directly interacting with the database models, leading to a cleaner architecture.

### 2.4. Data Seeding (`WatchlistSeeder.swift`)

On first launch, the app populates its database with sample data from `watchlists.json` and `sharedWatchlists.json`. This seeder creates the initial set of custom and shared watchlists, along with the birds and entries within them.

---

## 3. User Interface Flow & View Controllers

### 3.1. Main Dashboard: `WatchlistHomeViewController`

This is the primary screen of the Watchlist feature.
- **Layout:** It uses a modern compositional layout to display different sections.
- **"My Watchlist":** A prominent card at the top shows an aggregated summary of all unique birds across all other watchlists. It includes a collage of bird images and stats for observed vs. unobserved species.
- **Action Cells:** Beside or below the "My Watchlist" card are quick actions like "Add Observed Bird" and "Add Unobserved Bird."
- **Custom & Shared Lists:** It displays horizontally-scrolling lists of `CustomWatchlistCollectionViewCell` and `SharedWatchlistCollectionViewCell` for a quick overview.
- **Navigation:** It serves as the main hub for navigating to all other parts of the feature.

### 3.2. List Detail View: `SmartWatchlistViewController`

This is the versatile screen for viewing the contents of *any* watchlist.
- **Segmented Control:** A prominent "Observed" / "To Observe" segmented control at the top allows the user to toggle between the two lists of entries.
- **Bird List:** A `UITableView` displays the list of `BirdSmartCell`s, each representing a bird in the current view.
- **Functionality:** Users can search, sort, and swipe on entries to perform actions like editing or deleting.

### 3.3. Creating & Editing Watchlists: `EditWatchlistDetailViewController`

This is a detailed form for creating a new watchlist or editing an existing one.
- **Basic Info:** Users can set the watchlist's title, location, and a start/end date.
- **Auto-Assignment Rules:** This is the most powerful part of the screen. A dedicated section allows the user to create rules that automatically populate the watchlist. A user can, for example, create a rule to automatically add all birds from the "Raptor" family that are found within a 50km radius of a specific location on a map. This logic is powered by the `WatchlistRuleService`.

### 3.4. Adding/Editing Observations

- **`ObservedDetailViewController`:** This screen is presented when a user wants to log a new observation or edit an existing one. It includes fields for the date and time of the observation, a text view for notes, a location search bar, and a prominent image view that allows the user to select a photo from their library.
- **`UnobservedDetailViewController`:** This is a simpler detail screen for birds on the "To Observe" list. It primarily allows the user to add notes or specify a target date range for when they hope to see the bird.

### 3.5. Adding Birds to a List: `SpeciesSelectionViewController`

When a user wants to add one or more birds to a watchlist, this screen is presented.
- **Functionality:** It displays a searchable list of all bird species in the database. The user can select multiple birds.
- **Wizard Flow:** After selecting birds and tapping "Next," the controller initiates a "wizard" loop. It presents the appropriate detail screen (`ObservedDetail` or `UnobservedDetail`) for the *first* selected bird. When the user saves that bird, the controller automatically presents the detail screen for the *second* bird, and so on, until all selected birds have been processed.

---

## 4. UI Components (Custom Cells)

The UI is built with a variety of custom, reusable cells that present information in a visually appealing card-based format.

- **`MyWatchlistCollectionViewCell`:** A large, detailed cell for the main dashboard, featuring a photo collage and stat pills.
- **`CustomWatchlistCollectionViewCell`:** A card with a large cover image and text overlay for custom watchlists.
- **`SharedWatchlistCollectionViewCell`:** A horizontal card for shared lists, including a stack of participant avatars.
- **`BirdSmartCell`:** The standard table view cell for showing a bird entry, with its image, name, date, and location.
- **`WatchlistActionCell`:** A simple, tappable cell with a large icon and a title, used for primary actions on the home screen.
- **`WatchlitEmptyCollectionViewCell`:** An informative placeholder shown when a list has no items.
- **Section Headers:** Custom headers (`WatchlistSectionWithPlusCollectionReusableView`) provide titles for collection view sections and include tappable buttons for "See All" or adding new items.
