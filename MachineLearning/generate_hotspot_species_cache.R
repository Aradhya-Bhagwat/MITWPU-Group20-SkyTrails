library(jsonlite)
library(dplyr)
library(readr)
library(stringr)
library(uuid)
library(ebirdst)
library(sf)

message("Starting final robust hotspot species cache generation...")

# --- Configuration ---
required_env <- c("SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY", "EBIRD_STATUS_TRENDS_ACCESS_KEY")
missing_env <- required_env[Sys.getenv(required_env) == ""]
if (length(missing_env) > 0) stop(paste("Missing required environment variables:", paste(missing_env, collapse = ", ")))

supabase_url <- sub("/$", "", Sys.getenv("SUPABASE_URL"))
supabase_service_role_key <- Sys.getenv("SUPABASE_SERVICE_ROLE_KEY")
ebirdst_key <- Sys.getenv("EBIRD_STATUS_TRENDS_ACCESS_KEY")
status_data_dir <- Sys.getenv("EBIRD_STATUS_TRENDS_DATA_DIR", unset = file.path(getwd(), "MachineLearning", "ebirdst_data"))
target_weeks_env <- Sys.getenv("TARGET_WEEKS", unset = "")

dir.create(status_data_dir, recursive = TRUE, showWarnings = FALSE)
ebirdst::set_ebirdst_access_key(ebirdst_key, overwrite = TRUE)

# --- ISO Week Range (Matches Edge Function) ---
current_week <- as.integer(format(Sys.Date(), "%V"))
target_weeks <- if (nzchar(target_weeks_env)) {
  as.integer(unlist(str_split(target_weeks_env, ",")))
} else {
  unique((((current_week - 1) + 0:2) %% 53) + 1) # Matches the 3-week window in Edge Function
}

# --- Season Mapping ---
season_to_weeks <- list(breeding = c(18:30), postbreeding = c(31:39), nonbreeding = c(c(1:9), 49:53), prebreeding = c(10:17))

# --- Supabase Helpers ---
supabase_headers <- function() {
  paste(
    "-H", shQuote(paste0("apikey: ", supabase_service_role_key)),
    "-H", shQuote(paste0("Authorization: Bearer ", supabase_service_role_key)),
    collapse = " "
  )
}

supabase_get <- function(path, query = list()) {
  url <- paste0(supabase_url, "/rest/v1/", path)
  if (length(query) > 0) {
    url <- paste0(url, "?", paste(vapply(names(query), function(n) paste0(URLencode(n), "=", URLencode(as.character(query[[n]]))), character(1)), collapse = "&"))
  }
  command <- paste("/usr/bin/curl -sS -X GET", supabase_headers(), shQuote(url))
  output <- system(command, intern = TRUE)
  if (length(output) == 0) return(tibble::tibble())
  
  parsed <- tryCatch(jsonlite::fromJSON(paste(output, collapse = "\n"), simplifyVector = FALSE), error = function(e) list())
  if (length(parsed) == 0) return(tibble::tibble())
  dplyr::bind_rows(parsed)
}

supabase_upsert <- function(path, body_rows) {
  tmp_json <- tempfile(fileext = ".json")
  writeLines(jsonlite::toJSON(body_rows, auto_unbox = TRUE, null = "null"), tmp_json)
  url <- paste0(supabase_url, "/rest/v1/", path, "?on_conflict=hotspot_geo_id,week_number")
  command <- paste("/usr/bin/curl -sS -X POST", supabase_headers(), "-H 'Content-Type: application/json' -H 'Prefer: resolution=merge-duplicates,return=minimal' --data-binary", shQuote(paste0("@", tmp_json)), shQuote(url))
  system(command)
  unlink(tmp_json)
}

# --- Load Hotspots ---
message("Fetching hotspots from database...")
hotspots_raw <- supabase_get("hotspots_geo", query = list(select = "hotspot_geo_id,name,location"))
if (nrow(hotspots_raw) == 0 || !"location" %in% names(hotspots_raw)) {
  stop("Database returned no hotspots or missing 'location' column.")
}

hotspots_sf <- hotspots_raw %>%
  mutate(
    lng = as.numeric(str_extract(location, "(?<=POINT\\()[-0-9.]+")),
    lat = as.numeric(str_extract(location, "(?<=\\s)[-0-9.0]+(?=\\))"))
  ) %>%
  filter(!is.na(lat), !is.na(lng)) %>%
  st_as_sf(coords = c("lng", "lat"), crs = 4326)

message(sprintf("Loaded %d hotspots. Coordinates parsed successfully.", nrow(hotspots_sf)))

