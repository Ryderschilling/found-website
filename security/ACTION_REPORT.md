# FOUND — Security Action Report

Date: 2026-05-25 · Audit by: senior-architect mode against the FOUND repo, Supabase migrations, and website folder.

---

## TL;DR — What I Found

You're in better shape than I expected. The hard architectural decisions were made correctly. The gaps are concentrated in three areas: client-side token storage (now fixed), inbound abuse protection (no rate limiting, no CSAM scanning), and observability (no logging, no error tracking, no Sentry).

| Verdict | Item |
|---|---|
| ✅ Strong | 58 RLS policies across 25 tables, all RLS-enabled at table level |
| ✅ Strong | Service role key never in mobile bundle — only in two server-side scripts via env vars |
| ✅ Strong | Admin panel uses anon key + `_require_admin()` RPC guard. No service_role in browser. |
| ✅ Strong | `.env` gitignored, `.env.example` documents the rule "service role NEVER goes in here" |
| ✅ Strong | Block + Report + Delete Account already wired (migrations 0036, 0038) — Apple Guideline 1.2 + 5.1.1(v) covered |
| ✅ Strong | Client-side wordlist filter (`contentFilter.js`) for App Store Guideline 1.2 |
| ✅ Strong | `raw_user_meta_data` only used in INSERT triggers, never in RLS USING/WITH CHECK |
| 🛠 Fixed today | Session tokens were in AsyncStorage (unencrypted on Android). Moved to expo-secure-store (Keychain/Keystore) |
| 🛠 Fixed today | Apple Privacy Manifest added to app.json (mandatory since May 2024) |
| 🛠 Fixed today | `/.well-known/security.txt` VDP dropped into the website |
| 🔴 Critical gap | No rate limiting in front of Supabase API — scraping is currently trivial |
| 🔴 Critical gap | No CSAM scanning on photo uploads — federal liability under 18 U.S.C. § 2258A |
| 🔴 Critical gap | No Sentry / no error tracking / no logging pipeline |
| 🟡 High gap | No CI security workflow (no Dependabot config, no Snyk, no secret scanning) |
| 🟡 High gap | No public privacy policy or ToS on found.community |
| 🟡 High gap | No DPA signed with Supabase, Resend, Netlify |
| 🟡 High gap | EXIF data not stripped from uploaded photos (precise location leak) |

---

## What I Changed This Session

### 1. `src/lib/supabase.js` — session storage moved to SecureStore

Before: tokens in AsyncStorage (Android = unencrypted SQLite). After: tokens in iOS Keychain / Android Keystore via `expo-secure-store`.

**You need to:**
```bash
cd /Users/<you>/Developer/found-app   # wherever your repo lives locally
npx expo install expo-secure-store
```

Then rebuild:
```bash
npx expo prebuild --clean   # if you have a custom dev client
eas build --platform all --profile preview
```

**Migration note:** users currently signed in have their session in AsyncStorage. After this ships, they'll be logged out once. The app will re-authenticate them via magic link or password. Expect a single bump in "signed-out" telemetry the day the build ships. You can mitigate by adding a one-shot migration script that reads from AsyncStorage on first run and re-saves to SecureStore, but it's not worth the complexity — let users sign in once and move on.

### 2. `app.json` — Apple Privacy Manifest added

Apple requires this since May 2024. Without it, App Store submissions get rejected. The manifest declares: email, name, phone, address, precise location, photos, user content, user ID, device ID, crash data, performance data. All linked to identity (your app is signed-in only), none used for tracking. API reasons: UserDefaults (CA92.1), FileTimestamp (C617.1), SystemBootTime (35F9.1), DiskSpace (E174.1) — the standard Expo set.

**You need to:** rebuild and resubmit on next App Store push. Add additional API reasons if you ever ship analytics SDKs, ad SDKs, or other tracking libraries.

### 3. `website/.well-known/security.txt` — VDP page

Industry-standard responsible disclosure file at `/.well-known/security.txt`. Researchers find it automatically.

**You need to:** ensure Netlify serves files in `.well-known/` (it does by default for static sites — no config needed). Confirm by visiting `https://found.community/.well-known/security.txt` after next deploy. Also set up the `security@found.community` mailbox in Resend or Google Workspace (whichever you use for email).

---

## Artifacts Created in Found.community/security/

1. **`SECURITY_PLAYBOOK_FOUND.md`** (from earlier today) — the master playbook.
2. **`THREAT_MODEL.md`** — STRIDE + top 12 threats ranked, review cadence.
3. **`INCIDENT_RESPONSE.md`** — 72-hour breach runbook + user notification template.
4. **`RLS_AUDIT_CHECKLIST.md`** — quarterly RLS verification queries.
5. **`CLOUDFLARE_RULES.md`** — exact rate-limiting rules to deploy.
6. **`CI_SECURITY_WORKFLOW.yml`** — drop into `.github/workflows/` for automated scanning.
7. **`ACTION_REPORT.md`** — this file.

---

