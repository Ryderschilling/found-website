# Thorn Safer — Supabase Edge Function Template

Purpose: scan every newly uploaded photo against Thorn Safer's CSAM hash database before it's served. Confirmed hits get quarantined, the account terminated, and an NCMEC CyberTipline report filed.

This is a **template** — Thorn requires you to sign an agreement and get API credentials before it works. The function below is the integration plumbing; you fill in the credentials.

---

## 1. Get Thorn access

Email <strong>contact@safer.io</strong> describing FOUND (faith + community app, low volume to start). Expect a vendor agreement + pricing call. Solo founders / pre-revenue usually land around $500–1500/yr.

You'll receive:
- API endpoint URL
- API key
- An NCMEC reporting account (Thorn brokers this for you)

Store credentials as Supabase Edge Function secrets, not in your repo:

```bash
supabase secrets set SAFER_API_URL=https://api.safer.io/v1
supabase secrets set SAFER_API_KEY=...
supabase secrets set NCMEC_REPORTER_ID=...
```

---

## 2. Edge Function: `supabase/functions/scan-photo/index.ts`

```ts
// ─────────────────────────────────────────────────────────────────────────
// scan-photo
//
// Triggered by Storage object-created webhook on every photo bucket.
// 1. Downloads the file from storage.
// 2. Sends a perceptual hash to Thorn Safer.
// 3. If a CSAM match is returned:
//    - Move file to `quarantine` bucket (deny-all RLS)
//    - Mark profile.is_suspended = true
//    - Insert a row into `csam_incidents` with the file path + thorn match id
//    - Trigger an alert email to security@found.community
// 4. Otherwise: mark `photos.scanned = true`.
//
// This function uses the SERVICE ROLE key. It must never be called from the
// client. Trigger only via Storage webhook or pg_cron.
// ─────────────────────────────────────────────────────────────────────────

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPA = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

const SAFER_URL = Deno.env.get('SAFER_API_URL')!;
const SAFER_KEY = Deno.env.get('SAFER_API_KEY')!;

interface StorageHookBody {
  type: 'INSERT' | 'UPDATE' | 'DELETE';
  table: 'objects';
  record: { bucket_id: string; name: string; owner: string | null };
}

serve(async (req) => {
  try {
    const body: StorageHookBody = await req.json();
    if (body.type !== 'INSERT') return new Response('skip', { status: 200 });

    const { bucket_id, name, owner } = body.record;
    if (!['avatars', 'profile-photos', 'group-photos', 'group-post-photos'].includes(bucket_id)) {
      return new Response('not a photo bucket', { status: 200 });
    }

    // Pull file
    const { data, error } = await SUPA.storage.from(bucket_id).download(name);
    if (error || !data) {
      console.error('download failed', error);
      return new Response('download fail', { status: 500 });
    }

    // Send to Thorn — see Thorn API docs for exact request shape.
    // This is a placeholder request body matching the typical Safer match endpoint.
    const form = new FormData();
    form.append('file', data, name.split('/').pop());
    form.append('client_reference', `${bucket_id}/${name}`);

    const resp = await fetch(`${SAFER_URL}/match`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${SAFER_KEY}` },
      body: form,
    });
    if (!resp.ok) {
      console.error('safer error', resp.status, await resp.text());
      return new Response('safer error', { status: 500 });
    }
    const result = await resp.json() as { is_match: boolean; match_id?: string; severity?: string };

    if (result.is_match) {
      await handleHit({ bucket_id, name, owner, matchId: result.match_id ?? null });
      return new Response('quarantined', { status: 200 });
    }

    // Mark as scanned clean (storage_path is unique enough to find the row)
    await SUPA.from('photos')
      .update({ scanned: true, scanned_at: new Date().toISOString() })
      .eq('storage_path', `${bucket_id}/${name}`);

    return new Response('clean', { status: 200 });
  } catch (e) {
    console.error('scan-photo exception', e);
    return new Response('error', { status: 500 });
  }
});

