# What You Do — Clean Checklist

Everything below is your work. I've prepped all the code, configs, and policy docs in `Found.community/security/`. You execute. In order.

---

## Today (90 minutes total)

### 1. Install secure storage in the app (10 min)
```bash
cd ~/Developer/found-app
npx expo install expo-secure-store
```
Then rebuild a dev/preview build. Sign out and back in once to confirm session persists. You will be logged out one time when this ships to existing users — expected.

### 2. Push the website with the security.txt file (5 min)
The file is already at `website/.well-known/security.txt`. Commit + push. Netlify deploys automatically. Visit `https://found.community/.well-known/security.txt` to confirm it loads.

### 3. Create the security mailbox (10 min)
In Google Workspace (or wherever your email lives), create:
- `security@found.community`
- `privacy@found.community`

Both can forward to your inbox. Just need them to exist.

### 4. Upload privacy + terms to the website (15 min)
Files I prepped:
- `Found.community/security/PRIVACY_POLICY.html`
- `Found.community/security/TERMS_OF_SERVICE.html`

Copy them into your website repo as `website/privacy.html` and `website/terms.html`. Add nav links in the footer. Commit + push. Netlify deploys. Confirm at `https://found.community/privacy.html` and `/terms.html`.

### 5. Sign up for Sentry (10 min)
Go to https://sentry.io → free account → create a React Native project → copy DSN.

### 6. Wire Sentry into the app (40 min)
Open `Found.community/security/SENTRY_SETUP.md`. Follow it top to bottom:
- `npx @sentry/wizard@latest -i reactNative` in your repo
- Drop DSN into `.env.local`
- Copy `src/lib/sentry.js` from the doc into your repo
- Add the two imports in `App.js` (one at the very top, one in the auth listener)
- Wrap `App` with `Sentry.wrap(App)`
- Throw a deliberate error to confirm it appears in Sentry. Then remove.

---

## This week (3-4 hours total)

### 7. Cloudflare in front of Supabase (60 min)
Open `Found.community/security/CLOUDFLARE_RULES.md`. Steps:
1. Supabase dashboard → Settings → Custom Domains → add `api.found.community`. Copy the CNAME they give you.
2. Cloudflare DNS → add the CNAME → orange-cloud the proxy.
3. Wait for SSL to provision (~10 min).
4. Update `.env`: `EXPO_PUBLIC_SUPABASE_URL=https://api.found.community`. Rebuild app.
5. Upgrade Cloudflare to Pro ($20/mo).
6. In Security → WAF → Rate limiting rules: create the 9 rules in the doc, one by one.
7. Run the bash verification script at the bottom of the doc to confirm rate limits fire.

### 8. EXIF stripping on photo uploads (30 min)
Open `Found.community/security/EXIF_STRIP_PATCH.md`. Apply the patches to four files:
- `src/lib/imageSanitize.js` (new — copy the full content)
- `src/lib/uploadAvatar.js` (one import + a few lines in `pickImage`)
- `src/lib/profilePhotos.js` (same pattern)
- `src/lib/groupPhotos.js` (same pattern)
- `src/lib/groupPosts.js` (same pattern)

Then rebuild and run the verification (upload a photo, download from Supabase, run `exiftool` — should see no GPS).

### 9. CI security workflow (15 min)
Copy `Found.community/security/CI_SECURITY_WORKFLOW.yml` to `.github/workflows/security.yml` in your repo. Push. On next PR you'll see the workflow run.

