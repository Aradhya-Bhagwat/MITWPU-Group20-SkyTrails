library(jsonlite)
library(dplyr)
library(stringr)
library(ebirdst)
library(sf)
library(terra)

message("Starting India-Wide Regional Master Scan...")

# --- 1. Environment & Config ---
required_env <- c("SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY", "EBIRD_STATUS_TRENDS_ACCESS_KEY")
supabase_url <- sub("/$", "", Sys.getenv("SUPABASE_URL"))
supabase_service_role_key <- Sys.getenv("SUPABASE_SERVICE_ROLE_KEY")
ebirdst_key <- Sys.getenv("EBIRD_STATUS_TRENDS_ACCESS_KEY")
status_data_dir <- Sys.getenv("EBIRD_STATUS_TRENDS_DATA_DIR", unset = file.path(getwd(), "MachineLearning", "ebirdst_data"))

ebirdst::set_ebirdst_access_key(ebirdst_key, overwrite = TRUE)

# --- 2. Define India Master Grid (350 Polygons) ---
# We create 1x1 degree boxes. Lat 8-37, Lon 68-97 covers the Indian Landmass.
india_bbox <- st_bbox(c(xmin=68, xmax=97, ymin=8, ymax=37), crs=4326)
india_grid <- st_make_grid(india_bbox, cellsize = 1, square = TRUE) %>%
  st_as_sf() %>%
  mutate(
    # The ID format 'Lat_Lon' matches our Swift logic
    grid_id = paste0(
      as.integer(st_coordinates(st_centroid(.))[,2]), 
      "_", 
      as.integer(st_coordinates(st_centroid(.))[,1])
    )
  )

# --- 3. Supabase Helpers (CURL based as per your existing scripts) ---
supabase_headers <- function() {
  c("-H", paste0("apikey: ", supabase_service_role_key),
    "-H", paste0("Authorization: Bearer ", supabase_service_role_key))
}

run_supabase_get <- function(path, query = "") {
  url <- paste0(supabase_url, "/rest/v1/", path)
  if (nzchar(query)) url <- paste0(url, "?", query)
  
  args <- c("-sS", "-G", supabase_headers(), url)
  # Properly quote all arguments for the shell
  quoted_args <- vapply(args, shQuote, character(1))
  command <- paste("/usr/bin/curl", paste(quoted_args, collapse = " "))
  
  output <- system(command, intern = TRUE)
  if (length(output) == 0 || !nzchar(paste(output, collapse=""))) return(data.frame())
  
  jsonlite::fromJSON(paste(output, collapse = "\n")) %>% as.data.frame()
}

supabase_upsert <- function(path, body_rows) {
  tmp_json <- tempfile(fileext = ".json")
  writeLines(jsonlite::toJSON(body_rows, auto_unbox = TRUE, null = "null"), tmp_json)
  url <- paste0(supabase_url, "/rest/v1/", path, "?on_conflict=grid_id,week_number")
  
  args <- c("-sS", "-X", "POST", supabase_headers(), 
           "-H", "Content-Type: application/json", 
           "-H", "Prefer: resolution=merge-duplicates,return=minimal", 
           "--data-binary", paste0("@", tmp_json), url)
  
  quoted_args <- vapply(args, shQuote, character(1))
  command <- paste("/usr/bin/curl", paste(quoted_args, collapse = " "))
  system(command)
  unlink(tmp_json)
}

# --- 4. Main Processing Loop ---
target_weeks <- unique((((as.integer(format(Sys.Date(), "%V")) - 1) + 0:2) %% 53) + 1)

# Fetch birds
birds_lookup <- run_supabase_get("birds", "select=id,species_code,common_name")

species_code_filter <- Sys.getenv("EBIRD_SPECIES_CODE", unset = "")
if (nzchar(species_code_filter) && nrow(birds_lookup) > 0) {
  birds_lookup <- birds_lookup %>% filter(species_code == species_code_filter)
}

for (wk in target_weeks) {
  message(sprintf("--- Processing Week %d ---", wk))
  grid_results <- list() # Clear for each week
  
  for (i in seq_len(nrow(birds_lookup))) {
    sp_code <- birds_lookup$species_code[i]
    sp_id <- birds_lookup$id[i]
    sp_name <- birds_lookup$common_name[i]
    
    tryCatch({
      ebirdst_download_status(sp_code, path = status_data_dir, download_abundance = TRUE)
      r <- load_raster(sp_code, period = "weekly", metric = "median", path = status_data_dir)
      r_week <- r[[wk]]
      
      # THE VACUUM
      extracted_vals <- terra::extract(r_week, vect(india_grid), fun = "max", na.rm = TRUE)
      
      for (g_idx in seq_len(nrow(india_grid))) {
        abundance_val <- extracted_vals[g_idx, 2]
        if (!is.na(abundance_val) && abundance_val > 0.05) {
          g_id <- india_grid$grid_id[g_idx]
          # Matches your Swift expected keys and Edge Function processing
          entry <- list(
            bird_id = sp_id, 
            ebird_species_code = sp_code, 
            commonName = sp_name, 
            probability = as.integer(round(abundance_val * 100)),
            residencyStatus = "Status and Trends"
          )
          grid_results[[g_id]] <- c(grid_results[[g_id]], list(entry))
        }
      }
    }, error = function(e) { message(sprintf("Skipped %s: %s", sp_name, e$message)) })
  }
  
  # --- 5. Upload Week-Specific Results ---
  upsert_payload <- lapply(names(grid_results), function(g_id) {
    list(grid_id = g_id, week_number = wk, species_list = grid_results[[g_id]])
  })
  
  if (length(upsert_payload) > 0) {
     supabase_upsert("regional_trends", upsert_payload)
  }
}
message("Master Scan Complete for 3-week window.")
