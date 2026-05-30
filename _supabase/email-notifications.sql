-- ============================================================
-- FOUND — Email notifications + early-access location stats
-- ------------------------------------------------------------
-- Run this ONCE in the Supabase SQL editor (Dashboard -> SQL Editor).
-- Project: froqanfagdkjmfrmpfye
-- Safe to re-run — every object uses create-or-replace / if-not-exists.
--
-- What it does:
--   • Emails hello@found.community whenever
--       - someone signs up                    (new row in auth.users)
--       - someone COMPLETES their profile      (early_access_users.profile_completed -> true)
--       - someone submits Give/Invest/Donate   (new row in contact_submissions)
--   • The signup email includes name, email, phone and location.
--   • The profile-completed email includes EVERYTHING — location plus all
--     onboarding answers (life stage, activities, family values, etc.).
--   • Emails the NEW USER a branded "welcome / complete your profile" email
--     the moment they sign up.
--   • Exposes early_access_stats() — signup counts grouped by location,
--     for the investor / admin dashboard (admin.html).
--
-- RUN ORDER: run _supabase/early-access-profile.sql FIRST. This file's
--   profile-completed trigger attaches to the early_access_users table
--   that the other file creates. Both files are idempotent / safe to re-run.
--
-- BEFORE RUNNING:
--   1. Paste your real Resend API key in Step 2 (re_xxx...).
--   2. Edit the admin email allowlist in Step 7.
--
-- DELIVERABILITY NOTE:
--   The found.community domain is verified in Resend (DKIM + SPF).
--   The "from" address is FOUND <hello@found.community>.
--   Mail is delivered to hello@found.community.
-- ============================================================

-- 1. Extensions ------------------------------------------------
create extension if not exists pg_net;
create extension if not exists supabase_vault;

-- 2. Store the Resend API key in Vault (encrypted at rest) ------
--    >>> Paste your real Resend API key into v_key below (re_...). <<<
--    SAFE TO RE-RUN: if the placeholder is left in place, Vault is NOT
--    touched — so re-running this file can never wipe a working key.
--    Only a real key (anything other than the placeholder) gets written.
do $$
declare
  v_id  uuid;
  v_key text := 're_xxxxxxxxxxxxxxxxxxxxxxxx';   -- <<< paste real Resend API key here
begin
  if v_key = 're_xxxxxxxxxxxxxxxxxxxxxxxx' then
    raise notice 'resend_api_key: placeholder left in place — Vault untouched. Paste your real key to set/update it.';
  else
    select id into v_id from vault.secrets where name = 'resend_api_key' limit 1;
    if v_id is null then
      perform vault.create_secret(v_key, 'resend_api_key', 'Resend API key for FOUND email notifications');
    else
      perform vault.update_secret(v_id, v_key, 'resend_api_key', 'Resend API key for FOUND email notifications');
    end if;
  end if;
end $$;

-- 3. Make sure the contact_submissions table exists ------------
create table if not exists public.contact_submissions (
  id          uuid primary key default gen_random_uuid(),
  type        text,
  name        text,
  email       text,
  message     text,
  created_at  timestamptz not null default now()
);

alter table public.contact_submissions enable row level security;

-- Website visitors (anon key) need to be able to submit the form.
drop policy if exists "anon can insert contact" on public.contact_submissions;
create policy "anon can insert contact"
  on public.contact_submissions
  for insert to anon, authenticated
  with check (true);

-- 4. Generic email sender via Resend ---------------------------
create or replace function public.found_send_email(p_subject text, p_html text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_key text;
begin
  select decrypted_secret into v_key
  from vault.decrypted_secrets
  where name = 'resend_api_key'
  limit 1;

  if v_key is null then
    raise warning 'found_send_email: resend_api_key missing from Vault — email skipped';
    return;
  end if;

  -- Async fire-and-forget POST. A failed email never blocks the signup.
  perform net.http_post(
    url     := 'https://api.resend.com/emails',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || v_key,
      'Content-Type',  'application/json'
    ),
    body := jsonb_build_object(
      'from',    'FOUND <hello@found.community>',
      'to',      jsonb_build_array('hello@found.community'),
      'subject', p_subject,
      'html',    p_html
    )
  );
