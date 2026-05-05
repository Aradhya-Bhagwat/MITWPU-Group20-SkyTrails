library(jsonlite)
library(dplyr)
library(terra)
library(ebirdst)
library(parallel)

message("Starting grid trends generation...")
script_start_time <- Sys.time()
total_rows_written <- 0L

# ── Environment variables ──────────────────────────────────────────────────────
required_env <- c(
  "SUPABASE_URL",
  "SUPABASE_SERVICE_ROLE_KEY",
  "EBIRD_STATUS_TRENDS_ACCESS_KEY"
)

missing_env <- required_env[Sys.getenv(required_env) == ""]
if (length(missing_env) > 0) {
  stop(paste("Missing required environment variables:",
             paste(missing_env, collapse = ", ")))
}

supabase_url              <- sub("/$", "", Sys.getenv("SUPABASE_URL"))
supabase_service_role_key <- Sys.getenv("SUPABASE_SERVICE_ROLE_KEY")
ebirdst_key               <- Sys.getenv("EBIRD_STATUS_TRENDS_ACCESS_KEY")
status_data_dir           <- Sys.getenv(
  "EBIRD_STATUS_TRENDS_DATA_DIR",
  unset = file.path(getwd(), "MachineLearning", "ebirdst_data")
)

dir.create(status_data_dir, recursive = TRUE, showWarnings = FALSE)
ebirdst::set_ebirdst_access_key(ebirdst_key, overwrite = TRUE)
message("Configuration loaded.")

# ── Parallelisation setup ──────────────────────────────────────────────────────
# Use 6 cores locally (8 core Mac), 2 cores on GitHub Actions free runner
available_cores <- parallel::detectCores(logical = TRUE)
n_cores <- max(1L, min(6L, available_cores - 2L))
message(sprintf("Using %d of %d available cores.", n_cores, available_cores))

# ── Constants ──────────────────────────────────────────────────────────────────
INDIA_LAT_MIN       <-  6.0
INDIA_LAT_MAX       <- 37.5
INDIA_LON_MIN       <- 68.0
INDIA_LON_MAX       <- 97.5
GRID_SIZE           <-  0.5
SAMPLE_POINTS       <- 400L
MAX_SPECIES         <-  60L
ABUNDANCE_THRESHOLD <-  0.05
UPSERT_BATCH_SIZE   <-  50L   # rows per Supabase upsert call

# ── Supabase helpers ───────────────────────────────────────────────────────────
supabase_headers <- function(extra_headers = character()) {
  c(
    "-H", paste0("apikey: ", supabase_service_role_key),
    "-H", paste0("Authorization: Bearer ", supabase_service_role_key),
    extra_headers
  )
}

run_curl_command <- function(args, error_context) {
  quoted_args <- vapply(args, shQuote, character(1))
  command     <- paste("/usr/bin/curl", paste(quoted_args, collapse = " "))
  output      <- system(command, intern = TRUE, ignore.stderr = FALSE)
  status      <- attr(output, "status")
  if (!is.null(status) && status != 0) {
    stop(sprintf("%s failed: %s", error_context, paste(output, collapse = "\n")))
  }
  output
}

run_curl_json <- function(args, error_context) {
  output <- run_curl_command(args, error_context)
  text   <- paste(output, collapse = "\n")
  if (!nzchar(text)) return(NULL)
  parsed <- jsonlite::fromJSON(text, simplifyVector = FALSE)
  if (is.list(parsed) && !is.null(parsed$message)) {
    stop(sprintf("%s failed: %s", error_context, parsed$message))
  }
  parsed
}

supabase_get <- function(path, query = list(), error_context = "Supabase GET") {
  query_parts <- vapply(names(query), function(name) {
    paste0(utils::URLencode(name, reserved = TRUE), "=",
           utils::URLencode(as.character(query[[name]]), reserved = TRUE))
  }, character(1))

  url <- paste0(supabase_url, "/rest/v1/", path)
  if (length(query_parts) > 0) {
    url <- paste0(url, "?", paste(query_parts, collapse = "&"))
  }

  parsed <- run_curl_json(
    c("-sS", "-X", "GET", supabase_headers(), url),
    error_context
  )

  if (is.null(parsed)) return(tibble::tibble())
  if (is.data.frame(parsed)) return(tibble::as_tibble(parsed))
  if (is.list(parsed) && length(parsed) > 0) return(dplyr::bind_rows(parsed))
  tibble::tibble()
}

# Batch upsert — sends multiple rows in one curl call
supabase_upsert_batch <- function(path, body_rows, on_conflict,
                                  error_context = "Supabase upsert") {
  if (length(body_rows) == 0) return(invisible(NULL))

  tmp_json <- tempfile(fileext = ".json")
  on.exit(unlink(tmp_json), add = TRUE)
  writeLines(jsonlite::toJSON(body_rows, auto_unbox = TRUE, null = "null"),
             tmp_json)

  url <- paste0(supabase_url, "/rest/v1/", path,
                "?on_conflict=", utils::URLencode(on_conflict, reserved = TRUE))

  run_curl_command(
    c("-sS", "-X", "POST",
      supabase_headers(c(
        "-H", "Content-Type: application/json",
        "-H", "Prefer: resolution=merge-duplicates,return=minimal"
      )),
      "--data-binary", paste0("@", tmp_json),
      url),
    error_context
  )
}

