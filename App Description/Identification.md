# 🔍 Identification Tab Feature Documentation

![Status](https://img.shields.io/badge/Status-Implemented-brightgreen)

The Identification module is a logic-driven engine designed to help users identify bird species in the field through a structured, multi-step process that combines hard filtering with probabilistic matching.

---

## 1. Overview

Accessible via the **Identification** tab, this feature allows users to provide sighting details such as date, location, size, and markings to narrow down the probable bird species. The module supports saving completed sessions to a local history for future reference.

---

## 2. Core Architecture

The module is built on a robust MVC architecture with a central state manager and specialized image services.

### 🧠 The Logic Engine (`IdentificationManager`)
The heart of the identification process. It maintains session state and executes the **Confidence Ranking** algorithm:
*   **Filtering Categories:** Supports four primary data points: Location & Date, Size, Shape, and Field Marks. A minimum of two categories must be selected to start the process.
*   **Dynamic Data Seeding:** Features an automatic `IdentificationSeeder` that populates the local SwiftData store with shapes, field marks, and species mappings on the first run.
*   **Ranking Algorithm:** Calculates confidence scores based on morphological similarity, seasonal availability, and geographic likelihood.

### 🖼️ Image Service (`IdentificationImageService`)
An asynchronous service that manages bird imagery for the identification process:
*   **Prefetching:** Automatically prefetches images for candidate birds and historical records to ensure a zero-lag user experience.
*   **Manifest Management:** Maintains a dynamic manifest of bird imagery to ensure that only the most relevant assets are kept in memory.

---

## 3. The Identification Flow

### 🚦 Selection View (`IdentificationViewController`)
The primary entry point where users select which filters to apply.
*   **History Collection:** Displays previous successful identifications in a scrollable collection view, grouped by date.
*   **Validation:** Enables the "Start Identification" button only when sufficient criteria (at least 2 filters) are selected.

### 📍 Step 1: Context (`DateandLocationViewController`)
Captures the observation's date and location. Integrates with GPS or allows manual placement on a map to narrow down species by their regional ranges.

### 📏 Step 2: Scale (`IdentificationSizeViewController`)
Guides users to estimate the bird's size using a visual comparison scale, ranging from very small (e.g., Flowerpecker) to very large (e.g., Flamingo).

### 🦅 Step 3: Silhouette (`IdentificationShapeViewController`)
Presents a grid of bird silhouettes (Wader, Songbird, Raptor, etc.) to apply a primary categorical filter to the candidate list.

### 🎨 Step 4: Markings & GUI (`IdentificationFieldMarksViewController` & `GUIViewController`)
*   **Markings:** Users select which body parts (Crown, Wing, Tail, etc.) had distinct features.
*   **Advanced GUI:** For each selected body part, users choose from a visual gallery of patterns (e.g., Striped, Spotted, Crested). This builds a comprehensive visual profile of the sighted bird.

### 🏆 Results (`ResultViewController`)
Presents a ranked list of candidate species with confidence percentages.
*   **Detailed View:** Users can tap on a candidate to view high-resolution images and full species descriptions.
*   **Persistence:** Once a species is confirmed, the session is marked as `completed` and saved to the user's history in SwiftData.
