library(jsonlite)
library(dplyr)
library(stringr)
library(ebirdst)
library(sf)

message("Starting species range generation...")

script_start_time <- Sys.time()
total_rows_written <- 0L

required_env <- c(
  "SUPABASE_URL",
  "SUPABASE_SERVICE_ROLE_KEY",
  "EBIRD_STATUS_TRENDS_ACCESS_KEY"
)

missing_env <- required_env[Sys.getenv(required_env) == ""]
if (length(missing_env) > 0) {
  stop(
    paste(
      "Missing required environment variables:",
      paste(missing_env, collapse = ", ")
    )
  )
}

supabase_url <- sub("/$", "", Sys.getenv("SUPABASE_URL"))
supabase_service_role_key <- Sys.getenv("SUPABASE_SERVICE_ROLE_KEY")
ebirdst_key <- Sys.getenv("EBIRD_STATUS_TRENDS_ACCESS_KEY")
status_data_dir <- Sys.getenv(
  "EBIRD_STATUS_TRENDS_DATA_DIR",
  unset = file.path(getwd(), "MachineLearning", "ebirdst_data")
)
species_code_filter <- Sys.getenv("EBIRD_SPECIES_CODE", unset = "")
target_weeks_env <- Sys.getenv("TARGET_WEEKS", unset = "")

dir.create(status_data_dir, recursive = TRUE, showWarnings = FALSE)

ebirdst::set_ebirdst_access_key(ebirdst_key, overwrite = TRUE)
message("Configuration loaded.")
message(sprintf("Using Status and Trends data directory: %s", status_data_dir))

`%||%` <- function(lhs, rhs) {
  if (is.null(lhs) || length(lhs) == 0 || is.na(lhs)) rhs else lhs
}

run_curl_command <- function(args, error_context) {
  quoted_args <- vapply(args, shQuote, character(1))
  command <- paste("/usr/bin/curl", paste(quoted_args, collapse = " "))
  output <- system(command, intern = TRUE, ignore.stderr = FALSE)
  status <- attr(output, "status")
  if (!is.null(status) && status != 0) {
    stop(sprintf("%s failed: %s", error_context, paste(output, collapse = "\n")))
  }
  output
}

run_curl_json <- function(args, error_context) {
  output <- run_curl_command(args, error_context)
  text <- paste(output, collapse = "\n")
  if (!nzchar(text)) {
    return(NULL)
  }

  parsed <- jsonlite::fromJSON(text, simplifyVector = FALSE)
  if (is.list(parsed) && !is.null(parsed$message)) {
    stop(sprintf("%s failed: %s", error_context, parsed$message))
  }
  parsed
}

supabase_get <- function(path, query = list(), error_context = "Supabase GET") {
  query_parts <- vapply(
    names(query),
    function(name) {
      paste0(
        utils::URLencode(name, reserved = TRUE),
        "=",
        utils::URLencode(as.character(query[[name]]), reserved = TRUE)
      )
    },
    character(1)
  )

  url <- paste0(supabase_url, "/rest/v1/", path)
  if (length(query_parts) > 0) {
    url <- paste0(url, "?", paste(query_parts, collapse = "&"))
  }

  parsed <- run_curl_json(
    c("-sS", "-X", "GET", supabase_headers(), url),
    error_context
  )

  if (is.null(parsed)) {
    return(tibble::tibble())
  }

  if (is.data.frame(parsed)) {
    return(tibble::as_tibble(parsed))
  }

  if (is.list(parsed) && length(parsed) > 0) {
    return(dplyr::bind_rows(parsed))
  }

  tibble::tibble()
}

supabase_headers <- function(extra_headers = character()) {
  c(
    "-H", paste0("apikey: ", supabase_service_role_key),
    "-H", paste0("Authorization: Bearer ", supabase_service_role_key),
    extra_headers
  )
}