end;
$$;

-- 4b. Email sender to a SPECIFIC recipient (used for the welcome email) ---
create or replace function public.found_send_email_to(p_to text, p_subject text, p_html text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_key text;
begin
  if p_to is null or p_to = '' then
    return;
  end if;

  select decrypted_secret into v_key
  from vault.decrypted_secrets
  where name = 'resend_api_key'
  limit 1;

  if v_key is null then
    raise warning 'found_send_email_to: resend_api_key missing from Vault — email skipped';
    return;
  end if;

  -- Async fire-and-forget POST. A failed email never blocks the signup.
  perform net.http_post(
    url     := 'https://api.resend.com/emails',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || v_key,
      'Content-Type',  'application/json'
    ),
    body := jsonb_build_object(
      'from',    'FOUND <hello@found.community>',
      'to',      jsonb_build_array(p_to),
      'subject', p_subject,
      'html',    p_html
    )
  );
end;
$$;

-- 4c. Branded "welcome / complete your profile" email body --------------
--     {{NAME}} is swapped for the new user's first name.
create or replace function public.found_welcome_html(p_name text)
returns text
language sql
immutable
as $func$
  select replace($html$
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f8f6f3;padding:32px 0;">
  <tr>
    <td align="center">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;background:#ffffff;border:1px solid rgba(0,0,0,0.10);border-radius:20px;">
        <tr>
          <td style="padding:36px 36px 0 36px;">
            <div style="font:700 24px Georgia,'Times New Roman',serif;color:#111111;letter-spacing:-0.5px;">FOUND</div>
            <div style="font:600 11px Arial,sans-serif;color:#a3a3a3;letter-spacing:3px;text-transform:uppercase;margin-top:14px;">Early access</div>
          </td>
        </tr>
        <tr>
          <td style="padding:10px 36px 0 36px;">
            <h1 style="font:400 30px Georgia,'Times New Roman',serif;color:#111111;letter-spacing:-0.5px;margin:0 0 14px;">
              You're in, {{NAME}}.
            </h1>
            <p style="font:400 15px/1.6 Arial,sans-serif;color:#4b4b4b;margin:0 0 8px;">
              Thanks for joining FOUND — your spot on the early access list is saved.
            </p>
            <p style="font:400 15px/1.6 Arial,sans-serif;color:#4b4b4b;margin:0 0 26px;">
              If you haven't finished your profile yet, it only takes about two
              minutes — a few questions about your life, faith and the kind of
              community you're looking for. It's how we match you with real
              people nearby the moment FOUND launches.
            </p>
          </td>
        </tr>
        <tr>
          <td style="padding:0 36px;">
            <table role="presentation" cellpadding="0" cellspacing="0" width="100%">
              <tr>
                <td align="center" bgcolor="#111111" style="border-radius:9999px;">
                  <a href="https://found.community/complete-profile.html"
                     style="display:block;padding:15px 28px;font:600 15px Arial,sans-serif;color:#ffffff;text-decoration:none;border-radius:9999px;">
                    Complete my profile
                  </a>
                </td>
              </tr>
            </table>
          </td>
        </tr>
        <tr>
          <td style="padding:22px 36px 0 36px;">
            <p style="font:400 13px/1.6 Arial,sans-serif;color:#9a9a9a;margin:0;">
              If the button doesn't work, copy and paste this link into your browser:
            </p>
            <p style="font:400 13px/1.6 Arial,sans-serif;color:#7a846a;word-break:break-all;margin:6px 0 0;">
              https://found.community/complete-profile.html
            </p>
          </td>
        </tr>
        <tr>
          <td style="padding:26px 36px 36px 36px;">
            <hr style="border:none;border-top:1px solid rgba(0,0,0,0.08);margin:0 0 18px;" />
            <p style="font:400 12px/1.6 Arial,sans-serif;color:#a3a3a3;margin:0;">
              You're receiving this because you joined the FOUND early access list.
              If this wasn't you, you can safely ignore this email.
            </p>
            <p style="font:400 12px/1.6 Arial,sans-serif;color:#a3a3a3;margin:10px 0 0;">
              FOUND &middot; found.community &middot;
              <a href="mailto:hello@found.community" style="color:#a3a3a3;">hello@found.community</a>
            </p>
          </td>
        </tr>
      </table>
    </td>
  </tr>
</table>
$html$, '{{NAME}}', coalesce(nullif(trim($1), ''), 'friend'));
$func$;

