-- ============================================================
-- FOUND — Early-access users table + profile capture
-- ------------------------------------------------------------
-- Run this ONCE in the Supabase SQL editor (Dashboard -> SQL Editor).
-- Project: froqanfagdkjmfrmpfye
-- Safe to re-run — every object uses create-or-replace / if-not-exists.
--
-- What it does:
--   • Creates public.early_access_users — one row per signup, holding
--     ALL their info: signup fields + the app onboarding answers.
--   • Auto-creates a row on every new signup (trigger on auth.users)
--     and backfills every existing user.
--   • save_early_access_profile(...) — RPC the website's
--     complete-profile.html calls to store the onboarding answers.
--   • early_access_admin() — admin-only RPC to read every row
--     (for exporting the data before launch).
-- ============================================================

-- 1. The table ------------------------------------------------
create table if not exists public.early_access_users (
  id                    uuid primary key default gen_random_uuid(),
  user_id               uuid not null unique references auth.users(id) on delete cascade,

  -- ---- signup info (copied from auth.users metadata) ----
  full_name             text,
  email                 text,
  phone                 text,
  zip                   text,
  city                  text,
  state                 text,

  -- ---- onboarding answers (from complete-profile.html) ----
  life_stage            text,
  activities            text[]  not null default '{}',
  where_from            text,
  family_values         text[]  not null default '{}',
  school_types          text[]  not null default '{}',
  love_language         text,
  initiator             text,
  personality           text,
  hoping_to_find        text[]  not null default '{}',

  -- ---- meta ----
  profile_completed     boolean not null default false,
  profile_completed_at  timestamptz,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

-- 2. Row Level Security ---------------------------------------
alter table public.early_access_users enable row level security;

-- A signed-in user can read ONLY their own row (lets complete-profile.html
-- pre-fill answers if they come back to edit). No anon access. Writes go
-- through the security-definer RPC below, so no insert/update policy needed.
drop policy if exists "user reads own early access row" on public.early_access_users;
create policy "user reads own early access row"
  on public.early_access_users
  for select to authenticated
  using (user_id = auth.uid());

-- 3. Keep updated_at fresh ------------------------------------
create or replace function public.found_touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists found_early_access_touch on public.early_access_users;
create trigger found_early_access_touch
  before update on public.early_access_users
  for each row execute function public.found_touch_updated_at();

-- 4. Auto-create a row on every new signup --------------------
create or replace function public.found_create_early_access_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
begin
  insert into public.early_access_users
    (user_id, full_name, email, phone, zip, city, state)
  values (
    new.id,
    nullif(v_meta->>'full_name', ''),
    new.email,
    nullif(v_meta->>'phone', ''),
    nullif(v_meta->>'zip', ''),
    nullif(v_meta->>'city', ''),
    nullif(v_meta->>'state', '')
  )
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists found_on_new_signup_early_access on auth.users;
create trigger found_on_new_signup_early_access
  after insert on auth.users
  for each row execute function public.found_create_early_access_user();

-- 5. Backfill every existing user -----------------------------
insert into public.early_access_users
  (user_id, full_name, email, phone, zip, city, state)
select
  u.id,
  nullif(u.raw_user_meta_data->>'full_name', ''),
  u.email,
  nullif(u.raw_user_meta_data->>'phone', ''),
  nullif(u.raw_user_meta_data->>'zip', ''),
  nullif(u.raw_user_meta_data->>'city', ''),
  nullif(u.raw_user_meta_data->>'state', '')
from auth.users u
on conflict (user_id) do nothing;

-- 6. Save the onboarding answers (called by complete-profile.html) --
--    Security definer: the caller can only ever touch THEIR OWN row.
create or replace function public.save_early_access_profile(
  p_life_stage     text,
  p_activities     text[],
  p_where_from     text,
  p_family_values  text[],
  p_school_types   text[],
  p_love_language  text,
  p_initiator      text,
  p_personality    text,
  p_hoping_to_find text[]
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  -- Safety net: make sure the row exists even if the signup trigger
  -- never fired (e.g. user created before this migration).
  insert into public.early_access_users (user_id, email)
  values (v_uid, (select email from auth.users where id = v_uid))
  on conflict (user_id) do nothing;

  update public.early_access_users
  set life_stage           = nullif(p_life_stage, ''),
      activities           = coalesce(p_activities, '{}'),
      where_from           = nullif(p_where_from, ''),
      family_values        = coalesce(p_family_values, '{}'),
      school_types         = coalesce(p_school_types, '{}'),
      love_language        = nullif(p_love_language, ''),
      initiator            = nullif(p_initiator, ''),
      personality          = nullif(p_personality, ''),
      hoping_to_find       = coalesce(p_hoping_to_find, '{}'),
      profile_completed    = true,
      profile_completed_at = now()
  where user_id = v_uid;
end;
$$;

revoke all on function public.save_early_access_profile(
  text, text[], text, text[], text[], text, text, text, text[]
) from public, anon;
grant execute on function public.save_early_access_profile(
  text, text[], text, text[], text[], text, text, text, text[]
) to authenticated;

-- 7. Admin export — every early-access row --------------------
--    Locked to the admin allowlist (same one used by early_access_stats).
--    >>> Edit the allowlist below to your real admin emails. <<<
create or replace function public.early_access_admin()
returns setof public.early_access_users
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller text := lower(coalesce(auth.jwt() ->> 'email', ''));
begin
  if v_caller not in (
       'hello@found.community',
       'ryderscott33@icloud.com',
       'ryderschilling@gmail.com'
     ) then
    raise exception 'Not authorized';
  end if;

  return query
  select * from public.early_access_users
  order by profile_completed desc, created_at desc;
end;
$$;

revoke all on function public.early_access_admin() from public, anon;
grant execute on function public.early_access_admin() to authenticated;

-- ============================================================
-- DONE.
--
-- Verify the table + backfill:
--   select count(*) filter (where profile_completed) as completed,
--          count(*) as total
--   from public.early_access_users;
--
-- View everything as an admin (run signed in as an admin via admin.html,
-- or in the SQL editor — note auth.uid()/auth.jwt() are NULL here, so the
-- allowlist check fails in the SQL editor; query the table directly instead):
--   select * from public.early_access_users order by created_at desc;
-- ============================================================
