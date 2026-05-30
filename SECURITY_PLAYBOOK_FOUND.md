# FOUND — Security Playbook

How a senior cybersecurity consultant would actually protect this app. Brutally honest, FOUND-specific, ordered by what matters most.

---

## TL;DR — The Real Picture

You are building **the highest-risk class of consumer app**: religious affiliation (GDPR Article 9 "special category" — same tier as health data), precise location, private 1:1 messaging, photo uploads, community connection features. That stack triggers three legal regimes simultaneously: **GDPR Article 9, CCPA/CPRA, and the REPORT Act (CSAM scanning)**. If a security expert looked at FOUND today they'd flag five things first:

1. **Supabase `service_role` key discipline** — if that ever lands in the mobile bundle, in a GitHub commit, or in a screenshot, the app is over. Game-ending event.
2. **RLS policies must be indexed and audited per-table** — RLS is your only real wall. One bad policy = full enumeration.
3. **No rate limiting on PostgREST = guaranteed scraping** — WhatsApp got 3.5B accounts scraped in 2025 this exact way.
4. **CSAM scanning is legally required, not optional** — the moment users can upload photos, you have NCMEC reporting obligations under 18 U.S.C. § 2258A. Fines start at $850k.
5. **No abuse/trust-and-safety surface yet** — block, report, mute, content moderation are product features, not "do later."

Everything else is sequencing.

---

## The Three Battles That Matter

**1. Threat modeling against real abuse, not generic OWASP.** Top realistic threats for FOUND:
- **Stalking / doxxing** — attacker friend-gates, cross-references with LinkedIn, finds home.
- **Scraping by zip + faith + age** — builds targeting lists for harassment, romance scams, hate groups.
- **Account takeover** — credential stuffing (40% of dating-adjacent traffic is bots), magic-link interception, SIM swap.
- **Fake accounts at scale** — 20 accounts → ban → 20 more. Block evasion.
- **Grooming surface** — if any minors are present, adult-to-minor DMs are first-order risk.
- **Wild card** — coordinated harassment of a specific denomination. Religious data + location + messaging = ideal target stack.

**2. Data protection under GDPR Art 9 + CCPA + COPPA.** Religious affiliation triggers GDPR Article 9, which means explicit consent + DPIA + enhanced safeguards. CCPA treats it as "sensitive personal information" requiring an opt-out control. COPPA kicks in if anyone under 13 uses the app. **Simplest defensive move: age-gate to 13+ at signup. That alone removes COPPA from the picture.**

**3. Supabase hardening + API abuse prevention.** Supabase is a solid foundation, but a narrow blast radius. RLS done right + service_role discipline + rate limiting = 80% of the technical wins.

---

## Supabase-Specific Hardening (Do These First)

### Service role key — never in client
- **Never** embed `service_role` in the mobile bundle, in Expo config, or anywhere a user can reverse engineer.
- All admin operations go through a backend endpoint (Edge Function or your own Node server) that verifies the user's role server-side, then uses service_role.
- If you started the Supabase project before October 2025, you still have legacy long-lived JWT keys. Rotate to the new publishable/secret asymmetric keys.

### RLS done right
- Every table with user data gets explicit `FOR SELECT`, `FOR INSERT`, `FOR UPDATE`, `FOR DELETE` policies. No exceptions.
- **Index every column referenced in RLS policies.** Missing indexes on `user_id`, `zip_code`, `auth.uid()` columns = 100–200x slowdown at scale. Supabase's own 2025 retro flagged this as the #1 performance killer.
- **Never use `user_metadata` for authorization.** Authenticated users can edit their own `user_metadata` via the SDK. If your policy says `user_metadata->>'role' = 'admin'`, a user can self-promote. Use a separate `roles` table or custom JWT claims set by auth hooks.
- Defense in depth: even with RLS, do an explicit authz check in your API/Edge Function code on sensitive operations.

### Storage buckets
- All buckets private by default. Photos especially — face data has biometric implications.
- Policy enforces the user can only upload to their own folder: `auth.uid()::text = split_part(name, '/', 1)`.
- Never set a bucket `public = true` for user uploads. Enumeration is trivial.