-- Small helper: one labelled row in the notification email body.
create or replace function public.found_email_row(p_label text, p_value text)
returns text
language sql
immutable
as $$
  select '<tr>'
      || '<td style="padding:6px 14px 6px 0;color:#6b6b6b;font:14px Arial,sans-serif;'
      ||   'vertical-align:top;white-space:nowrap;">' || p_label || '</td>'
      || '<td style="padding:6px 0;color:#111;font:14px Arial,sans-serif;">'
      ||   coalesce(nullif(p_value, ''), '—') || '</td>'
      || '</tr>';
$$;

-- 5. Notify on new signup -------------------------------------
--    Format (Sam's spec): Type, Name, Email, Phone, Location, Time.
create or replace function public.found_notify_new_signup()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_meta     jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  v_name     text  := nullif(v_meta->>'full_name', '');
  v_phone    text  := nullif(v_meta->>'phone', '');
  v_zip      text  := nullif(v_meta->>'zip', '');
  v_city     text  := nullif(v_meta->>'city', '');
  v_state    text  := nullif(v_meta->>'state', '');
  v_location text;
begin
  v_location := trim(both ' ,' from
                  concat_ws(', ', v_city, v_state)
                  || coalesce(' ' || v_zip, ''));

  perform public.found_send_email(
    'New FOUND signup - ' || coalesce(new.email, 'unknown'),
    '<div style="font:14px Arial,sans-serif;color:#111;">'
      || '<h2 style="font:600 18px Arial,sans-serif;margin:0 0 14px;">New early access signup</h2>'
      || '<table style="border-collapse:collapse;">'
      || public.found_email_row('Type',     'New early access signup')
      || public.found_email_row('Name',     v_name)
      || public.found_email_row('Email',    new.email)
      || public.found_email_row('Phone',    v_phone)
      || public.found_email_row('Location', v_location)
      || public.found_email_row('Time',     to_char(now(), 'Mon DD, YYYY HH24:MI') || ' UTC')
      || '</table></div>'
  );

  -- Branded thank-you / "complete your profile" email to the new user.
  perform public.found_send_email_to(
    new.email,
    'Welcome to FOUND — you''re on the early access list',
    public.found_welcome_html(split_part(coalesce(v_name, ''), ' ', 1))
  );

  return new;
end;
$$;

drop trigger if exists found_on_new_signup on auth.users;
create trigger found_on_new_signup
  after insert on auth.users
  for each row execute function public.found_notify_new_signup();

-- 5b. Notify when a user COMPLETES their early-access profile ---
--     This is the "everything" email — full onboarding answers, not
--     just the signup fields. Fires once, on the false -> true
--     transition of profile_completed, so re-running this file or a
--     user editing their answers later never re-sends it.
create or replace function public.found_notify_profile_completed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_location text;
begin
  v_location := trim(both ' ,' from
                  concat_ws(', ', new.city, new.state)
                  || coalesce(' ' || new.zip, ''));

  perform public.found_send_email(
    'FOUND profile completed - ' || coalesce(nullif(new.full_name, ''), new.email, 'unknown'),
    '<div style="font:14px Arial,sans-serif;color:#111;">'
      || '<h2 style="font:600 18px Arial,sans-serif;margin:0 0 14px;">Early access profile completed</h2>'
      || '<table style="border-collapse:collapse;">'
      || public.found_email_row('Name',          new.full_name)
      || public.found_email_row('Email',         new.email)
      || public.found_email_row('Phone',         new.phone)
      || public.found_email_row('Location',      v_location)
      || public.found_email_row('Life stage',    new.life_stage)
      || public.found_email_row('Activities',    array_to_string(new.activities, ', '))
      || public.found_email_row('Where from',    new.where_from)
      || public.found_email_row('Family values', array_to_string(new.family_values, ', '))
      || public.found_email_row('School type',   array_to_string(new.school_types, ', '))
      || public.found_email_row('Love language', new.love_language)
      || public.found_email_row('Initiator',     new.initiator)
      || public.found_email_row('Personality',   new.personality)
      || public.found_email_row('Hoping to find',array_to_string(new.hoping_to_find, ', '))
      || public.found_email_row('Completed',     to_char(now(), 'Mon DD, YYYY HH24:MI') || ' UTC')
      || '</table></div>'
  );
  return new;
end;
$$;

drop trigger if exists found_on_profile_completed on public.early_access_users;
create trigger found_on_profile_completed
  after update on public.early_access_users
  for each row
  when (new.profile_completed is true and old.profile_completed is false)
  execute function public.found_notify_profile_completed();

-- 6. Notify on contact form (Give / Invest / Donate) ----------
--    Format (Sam's spec): Type, Name, Message, Email, Time.
create or replace function public.found_notify_contact()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_type text := coalesce(nullif(new.type, ''), 'contact');
begin
  perform public.found_send_email(
    'New FOUND ' || upper(v_type) || ' - ' || coalesce(new.name, 'unknown'),
    '<div style="font:14px Arial,sans-serif;color:#111;">'
      || '<h2 style="font:600 18px Arial,sans-serif;margin:0 0 14px;">New ' || v_type || ' inquiry</h2>'
      || '<table style="border-collapse:collapse;">'
      || public.found_email_row('Type',    v_type)
      || public.found_email_row('Name',    new.name)
      || public.found_email_row('Message', new.message)
      || public.found_email_row('Email',   new.email)
      || public.found_email_row('Time',    to_char(now(), 'Mon DD, YYYY HH24:MI') || ' UTC')
      || '</table></div>'
  );
  return new;
end;
$$;

drop trigger if exists found_on_contact on public.contact_submissions;
create trigger found_on_contact
  after insert on public.contact_submissions
  for each row execute function public.found_notify_contact();

-- 7. Early-access location stats (for admin.html dashboard) ----
--    Returns signup counts grouped by state / city / ZIP.
--    Locked to an admin allowlist — checked against the caller's JWT.
--
--    >>> Edit the allowlist below to your real admin emails. <<<
create or replace function public.early_access_stats()
returns table (
  state    text,
  city     text,
  zip      text,
  signups  bigint
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller text := lower(coalesce(auth.jwt() ->> 'email', ''));
begin
  -- ---- ADMIN ALLOWLIST — edit these emails ----
  if v_caller not in (
       'hello@found.community',
       'ryderscott33@icloud.com',
       'ryderschilling@gmail.com'
     ) then
    raise exception 'Not authorized';
  end if;

  return query
  select
    coalesce(nullif(u.raw_user_meta_data->>'state', ''), '—')::text as state,
    coalesce(nullif(u.raw_user_meta_data->>'city',  ''), '—')::text as city,
    coalesce(nullif(u.raw_user_meta_data->>'zip',   ''), '—')::text as zip,
    count(*)::bigint as signups
  from auth.users u
  group by 1, 2, 3
  order by signups desc, state, city;
end;
$$;

-- Only signed-in users can even attempt the call; the JWT check above
-- then narrows it to admins. Never expose this to the anon role.
revoke all on function public.early_access_stats() from public, anon;
grant execute on function public.early_access_stats() to authenticated;

-- ============================================================
-- DONE.
--
-- Test signup email:  sign up on the site with a ZIP + phone.
-- Test profile-completed email: finish complete-profile.html, OR flip the
--   flag on a test user:
--   update public.early_access_users set profile_completed = false
--     where email = 'test@example.com';
--   update public.early_access_users
--     set profile_completed = true, life_stage = 'Married',
--         activities = '{Hiking,Coffee}'
--     where email = 'test@example.com';
-- Test contact email:
--   insert into public.contact_submissions (type, name, email, message)
--   values ('give', 'Test User', 'test@example.com', 'testing notifications');
--
-- Test stats (run while signed in as an admin, or from admin.html):
--   select * from early_access_stats();
--
-- Debug delivery: select * from net._http_response order by created desc limit 5;
-- ============================================================