Optional: sign up for Snyk free tier (https://snyk.io) → get a token → add `SNYK_TOKEN` to GitHub repo Secrets.

### 10. Dependabot (5 min)
Copy `Found.community/security/DEPENDABOT.md`'s yaml block into `.github/dependabot.yml`. Commit + push.

Then in GitHub repo Settings → Code security and analysis → enable all five toggles listed in the doc.

### 11. Request DPAs (15 min)
Three quick emails. Copy/paste this template:

> Subject: DPA request for FOUND
>
> Hi — I operate FOUND (https://found.community), a mobile community app for Christians. We handle EU/UK user data and need a Data Processing Agreement on file with you as our processor. Please send your standard DPA. Operator: Ryder Scott, Florida, USA.
>
> Thanks,
> Ryder

Send to:
- `legal@supabase.io`
- `partnerships@resend.com`
- `legal@netlify.com` (or open a ticket from Netlify dashboard)

Sign and file the responses. Save the PDFs in `Found.community/security/dpas/`.

---

## This month (2-3 days of work spread out)

### 12. Thorn Safer (CSAM scanning) — START NOW
Open `Found.community/security/THORN_EDGE_FUNCTION.md`.

Step 1 today: email `contact@safer.io`. Tell them what FOUND is, your scale, and ask for low-volume pricing. Their sales cycle is the bottleneck — start it before the rest.

While you wait for the agreement, the doc has the Edge Function template ready to deploy. Run the SQL migration block (creates `csam_incidents` table and quarantine bucket). Deploy the function (it'll error until you have credentials, that's fine).

When credentials arrive: set the secrets, configure the Storage webhook, test with a single upload.

### 13. TOTP 2FA (1 hour)
Supabase dashboard → Authentication → MFA → enable TOTP.

In your app's Settings screen, add an "Enable two-factor auth" toggle that calls `supabase.auth.mfa.enroll({ factorType: 'totp' })`, shows the QR code, then verifies. Supabase has reference code in their docs: https://supabase.com/docs/guides/auth/auth-mfa

### 14. First tabletop drill (30 min)
Pick one threat from `Found.community/security/THREAT_MODEL.md`. Walk through `INCIDENT_RESPONSE.md` as if it just happened. Note any step you couldn't actually do (e.g., "I don't have a privacy lawyer's number to call"). Fix those gaps.

---

## What I've Already Done

In your app code repo (you'll see these in your next pull):
- `src/lib/supabase.js` — session tokens moved to expo-secure-store (Keychain/Keystore)
- `app.json` — Apple Privacy Manifest added
- `website/.well-known/security.txt` — VDP file

In `Found.community/security/`:
- `ACTION_REPORT.md` — your findings + state of play
- `THREAT_MODEL.md` — STRIDE + top 12 threats ranked
- `INCIDENT_RESPONSE.md` — 72-hour breach runbook + user notice template
- `RLS_AUDIT_CHECKLIST.md` — quarterly RLS verification queries
- `CLOUDFLARE_RULES.md` — exact rules to deploy
- `CI_SECURITY_WORKFLOW.yml` — drop into .github/workflows
- `EXIF_STRIP_PATCH.md` — code patch to strip photo metadata
- `SENTRY_SETUP.md` — full Sentry wire-up
- `PRIVACY_POLICY.html` — religion-aware, COPPA-aware, GDPR+CCPA rights
- `TERMS_OF_SERVICE.html` — Florida-jurisdictioned, class-action waiver, CSAM zero-tolerance
- `THORN_EDGE_FUNCTION.md` — CSAM scanning function template + NCMEC procedure
- `DEPENDABOT.md` — auto-update yaml + GitHub settings to flip
- `WHAT_YOU_DO.md` — this file

---

## Cost Summary

| Item | When | Cost |
|---|---|---|
| Cloudflare Pro | This week | $20/mo |
| GitHub Pro (private secret scanning) | This week | $4/mo |
| Sentry free tier | Today | $0 |
| Snyk free tier | This week | $0 |
| Thorn Safer | When agreement closes | ~$500-1500/yr |
| Privacy lawyer retainer (suggested) | Within 90 days | $5k one-time |
| **Running cost to be solid** | | **~$24/mo + $1k/yr + one $5k retainer** |

---

## What "Done" Looks Like

When you've checked off everything above, FOUND will be in a position where:
- Tokens are encrypted on device (Keychain/Keystore).
- Apple Privacy Manifest is filed.
- Photos have no GPS metadata.
- Every upload is scanned for CSAM.
- Sentry catches every error you don't see firsthand.
- Cloudflare absorbs scraping, credential stuffing, and DDoS attempts.
- Every dependency vulnerability gets a PR within a week.
- Every push gets a secret scan, CodeQL scan, npm audit.
- You have a public VDP + privacy policy + terms.
- You have a breach runbook you've actually drilled.
- Your RLS posture is audited quarterly.
- Three DPAs are on file.

That's a defensible posture for a faith + location + messaging app heading toward $50k–$100k ARR. After that, you upgrade with a vCISO retainer, a HackerOne program, and an annual pentest. All in the action report's "What Comes Next" section.

Stop. Execute. In order. Don't skip Thorn — that's the one with a startup cost (their sales cycle) and the highest legal exposure.
