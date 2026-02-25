# 🐦 SkyTrails: Your Personal Birding Companion

SkyTrails is a comprehensive iOS application designed for birdwatching enthusiasts. It provides a powerful suite of tools to help users create and manage watchlists, log sightings, identify birds through a step-by-step process, and visualize migration patterns. This project was developed by a team of four passionate students, blending software engineering with a love for conservation.

<p align="center">
  <!-- TODO: Add a GIF or screenshot of the app's home screen -->
  <img src="" alt="App Demo" width="300"/>
</p>

---

## ✨ Core Features

The app is built around three core modules: Watchlist, Identification, and Migration.

### 🔭 Watchlist & Sighting Log
A powerful system for tracking birds you want to see and those you have already found.

*   **Virtual "My Watchlist":** An aggregated dashboard showing all unique species from your other lists, giving you a single place to see your entire collection.
*   **Custom & Shared Watchlists:** Create personal lists for specific locations or trips (e.g., "Himalayan Expedition").
*   **Automated Rule Engine:** Automatically populate watchlists by defining rules based on criteria like **location**, **date range**, **bird shape**, and **rarity**.
*   **Sighting Status:** Each bird is tracked as either **"Observed"** or **"To Observe"**.
*   **Detailed Logging:** Log your sightings with crucial details, including precise date and time, location (via search or map pin), personal notes, and **photo uploads**.

### 🔍 Bird Identification
A step-by-step guided flow to help you identify a bird even if you only have a few details.

*   **Multi-Factor Filtering:** Start by narrowing down possibilities based on **location**, **date**, **size**, and general **shape**.
*   **Interactive Field Mark GUI:** Select distinct body parts on a bird silhouette (e.g., Crown, Wings, Tail) and then choose from visual variations (e.g., "Crested," "Striped," "Solid") on a dynamic canvas that updates in real-time.
*   **Ranked Results:** The app provides a ranked list of the most likely species based on your input, complete with confidence scores.

### 🗺️ Migration Tracking
Visualize and understand the incredible journeys of migratory birds.

*   **Interactive Map:** View predicted migration routes and timings.
*   **Species-Specific Patterns:** Explore data based on weather, historical trends, and known species behavior.

---

## 🛠️ Technology Stack

*   **UI Framework:** UIKit, Storyboards, Auto Layout
*   **Database:** SwiftData
*   **Location Services:** CoreLocation, MapKit
*   **Primary Language:** Swift 5

---

## 📂 Project Structure

The project is organized into modules based on the app's core features to ensure a clean and scalable architecture.

```
SkyTrails/
├── Home/         # Dashboard, news, and summary views
├── Watchlist/    # Core feature for creating and managing bird lists
├── Identification/ # Multi-step user flow for identifying birds
├── Migration/    # Views and logic for migration tracking
├── Profile/      # User profile and settings
└── Shared/       # Reusable components, services, and storyboards
```

---

## 💻 Installation and Setup

To get a local copy of the project up and running, follow these steps.

#### Prerequisites

*   **Xcode:** Latest stable version (e.g., Xcode 15+).
*   **iOS SDK:** Targeting iOS 17.0+.
    
#### Steps

1.  **Clone the Repository:**
    ```bash
    git clone https://github.com/aradhya0507/SkyTrails.git
    ```
2.  **Navigate to the Project Directory:**
    ```bash
    cd SkyTrails
    ```
3.  **Build and Run:**
    *   Open the `.xcodeproj` file in Xcode.
    *   Select a simulator or a physical device and press **Cmd + R** to build and run the application.

---

## 🧑‍💻 The Development Team

SkyTrails is a student project created by:

| Name                   | Contact                               |
| :--------------------- | :------------------------------------ |
| **Aradhya Bhagwat**    | `aradhya.bhagwat@mitwpu.edu.in`   |
| **Disha Jain**         | `disha.jain@mitwpu.edu.in`        |
| **Tanmay Dani**        | `tanmay.dani@mitwpu.edu.in`       |
| **Soumyadeep Guria**   | `soumyadeep.guria@mitwpu.edu.in`  |

---

## 🙏 Acknowledgements

We would like to express our sincere gratitude to the mentors and faculty members who supported and guided us throughout the development of **SkyTrails**.

### 🌟 Industry Mentors

We are especially thankful to:

- **Amit Sir ** 
- **Swaroop Sir ** 
- **Prasad Sir ** 

Their expert inputs and encouragement significantly contributed to enhancing the overall quality and direction of our application.

---

### 🎓 Faculty Mentors – MIT World Peace University

We are deeply grateful to our faculty members for their continuous guidance, encouragement, and academic support throughout the project lifecycle.

| Faculty Name | Official Email ID |
|--------------|------------------|
| Dr. Murtuza Dholkawala Sir | `murtuza.dholkawala@mitwpu.edu.in` |
| Dr Abhishek Chunawale Sir| `abhishek.chunawale@mitwpu.edu.in` |
| Dr. Akshita Chanchlani Ma'am| `akshita.chanchlani@mitwpu.edu.in` |
| Prof. Kamakshi Goyal Ma'am | `kamakshi.goyal@mitwpu.edu.in` |
| Dr Yogesh Sumant Sir | `yogesh.sumant@mitwpu.edu.in` |

We sincerely appreciate their unwavering support and mentorship throughout this journey.

## 📄 License

This project is distributed under the **MIT License**. See `LICENSE.md` for more information.
