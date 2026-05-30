# FOUND — Threat Model v1

Date: 2026-05-25 · Owner: Ryder · Stack: React Native / Expo + Supabase + Netlify + Resend

---

## Scope

The FOUND mobile app and supporting infrastructure: Supabase database (Postgres + PostGIS + Auth + Storage + Realtime), Netlify-hosted marketing site (found.community), Resend transactional email, and the admin moderation panel (admin.html). Includes user-generated content: profiles, photos, private 1:1 messages, group posts, religious affiliation, and approximate location (zip + city + state + lat/lng).

## Assets (ranked by sensitivity)

1. **Religious affiliation** — GDPR Article 9 special category data.
2. **Location data** — zip + city + state + lat/lng, captured once at signup. Identifies residence.
3. **Private 1:1 messages** — interception or leak triggers wiretap-adjacent legal exposure.
4. **User photos** — profile + group post photos. Biometric implications + CSAM risk.
5. **Personal profile data** — full name, phone, age, life stage, family values.
6. **Auth credentials** — session JWTs, password hashes.
7. **Service role key** — full DB access. Compromise = total breach.

## Trust Boundaries

| Boundary | Crossing |
|---|---|
| Mobile app ↔ Supabase API | Public internet, TLS, anon key, JWT |
| Mobile app ↔ Storage buckets | Public internet, TLS, signed URLs |
| Admin panel (admin.html) ↔ Supabase | Browser, anon key, `_require_admin()` RPC guard |
| Backend scripts ↔ Supabase | Server only, service_role key from env |
| Resend ↔ users | Outbound transactional email only |
| Netlify ↔ users | Static site only, no user data collection currently |

---

## STRIDE Analysis — Top Threats

### Spoofing (Identity)
- **Credential stuffing / account takeover.** ~40% of dating-adjacent app traffic is bots. Mitigation: rate limit `/auth/login` at 5 failures / 10 min per email, enforce strong password policy, offer TOTP MFA.
- **Magic-link interception.** Email account compromise → full app account compromise. Mitigation: short link expiry (60 min), bind to device fingerprint, log all magic-link usage.
- **SIM swap** if SMS MFA is added. Mitigation: never use SMS MFA. TOTP only.
- **Password reset social engineering** (Marks & Spencer 2025 pattern). Mitigation: never allow staff to reset user passwords; user self-service only.

### Tampering (Data Integrity)
- **Location spoofing** — attacker fakes GPS to enter a different community. Low impact for FOUND today (zip-based matching, not real-time GPS) but worth monitoring if you ever add live-location features.
- **Mass assignment on profile update** — user submits `{ is_admin: true }`. Mitigation: server-side whitelist on every `UPDATE` RPC. Verify each `update_*` function in migrations rejects unexpected fields.
- **JWT tampering / forged claims.** Mitigation: never read `raw_user_meta_data` in RLS `USING` clauses (confirmed clean). Use `profiles.is_admin` column, set only by `admin_*` RPCs.

### Repudiation
- User denies sending harassing message. Mitigation: message metadata (sender_id, recipient_id, timestamp, thread_id) preserved 1 year via `reports` table on report; full message body retained until either party deletes account.

### Information Disclosure
- **Enumeration / scraping by zip + faith + age** — without rate limiting, an attacker can pull every user. WhatsApp scraped 3.5B accounts via this vector in 2025. Mitigation: Cloudflare WAF with per-user rate limits (see `CLOUDFLARE_RULES.md`).
- **PostgREST error verbosity** leaking schema. Mitigation: confirm `PGRST_LOG_LEVEL` is `error` or `crit` in production.
- **Storage bucket public read** on `avatars` and `group-post-photos` and `group-photos`. Avatars are typical (most apps do this); but file names should be unguessable UUIDs, not `user-1.jpg`. Verify.
- **EXIF data in uploaded photos** can leak precise lat/lng. Mitigation: strip EXIF on upload (client-side or via a Supabase Edge Function).
- **Verbose logs** capturing PII (faith, full names, message bodies). Mitigation: structured logging guidelines in `INCIDENT_RESPONSE.md`.

### Denial of Service
- **Endpoint flooding** on signup, login, message POST. Mitigation: Cloudflare rate limits.
- **Storage quota attacks** — bulk photo uploads. Mitigation: per-user upload cap (10 MB / day).
- **Realtime channel spam.** Mitigation: monitor Supabase Realtime metrics, throttle subscriptions per user.

### Elevation of Privilege
- **Service role key exposure** — the single biggest risk. Mitigation confirmed: only in server-side scripts via env vars; never in mobile bundle.
- **`raw_user_meta_data` self-promotion** — would let users set `is_admin`. Confirmed clean: `is_admin` is a separate column, only mutated by admin RPCs.
- **RLS policy bypass via missing index** causing timeout-based oracle. Mitigation: index every column referenced in policies (RLS audit checklist).

---

## Top 12 Realistic Threats — Ranked

| # | Threat | Likelihood | Impact | Rating | Status |
|---|---|---|---|---|---|
| T1 | API scraping by zip + faith → targeting list | High | Critical | **Critical** | Open — needs Cloudflare WAF |
| T2 | CSAM upload → federal liability | Medium | Critical | **Critical** | Open — needs Thorn Safer |
| T3 | Stalking via cross-reference (FOUND profile + LinkedIn) | High | Critical | **Critical** | Mitigated partially via block/mute |
| T4 | Account takeover via credential stuffing | High | High | **High** | Open — needs rate limit + MFA |
| T5 | Stolen device → JWT exfiltration from AsyncStorage | High | High | **High** | **Fixed 2026-05-25** (moved to SecureStore) |
| T6 | Fake account farms → block evasion | High | Medium | **High** | Partial — block exists, need signup rate limit |
| T7 | Romance / tithe scams via faith trust signal | Medium | High | **High** | Open — moderation queue runs daily |
| T8 | Grooming (if minors present) | Medium if 13+, Low if 18+ | Critical | **High** | Open — recommend 18+ age gate |
| T9 | Supabase service_role key leak | Low | Critical | **High** | Mitigated — env-only, not in mobile |
| T10 | Vendor breach (Supabase / Resend / Netlify) | Low | High | **Medium** | Open — DPAs not yet signed |
| T11 | Supply chain (npm package compromise) | Medium | High | **High** | Open — needs Dependabot + Snyk |
| T12 | EXIF location leak in photos | High | Medium | **Medium** | Open — strip on upload |

---

## Out of Scope (For Now)

- Nation-state attackers, advanced persistent threats.
- Side-channel hardware attacks.
- Physical security of Ryder's laptop (separate concern).
- Cryptographic attacks on TLS/AES (handled by Supabase + AWS).

## Review Cadence

Re-review this threat model quarterly, or any time:
- A new feature touches messaging, location, or photos.
- A vendor is added or replaced.
- A user count milestone is hit (1k, 10k, 100k).
- A real incident occurs.
