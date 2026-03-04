# Supabase Watchlist Refactor Changes (Execute In Order)

This runbook applies the watchlist server changes in the same order as your refactor plan, with safeguards for:
- `watchlist_rules.parameters_json` currently being `text`.
- watchlist counter drift.
- cascade + photo storage cleanup queue.
- `observed_by` normalization to `observed_by_user_id`.

## How to run

1. Run **Phase A** and **Phase B** in Supabase SQL editor.
2. Deploy app build that uses typed rule fields and no legacy payload fields.
3. Run **Phase C** cleanup.

---

## Phase A: Additive + Safe Migration + Integrity + Runtime Protections

```sql
begin;

-- ============================================================
-- 1) Additive schema
-- ============================================================

alter table public.watchlist_rules
  add column if not exists lat double precision,
  add column if not exists lon double precision,
  add column if not exists radius_km double precision,
  add column if not exists start_date timestamptz,
  add column if not exists end_date timestamptz,
  add column if not exists shape_id text,
  add column if not exists pattern_key text;

alter table public.watchlist_shares
  add column if not exists sync_status text not null default 'pending_create',
  add column if not exists server_row_version integer not null default 0,
  add column if not exists last_synced_at timestamptz,
  add column if not exists deleted_at timestamptz;

alter table public.watchlist_entries
  add column if not exists observed_by_user_id uuid;

alter table public.watchlist_entries
  drop constraint if exists watchlist_entries_observed_by_user_id_fkey;

alter table public.watchlist_entries
  add constraint watchlist_entries_observed_by_user_id_fkey
  foreign key (observed_by_user_id)
  references auth.users(id)
  on delete set null;

-- Deduplicate active shares before unique partial index
with ranked as (
  select
    id,
    row_number() over (
      partition by watchlist_id, user_id
      order by shared_at desc nulls last, id desc
    ) as rn
  from public.watchlist_shares
  where deleted_at is null
)
update public.watchlist_shares ws
set deleted_at = now()
from ranked r
where ws.id = r.id
  and r.rn > 1
  and ws.deleted_at is null;

create unique index if not exists watchlist_shares_watchlist_user_active_uniq
  on public.watchlist_shares (watchlist_id, user_id)
  where deleted_at is null;


-- ============================================================
-- 2) Safe JSON conversion from text parameters_json
-- ============================================================

create or replace function public.try_parse_jsonb(input text)
returns jsonb
language plpgsql
as $$
declare
  parsed jsonb;
begin
  if input is null or btrim(input) = '' then
    return null;
  end if;

  begin
    parsed := input::jsonb;
    return parsed;
  exception when others then
    return null;
  end;
end;
$$;

create or replace function public.try_parse_double(input text)
returns double precision
language plpgsql
as $$
declare
  parsed double precision;
begin
  if input is null or btrim(input) = '' then
    return null;
  end if;

  begin
    parsed := input::double precision;
    return parsed;
  exception when others then
    return null;
  end;
end;
$$;

create or replace function public.try_parse_timestamptz(input text)
returns timestamptz
language plpgsql
as $$
declare
  parsed timestamptz;
begin
  if input is null or btrim(input) = '' then
    return null;
  end if;

  begin
    parsed := input::timestamptz;
    return parsed;
  exception when others then
    return null;
  end;
end;
$$;

create table if not exists public.watchlist_rule_migration_audit (
  id bigserial primary key,
  watchlist_rule_id uuid,
  watchlist_id uuid,
  rule_type text,
  parameters_json text,
  audit_reason text not null,
  created_at timestamptz not null default now()
);

insert into public.watchlist_rule_migration_audit (
  watchlist_rule_id,
  watchlist_id,
  rule_type,
  parameters_json,
  audit_reason
)
select
  wr.id,
  wr.watchlist_id,
  wr.rule_type,
  wr.parameters_json,
  'Malformed parameters_json; could not parse as JSON'
from public.watchlist_rules wr
where wr.parameters_json is not null
  and btrim(wr.parameters_json) <> ''
  and public.try_parse_jsonb(wr.parameters_json) is null;

-- Backfill location typed columns
with parsed as (
  select
    wr.id,
    public.try_parse_jsonb(wr.parameters_json) as js
  from public.watchlist_rules wr
)
update public.watchlist_rules wr
set
  lat = coalesce(
    wr.lat,
    public.try_parse_double(p.js ->> 'lat'),
    public.try_parse_double(p.js ->> 'latitude')
  ),
  lon = coalesce(
    wr.lon,
    public.try_parse_double(p.js ->> 'lon'),
    public.try_parse_double(p.js ->> 'longitude')
  ),
  radius_km = coalesce(
    wr.radius_km,
    public.try_parse_double(p.js ->> 'radius_km'),
    public.try_parse_double(p.js ->> 'radiusKm'),
    50.0
  )
from parsed p
where wr.id = p.id
  and wr.rule_type = 'location'
  and p.js is not null;

-- Backfill date range typed columns
with parsed as (
  select
    wr.id,
    public.try_parse_jsonb(wr.parameters_json) as js
  from public.watchlist_rules wr
)
update public.watchlist_rules wr
set
  start_date = coalesce(
    wr.start_date,
    public.try_parse_timestamptz(p.js ->> 'start_date'),
    public.try_parse_timestamptz(p.js ->> 'startDate')
  ),
  end_date = coalesce(
    wr.end_date,
    public.try_parse_timestamptz(p.js ->> 'end_date'),
    public.try_parse_timestamptz(p.js ->> 'endDate')
  )
from parsed p
where wr.id = p.id
  and wr.rule_type = 'date_range'
  and p.js is not null;

-- Backfill species-family -> shape_id (deterministic: first best shape_id from birds by family)
with parsed as (
  select
    wr.id,
    public.try_parse_jsonb(wr.parameters_json) as js
  from public.watchlist_rules wr
)
update public.watchlist_rules wr
set
  shape_id = coalesce(
    wr.shape_id,
    nullif(p.js ->> 'shape_id', ''),
    nullif(p.js ->> 'shapeId', ''),
    (
      select b.shape_id
      from public.birds b
      where b.shape_id is not null
        and b.family = coalesce(
          nullif(p.js ->> 'family', ''),
          nullif(p.js ->> 'species_family', ''),
          nullif(p.js #>> '{families,0}', '')
        )
      group by b.shape_id
      order by count(*) desc, b.shape_id
      limit 1
    )
  )
from parsed p
where wr.id = p.id
  and wr.rule_type = 'species_family'
  and p.js is not null;

-- Backfill migration-pattern -> first strategy -> pattern_key
with parsed as (
  select
    wr.id,
    public.try_parse_jsonb(wr.parameters_json) as js
  from public.watchlist_rules wr
)
update public.watchlist_rules wr
set
  pattern_key = coalesce(
    wr.pattern_key,
    nullif(p.js ->> 'pattern_key', ''),
    nullif(p.js ->> 'patternKey', ''),
    nullif(p.js #>> '{strategies,0}', ''),
    nullif(p.js ->> 'migration_strategy', '')
  )
from parsed p
where wr.id = p.id
  and wr.rule_type = 'migration_pattern'
  and p.js is not null;


-- ============================================================
-- 3) Migrate inline watchlist columns -> watchlist_rules
-- ============================================================

-- Species rule upsert
update public.watchlist_rules wr
set
  shape_id = w.species_rule_shape_id,
  is_active = true,
  deleted_at = null,
  updated_at = now()
from public.watchlists w
where wr.watchlist_id = w.id
  and wr.rule_type = 'species_family'
  and w.deleted_at is null
  and coalesce(w.species_rule_enabled, false) = true;

insert into public.watchlist_rules (
  watchlist_id,
  rule_type,
  shape_id,
  is_active,
  priority,
  row_version,
  created_at,
  updated_at
)
select
  w.id,
  'species_family',
  w.species_rule_shape_id,
  true,
  0,
  0,
  now(),
  now()
from public.watchlists w
where w.deleted_at is null
  and coalesce(w.species_rule_enabled, false) = true
  and not exists (
    select 1
    from public.watchlist_rules wr
    where wr.watchlist_id = w.id
      and wr.rule_type = 'species_family'
      and wr.deleted_at is null
  );

-- Location rule upsert
update public.watchlist_rules wr
set
  lat = w.location_rule_lat,
  lon = w.location_rule_lon,
  radius_km = coalesce(w.location_rule_radius_km, 50.0),
  is_active = true,
  deleted_at = null,
  updated_at = now()
from public.watchlists w
where wr.watchlist_id = w.id
  and wr.rule_type = 'location'
  and w.deleted_at is null
  and coalesce(w.location_rule_enabled, false) = true;

insert into public.watchlist_rules (
  watchlist_id,
  rule_type,
  lat,
  lon,
  radius_km,
  is_active,
  priority,
  row_version,
  created_at,
  updated_at
)
select
  w.id,
  'location',
  w.location_rule_lat,
  w.location_rule_lon,
  coalesce(w.location_rule_radius_km, 50.0),
  true,
  0,
  0,
  now(),
  now()
from public.watchlists w
where w.deleted_at is null
  and coalesce(w.location_rule_enabled, false) = true
  and not exists (
    select 1
    from public.watchlist_rules wr
    where wr.watchlist_id = w.id
      and wr.rule_type = 'location'
      and wr.deleted_at is null
  );

-- Date rule upsert
update public.watchlist_rules wr
set
  start_date = w.date_rule_start_date,
  end_date = w.date_rule_end_date,
  is_active = true,
  deleted_at = null,
  updated_at = now()
from public.watchlists w
where wr.watchlist_id = w.id
  and wr.rule_type = 'date_range'
  and w.deleted_at is null
  and coalesce(w.date_rule_enabled, false) = true;

insert into public.watchlist_rules (
  watchlist_id,
  rule_type,
  start_date,
  end_date,
  is_active,
  priority,
  row_version,
  created_at,
  updated_at
)
select
  w.id,
  'date_range',
  w.date_rule_start_date,
  w.date_rule_end_date,
  true,
  0,
  0,
  now(),
  now()
from public.watchlists w
where w.deleted_at is null
  and coalesce(w.date_rule_enabled, false) = true
  and not exists (
    select 1
    from public.watchlist_rules wr
    where wr.watchlist_id = w.id
      and wr.rule_type = 'date_range'
      and wr.deleted_at is null
  );

-- Deduplicate active rules to support one-row-per-(watchlist_id, rule_type)
with ranked as (
  select
    id,
    row_number() over (
      partition by watchlist_id, rule_type
      order by updated_at desc nulls last, created_at desc nulls last, id desc
    ) as rn
  from public.watchlist_rules
  where deleted_at is null
)
update public.watchlist_rules wr
set
  deleted_at = now(),
  is_active = false,
  updated_at = now()
from ranked r
where wr.id = r.id
  and r.rn > 1
  and wr.deleted_at is null;

create unique index if not exists watchlist_rules_watchlist_rule_active_uniq
  on public.watchlist_rules (watchlist_id, rule_type)
  where deleted_at is null;


-- ============================================================
-- 4) Enforce typed rule integrity
-- ============================================================

alter table public.watchlist_rules
  drop constraint if exists watchlist_rules_typed_payload_check;

alter table public.watchlist_rules
  add constraint watchlist_rules_typed_payload_check
  check (
    (
      rule_type = 'location'
      and lat is not null
      and lon is not null
      and radius_km is not null
      and start_date is null
      and end_date is null
      and shape_id is null
      and pattern_key is null
    )
    or
    (
      rule_type = 'date_range'
      and start_date is not null
      and end_date is not null
      and lat is null
      and lon is null
      and radius_km is null
      and shape_id is null
      and pattern_key is null
    )
    or
    (
      rule_type = 'species_family'
      and shape_id is not null
      and lat is null
      and lon is null
      and radius_km is null
      and start_date is null
      and end_date is null
      and pattern_key is null
    )
    or
    (
      rule_type = 'migration_pattern'
      and pattern_key is not null
      and lat is null
      and lon is null
      and radius_km is null
      and start_date is null
      and end_date is null
      and shape_id is null
    )
  )
  not valid;

alter table public.watchlist_rules
  validate constraint watchlist_rules_typed_payload_check;


-- ============================================================
-- 5) Fix drifting counters + server authoritative guard
-- ============================================================

create or replace function public.recompute_watchlist_counts(p_watchlist_id uuid)
returns void
language plpgsql
as $$
begin
  update public.watchlists w
  set
    observed_count = coalesce(s.observed_count, 0),
    species_count = coalesce(s.species_count, 0),
    updated_at = now()
  from (
    select
      count(*) filter (where e.status = 'observed' and e.deleted_at is null) as observed_count,
      count(distinct coalesce(e.bird_id, e.id)) filter (where e.deleted_at is null) as species_count
    from public.watchlist_entries e
    where e.watchlist_id = p_watchlist_id
  ) s
  where w.id = p_watchlist_id;
end;
$$;

-- One-time backfill
update public.watchlists w
set
  observed_count = coalesce(s.observed_count, 0),
  species_count = coalesce(s.species_count, 0),
  updated_at = now()
from (
  select
    e.watchlist_id,
    count(*) filter (where e.status = 'observed' and e.deleted_at is null) as observed_count,
    count(distinct coalesce(e.bird_id, e.id)) filter (where e.deleted_at is null) as species_count
  from public.watchlist_entries e
  group by e.watchlist_id
) s
where w.id = s.watchlist_id;

-- Ensure lists with no entries become zero
update public.watchlists w
set
  observed_count = 0,
  species_count = 0,
  updated_at = now()
where not exists (
  select 1
  from public.watchlist_entries e
  where e.watchlist_id = w.id
    and e.deleted_at is null
)
and (w.observed_count <> 0 or w.species_count <> 0);

create or replace function public.watchlist_entries_recompute_counts_trg()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' then
    perform public.recompute_watchlist_counts(new.watchlist_id);
    return new;
  elsif tg_op = 'DELETE' then
    perform public.recompute_watchlist_counts(old.watchlist_id);
    return old;
  else
    if old.watchlist_id is distinct from new.watchlist_id then
      perform public.recompute_watchlist_counts(old.watchlist_id);
      perform public.recompute_watchlist_counts(new.watchlist_id);
    elsif old.status is distinct from new.status
       or old.deleted_at is distinct from new.deleted_at
       or old.bird_id is distinct from new.bird_id then
      perform public.recompute_watchlist_counts(new.watchlist_id);
    end if;
    return new;
  end if;
end;
$$;

drop trigger if exists trg_watchlist_entries_recompute_counts on public.watchlist_entries;

create trigger trg_watchlist_entries_recompute_counts
after insert or update of watchlist_id, status, deleted_at, bird_id or delete
on public.watchlist_entries
for each row
execute function public.watchlist_entries_recompute_counts_trg();

-- Optional DB guard: prevent client count overwrites
create or replace function public.watchlists_count_guard_trg()
returns trigger
language plpgsql
as $$
begin
  if new.observed_count is distinct from old.observed_count
     or new.species_count is distinct from old.species_count then
    select
      count(*) filter (where e.status = 'observed' and e.deleted_at is null),
      count(distinct coalesce(e.bird_id, e.id)) filter (where e.deleted_at is null)
    into new.observed_count, new.species_count
    from public.watchlist_entries e
    where e.watchlist_id = old.id;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_watchlists_count_guard on public.watchlists;

create trigger trg_watchlists_count_guard
before update of observed_count, species_count
on public.watchlists
for each row
execute function public.watchlists_count_guard_trg();


-- ============================================================
-- 6) Cascade + photo leak protection queue
-- ============================================================

alter table public.watchlist_entries
  drop constraint if exists watchlist_entries_watchlist_id_fkey;

alter table public.watchlist_entries
  add constraint watchlist_entries_watchlist_id_fkey
  foreign key (watchlist_id)
  references public.watchlists(id)
  on delete cascade;

alter table public.observed_bird_photos
  drop constraint if exists observed_bird_photos_watchlist_entry_id_fkey;

alter table public.observed_bird_photos
  add constraint observed_bird_photos_watchlist_entry_id_fkey
  foreign key (watchlist_entry_id)
  references public.watchlist_entries(id)
  on delete cascade;

create table if not exists public.storage_gc_queue (
  id bigserial primary key,
  bucket text not null default 'photos',
  object_path text not null,
  source_table text not null,
  source_id uuid,
  reason text,
  enqueued_at timestamptz not null default now(),
  processed_at timestamptz,
  attempt_count integer not null default 0,
  last_error text,
  unique (bucket, object_path)
);

create index if not exists storage_gc_queue_pending_idx
  on public.storage_gc_queue (processed_at, enqueued_at)
  where processed_at is null;

create or replace function public.enqueue_observed_photo_storage_delete()
returns trigger
language plpgsql
as $$
declare
  object_path text;
begin
  object_path := null;

  if old.storage_url is not null and btrim(old.storage_url) <> '' then
    object_path := regexp_replace(
      old.storage_url,
      '^.*?/storage/v1/object/(public/)?photos/',
      ''
    );

    if object_path = old.storage_url then
      object_path := null;
    end if;
  end if;

  if object_path is null or btrim(object_path) = '' then
    object_path := old.image_path;
  end if;

  if object_path is not null and btrim(object_path) <> '' then
    insert into public.storage_gc_queue (
      bucket,
      object_path,
      source_table,
      source_id,
      reason
    )
    values (
      'photos',
      object_path,
      'observed_bird_photos',
      old.id,
      'observed_bird_photos row deleted'
    )
    on conflict (bucket, object_path)
    do update
      set
        source_table = excluded.source_table,
        source_id = excluded.source_id,
        reason = excluded.reason,
        enqueued_at = now(),
        processed_at = null;
  end if;

  return old;
end;
$$;

drop trigger if exists trg_enqueue_observed_photo_storage_delete on public.observed_bird_photos;

create trigger trg_enqueue_observed_photo_storage_delete
after delete on public.observed_bird_photos
for each row
execute function public.enqueue_observed_photo_storage_delete();


-- ============================================================
-- 7) Normalize observed_by -> observed_by_user_id (best effort)
-- ============================================================

with unique_name_users as (
  select
    lower(btrim(u.name)) as normalized_name,
    min(u.id) as user_id,
    count(*) as cnt
  from public.users u
  where u.name is not null
    and btrim(u.name) <> ''
  group by lower(btrim(u.name))
  having count(*) = 1
)
update public.watchlist_entries e
set observed_by_user_id = u.user_id
from unique_name_users u
where e.observed_by_user_id is null
  and e.observed_by is not null
  and btrim(e.observed_by) <> ''
  and lower(btrim(e.observed_by)) = u.normalized_name;

commit;
```