supabase_upsert <- function(path, body_rows, on_conflict, error_context = "Supabase upsert") {
  tmp_json <- tempfile(fileext = ".json")
  on.exit(unlink(tmp_json), add = TRUE)
  writeLines(jsonlite::toJSON(body_rows, auto_unbox = TRUE, null = "null"), tmp_json)

  url <- paste0(
    supabase_url,
    "/rest/v1/",
    path,
    "?on_conflict=",
    utils::URLencode(on_conflict, reserved = TRUE)
  )

  run_curl_command(
    c(
      "-sS",
      "-X", "POST",
      supabase_headers(c(
        "-H", "Content-Type: application/json",
        "-H", "Prefer: resolution=merge-duplicates,return=minimal"
      )),
      "--data-binary", paste0("@", tmp_json),
      url
    ),
    error_context
  )
}

supabase_patch <- function(path, body_rows, query = list(), error_context = "Supabase PATCH") {
  tmp_json <- tempfile(fileext = ".json")
  on.exit(unlink(tmp_json), add = TRUE)
  writeLines(jsonlite::toJSON(body_rows, auto_unbox = TRUE, null = "null"), tmp_json)

  query_parts <- vapply(
    names(query),
    function(name) {
      paste0(
        utils::URLencode(name, reserved = TRUE),
        "=",
        utils::URLencode(as.character(query[[name]]), reserved = TRUE)
      )
    },
    character(1)
  )

  url <- paste0(supabase_url, "/rest/v1/", path)
  if (length(query_parts) > 0) {
    url <- paste0(url, "?", paste(query_parts, collapse = "&"))
  }

  run_curl_command(
    c(
      "-sS",
      "-X", "PATCH",
      supabase_headers(c(
        "-H", "Content-Type: application/json",
        "-H", "Prefer: return=minimal"
      )),
      "--data-binary", paste0("@", tmp_json),
      url
    ),
    error_context
  )
}

current_week_number <- as.integer(format(Sys.Date(), "%V"))
target_weeks <- unique((((current_week_number - 1) + 0:2) %% 53) + 1)

if (nzchar(target_weeks_env)) {
  target_weeks <- target_weeks_env %>%
    str_split(",") %>%
    unlist() %>%
    str_trim() %>%
    as.integer() %>%
    unique()
}

message(sprintf("Target weeks for this run: %s", paste(target_weeks, collapse = ", ")))

status_trends_species <- ebirdst::ebirdst_runs %>%
  tibble::as_tibble() %>%
  transmute(
    ebird_species_code = species_code,
    common_name,
    scientific_name
  )

if (nzchar(species_code_filter)) {
  status_trends_species <- status_trends_species %>%
    filter(ebird_species_code == species_code_filter)
} else {
  # Fetch every bird currently in your master birds table
  all_birds <- supabase_get(
    "birds",
    query = list(select = "species_code"),
    error_context = "Loading master bird list"
  )

  if (nrow(all_birds) == 0) {
    message("No birds found in the master table.")
    quit(save = "no", status = 0)
  }

  # Filter status_trends_species to match your database
  test_species <- c('bladro1', 'blakit1', 'commyn', 'brakit1', 'amufal1',
                    'indrol2', 'houspa', 'shikra1', 'asikoe2', 'spoowl1')
   
   status_trends_species <- status_trends_species %>%
   filter(ebird_species_code %in% test_species)

  # We want maps for ALL weeks for these birds, not just a 3-week window
  target_weeks <- 1:52
}

if (nrow(status_trends_species) == 0) {
  stop("No candidate species found for range generation.")
}

message(sprintf("Loaded %d candidate species for range generation.", nrow(status_trends_species)))

season_to_weeks <- list(
  breeding = c(18:30),
  postbreeding = c(31:39),
  nonbreeding = c(c(1:9), 49:53),
  prebreeding = c(10:17)
)

weeks_for_season <- function(season_name) {
  season_key <- tolower(gsub("[^A-Za-z]", "", season_name %||% ""))
  if (season_key %in% c("breeding")) return(season_to_weeks$breeding)
  if (season_key %in% c("postbreeding", "postbreedingmigration")) return(season_to_weeks$postbreeding)
  if (season_key %in% c("nonbreeding", "nonbreedingwinter")) return(season_to_weeks$nonbreeding)
  if (season_key %in% c("prebreeding", "prebreedingmigration")) return(season_to_weeks$prebreeding)
  integer()
}

# India bounding box with small buffer
INDIA_BBOX <- sf::st_bbox(c(
  xmin = 67.0, ymin = 5.0,
  xmax = 98.0, ymax = 38.0
), crs = sf::st_crs(4326)) %>% sf::st_as_sfc()