# --- Load Birds ---
birds_lookup <- supabase_get("birds", query = list(select = "id,common_name,scientific_name,species_code,image_url"))
if (nrow(birds_lookup) > 0) {
  birds_lookup <- birds_lookup %>% rename(bird_id = id, ebird_species_code = species_code, static_image_name = image_url)
}

# --- Target Species (India) ---
common_india_codes <- c(
  "asikoel1", "blakit1", "houcro1", "commyn", "rosrin1", "indrol2", "hoopoe", "asipre1", "purcon1", "gretit1",
  "rocpig", "categr", "grecou1", "revbul", "junbab1", "pursun4", "magrob", "indpea", "copbar1", "whtkin2"
)
status_trends_species <- ebirdst::ebirdst_runs %>% 
  filter(species_code %in% common_india_codes | species_code %in% birds_lookup$ebird_species_code)

# --- Core Loop ---
hotspot_results <- list() # key: h_id + week

message(sprintf("Analyzing %d bird species across weeks: %s", nrow(status_trends_species), paste(target_weeks, collapse=", ")))

for (i in seq_len(nrow(status_trends_species))) {
  sp_code <- status_trends_species$species_code[i]
  sp_name <- status_trends_species$common_name[i]
  sp_sci <- status_trends_species$scientific_name[i]
  
  message(sprintf("[%d/%d] Checking %s...", i, nrow(status_trends_species), sp_name))
  
  tryCatch({
    ebirdst_download_status(sp_code, path = status_data_dir, download_ranges = TRUE, download_abundance = FALSE, download_occurrence = FALSE, download_count = FALSE, download_all = FALSE)
    ranges <- load_ranges(sp_code, resolution = "27km", smoothed = TRUE, path = status_data_dir)
    ranges_4326 <- st_transform(ranges, 4326)
    
    for (wk in target_weeks) {
      target_season <- if (wk %in% season_to_weeks$breeding) "breeding"
                  else if (wk %in% season_to_weeks$postbreeding) "postbreeding"
                  else if (wk %in% season_to_weeks$nonbreeding) "nonbreeding"
                  else if (wk %in% season_to_weeks$prebreeding) "prebreeding"
                  else NA_character_
      
      if (is.na(target_season)) next
      
      seasonal_poly <- ranges_4326 %>% filter(str_detect(tolower(season), target_season))
      if (nrow(seasonal_poly) == 0) next
      
      # Spatial Match
      hits <- st_intersects(hotspots_sf, seasonal_poly, sparse = FALSE)
      hit_indices <- which(apply(hits, 1, any))
      
      if (length(hit_indices) > 0) {
        for (h_idx in hit_indices) {
          h_id <- hotspots_sf$hotspot_geo_id[h_idx]
          res_key <- paste0(h_id, "_", wk)
          
          bird_meta <- birds_lookup %>% filter(ebird_species_code == sp_code) %>% head(1)
          img_name <- if(nrow(bird_meta) > 0) bird_meta$static_image_name else str_replace_all(tolower(sp_sci), "[^a-z0-9]+", "_")
          
          entry <- list(
            bird_id = if(nrow(bird_meta) > 0) bird_meta$bird_id else NA_character_,
            ebird_species_code = sp_code,
            commonName = sp_name,
            scientificName = sp_sci,
            imageName = img_name,
            probability = 85,
            residencyStatus = "Status and Trends"
          )
          hotspot_results[[res_key]] <- c(hotspot_results[[res_key]], list(entry))
        }
      }
    }
  }, error = function(e) { message(sprintf("Skipped %s: %s", sp_name, e$message)) })
}

# --- Upload ---
message("Syncing results to Supabase...")
upsert_payload <- list()
for (res_key in names(hotspot_results)) {
  parts <- str_split(res_key, "_")[[1]]
  species_list <- hotspot_results[[res_key]]
  if (length(species_list) > 15) species_list <- species_list[1:15]
  
  upsert_payload[[length(upsert_payload) + 1]] <- list(
    hotspot_geo_id = parts[1],
    week_number = as.integer(parts[2]),
    species_json = species_list,
    species_count = length(species_list),
    source = "ebird_status_trends",
    updated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  )
}

if (length(upsert_payload) > 0) {
  chunk_size <- 50
  for (i in seq(1, length(upsert_payload), by = chunk_size)) {
    end <- min(i + chunk_size - 1, length(upsert_payload))
    supabase_upsert("hotspot_species_cache", upsert_payload[i:end])
  }
}

message("Hotspot species cache generation completed.")
