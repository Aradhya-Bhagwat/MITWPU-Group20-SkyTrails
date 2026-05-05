library(jsonlite)
library(dplyr)
library(httr)

message("Starting grid hotspots generation...")
script_start_time <- Sys.time()
total_rows_written <- 0L

# ── Environment variables ──────────────────────────────────────────────────────
required_env <- c(
  "SUPABASE_URL",
  "SUPABASE_SERVICE_ROLE_KEY",
  "EBIRD_API_KEY"
)

missing_env <- required_env[Sys.getenv(required_env) == ""]
if (length(missing_env) > 0) {
  stop(paste("Missing required environment variables:",
             paste(missing_env, collapse = ", ")))
}

supabase_url              <- sub("/$", "", Sys.getenv("SUPABASE_URL"))
supabase_service_role_key <- Sys.getenv("SUPABASE_SERVICE_ROLE_KEY")
ebird_api_key             <- Sys.getenv("EBIRD_API_KEY")

message("Configuration loaded.")

# ── India bounding box — must match generate_grid_trends.R exactly ─────────────
INDIA_LAT_MIN  <-  6.0
INDIA_LAT_MAX  <- 37.5
INDIA_LON_MIN  <- 68.0
INDIA_LON_MAX  <- 97.5
GRID_SIZE      <-  0.5
TOP_N_HOTSPOTS <- 10L
EBIRD_RADIUS_KM <- 40L    # covers the 0.5 degree cell from its centre

lat_breaks <- seq(INDIA_LAT_MIN, INDIA_LAT_MAX, by = GRID_SIZE)
lon_breaks <- seq(INDIA_LON_MIN, INDIA_LON_MAX, by = GRID_SIZE)

grid_cells <- expand.grid(lat_sw = lat_breaks, lon_sw = lon_breaks) %>%
  tibble::as_tibble() %>%
  mutate(
    grid_id    = sprintf("%.1f_%.1f", lat_sw, lon_sw),
    lat_centre = lat_sw + GRID_SIZE / 2,
    lon_centre = lon_sw + GRID_SIZE / 2
  )

message(sprintf("Grid: %d cells to process.", nrow(grid_cells)))

# ── Null coalescing helper ─────────────────────────────────────────────────────
`%||%` <- function(lhs, rhs) {
  if (is.null(lhs) || length(lhs) == 0 || is.na(lhs[1])) rhs else lhs
}

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
    stop(sprintf("%s failed: %s", error_context,
                 paste(output, collapse = "\n")))
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

supabase_upsert <- function(path, body_rows, on_conflict,
                            error_context = "Supabase upsert") {
  tmp_json <- tempfile(fileext = ".json")
  on.exit(unlink(tmp_json), add = TRUE)
  writeLines(jsonlite::toJSON(body_rows, auto_unbox = TRUE, null = "null"),
             tmp_json)

  url <- paste0(supabase_url, "/rest/v1/", path,
                "?on_conflict=",
                utils::URLencode(on_conflict, reserved = TRUE))

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

# ── eBird hotspot fetch ────────────────────────────────────────────────────────
fetch_hotspots_for_cell <- function(lat, lon, radius_km, api_key) {
  url <- sprintf(
    "https://api.ebird.org/v2/ref/hotspot/geo?lat=%.4f&lng=%.4f&dist=%d&fmt=json",
    lat, lon, radius_km
  )

  tryCatch({
    resp <- httr::GET(
      url,
      httr::add_headers("X-eBirdApiToken" = api_key),
      httr::timeout(30)
    )

    if (httr::status_code(resp) != 200) {
      message(sprintf("    eBird returned %d for lat=%.2f lon=%.2f",
                      httr::status_code(resp), lat, lon))
      return(NULL)
    }

    content <- httr::content(resp, as = "text", encoding = "UTF-8")
    if (!nzchar(content) || content == "[]") return(NULL)

    parsed <- jsonlite::fromJSON(content, simplifyVector = TRUE)
    if (is.null(parsed) || nrow(parsed) == 0) return(NULL)

    parsed
  }, error = function(e) {
    message(sprintf("    Error fetching hotspots: %s", conditionMessage(e)))
    NULL
  })
}

# ── Main loop ──────────────────────────────────────────────────────────────────
now_utc <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

for (g_idx in seq_len(nrow(grid_cells))) {
  cell <- grid_cells[g_idx, ]

  if (g_idx %% 50 == 0 || g_idx == 1) {
    message(sprintf("Processing cell %d/%d — %s",
                    g_idx, nrow(grid_cells), cell$grid_id))
  }

  hotspots <- fetch_hotspots_for_cell(
    lat       = cell$lat_centre,
    lon       = cell$lon_centre,
    radius_km = EBIRD_RADIUS_KM,
    api_key   = ebird_api_key
  )

  if (is.null(hotspots)) {
    # No hotspots found for this cell — skip, don't write empty row
    next
  }

  # Sort by numSpeciesAllTime descending, take top 5
  if ("numSpeciesAllTime" %in% names(hotspots)) {
    hotspots <- hotspots %>%
      arrange(desc(numSpeciesAllTime)) %>%
      slice_head(n = TOP_N_HOTSPOTS)
  } else {
    hotspots <- hotspots %>%
      slice_head(n = TOP_N_HOTSPOTS)
  }

  # Build clean hotspot list
  hotspot_list <- lapply(seq_len(nrow(hotspots)), function(i) {
    h <- hotspots[i, ]
    list(
      hotspot_id      = as.character(h$locId      %||% ""),
      name            = as.character(h$locName    %||% ""),
      lat             = as.numeric(h$lat          %||% 0),
      lon             = as.numeric(h$lng          %||% 0),
      checklist_count = as.integer(h$numSpeciesAllTime %||% 0L)
    )
  })

  row <- list(
    grid_id      = cell$grid_id,
    lat_sw       = cell$lat_sw,
    lon_sw       = cell$lon_sw,
    hotspots     = hotspot_list,
    last_updated = now_utc
  )

  supabase_upsert(
    "grid_hotspots",
    body_rows   = list(row),
    on_conflict = "grid_id",
    error_context = sprintf("Upserting grid_hotspots for %s", cell$grid_id)
  )

  total_rows_written <- total_rows_written + 1L

  # Polite delay — eBird rate limit is 100 requests/min
  Sys.sleep(0.65)
}

# ── Pipeline run log ───────────────────────────────────────────────────────────
pipeline_log <- list(
  script_name  = "generate_grid_hotspots",
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

message(sprintf("\nDone. %d grid cells written to grid_hotspots.",
                total_rows_written))
