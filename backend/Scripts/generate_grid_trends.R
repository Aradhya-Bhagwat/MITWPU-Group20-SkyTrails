library(jsonlite)
library(dplyr)
library(terra)
library(ebirdst)

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

supabase_url             <- sub("/$", "", Sys.getenv("SUPABASE_URL"))
supabase_service_role_key <- Sys.getenv("SUPABASE_SERVICE_ROLE_KEY")
ebirdst_key              <- Sys.getenv("EBIRD_STATUS_TRENDS_ACCESS_KEY")
status_data_dir          <- Sys.getenv(
  "EBIRD_STATUS_TRENDS_DATA_DIR",
  unset = file.path(getwd(), "MachineLearning", "ebirdst_data")
)

dir.create(status_data_dir, recursive = TRUE, showWarnings = FALSE)
ebirdst::set_ebirdst_access_key(ebirdst_key, overwrite = TRUE)
message("Configuration loaded.")

# ── Helpers ────────────────────────────────────────────────────────────────────
`%||%` <- function(lhs, rhs) {
  if (is.null(lhs) || length(lhs) == 0 || is.na(lhs)) rhs else lhs
}

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

supabase_upsert <- function(path, body_rows, on_conflict,
                            error_context = "Supabase upsert") {
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

# ── India bounding box ─────────────────────────────────────────────────────────
# Covers mainland India + Andaman & Nicobar + Lakshadweep
INDIA_LAT_MIN <-  6.0
INDIA_LAT_MAX <- 37.5
INDIA_LON_MIN <- 68.0
INDIA_LON_MAX <- 97.5
GRID_SIZE     <-  0.5   # degrees — ~55km × 55km
SAMPLE_POINTS <- 400L   # random points per grid cell
MAX_SPECIES   <-  60L   # top species to store per cell per week
ABUNDANCE_THRESHOLD <- 0.05  # minimum abundance to count as present

# ── Build grid cell list ───────────────────────────────────────────────────────
lat_breaks <- seq(INDIA_LAT_MIN, INDIA_LAT_MAX - GRID_SIZE, by = GRID_SIZE)
lon_breaks <- seq(INDIA_LON_MIN, INDIA_LON_MAX - GRID_SIZE, by = GRID_SIZE)

grid_cells <- expand.grid(lat_sw = lat_breaks, lon_sw = lon_breaks) %>%
  tibble::as_tibble() %>%
  mutate(
    grid_id = sprintf("%.1f_%.1f", lat_sw, lon_sw),
    lat_ne  = lat_sw + GRID_SIZE,
    lon_ne  = lon_sw + GRID_SIZE
  )

message(sprintf("Grid: %d cells at 0.5 degree resolution.", nrow(grid_cells)))

# ── Species list — only birds in your master table ─────────────────────────────
all_birds <- supabase_get(
  "birds",
  query = list(select = "species_code"),
  error_context = "Loading master bird list"
)

if (nrow(all_birds) == 0) {
  stop("No birds found in the master table.")
}

candidate_species <- ebirdst::ebirdst_runs %>%
  tibble::as_tibble() %>%
  filter(species_code %in% all_birds$species_code) %>%
  select(species_code, common_name)

message(sprintf("Processing %d species across %d grid cells.",
                nrow(candidate_species), nrow(grid_cells)))

# ── Week range — all 52 weeks ──────────────────────────────────────────────────
target_weeks <- 1:52

# ── Per-species abundance download helper ──────────────────────────────────────
load_abundance_raster <- function(species_code, week_number, data_dir) {
  tryCatch({
    ebirdst::ebirdst_download_status(
      species          = species_code,
      path             = data_dir,
      download_abundance = TRUE,
      download_occurrence = FALSE,
      download_count   = FALSE,
      download_ranges  = FALSE,
      download_regional = FALSE,
      download_pis     = FALSE,
      download_ppms    = FALSE,
      download_all     = FALSE
    )
    abd <- ebirdst::load_raster(
      species   = species_code,
      product   = "abundance",
      resolution = "27km",
      path      = data_dir
    )
    # ebirdst rasters have 52 layers — one per week
    terra::subset(abd, week_number)
  }, error = function(e) {
    message(sprintf("  Skipping %s week %d: %s",
                    species_code, week_number, conditionMessage(e)))
    NULL
  })
}

# ── Main loop: week → grid cell → species ─────────────────────────────────────
# Outer loop is week so we load each species raster once per week
# and sample all grid cells before moving on.

for (week_number in target_weeks) {
  message(sprintf("\n── Week %d/52 ──────────────────────────────", week_number))

  # Collect scores for every grid cell this week
  # grid_scores[[grid_id]] = named list of species scores
  grid_scores <- vector("list", nrow(grid_cells))
  names(grid_scores) <- grid_cells$grid_id

  # Initialise empty score table per grid
  for (gid in names(grid_scores)) {
    grid_scores[[gid]] <- list()
  }

  for (sp_idx in seq_len(nrow(candidate_species))) {
    sp_code <- candidate_species$species_code[[sp_idx]]
    sp_name <- candidate_species$common_name[[sp_idx]]

    message(sprintf("  Species %d/%d: %s",
                    sp_idx, nrow(candidate_species), sp_name))

    raster_layer <- load_abundance_raster(sp_code, week_number, status_data_dir)
    if (is.null(raster_layer)) next

    # Sample each grid cell
    for (g_idx in seq_len(nrow(grid_cells))) {
      cell <- grid_cells[g_idx, ]

      # 400 random points inside this cell
      sample_lons <- runif(SAMPLE_POINTS, cell$lon_sw, cell$lon_ne)
      sample_lats <- runif(SAMPLE_POINTS, cell$lat_sw, cell$lat_ne)
      pts <- terra::vect(
        cbind(sample_lons, sample_lats),
        crs = "EPSG:4326"
      )

      vals <- terra::extract(raster_layer, pts)[, 2]
      vals <- vals[!is.na(vals)]

      if (length(vals) == 0) next

      hits <- sum(vals > ABUNDANCE_THRESHOLD)
      if (hits == 0) next

      max_abd <- max(vals)
      score   <- 0.7 * max_abd + 0.3 * (hits / SAMPLE_POINTS)

      grid_scores[[cell$grid_id]][[sp_code]] <- list(
        id    = sp_code,
        name  = sp_name,
        max   = round(max_abd, 4),
        hits  = as.integer(hits),
        score = round(score, 4)
      )
    }
  }

  # ── Write results for this week to Supabase ──────────────────────────────
  message(sprintf("  Writing week %d results to Supabase...", week_number))
  now_utc <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

  for (g_idx in seq_len(nrow(grid_cells))) {
    cell    <- grid_cells[g_idx, ]
    scores  <- grid_scores[[cell$grid_id]]

    if (length(scores) == 0) next

    # Sort by score descending, cap at top 60
    scores_sorted <- scores[order(
      sapply(scores, `[[`, "score"),
      decreasing = TRUE
    )]
    scores_capped <- scores_sorted[seq_len(min(length(scores_sorted), MAX_SPECIES))]

    row <- list(
      grid_id      = cell$grid_id,
      week_number  = as.integer(week_number),
      lat_sw       = cell$lat_sw,
      lon_sw       = cell$lon_sw,
      species_data = scores_capped,
      last_updated = now_utc
    )

    supabase_upsert(
      "regional_trends",
      body_rows   = list(row),
      on_conflict = "grid_id,week_number",
      error_context = sprintf("Upserting regional_trends %s week %d",
                              cell$grid_id, week_number)
    )

    total_rows_written <- total_rows_written + 1L
  }

  message(sprintf("  Week %d done. Total rows written so far: %d",
                  week_number, total_rows_written))
}

# ── Pipeline run log ───────────────────────────────────────────────────────────
pipeline_log <- list(
  script_name  = "generate_grid_trends",
  started_at   = format(script_start_time, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  finished_at  = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  status       = "success",
  rows_written = as.integer(total_rows_written)
)

supabase_upsert(
  "pipeline_runs",
  body_rows   = list(pipeline_log),
  on_conflict = "script_name",
  error_context = "Logging pipeline run"
)

message(sprintf("\nDone. %d rows written to regional_trends.", total_rows_written))
