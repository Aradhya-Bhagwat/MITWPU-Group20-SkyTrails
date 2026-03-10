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

Enum SyncStatus {
  pendingOwner
  pendingCreate
  pendingUpdate
  pendingDelete
  synced
  failed
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

  validLocations "[String]"
  validMonths "[Int]"
  likelySpot String
  shape_id String
  size_category Int
}

Table BirdShape {
  id String [primary key]
  name String
  icon String
}
Ref: Bird.shape_id - BirdShape.id

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

// -----------------------------------------------------------------------------
// Supabase Backend DBML for dbdiagram.io
// -----------------------------------------------------------------------------

Table public.bird_field_mark_variant_links {
  bird_field_mark_variant_link_id uuid [primary key]
  bird_id uuid [not null]
  field_mark_id uuid
  variant_id uuid
  area text [not null]
}

Table public.birds {
  bird_id uuid [primary key]
  common_name text [not null]
  scientific_name text
  static_image_name text
  family text
  order_name text
  description_text text
  conservation_status text
  migration_strategy text
  valid_months jsonb
  shape_id text
  size_category integer
  field_mark_data jsonb
}

Table public.hotspots_geo {
  hotspot_geo_id uuid [primary key]
  ebird_hotspot_id text [unique]
  name text [not null]
  locality text
  location USER-DEFINED [not null]
  image_name text
  updated_at timestamp
}

Table public.identification_candidates {
  identification_candidate_id uuid [primary key]
  identification_result_id uuid
  bird_id uuid
  confidence double_precision
  rank integer
  matched_features ARRAY
  mismatched_features ARRAY
  created_at timestamp
  updated_at timestamp
}

Table public.identification_results {
  identification_result_id uuid [primary key]
  identification_session_id uuid
  user_id uuid
  bird_id uuid
  created_at timestamp
  updated_at timestamp
}

Table public.identification_session_marks {
  identification_session_mark_id uuid [primary key]
  identification_session_id uuid
  field_mark_id uuid
  variant_id uuid
  area text
  created_at timestamp
  updated_at timestamp
}

Table public.identification_sessions {
  identification_session_id uuid [primary key]
  user_id uuid
  status text
  location_lat double_precision
  location_long double_precision
  device_info text
  notes text
  is_public boolean
  weather_conditions text
  metadata jsonb
  created_at timestamp
  updated_at timestamp
}

Table public.news_articles {
  news_article_id uuid [primary key]
  title text
  description text
  image_url text
  article_url text [unique]
  source text
  published_at timestamp
  created_at timestamp
}

Table public.observed_bird_photos {
  observed_bird_photo_id uuid [primary key]
  watchlist_entry_id uuid [not null]
  image_path text [not null]
  storage_url text
  row_version integer
  last_synced_at timestamp
  captured_at timestamp
  uploaded_at timestamp
  created_at timestamp
  updated_at timestamp
}

Table public.photo_delete_gc_queue {
  photo_delete_gc_queue_id uuid [primary key]
  photo_id uuid
  storage_path text [not null]
  status text [not null]
  retry_count integer [not null]
  last_error text
  created_at timestamp [not null]
  updated_at timestamp
}

Table public.user_nearby_spot_cache {
  user_id uuid [primary key]
  anchor_location USER-DEFINED [not null]
  hotspot_id uuid [not null]
  updated_at timestamp
}

Table public.users {
  user_id uuid [primary key]
  name text [not null]
  gender text
  email text [not null]
  profile_photo text
  created_at timestamp
  updated_at timestamp
}

Table auth.users {
  id uuid [primary key]
}

Table public.watchlist_entries {
  watchlist_entry_id uuid [primary key]
  watchlist_id uuid [not null]
  bird_id uuid
  nickname text
  status text [not null]
  notes text
  added_date timestamp
  observation_date timestamp
  to_observe_start_date timestamp
  to_observe_end_date timestamp
  observed_by text
  lat double_precision
  lon double_precision
  location_display_name text
  priority integer
  notify_upcoming boolean
  row_version integer
  last_synced_at timestamp
  deleted_at timestamp
  created_at timestamp
  updated_at timestamp
  observed_by_user_id uuid
}

Table public.watchlist_rule_migration_audit {
  watchlist_rule_migration_audit_id bigint [primary key]
  watchlist_rule_id uuid [not null]
  watchlist_id uuid [not null]
  parameters_json text
  error_reason text [not null]
  captured_at timestamp [not null]
}

Table public.watchlist_rules {
  watchlist_rule_id uuid [primary key]
  watchlist_id uuid [not null]
  rule_type text [not null]
  is_active boolean
  priority integer
  row_version integer
  last_synced_at timestamp
  deleted_at timestamp
  created_at timestamp
  updated_at timestamp
  lat double_precision
  lon double_precision
  radius_km double_precision
  start_date timestamp
  end_date timestamp
  shape_id text
  pattern_key text
}

Table public.watchlist_shares {
  watchlist_share_id uuid [primary key]
  watchlist_id uuid [not null]
  user_id uuid [not null]
  permission text
  shared_at timestamp
  shared_by_user_id uuid
  sync_status text [not null]
  server_row_version integer [not null]
  last_synced_at timestamp
  deleted_at timestamp
}

Table public.watchlists {
  watchlist_id uuid [primary key]
  user_id uuid
  type text
  title text
  location text
  location_display_name text
  start_date timestamp
  end_date timestamp
  observed_count integer
  species_count integer
  cover_image_path text
  row_version integer
  last_synced_at timestamp
  deleted_at timestamp
  created_at timestamp
  updated_at timestamp
}

// Relationships
Ref: public.bird_field_mark_variant_links.bird_id > public.birds.bird_id
Ref: public.identification_candidates.identification_result_id > public.identification_results.identification_result_id
Ref: public.identification_candidates.bird_id > public.birds.bird_id
Ref: public.identification_results.identification_session_id > public.identification_sessions.identification_session_id
Ref: public.identification_results.user_id > auth.users.id
Ref: public.identification_results.bird_id > public.birds.bird_id
Ref: public.identification_session_marks.identification_session_id > public.identification_sessions.identification_session_id
Ref: public.identification_sessions.user_id > auth.users.id
Ref: public.observed_bird_photos.watchlist_entry_id > public.watchlist_entries.watchlist_entry_id
Ref: public.user_nearby_spot_cache.user_id > auth.users.id
Ref: public.user_nearby_spot_cache.hotspot_id > public.hotspots_geo.hotspot_geo_id
Ref: public.users.user_id - auth.users.id
Ref: public.watchlist_entries.bird_id > public.birds.bird_id
Ref: public.watchlist_entries.observed_by_user_id > auth.users.id
Ref: public.watchlist_entries.watchlist_id > public.watchlists.watchlist_id
Ref: public.watchlist_rule_migration_audit.watchlist_rule_id > public.watchlist_rules.watchlist_rule_id
Ref: public.watchlist_rule_migration_audit.watchlist_id > public.watchlists.watchlist_id
Ref: public.watchlist_rules.watchlist_id > public.watchlists.watchlist_id
Ref: public.watchlist_shares.watchlist_id > public.watchlists.watchlist_id
Ref: public.watchlist_shares.user_id > auth.users.id
Ref: public.watchlist_shares.shared_by_user_id > auth.users.id
Ref: public.watchlists.user_id > auth.users.id