### PostgREST attack surface
- Disable verbose error messages in production (don't leak schema).
- Restrict the `anon` role to specific filtered endpoints. Don't allow `/users` with no filters — that's a full-table dump.
- Enforce pagination, max 100 rows per response.

### Auth
- TOTP MFA, not SMS. SMS = SIM swap. Magic links acceptable as recovery, not primary MFA.
- Session: 1h access token, 7d refresh. On IP/UA change, re-challenge with MFA.
- Password reset must require MFA re-verification before the new password sticks.
- Account lockout after 5 failed logins per user per 10 min.

---

## Rate Limiting — Mandatory Before Launch

Per-IP alone is insufficient (mobile users share NAT). You need **identity-aware** rate limiting. Cloudflare Pro ($20/mo) sits in front of Supabase.

| Endpoint | Limit | Scope |
|---|---|---|
| `/auth/signup` | 10 / 10 min | per IP |
| `/auth/login` | 5 failures / 10 min | per user |
| `/auth/magic-link` | 3 / hour | per email |
| `/profiles?zip=*` | 100 / min | per authed user |
| `/messages` POST | 50 / day | per user |
| `/messages` GET | 200 / min | per user |
| `/storage/upload` | 10MB / day | per user |
| `/report` | 10 / day | per user |

Without these, FOUND will be scraped within weeks of launch.

---

## Mobile App Hardening (Expo / React Native)

What's worth doing as a solo founder vs theater:

**Worth it:**
- `expo-secure-store` for tokens — never AsyncStorage.
- Validate file MIME types server-side, not just extension.
- Universal Links (iOS) / App Links (Android) instead of custom URL schemes (deep link hijacking).
- Lock dependency versions. Commit `package-lock.json` / `yarn.lock`.
- Enable Dependabot (free, GitHub native).
- Sentry for crash + error tracking (free tier).

**Skip until you have revenue and scale:**
- SSL certificate pinning — operational cost > benefit for now. TLS 1.2+ is fine.
- Heavy obfuscation — slows casual reverse engineering, won't stop a real attacker.
- App Attest / SafetyNet — defer until you handle payments.

**Borderline:**
- Jailbreak/root detection via JailMonkey. Useful as a signal, log it to Sentry. Don't hard-block — you'll lock out security researchers and harm legit users.

---

## CSAM Scanning — Legally Required Day One

The moment users upload photos, **18 U.S.C. § 2258A applies**. You are legally required to detect and report Child Sexual Abuse Material to NCMEC. The REPORT Act (2024) reinforced this. Penalties start at $850k per first offense.

**The right answer:** integrate **Thorn Safer** (industry standard, ~$500–2000/year for low volume). On upload, async scan. If CSAM detected: do not store the file, log the incident, file a CyberTipline report with NCMEC, keep metadata for 1 year (legal preservation).

This is non-optional. Don't launch image uploads without it.

**Text moderation:** OpenAI Moderation API (~$0.001 / 1000 tokens) on outgoing messages and bios. Cheap. Filters hate, sexual, self-harm.

---

## Trust & Safety — Product Features, Not Afterthoughts

Ship these at MVP:
- **Block** — blocked user can't message, see profile, search for you.
- **Mute** — relationship persists, you don't see their content.
- **Report** — user, message, photo. Routes to a moderation queue.
- **Moderation queue** — start as a simple Supabase view you check daily. Tools like OpenModeration come later.
- **Community Guidelines** — public doc. Harassment, hate, impersonation, CSAM = ban. Clear and short.

A community app's security is inseparable from its trust & safety surface. Bad actors will probe both. Raise the cost of attack.

---

## Compliance Reality

| Regime | Applies? | Cost of Compliance | Penalty if ignored |
|---|---|---|---|
| **GDPR Art 9 (religious data)** | Yes if any EU users (assume yes) | Explicit consent UI, DPIA, DPA with vendors | €10M or 2% global revenue |
| **CCPA / CPRA** | Yes if any California users | Privacy controls, deletion, "Limit Sensitive Data" toggle | $7,500 per record |
| **COPPA (under-13)** | Only if you allow under-13 | Verifiable parental consent (hard) | $50k+ per violation |
| **REPORT Act / 2258A (CSAM)** | Yes the moment you allow image upload | Thorn Safer + NCMEC reporting | $850k–$1M+ |
| **Apple Privacy Label** | Yes (App Store requirement) | Accurate disclosure | App rejected |
| **Apple Privacy Manifest** | Yes (mandatory May 2024+) | Justify all APIs used + 3rd party SDKs | App rejected |

**Strong recommendation:** **age-gate to 13+ at signup**. That alone takes COPPA off the table. If you ever want under-13 users, you need verifiable parental consent (face-match ID, parent email verification) which is genuinely expensive.

---

## Secrets Discipline

**Where things go:**
- Supabase **anon** key → mobile bundle, fine (designed to be public, respects RLS).
- Supabase **service_role** key → server-only `.env`, never anywhere else.
- JWT signing key → Supabase manages, rotate quarterly.
- Database URL with creds → server `.env` only.
- OpenAI / Thorn / Resend API keys → server `.env` only.

**Setup:**
- `.env`, `.env.local`, `.env.production` in `.gitignore`.
- `.env.example` with placeholder values committed.
- GitHub Secret Scanning enabled (free with Pro or $21/mo).
- Pre-commit hook with TruffleHog (free, 30-min setup).
- Snyk free tier for dependency scanning.

---

## Logging & Incident Response

**Log:** auth events, API calls (endpoint + user_id + result code), data writes, abuse reports, admin actions, security events (rate-limit hits, jailbreak detections).

**Don't log:** passwords, JWTs, magic-link tokens, religious affiliation in plaintext, full message text, full photos, full stack traces.

**Stack for solo founder:** Sentry (free tier) + structured JSON logs to stdout + Cloudflare access logs. Upgrade to Datadog at $100k+ ARR.

**Breach timeline (GDPR — non-negotiable):**
- **Hour 0–1:** detect, triage, scope.
- **Hour 1–6:** preserve evidence, contain, brief counsel.
- **Hour 6–24:** identify affected users, draft notification.
- **Hour 24–72:** notify the relevant EU DPA in writing. Notify affected users.
- Failure = €10M or 2% global revenue.

Have a 1-page incident response runbook written **before** you launch.

---

## Vendor Risk

Request a signed DPA from each:
- **Supabase** — legal@supabase.io. ISO 27001 certified. Confirm data residency (US default; EU available).
- **Resend** — partnerships@resend.com. SOC 2 Type II.
- **Netlify** — DPA available. SOC 2 Type II.
- **Thorn (when added)** — DPA + NCMEC integration confirmed.

List all subprocessors in your privacy policy. Supabase had a support-agent credential incident in 2025 — proves vendor breach is real.

---

## What Actually Scares Security People About FOUND-Class Apps

1. **Social engineering of you.** Solo founder = single point of failure. Attacker calls pretending to be a lawyer, you hand over creds. Mitigation: never give credentials by phone. Verify through known channel.
2. **Grooming at scale.** Adult-aged accounts targeting flagged minors in DMs. You don't notice for 6 months. Mitigation: flag adult-to-minor messaging patterns, human review. Or just age-gate to 18+ if FOUND is dating-adjacent.
3. **Untested backups.** Supabase backs up. You've never tested restore. Ransomware hits. Backup is corrupted. Mitigation: test restore quarterly.
4. **Determined attackers targeting religion.** A hate group targeting your denomination. They scrape, harass, doxx. Mitigation: rate limiting, abuse detection, pentesting, bug bounty.
5. **Supply chain poisoning.** A popular npm package gets compromised (chalk, debug, axios all hit in 2025–26). You update. Code exfiltrates user data. Mitigation: lock versions, audit updates, SCA tools.
6. **Regulatory surprise.** A state AG subpoenas data. You hand it over without scrutiny = privacy violation. Mitigation: privacy lawyer on retainer ($5k for templates), legal response playbook.
7. **Scaling without security.** At 100k users, no logging, no audit trail. Can't notify in 72h. Massive fine. Mitigation: build observability early.

---

## What a vCISO Would Deliver

If you hired Latacora, Bishop Fox, Trail of Bits, or a startup-focused vCISO retainer, this is what they'd hand you:

1. **Threat model document** (STRIDE + risk matrix, top 20 risks ranked).
2. **Data flow diagram** with trust boundaries annotated.
3. **Risk register** (table, owner, timeline, status).
4. **Security policy** (data retention, AUP, change management).
5. **Incident response plan** (72-hour breach runbook, contacts, templates).
6. **Architecture review** with specific code-level recommendations.
7. **RACI matrix** for security responsibilities.
8. **12-month security roadmap**.
9. **Monthly security scorecard** for board / investors.
10. **Quarterly review cadence**.

You can produce all of these yourself for FOUND in a long weekend with this playbook as the spine.

---

## Cost-Realistic Phased Plan

| Phase | What | Cost | When |
|---|---|---|---|
| **Bootstrap** | Threat model, RLS audit, Dependabot, Sentry free, Cloudflare free, GitHub Secret Scanning, `.well-known/security.txt` (VDP) | $0–$50/mo | Now |
| **MVP launch** | Cloudflare Pro, Thorn Safer, OpenAI Moderation, TermsFeed legal docs, Supabase DPA | $100–$300/mo | Before public launch |
| **Traction (1–10k users)** | vCISO retainer (2–4 hrs/mo), Sentry Team, basic anomaly alerts | $500–$1,500/mo | At first signs of PMF |
| **Mature ($100k ARR / Series A)** | Pentest (annual), bug bounty (HackerOne/Bugcrowd), Datadog, cyber liability insurance | $5k–$10k/mo + $20–40k pentest | Pre-Series A |

---

## The 90-Day Plan for FOUND Specifically

**Weeks 1–2 — Foundation**
- Write the 1-page threat model. Identify top 10 risks.
- Audit every Supabase RLS policy. Confirm `user_id`, `zip_code` indexed.
- Verify `service_role` not in mobile bundle. Grep your repo.
- Rotate Supabase keys if pre-October-2025 project.
- Confirm `expo-secure-store` is holding tokens, not AsyncStorage.

**Weeks 3–4 — Secrets + CI**
- `.gitignore` audit, `.env.example` checked in.
- GitHub Secret Scanning on.
- TruffleHog pre-commit hook.
- Dependabot on.
- Snyk free tier on.

**Weeks 5–6 — Legal + CSAM**
- Integrate Thorn Safer before image upload ships publicly.
- Privacy policy (TermsFeed, match Apple Privacy Label exactly).
- Terms of Service (plain language, age 13+, community standards).
- `/.well-known/security.txt` VDP page.

**Weeks 7–8 — Auth + Rate Limiting**
- Cloudflare Pro, rate-limit rules per table above.
- TOTP MFA in Supabase. Optional first, mandatory later for power users.
- Account lockout after 5 failed logins.
- Password reset requires MFA re-verification.

**Weeks 9–12 — Logging + IR**
- Structured JSON logs.
- Sentry integrated, source maps uploaded.
- 1-page incident response runbook written.
- Simulate a breach — can you scope affected users in 1 hour?
- Request Supabase DPA. Sign.

**Month 4** — Write security policy (2 pages), risk register table. If budget allows: vCISO retainer at $500–1500/mo for ongoing oversight.

---

## Single Best Next Move

If you do only one thing this week: **audit the mobile bundle and your GitHub repo for `service_role` exposure**, then **add Cloudflare Pro with the rate-limiting rules above in front of your Supabase API**. Those two moves prevent the two attacks most likely to end FOUND before it scales.

Everything else is sequenced after.

---

*Researched and synthesized for Ryder — May 25, 2026. Sources: GDPR Art 9, CCPA/CPRA 2026 updates, COPPA 2025 FTC rule, 18 U.S.C. § 2258A, Supabase 2025 security retro, OWASP MAS / MSTG, Zimperium 2025 Mobile Threat Report, Thorn Safer, current pentesting / vCISO market rates.*
