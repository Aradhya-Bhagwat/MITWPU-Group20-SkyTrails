library(DBI)
library(RPostgres)
library(jsonlite)
library(dplyr)
library(readr)
library(stringr)
library(uuid)
library(ebirdst)
library(terra)

message("Starting hotspot species cache generation...")

required_env <- c(
  "SUPABASE_DB_HOST",
  "SUPABASE_DB_PORT",
  "SUPABASE_DB_NAME",
  "SUPABASE_DB_USER",
  "SUPABASE_DB_PASSWORD",
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

db_host <- Sys.getenv("SUPABASE_DB_HOST")
db_port <- as.integer(Sys.getenv("SUPABASE_DB_PORT"))
db_name <- Sys.getenv("SUPABASE_DB_NAME")
db_user <- Sys.getenv("SUPABASE_DB_USER")
db_password <- Sys.getenv("SUPABASE_DB_PASSWORD")
ebirdst_key <- Sys.getenv("EBIRD_STATUS_TRENDS_ACCESS_KEY")
status_data_dir <- Sys.getenv(
  "EBIRD_STATUS_TRENDS_DATA_DIR",
  unset = file.path(getwd(), "MachineLearning", "ebirdst_data")
)

dir.create(status_data_dir, recursive = TRUE, showWarnings = FALSE)

ebirdst::set_ebirdst_access_key(ebirdst_key)

con <- DBI::dbConnect(
  RPostgres::Postgres(),
  host = db_host,
  port = db_port,
  dbname = db_name,
  user = db_user,
  password = db_password,
  sslmode = "require"
)

on.exit({
  if (DBI::dbIsValid(con)) {
    DBI::dbDisconnect(con)
  }
}, add = TRUE)

message("Configuration loaded and database connection established.")
message(sprintf("Using Status and Trends data directory: %s", status_data_dir))

hotspots_query <- "
  select
    hotspot_geo_id,
    ebird_hotspot_id,
    name,
    locality,
    st_y(location::geometry) as lat,
    st_x(location::geometry) as lng
  from public.hotspots_geo
  where ebird_hotspot_id is not null
"

birds_query <- "
  select
    bird_id,
    common_name,
    scientific_name,
    static_image_name
  from public.birds
"

hotspots <- DBI::dbGetQuery(con, hotspots_query) %>%
  tibble::as_tibble()

birds_lookup <- DBI::dbGetQuery(con, birds_query) %>%
  tibble::as_tibble() %>%
  mutate(
    common_name_key = str_to_lower(str_trim(common_name)),
    scientific_name_key = str_to_lower(str_trim(scientific_name))
  )

status_trends_species <- ebirdst::ebirdst_runs %>%
  tibble::as_tibble() %>%
  transmute(
    ebird_species_code = species_code,
    common_name,
    scientific_name,
    common_name_key = str_to_lower(str_trim(common_name)),
    scientific_name_key = str_to_lower(str_trim(scientific_name)),
    is_migrant
  )

if (nrow(hotspots) == 0) {
  stop("No hotspots found in public.hotspots_geo.")
}

if (nrow(birds_lookup) == 0) {
  stop("No birds found in public.birds.")
}

message(sprintf("Loaded %d hotspots.", nrow(hotspots)))
message(sprintf("Loaded %d birds for lookup.", nrow(birds_lookup)))
message(sprintf(
  "Loaded %d modeled species from ebirdst_runs.",
  nrow(status_trends_species)
))

current_week_number <- as.integer(format(Sys.Date(), "%V"))
target_weeks <- unique((((current_week_number - 1) + 0:2) %% 53) + 1)

week_label <- function(week_number) {
  sprintf("Week %d", week_number)
}

resolve_week_layer_index <- function(raster_obj, week_number) {
  layer_count <- terra::nlyr(raster_obj)
  if (layer_count <= 0) {
    stop("Status-and-Trends raster has no layers.")
  }

  as.integer(min(week_number, layer_count))
}

match_bird_metadata <- function(common_name, scientific_name, birds_tbl) {
  sci_key <- str_to_lower(str_trim(scientific_name %||% ""))
  common_key <- str_to_lower(str_trim(common_name %||% ""))

  if (nzchar(sci_key)) {
    sci_match <- birds_tbl %>%
      filter(scientific_name_key == sci_key) %>%
      slice_head(n = 1)

    if (nrow(sci_match) > 0) {
      return(sci_match)
    }
  }

  common_match <- birds_tbl %>%
    filter(common_name_key == common_key) %>%
    slice_head(n = 1)

  if (nrow(common_match) > 0) {
    return(common_match)
  }

  tibble::tibble(
    bird_id = NA_character_,
    common_name = common_name,
    scientific_name = scientific_name,
    static_image_name = NA_character_
  )
}

`%||%` <- function(lhs, rhs) {
  if (is.null(lhs) || length(lhs) == 0 || is.na(lhs)) rhs else lhs
}

build_candidate_species <- function(birds_tbl, status_trends_tbl) {
  by_scientific_name <- birds_tbl %>%
    filter(!is.na(scientific_name_key), scientific_name_key != "") %>%
    inner_join(
      status_trends_tbl %>%
        filter(!is.na(scientific_name_key), scientific_name_key != ""),
      by = "scientific_name_key",
      suffix = c("_bird", "_st")
    )

  by_common_name <- birds_tbl %>%
    filter(!is.na(common_name_key), common_name_key != "") %>%
    inner_join(
      status_trends_tbl %>%
        filter(!is.na(common_name_key), common_name_key != ""),
      by = "common_name_key",
      suffix = c("_bird", "_st")
    )

  bind_rows(by_scientific_name, by_common_name) %>%
    transmute(
      bird_id,
      common_name = coalesce(common_name_bird, common_name_st),
      scientific_name = coalesce(scientific_name_bird, scientific_name_st),
      static_image_name,
      ebird_species_code,
      is_migrant
    ) %>%
    distinct(ebird_species_code, .keep_all = TRUE) %>%
    arrange(common_name)
}

candidate_species <- build_candidate_species(
  birds_tbl = birds_lookup,
  status_trends_tbl = status_trends_species
)

if (nrow(candidate_species) == 0) {
  stop("No overlap found between public.birds and ebirdst_runs.")
}

message(sprintf(
  "Resolved %d candidate species shared between birds and Status and Trends.",
  nrow(candidate_species)
))
message(sprintf(
  "Target weeks for this run: %s",
  paste(target_weeks, collapse = ", ")
))

raster_cache <- new.env(parent = emptyenv())

load_species_abundance_raster <- function(species_code, data_dir) {
  if (exists(species_code, envir = raster_cache, inherits = FALSE)) {
    return(get(species_code, envir = raster_cache, inherits = FALSE))
  }

  tryCatch(
    {
      ebirdst::ebirdst_download_status(species = species_code, path = data_dir)
      raster_obj <- ebirdst::load_raster(
        species = species_code,
        product = "abundance",
        period = "weekly",
        resolution = "27km",
        path = data_dir
      )
      assign(species_code, raster_obj, envir = raster_cache)
      raster_obj
    },
    error = function(error) {
      message(sprintf(
        "Skipping species %s because status data could not be loaded: %s",
        species_code,
        conditionMessage(error)
      ))
      NULL
    }
  )
}

extract_hotspot_abundance <- function(raster_obj, lat, lng, week_number) {
  if (is.null(raster_obj)) {
    return(NA_real_)
  }

  layer_index <- resolve_week_layer_index(raster_obj, week_number)
  hotspot_point <- terra::vect(
    matrix(c(lng, lat), ncol = 2),
    type = "points",
    crs = "EPSG:4326"
  )

  extracted <- terra::extract(raster_obj[[layer_index]], hotspot_point)
  if (nrow(extracted) == 0) {
    return(NA_real_)
  }

  as.numeric(extracted[[2]][[1]])
}

normalize_probabilities <- function(values) {
  valid_values <- values[is.finite(values) & values > 0]
  if (length(valid_values) == 0) {
    return(rep(0L, length(values)))
  }

  max_value <- max(valid_values)
  scaled <- round((pmax(values, 0) / max_value) * 100)
  as.integer(pmin(pmax(scaled, 0), 100))
}

get_hotspot_species_for_week <- function(hotspot_row, week_number, candidate_species_tbl, data_dir) {
  scored_species <- lapply(seq_len(nrow(candidate_species_tbl)), function(idx) {
    species_row <- candidate_species_tbl[idx, ]
    species_code <- species_row$ebird_species_code[[1]]
    raster_obj <- load_species_abundance_raster(species_code, data_dir)
    abundance_value <- extract_hotspot_abundance(
      raster_obj = raster_obj,
      lat = hotspot_row$lat[[1]],
      lng = hotspot_row$lng[[1]],
      week_number = week_number
    )

    tibble::tibble(
      bird_id = species_row$bird_id[[1]],
      ebird_species_code = species_code,
      common_name = species_row$common_name[[1]],
      scientific_name = species_row$scientific_name[[1]],
      image_name = species_row$static_image_name[[1]],
      abundance_value = abundance_value
    )
  }) %>%
    bind_rows() %>%
    filter(is.finite(abundance_value), abundance_value > 0)

  if (nrow(scored_species) == 0) {
    return(tibble::tibble())
  }

  scored_species %>%
    mutate(
      probability = normalize_probabilities(abundance_value),
      residency_status = "Status and Trends",
      rank_score = abundance_value
    ) %>%
    arrange(desc(rank_score), common_name) %>%
    slice_head(n = 12)
}

build_species_payload <- function(species_tbl, week_number, birds_tbl) {
  if (nrow(species_tbl) == 0) {
    return(list(
      species_json = jsonlite::toJSON(list(), auto_unbox = TRUE),
      species_count = 0L
    ))
  }

  rows <- lapply(seq_len(nrow(species_tbl)), function(idx) {
    species_row <- species_tbl[idx, ]
    bird_match <- match_bird_metadata(
      common_name = species_row$common_name,
      scientific_name = species_row$scientific_name,
      birds_tbl = birds_tbl
    )

    list(
      bird_id = bird_match$bird_id[[1]] %||% NULL,
      ebird_species_code = species_row$ebird_species_code[[1]] %||% NULL,
      commonName = species_row$common_name[[1]],
      scientificName = species_row$scientific_name[[1]] %||% NULL,
      imageName = bird_match$static_image_name[[1]] %||% species_row$image_name[[1]] %||% NULL,
      probability = as.integer(round(species_row$probability[[1]] %||% 70)),
      weekNumberValue = as.integer(week_number),
      weekNumber = week_label(week_number),
      residencyStatus = species_row$residency_status[[1]] %||% "Present"
    )
  })

  list(
    species_json = jsonlite::toJSON(rows, auto_unbox = TRUE),
    species_count = length(rows)
  )
}

upsert_cache_row <- function(con, hotspot_geo_id, week_number, payload) {
  sql <- "
    insert into public.hotspot_species_cache (
      hotspot_geo_id,
      week_number,
      species_json,
      species_count,
      source,
      fetched_at,
      updated_at
    )
    values ($1, $2, $3::jsonb, $4, 'ebird_status_trends', now(), now())
    on conflict (hotspot_geo_id, week_number)
    do update set
      species_json = excluded.species_json,
      species_count = excluded.species_count,
      source = excluded.source,
      fetched_at = excluded.fetched_at,
      updated_at = excluded.updated_at
  "

  DBI::dbExecute(
    con,
    sql,
    params = list(
      hotspot_geo_id,
      week_number,
      payload$species_json,
      payload$species_count
    )
  )
}

for (hotspot_idx in seq_len(nrow(hotspots))) {
  hotspot_row <- hotspots[hotspot_idx, ]
  message(sprintf(
    "Processing hotspot %d/%d: %s",
    hotspot_idx,
    nrow(hotspots),
    hotspot_row$name[[1]]
  ))

  for (week_number in target_weeks) {
    species_tbl <- get_hotspot_species_for_week(
      hotspot_row,
      week_number,
      candidate_species,
      status_data_dir
    )
    payload <- build_species_payload(species_tbl, week_number, birds_lookup)
    upsert_cache_row(con, hotspot_row$hotspot_geo_id[[1]], week_number, payload)
  }
}

message("Hotspot species cache generation completed.")
