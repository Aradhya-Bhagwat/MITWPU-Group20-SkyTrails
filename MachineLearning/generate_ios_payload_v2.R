# Generate iOS HomeDataPayload for Amur Falcon (V2 - Weighted Centroid + iOS-compatible schema)
# Changes from V1:
#   - Trajectory now uses probability-weighted centroid instead of argmax (which.max).
#     This produces a smooth, biologically meaningful path that tracks the centre of mass
#     of the population distribution across each week.
#   - Output JSON schema now matches exactly what the iOS app expects (MigrationSessionData /
#     TrajectoryPathData DTOs): every entry has a UUID "id" field, birdId is the canonical
#     Amur Falcon UUID, hemisphere is set, and hotspotIds use the UUIDs from home_data.json.
#   - Output is wrapped in { "migration_sessions": [...] } — a drop-in entry ready to be
#     copy-pasted into the migration_sessions array in home_data.json.

library(BirdFlowR)
library(jsonlite)
library(terra)
library(uuid)

# 1. LOAD THE FITTED MODEL
model_path <- "amufal1_2023_27km_obs1.0_ent0.0001_dist0.01_pow0.4.hdf5"
if (!file.exists(model_path)) stop("Model file not found: ", model_path)
bf <- import_birdflow(model_path)

# 2. DEFINE REAL HOTSPOTS with their canonical UUIDs from home_data.json
real_hotspots <- data.frame(
  hotspotId = c(
    "B0A1C2D3-E4F5-4678-90AB-CDEF12345678",  # Pangti Village, Nagaland
    "C1B2A3D4-E5F6-4789-01BC-DEF234567890",  # Doyang Reservoir, Nagaland
    "D2C3B4A5-F6E7-4890-12CD-EF3456789012",  # Umrangso, Assam
    "E3D4C5B6-A7B8-4901-23DE-F45678901234"   # Lonavala Roost, Maharashtra
  ),
  lat = c(26.21, 26.20, 25.51, 18.75),
  lon = c(94.13, 94.25, 92.74, 73.40),
  stringsAsFactors = FALSE
)

# 3. HELPER TO CONVERT X/Y TO LAT/LON
convert_to_latlon <- function(x, y, model_crs) {
  pt <- vect(matrix(c(x, y), ncol = 2), crs = model_crs)
  pt_ll <- project(pt, "EPSG:4326")
  ll_matrix <- crds(pt_ll)
  return(list(lat = as.numeric(ll_matrix[1, "y"]), lon = as.numeric(ll_matrix[1, "x"])))
}

# 4. GENERATE WEIGHTED-CENTROID TRAJECTORY PATH (Timesteps 1-13)
#    For each timestep we compute the probability-weighted mean of ALL non-zero cells.
#    This tracks the true centre of mass of the population distribution and produces
#    a far smoother, more meaningful path than picking a single argmax cell.
timesteps <- 1:13
model_crs <- crs(bf)

trajectory_paths <- lapply(timesteps, function(ts) {
  distr <- get_distr(bf, ts)

  nonzero_i <- which(distr > 0)

  if (length(nonzero_i) == 0) {
    # Fallback: use argmax if distribution is entirely zero (should not happen)
    max_i <- which.max(distr)
    xy <- i_to_xy(max_i, bf)
    ll <- convert_to_latlon(xy$x, xy$y, model_crs)
    peak_prob <- as.integer(distr[max_i] * 100)
  } else {
    all_xy  <- i_to_xy(nonzero_i, bf)
    weights <- distr[nonzero_i]

    wmean_x <- sum(all_xy$x * weights) / sum(weights)
    wmean_y <- sum(all_xy$y * weights) / sum(weights)

    ll <- convert_to_latlon(wmean_x, wmean_y, model_crs)
    # probability represents the peak (max) probability across all cells this week
    peak_prob <- as.integer(max(distr) * 100)
  }

  iso_week <- bf$dates$week[ts]

  list(
    id          = UUIDgenerate(),
    week        = iso_week,
    lat         = round(ll$lat, 4),
    lon         = round(ll$lon, 4),
    probability = peak_prob
  )
})

# 5. SCORE REAL HOTSPOTS across ALL timesteps
#    Returns the peak probability for each hotspot over the full migration window,
#    using the timestep at which that hotspot's cell has the highest sighting probability.
hotspot_scores <- lapply(1:nrow(real_hotspots), function(i) {
  pt     <- vect(matrix(c(real_hotspots$lon[i], real_hotspots$lat[i]), ncol = 2), crs = "EPSG:4326")
  pt_xy  <- project(pt, model_crs)
  xy_mat <- crds(pt_xy)

  target_i <- xy_to_i(xy_mat[1, "x"], xy_mat[1, "y"], bf)

  # Collect this hotspot cell's probability across every timestep
  probs_across_timesteps <- sapply(1:n_timesteps(bf), function(ts) {
    get_distr(bf, ts)[target_i]
  })

  peak_prob <- as.integer(max(probs_across_timesteps) * 100)

  list(
    hotspotId   = real_hotspots$hotspotId[i],
    probability = peak_prob
  )
})

# 6. ASSEMBLE THE MIGRATION SESSION in the exact iOS MigrationSessionData schema
migration_session <- list(
  id             = UUIDgenerate(),
  birdId         = "550e8400-e29b-41d4-a716-446655440007",  # Amur Falcon canonical UUID
  startWeek      = 40,
  endWeek        = 52,
  hemisphere     = "Northern",
  trajectoryPaths = trajectory_paths,
  hotspotScores  = hotspot_scores
)

# Wrap in migration_sessions array — drop-in ready for home_data.json
output <- list(
  migration_sessions = list(migration_session)
)

# 7. EXPORT
output_file <- "AmurFalcon_migration_session_v2.json"
write_json(output, output_file, auto_unbox = TRUE, pretty = TRUE)

message("Done. Payload written to: ", output_file)
message("To use: copy the object inside migration_sessions[] into the")
message("        migration_sessions array in SkyTrails/SkyTrails/Home/Model/home_data.json")