# ── Build grid ────────────────────────────────────────────────────────────────
lat_breaks <- seq(INDIA_LAT_MIN, INDIA_LAT_MAX, by = GRID_SIZE)
lon_breaks <- seq(INDIA_LON_MIN, INDIA_LON_MAX, by = GRID_SIZE)

grid_cells <- expand.grid(lat_sw = lat_breaks, lon_sw = lon_breaks) %>%
  tibble::as_tibble() %>%
  mutate(
    grid_id = sprintf("%.1f_%.1f", lat_sw, lon_sw),
    lat_ne  = lat_sw + GRID_SIZE,
    lon_ne  = lon_sw + GRID_SIZE
  )

message(sprintf("Grid: %d total cells.", nrow(grid_cells)))

# ── Filter to cells that have hotspot data ────────────────────────────────────
message("Fetching grid cells with hotspot data from Supabase...")
hotspot_grids <- supabase_get(
  "grid_hotspots",
  query = list(select = "grid_id"),
  error_context = "Fetching hotspot grid IDs"
)

if (nrow(hotspot_grids) == 0) {
  stop("No hotspot data found. Run generate_grid_hotspots.R first.")
}

grid_cells <- grid_cells %>%
  filter(grid_id %in% hotspot_grids$grid_id)

message(sprintf("Filtered to %d cells with hotspot data.", nrow(grid_cells)))

# ── Species list ──────────────────────────────────────────────────────────────
all_birds <- supabase_get(
  "birds",
  query = list(select = "species_code"),
  error_context = "Loading master bird list"
)

if (nrow(all_birds) == 0) stop("No birds found in master table.")

test_species <- c('bladro1', 'blakit1', 'commyn', 'brakit1', 'amufal1',
                  'indrol2', 'houspa', 'shikra1', 'asikoe2', 'spoowl1')

candidate_species <- ebirdst::ebirdst_runs %>%
  tibble::as_tibble() %>%
  filter(species_code %in% test_species) %>%
  select(species_code, common_name)

message(sprintf("Processing %d species across %d grid cells.",
                nrow(candidate_species), nrow(grid_cells)))

# ── Pre-generate sample points for every cell (fixed per run) ─────────────────
# Generating random points once avoids repeated runif calls in inner loops
set.seed(42)
cell_sample_pts <- lapply(seq_len(nrow(grid_cells)), function(g_idx) {
  cell <- grid_cells[g_idx, ]
  cbind(
    lon = runif(SAMPLE_POINTS, cell$lon_sw, cell$lon_ne),
    lat = runif(SAMPLE_POINTS, cell$lat_sw, cell$lat_ne)
  )
})
names(cell_sample_pts) <- grid_cells$grid_id
message("Sample points pre-generated for all cells.")

# ── Process one species across all weeks and all cells ────────────────────────
# Returns a flat list of Supabase rows ready to upsert
process_species <- function(sp_code, sp_name, data_dir,
                            grid_cells, cell_sample_pts,
                            target_weeks, sample_points,
                            abundance_threshold, max_species) {

  # Download once — all 52 week layers in one file
  result <- tryCatch({
    ebirdst::ebirdst_download_status(
      species             = sp_code,
      path                = data_dir,
      download_abundance  = TRUE,
      download_occurrence = FALSE,
      download_count      = FALSE,
      download_ranges     = FALSE,
      download_regional   = FALSE,
      download_pis        = FALSE,
      download_ppms       = FALSE,
      download_all        = FALSE
    )
    abd_full <- ebirdst::load_raster(
      species    = sp_code,
      product    = "abundance",
      resolution = "27km",
      path       = data_dir
    )
    abd_full
  }, error = function(e) {
    message(sprintf("  Skipping %s: %s", sp_code, conditionMessage(e)))
    NULL
  })

  if (is.null(result)) return(list())

  abd_full <- result
  sp_rows  <- list()  # accumulate rows across all weeks and cells

  for (week_number in target_weeks) {
    # Extract just this week's layer — no re-download
    raster_layer <- tryCatch(
      terra::subset(abd_full, week_number),
      error = function(e) NULL
    )
    if (is.null(raster_layer)) next

    for (g_idx in seq_len(nrow(grid_cells))) {
      cell    <- grid_cells[g_idx, ]
      pts_mat <- cell_sample_pts[[cell$grid_id]]

      pts  <- terra::vect(pts_mat, crs = "EPSG:4326")
      vals <- terra::extract(raster_layer, pts)[, 2]
      vals <- vals[!is.na(vals)]

      if (length(vals) == 0) next

      hits <- sum(vals > abundance_threshold)
      if (hits == 0) next

      max_abd <- max(vals)
      score   <- 0.7 * max_abd + 0.3 * (hits / sample_points)

      sp_rows[[length(sp_rows) + 1]] <- list(
        grid_id     = cell$grid_id,
        week_number = as.integer(week_number),
        sp_code     = sp_code,
        sp_name     = sp_name,
        max_abd     = round(max_abd, 2),
        hits        = as.integer(hits),
        score       = round(score, 2)
      )
    }
  }

  sp_rows
}

