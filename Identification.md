# SkyTrails Bird Identification Feature Documentation

This document provides a detailed explanation of the bird identification feature in the SkyTrails application. It covers the user flow, the underlying data models, the main logic controllers, and the UI components involved in helping a user identify a bird based on its characteristics.

---

## 1. Overview

The Identification feature is a core component of the SkyTrails app, designed to help users identify a bird they have observed. It works by guiding the user through a series of steps where they provide information about the bird, such as its location, size, shape, and distinct markings (field marks).

Based on this input, the app filters a comprehensive database of birds and presents the user with a ranked list of the most likely matches, complete with images and confidence scores. Users can also view a history of their past identification sessions.

---

## 2. Core Components & Architecture

The feature is built on a Model-View-Controller (MVC) architecture, with a central manager class handling the business logic and state.

### 2.1. Main Hub: `IdentificationViewController`

This is the entry point and main screen for the feature. Its key responsibilities are:
- **Starting a New Session:** It presents a list of identification criteria (Location & Date, Size, Shape, Field Marks). The user must select at least two criteria to begin the identification process.
- **Displaying History:** It fetches and displays a collection of previously completed identification sessions (`HistoryCollectionViewCell`), allowing users to revisit past results.
- **Data Seeding Trigger:** It ensures that the app's database is populated with bird data on the first run by invoking the `IdentificationSeeder`.
- **Flow Management:** It constructs and initiates the sequence of identification steps based on the user's selected criteria.

### 2.2. The Brain: `IdentificationManager`

This is the most critical class in the feature. It acts as the central repository for state and logic throughout the identification process.
- **State Management:** It holds all the user's selections as they progress through the flow, including `selectedDate`, `selectedLocation`, `selectedSizeCategory`, `selectedShape`, and a dictionary of `selectedFieldMarks`.
- **Filtering Logic (`runFilter`):** This is the core algorithm. It iterates through all birds in the database and calculates a confidence score for each one based on the user's input.
    - **Scoring:** The algorithm adds or subtracts points based on how well a bird matches the selected criteria (Shape is a strict filter, while Size is a fuzzy match). Location and seasonal presence are also heavily weighted.
    - **Results:** It produces a sorted list of `IdentificationCandidate` objects, ranked from the highest to the lowest confidence score.
- **Session Management:** It handles the creation, loading, and saving of `IdentificationSession` objects to the SwiftData database. This persists user activity.

### 2.3. Data Models (`IdentificationModels.swift`)

The feature relies on a set of robust SwiftData models to structure and persist information:
- **`Bird`:** Represents a single bird species, containing details like name, image, and its association with size, shape, and field marks.
- **`BirdShape`:** A general bird category (e.g., "Duck-like", "Finch-like").
- **`BirdFieldMark`:** A specific area on a bird's body (e.g., "Crown", "Wings"). Each field mark is associated with a `BirdShape`.
- **`FieldMarkVariant`:** A specific pattern or characteristic for a `BirdFieldMark` (e.g., for the "Back" area, a variant could be "Streaked" or "Solid").
- **`IdentificationSession`:** Records a single identification attempt, storing all the user's selections and the final result.
- **`IdentificationResult`:** Stores the outcome of a session, including the chosen bird and a list of all ranked candidates (`IdentificationCandidate`).
- **`IdentificationCandidate`:** Represents a single bird in the result list, containing a reference to the `Bird` and the calculated `confidence` score.

### 2.4. Data Seeding (`IdentificationSeeder.swift`)

To function, the app needs a pre-populated database. The `IdentificationSeeder` is responsible for this.
- **Data Source:** It reads data from a local JSON file (`bird_database.json`).
- **One-Time Operation:** On the app's first launch, it parses the JSON and populates the SwiftData database with `Bird`, `BirdShape`, `BirdFieldMark`, and `FieldMarkVariant` objects, establishing their relationships.

---

## 3. The Identification Flow: Steps & View Controllers

