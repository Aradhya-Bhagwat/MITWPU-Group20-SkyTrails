# Supabase Step 5: Watchlist Counter Drift Fix

Run this SQL in Supabase SQL Editor.

## What this does

1. Backfills `watchlists.observed_count` and `watchlists.species_count` from active (`deleted_at is null`) `watchlist_entries`.
2. Installs an `AFTER` trigger on `watchlist_entries` so counters stay correct on insert/update/delete.
3. Adds an optional `BEFORE UPDATE` guard trigger on `watchlists` so stale client count payloads cannot overwrite server-derived values.

## SQL

```sql
begin;

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
      count(*) filter (
        where e.status = 'observed' and e.deleted_at is null
      ) as observed_count,
      count(distinct coalesce(e.bird_id, e.id)) filter (
        where e.deleted_at is null
      ) as species_count
    from public.watchlist_entries e
    where e.watchlist_id = p_watchlist_id
  ) s
  where w.id = p_watchlist_id;
end;
$$;

-- One-time full backfill for lists that currently have entries.
update public.watchlists w
set
  observed_count = coalesce(s.observed_count, 0),
  species_count = coalesce(s.species_count, 0),
  updated_at = now()
from (
  select
    e.watchlist_id,
    count(*) filter (
      where e.status = 'observed' and e.deleted_at is null
    ) as observed_count,
    count(distinct coalesce(e.bird_id, e.id)) filter (
      where e.deleted_at is null
    ) as species_count
  from public.watchlist_entries e
  group by e.watchlist_id
) s
where w.id = s.watchlist_id;

-- Ensure lists with no active entries are reset to zero.
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

drop trigger if exists trg_watchlist_entries_recompute_counts
on public.watchlist_entries;

create trigger trg_watchlist_entries_recompute_counts
after insert or update of watchlist_id, status, deleted_at, bird_id or delete
on public.watchlist_entries
for each row
execute function public.watchlist_entries_recompute_counts_trg();

-- Optional guard: blocks stale client writes for count columns by recomputing on write.
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

drop trigger if exists trg_watchlists_count_guard
on public.watchlists;

create trigger trg_watchlists_count_guard
before update of observed_count, species_count
on public.watchlists
for each row
execute function public.watchlists_count_guard_trg();

commit;
```

## Validation query

```sql
select
  w.id as watchlist_id,
  w.observed_count,
  w.species_count,
  s.observed_count as computed_observed_count,
  s.species_count as computed_species_count
from public.watchlists w
join lateral (
  select
    count(*) filter (where e.status = 'observed' and e.deleted_at is null) as observed_count,
    count(distinct coalesce(e.bird_id, e.id)) filter (where e.deleted_at is null) as species_count
  from public.watchlist_entries e
  where e.watchlist_id = w.id
) s on true
where w.observed_count is distinct from s.observed_count
   or w.species_count is distinct from s.species_count;
```

Expected result: zero rows.
