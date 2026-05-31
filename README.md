# 🐦 SkyTrails: Your Personal Birding Companion

[![iOS](https://img.shields.io/badge/Platform-iOS%2026.0+-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE.md)

SkyTrails is a professional-grade iOS application designed for birdwatching enthusiasts. It provides a robust suite of tools to help users create and manage watchlists, log sightings with precision, identify birds through an interactive guided process, and visualize complex migration patterns.

---

## 🚀 Key Features by Tab

### 🏠 Home Tab
The central hub for discovery and daily birding insights.
*   **Migration Forecast:** A high-performance carousel showing active bird migrations and hotspots.
*   **Discovery Highlights:** Nearby birding spots and upcoming sightings tailored to your location.
*   **Ornithology News:** Stay updated with the latest research and community sightings.

### 📋 Watchlist Tab
A sophisticated system for tracking avian encounters, featuring both personal and collaborative capabilities.
*   **Discovery Dashboard:** An aggregated view of all unique species across your collections.
*   **Curated Collections:** Create personal or shared lists for specific trips (e.g., "Himalayan Expedition").
*   **Intelligent Filter Engine:** Automatically populate watchlists using smart rules based on **location**, **temporal range**, and **bird morphology**.
*   **Precision Logging:** Log sightings with GPS-tagged locations, field notes, and **photo attachments**.

### 🔍 Identification Tab
A logic-driven, step-by-step identification engine designed for accuracy in the field.
*   **Multi-Dimensional Filtering:** Narrow down species by geographic location, date, size, and silhouette.
*   **Dynamic Field Mark GUI:** An interactive canvas allowing users to select visual variations of specific body parts (Crown, Wings, Tail) in real-time.
*   **Confidence Ranking:** View a prioritized list of probable matches with confidence scores.

---

## 🛠️ Technology Stack & Architecture

*   **Target OS:** iOS 26.0+
*   **Language:** Swift 6.0
*   **Architecture:** Clean MVC with Service-Oriented Logic layers.
*   **Persistence:** **SwiftData** for native object persistence.
*   **Geospatial:** CoreLocation and MapKit for precise tracking.

---

## 📂 Project Structure

```
.
├── SkyTrails/                  # iOS Project Container Directory
│   ├── SkyTrails/              # Primary iOS Application Source
│   │   ├── Onboard/            # Authentication & onboarding logic (Supabase Auth)
│   │   ├── Home/               # Discovery dashboard and highlight cards
│   │   ├── Watchlist/          # List management, sighting logs, and offline persistence
│   │   ├── Identification/     # Step-by-step logic-driven bird identification engine
│   │   ├── Profile/            # User profile settings & birding gamification
│   │   ├── Sync/               # Background and real-time data sync with Supabase
│   │   ├── Shared/             # Common coordinators, UI controls, and core utilities
│   │   ├── Resources/          # Static reference bundles (bird_reference_info.json)
│   │   └── Assets.xcassets/    # Theme styling, asset icons, and launch screens
│   ├── SkyTrails.xcodeproj/    # Xcode project configuration
│   ├── SkyTrailsUITests/       # UI automation test suite
│   └── .swiftlint.yml          # Swift code quality linting guidelines
├── backend/                    # Backend data pipeline (R scripts)
│   └── Scripts/                # Cloud workflows for hotspots, trends, and ranges
├── App Description/            # Detailed documentation
│   ├── Home.md                 # Home module architecture
│   ├── Watchlist.md            # Watchlist database and rules mapping
│   ├── Identification.md       # Identification matrix and matcher details
│   ├── Architecture.md         # System design overview (MVC + Service layers)
│   └── ERDiagram.md            # Database schema details
├── .gitignore                  # Git untracked path rules
├── LICENSE.md                  # MIT License details
└── README.md                   # Project overview documentation
```

---

## 💻 Installation & Setup

#### Prerequisites
*   **Xcode 17.0+**
*   **macOS 16.0+**
*   **iOS 26.0+** (Target device or Simulator)

#### Steps
1.  **Clone the Repository:** 
`git clone https://github.com/Aradhya-Bhagwat/MITWPU-Group20-SkyTrails.git`
2.  **Open Project:** Open `SkyTrails/SkyTrails.xcodeproj` in Xcode.
3.  **Build and Run:** Select your target device and press `⌘R`.

---

## 🧑‍💻 The Development Team

SkyTrails was conceptualized and developed by:

| Name                   | Contact                               |
| :--------------------- | :------------------------------------ |
| **Aradhya Bhagwat**    | `aradhyabhagwat@mitwpu.edu.in`   |
| **Disha Jain**         | `disha.jain@mitwpu.edu.in`        |
| **Tanmay Dani**        | `tanmay.dani@mitwpu.edu.in`       |
| **Soumyadeep Guria**   | `soumyadeep.guria@mitwpu.edu.in`  |

---

## 🙏 Acknowledgements

### 🌟 Industry Mentors
*   **Amit Sir** | **Swaroop Sir** | **Prasad Sir** 

### 🎓 Faculty Mentors – MIT World Peace University
| Faculty Name | Official Email ID |
|--------------|------------------|
| Dr. Murtuza Dholkawala Sir | `murtuza.dholkawala@mitwpu.edu.in` |
| Dr Abhishek Chunawale Sir| `abhishek.chunawale@mitwpu.edu.in` |
| Dr. Akshita Chanchlani Ma'am| `akshita.chanchlani@mitwpu.edu.in` |
| Prof. Kamakshi Goyal Ma'am | `kamakshi.goyal@mitwpu.edu.in` |
| Prof. Yogesh Sumant Sir | `yogesh.sumant@mitwpu.edu.in` |

## 📄 License
Distributed under the **MIT License**. See [LICENSE.md](LICENSE.md) for details.