Once a user starts a session, they are guided through a series of view controllers. The `IdentificationManager` instance is passed from one controller to the next, maintaining the state.

### 3.1. Date & Location (`DateandLocationViewController`)

- **Functionality:** Allows the user to specify when and where the bird was seen.
- **UI:**
    - Uses a `DateInputCell` with a `UIDatePicker` for date selection.
    - Includes a `SearchCell` with a `UISearchBar` for location input. It provides autocomplete suggestions by querying the `LocationService`.
    - Provides options to use the device's "Current Location" or select a location from a map view.

### 3.2. Size (`IdentificationSizeViewController`)

- **Functionality:** Lets the user estimate the bird's size.
- **UI:**
    - A `UISlider` allows the user to select from several size categories (e.g., "Flowerpecker–Sparrow sized").
    - Two `UIImageView`s update to show example birds for the selected size range, providing a visual reference.

### 3.3. Shape (`IdentificationShapeViewController`)

- **Functionality:** Allows the user to select the general body shape of the bird.
- **UI:** A `UICollectionView` displays various bird shapes (e.g., "Wader", "Songbird") using a custom `shapeCollectionViewCell`. The list of available shapes is intelligently filtered based on the size category chosen in the previous step.

### 3.4. Field Marks (`IdentificationFieldMarksViewController`)

- **Functionality:** Lets the user pick up to five general areas on the bird that had distinctive features.
- **UI:**
    - A central `UIImageView` displays a generic bird silhouette.
    - A horizontal `UICollectionView` (`CategoryCell`) shows icons for different body parts (e.g., Head, Tail, Wings).
    - As the user selects areas, the silhouette on the canvas highlights those parts.

### 3.5. GUI Variations (`GUIViewController`)

- **Functionality:** This is the most interactive step. For each "field mark" area selected previously, the user can now choose a specific visual characteristic.
- **UI:**
    - A large central "canvas" view (`canvasContainerView`) displays a composite image of the bird being "built" by the user.
    - Two horizontal `UICollectionView`s are used:
        1. **Categories (`categoriesCollectionView`):** Shows the field mark areas the user selected in the previous step.
        2. **Variations (`variationsCollectionView`):** When a category is selected, this collection view is populated with `VariationCell`s, each showing a different visual pattern for that body part (e.g., "Solid", "Striped", "Crested").
    - Selecting a variation instantly updates the main canvas, providing immediate visual feedback.

### 3.6. Results (`ResultViewController`)

- **Functionality:** This is the final screen, where the app presents its findings.
- **UI:**
    - It displays a grid of `ResultCollectionViewCell`s. Each cell shows a potential bird match, its name, a photo, and the confidence percentage calculated by the `IdentificationManager`.
    - The user can select the bird that they believe is the correct one.
    - Tapping "Save" persists the entire session—including the user's inputs and the final chosen bird—to the database for viewing in the History section.
    - An option to "Restart" allows the user to modify their criteria and re-run the filter without losing their initial selections.

---

## 4. UI Components (Custom Cells & Views)

- **`CategoryCell` / `VariationCell`:** Circular collection view cells with an icon, used in the Field Marks and GUI screens. Their appearance changes to indicate selection (border color, background).
- **`DateInputCell` / `SearchCell`:** Custom table view cells used in the `DateandLocationViewController` to encapsulate the date picker and search bar.
- **`HistoryCollectionViewCell`:** A card-like cell used on the main screen to display a summary of a past identification, including the bird's image and observation date.
- **`ResultCollectionViewCell`:** A card-like cell for the results screen, showing the bird image, name, and confidence score. It includes a menu for actions like "Add to Watchlist".
- **`shapeCollectionViewCell`:** A simple cell with an image and a label used to display bird shapes.
- **Storyboards & XIBs:** The UI is primarily laid out in `Identification.storyboard` and various `.xib` files for the custom cells, defining the visual structure and flow between screens.