async function handleHit(input: {
  bucket_id: string;
  name: string;
  owner: string | null;
  matchId: string | null;
}) {
  // 1. Move file to quarantine bucket
  await SUPA.storage.from(input.bucket_id).move(input.name, `quarantine/${input.name}`);
  // (Operationally: have a `quarantine` bucket with no public read and an RLS
  // deny-all policy. Use service role only.)

  // 2. Suspend the owning account
  if (input.owner) {
    await SUPA.from('profiles')
      .update({ is_suspended: true, suspended_reason: 'CSAM_AUTO' })
      .eq('id', input.owner);
  }

  // 3. Record the incident
  await SUPA.from('csam_incidents').insert({
    bucket_id: input.bucket_id,
    storage_path: input.name,
    profile_id: input.owner,
    thorn_match_id: input.matchId,
    reported_to_ncmec: false,
  });

  // 4. Alert ops out-of-band (so a takedown can be audited by a human)
  await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${Deno.env.get('RESEND_API_KEY')}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: 'security@found.community',
      to: 'security@found.community',
      subject: '[CSAM HIT] photo auto-quarantined',
      text:
        `Bucket: ${input.bucket_id}\nPath: ${input.name}\nOwner: ${input.owner}\n` +
        `Thorn match id: ${input.matchId}\n\n` +
        `Action items:\n` +
        ` 1. File NCMEC CyberTipline report (https://report.cybertip.org/) within 24h.\n` +
        ` 2. Mark csam_incidents.reported_to_ncmec = true with cybertip_id.\n` +
        ` 3. Preserve evidence per 18 U.S.C. § 2258A (90 days minimum).\n`,
    }),
  });
}
```

---

## 3. Required migration

```sql
-- Run this once before deploying the function.
-- Add columns to track scan state on photos
alter table public.photos
  add column if not exists scanned boolean not null default false,
  add column if not exists scanned_at timestamptz;

-- Incident table (admin-only)
create table if not exists public.csam_incidents (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  bucket_id text not null,
  storage_path text not null,
  profile_id uuid references public.profiles(id) on delete set null,
  thorn_match_id text,
  reported_to_ncmec boolean not null default false,
  cybertip_id text,
  notes text
);
alter table public.csam_incidents enable row level security;

-- Only platform admins can read this table
create policy "csam_incidents admin read"
  on public.csam_incidents for select
  using ( public._is_admin() );

-- No client-side writes — function uses service role
create policy "csam_incidents admin write"
  on public.csam_incidents for all
  using ( public._is_admin() )
  with check ( public._is_admin() );

-- Quarantine bucket via SQL (Supabase Storage)
insert into storage.buckets (id, name, public)
  values ('quarantine', 'quarantine', false)
  on conflict (id) do nothing;
```

---

## 4. Deploy

```bash
supabase functions deploy scan-photo --no-verify-jwt
```

`--no-verify-jwt` because Storage webhooks don't include a JWT. Lock it down by:
- Using a long random URL slug; OR
- Adding a shared secret check at the top of the function:

```ts
if (req.headers.get('x-webhook-secret') !== Deno.env.get('STORAGE_HOOK_SECRET')) {
  return new Response('forbidden', { status: 403 });
}
```

Then set the same secret in the Storage webhook config.

---

## 5. Hook up the trigger

Supabase dashboard → Database → Webhooks → Create a new "HTTP Request" hook:
- Table: `storage.objects`
- Events: INSERT
- URL: your deployed function URL
- HTTP headers: `x-webhook-secret: <STORAGE_HOOK_SECRET>`

---

## 6. Manual NCMEC reporting

The CyberTipline at https://report.cybertip.org/ is where you file the report. Thorn Safer can also broker reports automatically depending on plan. Confirm with them which option you're on; manual reporting is the safe fallback.

For each hit:
1. Receive auto-quarantine email.
2. Open https://report.cybertip.org/ → "Make a Report".
3. Reference type: ESP (Electronic Service Provider).
4. Include: thorn_match_id, storage path, account id, account email if available.
5. Submit. Save the CyberTip ID into the `csam_incidents` row.

Federal law (18 U.S.C. § 2258A) requires reporting "as soon as reasonably possible" — interpret as same-day, no longer than 24 hours.

---

## 7. What this does NOT do

- It does not pre-scan video, only still images. For video, you need a frame-extraction step before the Thorn call.
- It does not detect novel CSAM (Thorn matches against known hashes). For unknown content, you would need a classifier — a much higher cost option, not necessary for FOUND's risk profile right now.
- It does not check text. Use a separate moderation pass (OpenAI moderation endpoint, free) on `messages` and `group_posts` if you want grooming-language detection.