---

## Phase B: Validation Queries (Run after Phase A)

```sql
-- Rule migration audit
select *
from public.watchlist_rule_migration_audit
order by created_at desc, id desc
limit 200;

-- Ensure typed columns populated for active rules
select
  rule_type,
  count(*) filter (where deleted_at is null) as active_rules,
  count(*) filter (where deleted_at is null and rule_type = 'location' and (lat is null or lon is null or radius_km is null)) as bad_location,
  count(*) filter (where deleted_at is null and rule_type = 'date_range' and (start_date is null or end_date is null)) as bad_date_range,
  count(*) filter (where deleted_at is null and rule_type = 'species_family' and shape_id is null) as bad_species,
  count(*) filter (where deleted_at is null and rule_type = 'migration_pattern' and pattern_key is null) as bad_migration
from public.watchlist_rules
group by rule_type
order by rule_type;

-- Compare legacy inline enabled rule counts vs active rules after migration
select
  (select count(*) from public.watchlists where deleted_at is null and coalesce(species_rule_enabled, false) = true) as legacy_species_enabled,
  (select count(*) from public.watchlist_rules where deleted_at is null and rule_type = 'species_family') as migrated_species_rules,
  (select count(*) from public.watchlists where deleted_at is null and coalesce(location_rule_enabled, false) = true) as legacy_location_enabled,
  (select count(*) from public.watchlist_rules where deleted_at is null and rule_type = 'location') as migrated_location_rules,
  (select count(*) from public.watchlists where deleted_at is null and coalesce(date_rule_enabled, false) = true) as legacy_date_enabled,
  (select count(*) from public.watchlist_rules where deleted_at is null and rule_type = 'date_range') as migrated_date_rules;

-- Counter sanity spot check
select
  w.id,
  w.title,
  w.observed_count,
  w.species_count,
  s.observed_count as computed_observed_count,
  s.species_count as computed_species_count
from public.watchlists w
left join (
  select
    e.watchlist_id,
    count(*) filter (where e.status = 'observed' and e.deleted_at is null) as observed_count,
    count(distinct coalesce(e.bird_id, e.id)) filter (where e.deleted_at is null) as species_count
  from public.watchlist_entries e
  group by e.watchlist_id
) s on s.watchlist_id = w.id
order by w.updated_at desc nulls last
limit 100;

-- FK check: no orphan photos
select count(*) as orphan_photos
from public.observed_bird_photos p
left join public.watchlist_entries e on e.id = p.watchlist_entry_id
where e.id is null;
```

