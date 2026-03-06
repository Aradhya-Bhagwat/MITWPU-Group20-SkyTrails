create extension if not exists pgcrypto;

create table if not exists public.user_device_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id text not null,
  platform text not null default 'ios',
  app_version text,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  revoked_at timestamptz
);

create index if not exists idx_user_device_sessions_user_id on public.user_device_sessions(user_id);
create index if not exists idx_user_device_sessions_active on public.user_device_sessions(user_id, revoked_at, last_seen_at);

alter table public.user_device_sessions enable row level security;

drop policy if exists "uds_select_own" on public.user_device_sessions;
create policy "uds_select_own"
on public.user_device_sessions
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "uds_insert_own" on public.user_device_sessions;
create policy "uds_insert_own"
on public.user_device_sessions
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "uds_update_own" on public.user_device_sessions;
create policy "uds_update_own"
on public.user_device_sessions
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
