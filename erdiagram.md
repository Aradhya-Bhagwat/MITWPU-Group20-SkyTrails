# 📊 SkyTrails Entity-Relationship Diagram

This document defines the data architecture for SkyTrails, covering both the local **SwiftData** persistence layer and the **Supabase** cloud backend. The schema is designed to support offline-first capabilities with robust cloud synchronization.

---

## 💾 Local Persistence (SwiftData)

The local schema is optimized for high-performance native queries and reactive UI updates.

### Core Models (DBML)

```dbml
// MARK: - Enums
Enum WatchlistType { custom; shared; my_watchlist }
Enum WatchlistEntryStatus { to_observe; observed }
Enum WatchlistRuleType { location; date_range; species_family; migration_pattern }

// MARK: - Reference Data
Table Bird {
  id UUID [primary key]
  commonName String
  scientificName String
  staticImageName String
  family String
  order_name String
  shape_id String
  size_category Int
}

Table BirdShape {
  id String [primary key]
  name String
  icon String
}

// MARK: - Watchlist Management
Table Watchlist {
  id UUID [primary key]
  type WatchlistType
  title String
  location String
  startDate Date
  endDate Date
}

Table WatchlistEntry {
  id UUID [primary key]
  watchlist_id UUID
  bird_id UUID
  status WatchlistEntryStatus
  notes String
  observationDate Date
}

Table WatchlistRule {
  id UUID [primary key]
  watchlist_id UUID
  rule_type WatchlistRuleType
  radius_km Double
  is_active Bool
}

// Relationships
Ref: Bird.shape_id > BirdShape.id
Ref: WatchlistEntry.watchlist_id > Watchlist.id
Ref: WatchlistEntry.bird_id > Bird.id
Ref: WatchlistRule.watchlist_id > Watchlist.id
```

---

## ☁️ Backend Schema (Supabase/PostgreSQL)

The cloud schema mirrors essential local data for cross-device syncing and collaborative features (Shared Watchlists).

### Database Features
*   **PostGIS:** Used for advanced geospatial queries (e.g., finding birds within a 50km radius).
*   **Row Level Security (RLS):** Ensures private data is only accessible to the owner.
*   **Realtime:** Enables collaborative updates for shared collections.

### Sync Architecture
SkyTrails uses a **Timestamp-based Conflict Resolution** strategy. Each record includes a `row_version` and `last_synced_at` field to manage updates between the local device and the cloud.

---

## 🛠️ Usage for Developers

To visualize or modify this schema:
1.  Copy the DBML code above.
2.  Paste it into [dbdiagram.io](https://dbdiagram.io).
3.  The tool will generate a full visual ER Diagram.