range_feature_to_geojson <- function(feature_row) {
  tmp_geojson <- tempfile(fileext = ".geojson")
  on.exit(unlink(tmp_geojson), add = TRUE)

  feature_sf    <- sf::st_as_sf(feature_row)
  geometry_only <- sf::st_sf(
    geometry = sf::st_geometry(feature_sf),
    crs      = sf::st_crs(feature_sf)
  )

  # Clip to India bounding box
  clipped <- tryCatch({
    sf::st_intersection(geometry_only, sf::st_transform(INDIA_BBOX, sf::st_crs(feature_sf)))
  }, error = function(e) geometry_only)

  if (nrow(clipped) == 0 || all(sf::st_is_empty(clipped))) return(NULL)

  sf::st_write(clipped, tmp_geojson, driver = "GeoJSON", quiet = TRUE, delete_dsn = TRUE)
  paste(readLines(tmp_geojson, warn = FALSE), collapse = "\n")
}

load_species_ranges <- function(species_code, data_dir) {
  tryCatch(
    {
      ebirdst::ebirdst_download_status(
        species = species_code,
        path = data_dir,
        download_abundance = FALSE,
        download_occurrence = FALSE,
        download_count = FALSE,
        download_ranges = TRUE,
        download_regional = FALSE,
        download_pis = FALSE,
        download_ppms = FALSE,
        download_all = FALSE
      )
      ebirdst::load_ranges(
        species = species_code,
        resolution = "27km",
        smoothed = TRUE,
        path = data_dir
      )
    },
    error = function(error) {
      message(sprintf(
        "Skipping species %s because ranges could not be loaded: %s",
        species_code,
        conditionMessage(error)
      ))
      NULL
    }
  )
}

build_range_rows <- function(species_row, ranges_sf, target_weeks) {
  if (is.null(ranges_sf) || nrow(ranges_sf) == 0) {
    return(list())
  }

  rows <- list()
  for (i in seq_len(nrow(ranges_sf))) {
    feature <- ranges_sf[i, ]
    season_name <- feature$season[[1]] %||% ""
    season_weeks <- weeks_for_season(season_name)
    matching_weeks <- intersect(target_weeks, season_weeks)

    if (length(matching_weeks) == 0) {
      next
    }

    geojson_string <- range_feature_to_geojson(feature)
    if (is.null(geojson_string)) next

    for (week_number in matching_weeks) {
      rows[[length(rows) + 1]] <- list(
        ebird_species_code = species_row$ebird_species_code[[1]],
        scientific_name = species_row$scientific_name[[1]] %||% NULL,
        common_name = species_row$common_name[[1]] %||% NULL,
        week_number = as.integer(week_number),
        range_geojson = geojson_string,
        source = "status_trends_range",
        updated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
      )
    }
  }

  rows
}

for (species_idx in seq_len(nrow(status_trends_species))) {
  species_row <- status_trends_species[species_idx, ]
  species_code <- species_row$ebird_species_code[[1]]

  message(sprintf(
    "Processing species %d/%d: %s (%s)",
    species_idx,
    nrow(status_trends_species),
    species_row$common_name[[1]],
    species_code
  ))

  ranges_sf <- load_species_ranges(species_code, status_data_dir)
  upsert_rows <- build_range_rows(species_row, ranges_sf, target_weeks)

  if (length(upsert_rows) == 0) {
    next
  }

  supabase_upsert(
    "species_ranges",
    body_rows = upsert_rows,
    on_conflict = "ebird_species_code,week_number",
    error_context = sprintf("Upserting species_ranges for %s", species_code)
  )
  total_rows_written <- total_rows_written + length(upsert_rows)
}

message("Species range generation completed.")

# Log pipeline run to Supabase
pipeline_log <- list(
  script_name = "generate_species_ranges",
  started_at  = format(script_start_time, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  finished_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  status      = "success",
  rows_written = as.integer(total_rows_written)
)

supabase_upsert(
  "pipeline_runs",
  body_rows  = list(pipeline_log),
  on_conflict = "script_name",
  error_context = "Logging pipeline run"
)

message("Pipeline run logged.")



