-- Speeds up selected-hotspot prediction reads and lets the edge function
-- upsert cache rows safely.

CREATE UNIQUE INDEX IF NOT EXISTS hotspot_species_cache_hotspot_week_uidx
  ON public.hotspot_species_cache (hotspot_geo_id, week_number);

CREATE INDEX IF NOT EXISTS hotspot_species_cache_lookup_idx
  ON public.hotspot_species_cache (hotspot_geo_id, week_number, updated_at DESC);

CREATE INDEX IF NOT EXISTS hotspot_recent_observations_cache_updated_idx
  ON public.hotspot_recent_observations_cache (hotspot_geo_id, updated_at DESC);

CREATE INDEX IF NOT EXISTS spot_species_predictions_hotspot_week_rank_idx
  ON public.spot_species_predictions (hotspot_geo_id, week_number, rank_score DESC NULLS LAST, probability DESC NULLS LAST);

CREATE INDEX IF NOT EXISTS spot_species_predictions_hotspot_week_updated_idx
  ON public.spot_species_predictions (hotspot_geo_id, week_number, updated_at DESC);

CREATE INDEX IF NOT EXISTS species_ranges_species_week_idx
  ON public.species_ranges (ebird_species_code, week_number);
