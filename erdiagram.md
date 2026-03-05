// -----------------------------------------------------------------------------
// SwiftData Models DBML for dbdiagram.io
// -----------------------------------------------------------------------------

// MARK: - Enums

Enum WatchlistType {
  custom
  shared
  my_watchlist
}

Enum WatchlistEntryStatus {
  to_observe
  observed
}

Enum WatchlistSharePermission {
  view
  edit
  admin
}

Enum WatchlistRuleType {
  location
  date_range
  species_family
  migration_pattern
}

Enum SessionStatus {
  inProgress
  completed
  abandoned
}

// MARK: - Reference & Core Bird Models

Table Bird {
  id UUID [primary key]
  commonName String
  scientificName String
  staticImageName String
  family String
  order_name String
  descriptionText String
  conservation_status String
  migration_strategy String
  hemisphere String
  validLocations "[String]"
  validMonths "[Int]"
  likelySpot String
  // Note: shape_id, size_category, and fieldMarkData are omitted (legacy)
}

Table BirdShape {
  id String [primary key]
  name String
  icon String
}
Ref: Bird.id - BirdShape.id

Table BirdFieldMark {
  id UUID [primary key]
  shape_id String
  area String
}
Ref: BirdFieldMark.shape_id > BirdShape.id

Table FieldMarkVariant {
  id UUID [primary key]
  fieldMark_id UUID
  name String
}
Ref: FieldMarkVariant.fieldMark_id > BirdFieldMark.id

Table BirdFieldMarkVariantLink {
  id UUID [primary key]
  bird_id UUID
  fieldMark_id UUID
  variant_id UUID
  area String
}
Ref: BirdFieldMarkVariantLink.bird_id > Bird.id
Ref: BirdFieldMarkVariantLink.fieldMark_id > BirdFieldMark.id
Ref: BirdFieldMarkVariantLink.variant_id > FieldMarkVariant.id


// MARK: - Watchlist Models

Table Watchlist {
  id UUID [primary key]
  owner_id UUID
  type WatchlistType
  title String
  location String
  locationDisplayName String
  startDate Date
  endDate Date
  observedCount Int
  speciesCount Int
  coverImagePath String
  syncStatusRaw String
  lastSyncedAt Date
  serverRowVersion Int
  created_at Date
  updated_at Date
  deleted_at Date
}

Table WatchlistEntry {
  id UUID [primary key]
  watchlist_id UUID
  bird_id UUID
  nickname String
  status WatchlistEntryStatus
  notes String
  addedDate Date
  observationDate Date
  toObserveStartDate Date
  toObserveEndDate Date
  observedBy String
  observedByUserId UUID
  lat Double
  lon Double
  locationDisplayName String
  priority Int
  notify_upcoming Bool
  syncStatusRaw String
  lastSyncedAt Date
  serverRowVersion Int
}
Ref: WatchlistEntry.watchlist_id > Watchlist.id
Ref: WatchlistEntry.bird_id > Bird.id

Table WatchlistRule {
  id UUID [primary key]
  watchlist_id UUID
  rule_type WatchlistRuleType
  lat Double
  lon Double
  radius_km Double
  start_date Date
  end_date Date
  shape_id String
  pattern_key String
  is_active Bool
  priority Int
  syncStatusRaw String
  lastSyncedAt Date
  serverRowVersion Int
  created_at Date
  deleted_at Date
}
Ref: WatchlistRule.watchlist_id > Watchlist.id

Table WatchlistShare {
  id UUID [primary key]
  watchlist_id UUID
  user_id UUID
  permission WatchlistSharePermission
  shared_at Date
  shared_by_user_id UUID
  syncStatusRaw String
  serverRowVersion Int
  lastSyncedAt Date
  deleted_at Date
}
Ref: WatchlistShare.watchlist_id > Watchlist.id

Table ObservedBirdPhoto {
  id UUID [primary key]
  watchlistEntry_id UUID
  imagePath String
  storageUrl String
  syncStatusRaw String
  lastSyncedAt Date
  serverRowVersion Int
  captured_at Date
  uploaded_at Date
}
Ref: ObservedBirdPhoto.watchlistEntry_id > WatchlistEntry.id


// MARK: - Identification Models

Table IdentificationSession {
  id UUID [primary key]
  ownerId UUID
  shape_id String
  locationId UUID
  locationDisplayName String
  observationDate Date
  status SessionStatus
  sizeCategory Int
  selectedFilterCategories "[String]"
  syncStatusRaw String
  serverRowVersion Int64
  lastSyncedAt Date
  createdAt Date
  created_at Date
  updated_at Date
  deletedAt Date
}
Ref: IdentificationSession.shape_id > BirdShape.id

Table IdentificationSessionFieldMark {
  id UUID [primary key]
  session_id UUID
  fieldMark_id UUID
  variant_id UUID
  area String
}
Ref: IdentificationSessionFieldMark.session_id > IdentificationSession.id
Ref: IdentificationSessionFieldMark.fieldMark_id > BirdFieldMark.id
Ref: IdentificationSessionFieldMark.variant_id > FieldMarkVariant.id

Table IdentificationResult {
  id UUID [primary key]
  session_id UUID
  bird_id UUID
  ownerId UUID
  syncStatus String
  serverRowVersion Int64
  lastSyncedAt Date
  createdAt Date
  created_at Date
  updated_at Date
  deletedAt Date
}
Ref: IdentificationResult.session_id - IdentificationSession.id
Ref: IdentificationResult.bird_id > Bird.id

Table IdentificationCandidate {
  id UUID [primary key]
  result_id UUID
  bird_id UUID
  confidence Double
  rank Int
  matchScore String // Struct MatchScore mapping
  syncStatus String
  serverRowVersion Int64
  lastSyncedAt Date
  created_at Date
  updated_at Date
  deletedAt Date
}
Ref: IdentificationCandidate.result_id > IdentificationResult.id
Ref: IdentificationCandidate.bird_id > Bird.id


// MARK: - Hotspot Models

Table Hotspot {
  id UUID [primary key]
  name String
  locality String
  lat Double
  lon Double
  imageName String
}

Table HotspotSpeciesPresence {
  id UUID [primary key]
  hotspot_id UUID
  bird_id UUID
  validWeeks "[Int]"
  weeklyProbabilities "[Int]"
  probability Int
}
Ref: HotspotSpeciesPresence.hotspot_id > Hotspot.id
Ref: HotspotSpeciesPresence.bird_id > Bird.id


// MARK: - Migration Models

Table MigrationSession {
  id UUID [primary key]
  bird_id UUID
  startWeek Int
  endWeek Int
  hemisphere String
}
Ref: MigrationSession.bird_id > Bird.id

Table TrajectoryPath {
  id UUID [primary key]
  session_id UUID
  week Int
  lat Double
  lon Double
  probability Int
}
Ref: TrajectoryPath.session_id > MigrationSession.id

Table MigrationDataPayload {
  id UUID [primary key]
  session_id UUID
  weeklyData Data
}
Ref: MigrationDataPayload.session_id > MigrationSession.id


// MARK: - Community Models

Table CommunityObservation {
  id UUID [primary key]
  observationId String
  username String
  userAvatar String
  observationTitle String
  location String
  lat Double
  lon Double
  observedAt Date
  likesCount Int
  imageName String
  birdName String
}
