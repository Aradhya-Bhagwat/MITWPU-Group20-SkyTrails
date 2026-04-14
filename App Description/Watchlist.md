# 📋 Watchlist Tab Feature Documentation

![Status](https://img.shields.io/badge/Status-Implemented-brightgreen)

The Watchlist module is a comprehensive system for organizing and tracking bird species sightings, providing users with personal and collaborative tools for both historical records and future observations.

---

## 1. Overview

Accessible via the **Watchlist** tab, this feature allows users to maintain detailed records of their sightings and plan future encounters. It distinguish between birds the user wants **to observe** (unobserved) and birds they **have observed**.

Key capabilities include personal collections, shared watchlists for community collaboration, and an **automated smart filter engine** that populates lists based on location, timeframe, or species morphology.

---

## 2. Core Architecture

The module follows a repository pattern coordinated by the `WatchlistManager`.

### 💾 Persistence Layer (`WatchlistManager`)
Handles all CRUD (Create, Read, Update, Delete) operations using **SwiftData**. This layer is responsible for the atomic storage of `Watchlist`, `WatchlistEntry`, and `WatchlistRule` models. It also manages data prefetching and view model generation.

### 🔍 Search & Filtering (`WatchlistRepository`)
Processes complex data requests, including:
*   **Virtual Aggregation:** Generates a "Summary" (My Watchlist) view by aggregating species from the core collection.
*   **Smart Rule Matching:** Evaluates user-defined rules (e.g., "Add all Raptor-shaped birds within 50km") to automatically populate collections.

---

## 3. User Interface & Flow

### 📋 Watchlist Dashboard (`WatchlistHomeViewController`)
The primary hub of the tab, featuring three distinct sections:
*   **Summary (Section 0):** A high-level overview of the user's primary collection and stats, along with quick actions like "Log Observation" and "Find New Species."
*   **Curated Watchlists (Section 1):** A horizontally scrollable list of personal collections (e.g., "Pune Weekend Trip").
*   **Shared Watchlists (Section 2):** Collaborative collections shared with other users for joint birding expeditions.

### 🔭 Collection Details (`SmartWatchlistViewController`)
A versatile list view for any collection.
*   **Segmented Tracking:** Toggle between "Sightings" (observed) and "To Discover" (unobserved) within the same collection.
*   **Rich Bird Cells:** Displays bird images, precision timestamps, and GPS-tagged locations with clear visual distinction.

### ⚙️ Collection Settings (`EditWatchlistDetailViewController`)
A comprehensive form for creating and configuring collections.
*   **Smart Rules:** A dedicated UI for setting up automatic inclusion rules based on geographic boundaries, date ranges, and bird characteristics.
*   **Collaborative Sharing:** Allows users to manage permissions and invite others to shared watchlists.

### 📸 Precision Logging (`ObservedDetailViewController` & `UnobservedDetailViewController`)
Specialized forms for capturing sighting details.
*   **Observed:** Fields for exact date/time, GPS coordinates (via an interactive map), field notes, and high-resolution photo uploads.
*   **To Discover:** Planning tools for setting target discovery windows and preferred locations for new bird encounters.