## What You Need to Do This Week (Ordered by Leverage)

### Day 1 (today) — Confirm & ship

1. `npx expo install expo-secure-store` in your local repo and rebuild. Confirm the app still logs in / out / persists session correctly after sign-out + sign-back-in.
2. Push the website with the new `.well-known/security.txt`. Verify it serves at `https://found.community/.well-known/security.txt`.
3. Create `security@found.community` mailbox.

### Day 2–3 — Cloudflare in front of Supabase

4. Supabase dashboard → Settings → Custom Domains → set `api.found.community`. Follow the CNAME instructions.
5. Cloudflare DNS → confirm CNAME + orange-cloud proxy.
6. Update `.env` → `EXPO_PUBLIC_SUPABASE_URL=https://api.found.community`. Rebuild.
7. Deploy the rate-limiting rules from `CLOUDFLARE_RULES.md`. Use the bash verification script to confirm rules fire at expected thresholds.

### Day 4–5 — Observability

8. Sign up for Sentry (free tier). Install `@sentry/react-native`:
```bash
npx @sentry/wizard@latest -i reactNative
```
Drop the DSN into `EXPO_PUBLIC_SENTRY_DSN` env var. Confirm a deliberate `throw new Error("sentry test")` shows up in the Sentry dashboard.

9. Drop `CI_SECURITY_WORKFLOW.yml` at `.github/workflows/security.yml`. Push. Confirm the workflow runs on the next PR. Add `SNYK_TOKEN` to GitHub Secrets if you sign up for Snyk (free tier covers solo founders).

10. Enable Dependabot in GitHub repo Settings → Code security → Dependabot alerts + security updates.

### Week 2 — Legal + CSAM

11. Email legal@supabase.io requesting the DPA. Same with partnerships@resend.com and Netlify support. Sign all three.
12. Use TermsFeed ($60–100) to generate a privacy policy + ToS. Match the Apple Privacy Manifest data categories exactly. Publish at `https://found.community/privacy` and `https://found.community/terms`.
13. Stand up Thorn Safer integration. Pricing: email contact@safer.io for low-volume pricing (probably $500–1500/yr for FOUND's scale). The integration is async — on photo upload, queue a scan job, quarantine if hit, file NCMEC CyberTipline report. The 0024 / 0006 / 0018 photo migrations are where the upload paths live; wrap each in a pre-store scan call.

### Week 3 — Quick wins

14. EXIF strip on upload. Two options:
    - Client-side: use `expo-image-manipulator` to re-encode the image before upload (strips EXIF as a side effect).
    - Server-side: Supabase Edge Function that wraps the storage upload and runs ImageMagick or a Node EXIF stripper.
    Client-side is simpler and good enough. Server-side is more defensive but adds latency.
15. TOTP MFA. Supabase Auth supports it — enable in dashboard → Authentication → MFA. Add an opt-in toggle in your account settings screen.
16. Tabletop drill — pick one threat from `THREAT_MODEL.md` and walk through `INCIDENT_RESPONSE.md` with yourself. Note any gaps. 30 minutes.

---

## What I Did NOT Touch

I deliberately did not:
- Install npm packages on your computer (that's a local dev action — you do it).
- Set up Cloudflare, Sentry, or Thorn accounts (require your credentials).
- Sign the Supabase DPA (requires your legal signature).
- Modify any RLS policy or migration (existing ones look solid; changes need careful testing).
- Touch the website's privacy/terms pages (no current pages to edit; you'll need to write or buy them).

These are the items where I'd add risk by doing them blind. They're listed in the week-by-week plan above.

---

## Budget Check

Cost of doing everything above:

| Item | Cost | When |
|---|---|---|
| Cloudflare Pro | $20/mo | Day 2 |
| Sentry free tier | $0 | Day 4 |
| GitHub Pro (secret scanning) | $4/mo | Day 4 |
| Snyk free tier | $0 | Day 4 |
| Privacy policy (TermsFeed) | $60–100 one-time | Week 2 |
| Thorn Safer (CSAM) | ~$500–1500/yr | Week 2 |
| `security@found.community` mailbox | Already paid via existing email | Day 1 |
| **Total to be properly hardened** | **~$30/mo + $100 one-time + $1k/yr Thorn** | 3 weeks |

That's the deal. ~$30/month operating cost + a one-day Thorn integration to get to a defensible position on a faith + location + messaging app.

---

## What Comes Next After This Sprint

- **Month 2:** vCISO retainer if budget allows ($500–1500/mo). I can keep operating as your ongoing reviewer in this thread for free, but a human retainer at $50k+ ARR is worth it.
- **Month 3:** First tabletop drill. Confirm incident response actually works.
- **Month 6:** Privacy lawyer engagement ($5k retainer for template DPA review + breach-notification templates).
- **$50k ARR:** Launch bug bounty (HackerOne or Bugcrowd, ~$5k/yr budget).
- **$100k ARR / Series A:** First proper pentest ($20–40k, annual cadence).