---

## Phase C: Post-App-Cutover Cleanup (Run only after new app is deployed)

```sql
begin;

-- Drop JSON compatibility column once typed reads/writes are live
alter table public.watchlist_rules
  drop column if exists parameters_json;

-- Drop legacy columns no longer used by app
alter table public.watchlist_entries
  drop column if exists target_date_range;

alter table public.observed_bird_photos
  drop column if exists is_uploaded;

alter table public.watchlists
  drop column if exists species_rule_enabled,
  drop column if exists species_rule_shape_id,
  drop column if exists location_rule_enabled,
  drop column if exists location_rule_lat,
  drop column if exists location_rule_lon,
  drop column if exists location_rule_radius_km,
  drop column if exists location_rule_display_name,
  drop column if exists date_rule_enabled,
  drop column if exists date_rule_start_date,
  drop column if exists date_rule_end_date;

commit;
```

---

## Rollback SQL Snippets For Dropped Columns

```sql
-- watchlist_rules.parameters_json
alter table public.watchlist_rules
  add column if not exists parameters_json text not null default '{}'::text;

-- watchlist_entries.target_date_range
alter table public.watchlist_entries
  add column if not exists target_date_range text;

-- observed_bird_photos.is_uploaded
alter table public.observed_bird_photos
  add column if not exists is_uploaded boolean default false;

-- watchlists inline rule columns
alter table public.watchlists
  add column if not exists species_rule_enabled boolean default false,
  add column if not exists species_rule_shape_id text,
  add column if not exists location_rule_enabled boolean default false,
  add column if not exists location_rule_lat double precision,
  add column if not exists location_rule_lon double precision,
  add column if not exists location_rule_radius_km double precision default 50.0,
  add column if not exists location_rule_display_name text,
  add column if not exists date_rule_enabled boolean default false,
  add column if not exists date_rule_start_date timestamptz,
  add column if not exists date_rule_end_date timestamptz;
```

---

## Manual Worker Requirement (Non-SQL)

You still need an Edge Function / worker that drains `public.storage_gc_queue` and deletes `photos/<object_path>` from Supabase Storage idempotently, then marks:
- `processed_at = now()` on success,
- or increments `attempt_count` and stores `last_error` on failure.