# ── Run species in parallel ───────────────────────────────────────────────────
message(sprintf("\nProcessing %d species in parallel on %d cores...",
                nrow(candidate_species), n_cores))

cl <- parallel::makeCluster(n_cores)
on.exit(parallel::stopCluster(cl), add = TRUE)

# Export everything workers need
parallel::clusterExport(cl, varlist = c(
  "status_data_dir", "grid_cells", "cell_sample_pts",
  "SAMPLE_POINTS", "ABUNDANCE_THRESHOLD", "MAX_SPECIES",
  "candidate_species", "process_species"
), envir = environment())

parallel::clusterEvalQ(cl, {
  library(terra)
  library(ebirdst)
})

all_sp_rows <- parallel::parLapply(
  cl,
  seq_len(nrow(candidate_species)),
  function(sp_idx) {
    sp_code <- candidate_species$species_code[[sp_idx]]
    sp_name <- candidate_species$common_name[[sp_idx]]
    message(sprintf("  [core] Species %d/%d: %s",
                    sp_idx, nrow(candidate_species), sp_name))
    process_species(
      sp_code          = sp_code,
      sp_name          = sp_name,
      data_dir         = status_data_dir,
      grid_cells       = grid_cells,
      cell_sample_pts  = cell_sample_pts,
      target_weeks     = 1:52,
      sample_points    = SAMPLE_POINTS,
      abundance_threshold = ABUNDANCE_THRESHOLD,
      max_species      = MAX_SPECIES
    )
  }
)

parallel::stopCluster(cl)
message("Parallel species processing complete. Aggregating results...")

# ── Aggregate scores per grid_id + week_number ────────────────────────────────
# Flatten all species rows into one list
flat_rows <- do.call(c, all_sp_rows)
message(sprintf("Total species-cell-week observations: %d", length(flat_rows)))

# Group by grid_id + week_number
grouped <- list()
for (row in flat_rows) {
  key <- paste0(row$grid_id, "|", row$week_number)
  if (is.null(grouped[[key]])) {
    grouped[[key]] <- list(
      grid_id     = row$grid_id,
      week_number = row$week_number,
      species     = list()
    )
  }
  grouped[[key]]$species[[length(grouped[[key]]$species) + 1]] <- list(
    id    = row$sp_code,
    name  = row$sp_name,
    max   = row$max_abd,
    hits  = row$hits,
    score = row$score
  )
}

message(sprintf("Unique grid+week combinations: %d", length(grouped)))

# ── Write to Supabase in batches ──────────────────────────────────────────────
message("Writing results to Supabase in batches...")
now_utc    <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
batch      <- list()
batch_count <- 0L

flush_batch <- function(batch) {
  if (length(batch) == 0) return(0L)
  supabase_upsert_batch(
    "regional_trends",
    body_rows   = batch,
    on_conflict = "grid_id,week_number",
    error_context = "Batch upserting regional_trends"
  )
  length(batch)
}

for (key in names(grouped)) {
  grp <- grouped[[key]]

  # Sort species by score, cap at top 60
  scores_sorted <- grp$species[order(
    sapply(grp$species, `[[`, "score"),
    decreasing = TRUE
  )]
  scores_capped <- scores_sorted[seq_len(min(length(scores_sorted), MAX_SPECIES))]

  batch[[length(batch) + 1]] <- list(
    grid_id      = grp$grid_id,
    week_number  = as.integer(grp$week_number),
    species_data = scores_capped,
    last_updated = now_utc
  )

  if (length(batch) >= UPSERT_BATCH_SIZE) {
    written      <- flush_batch(batch)
    total_rows_written <- total_rows_written + written
    batch_count  <- batch_count + 1L
    batch        <- list()
    message(sprintf("  Batch %d written. Total rows: %d",
                    batch_count, total_rows_written))
  }
}

# Flush remaining
if (length(batch) > 0) {
  written            <- flush_batch(batch)
  total_rows_written <- total_rows_written + written
  message(sprintf("  Final batch written. Total rows: %d", total_rows_written))
}

# ── Pipeline run log ──────────────────────────────────────────────────────────
pipeline_log <- list(
  script_name  = "generate_grid_trends",
  started_at   = format(script_start_time, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  finished_at  = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  status       = "success",
  rows_written = as.integer(total_rows_written)
)

supabase_upsert_batch(
  "pipeline_runs",
  body_rows   = list(pipeline_log),
  on_conflict = "script_name",
  error_context = "Logging pipeline run"
)

message(sprintf("\nDone. %d rows written to regional_trends in %.1f minutes.",
                total_rows_written,
                as.numeric(difftime(Sys.time(), script_start_time, units = "mins"))))
