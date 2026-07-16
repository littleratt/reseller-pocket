-- Teen Reseller App: cloud sync, realtime updates, and daily snapshots
-- Run this entire file once in Supabase Dashboard > SQL Editor.

create table if not exists public.reseller_app_state (
  user_id uuid primary key references auth.users(id) on delete cascade,
  payload jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  device_name text
);

create table if not exists public.reseller_app_backups (
  user_id uuid not null references auth.users(id) on delete cascade,
  backup_date date not null,
  payload jsonb not null,
  state_updated_at timestamptz,
  device_name text,
  created_at timestamptz not null default now(),
  primary key (user_id, backup_date)
);

alter table public.reseller_app_state enable row level security;
alter table public.reseller_app_backups enable row level security;

drop policy if exists "Users read own reseller state" on public.reseller_app_state;
drop policy if exists "Users insert own reseller state" on public.reseller_app_state;
drop policy if exists "Users update own reseller state" on public.reseller_app_state;
drop policy if exists "Users delete own reseller state" on public.reseller_app_state;

create policy "Users read own reseller state"
on public.reseller_app_state for select to authenticated
using (auth.uid() = user_id);

create policy "Users insert own reseller state"
on public.reseller_app_state for insert to authenticated
with check (auth.uid() = user_id);

create policy "Users update own reseller state"
on public.reseller_app_state for update to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "Users delete own reseller state"
on public.reseller_app_state for delete to authenticated
using (auth.uid() = user_id);

drop policy if exists "Users read own reseller backups" on public.reseller_app_backups;
drop policy if exists "Users insert own reseller backups" on public.reseller_app_backups;
drop policy if exists "Users update own reseller backups" on public.reseller_app_backups;
drop policy if exists "Users delete own reseller backups" on public.reseller_app_backups;

create policy "Users read own reseller backups"
on public.reseller_app_backups for select to authenticated
using (auth.uid() = user_id);

create policy "Users insert own reseller backups"
on public.reseller_app_backups for insert to authenticated
with check (auth.uid() = user_id);

create policy "Users update own reseller backups"
on public.reseller_app_backups for update to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "Users delete own reseller backups"
on public.reseller_app_backups for delete to authenticated
using (auth.uid() = user_id);

grant select, insert, update, delete on public.reseller_app_state to authenticated;
grant select, insert, update, delete on public.reseller_app_backups to authenticated;

-- Enable live updates for the current-state table.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'reseller_app_state'
  ) then
    alter publication supabase_realtime add table public.reseller_app_state;
  end if;
end $$;

-- True automatic daily snapshots, independent of whether a phone opens the app.
-- 10:00 UTC is approximately 2–3 a.m. Pacific depending on daylight saving time.
create extension if not exists pg_cron;

do $$
declare existing_job bigint;
begin
  select jobid into existing_job from cron.job where jobname = 'reseller-daily-backup' limit 1;
  if existing_job is not null then
    perform cron.unschedule(existing_job);
  end if;
exception when undefined_table then
  null;
end $$;

select cron.schedule(
  'reseller-daily-backup',
  '0 10 * * *',
  $job$
    insert into public.reseller_app_backups
      (user_id, backup_date, payload, state_updated_at, device_name, created_at)
    select
      user_id,
      current_date,
      payload,
      updated_at,
      coalesce(device_name, 'Automatic daily snapshot'),
      now()
    from public.reseller_app_state
    on conflict (user_id, backup_date)
    do update set
      payload = excluded.payload,
      state_updated_at = excluded.state_updated_at,
      device_name = excluded.device_name,
      created_at = now();
  $job$
);
