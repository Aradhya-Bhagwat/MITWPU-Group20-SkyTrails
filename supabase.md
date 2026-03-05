-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.birds (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  common_name text NOT NULL,
  scientific_name text,
  static_image_name text,
  family text,
  order_name text,
  description_text text,
  conservation_status text,
  migration_strategy text,
  hemisphere text,
  valid_locations jsonb DEFAULT '[]'::jsonb,
  valid_months jsonb DEFAULT '[]'::jsonb,
  shape_id text,
  size_category integer,
  field_mark_data jsonb DEFAULT '{}'::jsonb,
  CONSTRAINT birds_pkey PRIMARY KEY (id)
);
CREATE TABLE public.identification_candidates (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  result_id uuid,
  bird_id uuid,
  confidence double precision,
  rank integer,
  matched_features ARRAY DEFAULT '{}'::text[],
  mismatched_features ARRAY DEFAULT '{}'::text[],
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone,
  CONSTRAINT identification_candidates_pkey PRIMARY KEY (id),
  CONSTRAINT identification_candidates_result_id_fkey FOREIGN KEY (result_id) REFERENCES public.identification_results(id),
  CONSTRAINT identification_candidates_bird_id_fkey FOREIGN KEY (bird_id) REFERENCES public.birds(id)
);
CREATE TABLE public.identification_results (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  session_id uuid,
  owner_id uuid,
  bird_id uuid,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone,
  CONSTRAINT identification_results_pkey PRIMARY KEY (id),
  CONSTRAINT identification_results_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.identification_sessions(id),
  CONSTRAINT identification_results_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES auth.users(id),
  CONSTRAINT identification_results_bird_id_fkey FOREIGN KEY (bird_id) REFERENCES public.birds(id)
);
CREATE TABLE public.identification_session_marks (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  session_id uuid,
  field_mark_id uuid,
  variant_id uuid,
  area text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone,
  CONSTRAINT identification_session_marks_pkey PRIMARY KEY (id),
  CONSTRAINT identification_session_marks_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.identification_sessions(id)
);
CREATE TABLE public.identification_sessions (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  user_id uuid,
  status text DEFAULT 'in_progress'::text,
  location_lat double precision,
  location_long double precision,
  device_info text,
  notes text,
  is_public boolean DEFAULT false,
  weather_conditions text,
  metadata jsonb,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone,
  CONSTRAINT identification_sessions_pkey PRIMARY KEY (id),
  CONSTRAINT identification_sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.observed_bird_photos (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  watchlist_entry_id uuid NOT NULL,
  image_path text NOT NULL,
  storage_url text,
  is_uploaded boolean DEFAULT false,
  row_version integer DEFAULT 0,
  last_synced_at timestamp with time zone,
  captured_at timestamp with time zone,
  uploaded_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone,
  CONSTRAINT observed_bird_photos_pkey PRIMARY KEY (id),
  CONSTRAINT observed_bird_photos_watchlist_entry_id_fkey FOREIGN KEY (watchlist_entry_id) REFERENCES public.watchlist_entries(id)
);
CREATE TABLE public.users (
  id uuid NOT NULL,
  name text NOT NULL,
  gender text DEFAULT 'Not Specified'::text,
  email text NOT NULL,
  profile_photo text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone,
  CONSTRAINT users_pkey PRIMARY KEY (id),
  CONSTRAINT users_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id)
);
CREATE TABLE public.watchlist_entries (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  watchlist_id uuid NOT NULL,
  bird_id uuid,
  nickname text,
  status text NOT NULL DEFAULT 'to_observe'::text CHECK (status = ANY (ARRAY['to_observe'::text, 'observed'::text])),
  notes text,
  added_date timestamp with time zone DEFAULT now(),
  observation_date timestamp with time zone,
  to_observe_start_date timestamp with time zone,
  to_observe_end_date timestamp with time zone,
  observed_by text,
  lat double precision,
  lon double precision,
  location_display_name text,
  priority integer DEFAULT 0,
  notify_upcoming boolean DEFAULT false,
  target_date_range text,
  row_version integer DEFAULT 0,
  last_synced_at timestamp with time zone,
  deleted_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone,
  CONSTRAINT watchlist_entries_pkey PRIMARY KEY (id),
  CONSTRAINT watchlist_entries_watchlist_id_fkey FOREIGN KEY (watchlist_id) REFERENCES public.watchlists(id),
  CONSTRAINT watchlist_entries_bird_id_fkey FOREIGN KEY (bird_id) REFERENCES public.birds(id)
);
CREATE TABLE public.watchlist_rules (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  watchlist_id uuid NOT NULL,
  rule_type text NOT NULL CHECK (rule_type = ANY (ARRAY['location'::text, 'date_range'::text, 'species_family'::text, 'migration_pattern'::text])),
  parameters_json text NOT NULL DEFAULT '{}'::text,
  is_active boolean DEFAULT true,
  priority integer DEFAULT 0,
  row_version integer DEFAULT 0,
  last_synced_at timestamp with time zone,
  deleted_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone,
  CONSTRAINT watchlist_rules_pkey PRIMARY KEY (id),
  CONSTRAINT watchlist_rules_watchlist_id_fkey FOREIGN KEY (watchlist_id) REFERENCES public.watchlists(id)
);
CREATE TABLE public.watchlist_shares (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  watchlist_id uuid NOT NULL,
  user_id uuid NOT NULL,
  permission text DEFAULT 'view'::text CHECK (permission = ANY (ARRAY['view'::text, 'edit'::text, 'admin'::text])),
  shared_at timestamp with time zone DEFAULT now(),
  shared_by_user_id uuid,
  CONSTRAINT watchlist_shares_pkey PRIMARY KEY (id),
  CONSTRAINT watchlist_shares_watchlist_id_fkey FOREIGN KEY (watchlist_id) REFERENCES public.watchlists(id),
  CONSTRAINT watchlist_shares_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id),
  CONSTRAINT watchlist_shares_shared_by_user_id_fkey FOREIGN KEY (shared_by_user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.watchlists (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  owner_id uuid,
  type text DEFAULT 'custom'::text CHECK (type = ANY (ARRAY['custom'::text, 'shared'::text, 'my_watchlist'::text])),
  title text,
  location text,
  location_display_name text,
  start_date timestamp with time zone,
  end_date timestamp with time zone,
  observed_count integer DEFAULT 0,
  species_count integer DEFAULT 0,
  cover_image_path text,
  species_rule_enabled boolean DEFAULT false,
  species_rule_shape_id text,
  location_rule_enabled boolean DEFAULT false,
  location_rule_lat double precision,
  location_rule_lon double precision,
  location_rule_radius_km double precision DEFAULT 50.0,
  location_rule_display_name text,
  date_rule_enabled boolean DEFAULT false,
  date_rule_start_date timestamp with time zone,
  date_rule_end_date timestamp with time zone,
  row_version integer DEFAULT 0,
  last_synced_at timestamp with time zone,
  deleted_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone,
  CONSTRAINT watchlists_pkey PRIMARY KEY (id),
  CONSTRAINT watchlists_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES auth.users(id)
);