# 🔍 Identification Tab Feature Documentation

The Identification module is a logic-driven engine designed to help users identify bird species in the field through a structured, multi-step process.

---

## 1. Overview

Accessible via the **Identification** tab, this feature guides the user through narrowing down potential species matches by providing geographic, temporal, and morphological data. The system combines strict filtering (Shape) with "fuzzy" matching (Size and Field Marks) to produce a prioritized list of probable matches.

---

## 2. Core Architecture

The feature is built on a clean MVC architecture with a central state manager.

### 🧠 The Logic Engine (`IdentificationManager`)
The brain of the module. It maintains the session state and executes the **Confidence Ranking** algorithm:
*   **Filtering Logic:** Eliminates species that don't match the selected general shape.
*   **Scoring Logic:** Applies weighted scores based on size similarity, seasonal presence in the selected location, and matching field mark variations.
*   **Persistence:** Handles saving and loading of `IdentificationSession` and `IdentificationResult` objects via SwiftData.

### 📊 Data Persistence (`IdentificationModels.swift`)
Utilizes a relational SwiftData schema to manage:
*   **`Bird`:** Core species data and characteristics.
*   **`BirdShape`:** Categorical silhouetting data.
*   **`BirdFieldMark` & `FieldMarkVariant`:** Detailed morphological data used for the dynamic GUI.

---

## 3. The Guided Identification Flow

Users are guided through a series of interactive steps to provide sighting data.

### 📍 Step 1: Context (`DateandLocationViewController`)
Captures when and where the bird was seen. Supports GPS-tagged "Current Location" and manual map selection.

### 📏 Step 2: Scale (`IdentificationSizeViewController`)
Uses an interactive slider and visual reference birds to help users estimate the specimen's size category.

### 🦅 Step 3: Silhouette (`IdentificationShapeViewController`)
Allows users to select the general body shape (e.g., Wader, Songbird). This selection acts as a primary filter for the logic engine.

### 🎨 Step 4: Markings (`IdentificationFieldMarksViewController`)
An interactive step where users pick up to five distinctive body parts (e.g., Crown, Wings) on a bird silhouette.

### 🛠️ Step 5: Visual GUI (`GUIViewController`)
The most advanced step. Users select specific visual patterns (e.g., "Striped," "Crested") for their chosen body parts. The module uses a dynamic canvas to build a composite visual of the bird in real-time.

### 🏆 Step 6: Results (`ResultViewController`)
Presents a ranked list of candidate species with confidence percentages. Users can save the result to their history or directly add the identified bird to a collection in the **Watchlist** tab.
