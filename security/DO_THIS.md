# DO THIS

No thinking. Top to bottom. Don't skip steps.

---

# BUCKET A — Paste 5 things into your code (15 min)

Open your code editor on the `found-app` folder.

---

## A1. Install 3 packages

Open Terminal. Run this one line:

```bash
cd ~/Developer/found-app
npx expo install expo-secure-store expo-image-manipulator @sentry/react-native
```

Done. Move on.

---

## A2. Edit `App.js`

Open `App.js` (top level of found-app).

**Find the very first import line.** Add this ONE line ABOVE everything else:

```js
import './src/lib/sentry';
```

Save. Done.

---

## A3. Edit `src/lib/uploadAvatar.js`

Open `src/lib/uploadAvatar.js`.

**Step 1:** Find this line near the top:
```js
import { supabase } from './supabase';
```

Add this line right below it:
```js
import { stripExif } from './imageSanitize';
```

**Step 2:** Find these 3 lines (around line 54-57):
```js
  if (result.canceled) return null;
  const asset = result.assets?.[0];
  if (!asset) return null;
  return { uri: asset.uri, base64: asset.base64 ?? null };
```

Replace them with:
```js
  if (result.canceled) return null;
  const asset = result.assets?.[0];
  if (!asset) return null;
  const sanitized = await stripExif(asset.uri, { maxWidth: 1024, compress: 0.8 });
  return { uri: sanitized.uri, base64: sanitized.base64 };
```

Save. Done.

---

## A4. Edit `src/lib/profilePhotos.js`

Open `src/lib/profilePhotos.js`.

**Step 1:** At the top with the other imports, add:
```js
import { stripExif } from './imageSanitize';
```

**Step 2:** Find where it grabs the picked image — search for the word `base64` in the file. There will be a spot where it gets `asset.base64` from the image picker. Right before that, add:

```js
const sanitized = await stripExif(asset.uri, { maxWidth: 2048, compress: 0.85 });
```

Then change the next reference from `asset.base64` to `sanitized.base64` and `asset.uri` to `sanitized.uri`.

Save. Done.

(If you can't figure out exactly where, send me the file and I'll show you the exact diff. But the pattern is identical to A3.)

---

## A5. Edit `src/lib/groupPhotos.js` and `src/lib/groupPosts.js`

Same as A4. Two files, identical pattern:

1. Add the import at the top: `import { stripExif } from './imageSanitize';`
2. Find where `asset.base64` is used after the picker
3. Insert `const sanitized = await stripExif(asset.uri, { maxWidth: 2048, compress: 0.85 });` right before
4. Swap `asset.base64` → `sanitized.base64`, `asset.uri` → `sanitized.uri`

Save both. Done with Bucket A.

---

# BUCKET B — Sign up for 4 things (30 min)

## B1. Sentry (free, 10 min)

1. Go to https://sentry.io → "Sign up" → use your email.
2. Once in, click "Create Project" → pick "React Native".
3. Copy the DSN it shows you (looks like `https://abc123@o12345.ingest.sentry.io/67890`).
4. Open `found-app/.env.local` in your code editor.
5. Add this line at the bottom:
   ```
   EXPO_PUBLIC_SENTRY_DSN=paste_the_dsn_here
   ```
6. Save.

Done.

## B2. GitHub security toggles (free, 5 min)

1. Go to https://github.com/[your-username]/found-app/settings/security_analysis
2. Turn ON every toggle you see:
   - Dependency graph
   - Dependabot alerts
   - Dependabot security updates
   - Secret scanning
   - Push protection

Click. Click. Click. Done.

## B3. Cloudflare Pro ($20/mo, 10 min)

1. Go to https://dash.cloudflare.com → log in (you already use them for the website).
2. Click your `found.community` site.
3. Top menu → "Plans" → upgrade to **Pro** ($20/mo).
4. Pay.

That's it for now. The rate-limiting rules I'll walk you through separately once Pro is live — they take 15 min of clicking and I'll send you the exact rule-by-rule screenshots.

## B4. Snyk (free, 5 min) — optional, do if you want extra scanning

1. Go to https://snyk.io → sign up free.
2. Account settings → General → "Auth Token" → copy it.
3. Go to https://github.com/[your-username]/found-app/settings/secrets/actions
4. Click "New repository secret".
5. Name: `SNYK_TOKEN`. Value: paste. Save.

Done.

---

# BUCKET C — Send 4 emails (10 min)

Just copy-paste these. Replace the bracketed bits.

## C1. Email Thorn (CSAM scanning vendor)

To: `contact@safer.io`

> Subject: FOUND — Safer evaluation
>
> Hi,
>
> I run FOUND (https://found.community), a Christian community mobile app. Pre-launch / early users. We let members post profile photos and group photos and I want CSAM hash matching in place before scale.
>
> Could you send pricing and an agreement for a low-volume Safer plan?
>
> Thanks,
> Ryder Scott
> Florida, USA
> security@found.community

## C2. Email Supabase for DPA

To: `legal@supabase.io`

> Subject: DPA request — FOUND
>
> Hi, I operate FOUND (https://found.community). We process EU/UK personal data and need a Data Processing Agreement on file with Supabase as our processor.
>
> Please send your standard DPA. Operator: Ryder Scott, Florida, USA.
>
> Thanks,
> Ryder

## C3. Email Resend for DPA

To: `partnerships@resend.com`

> Subject: DPA request — FOUND
>
> Hi, I'm running FOUND (https://found.community) and use Resend for transactional email. We process EU/UK user data and I need a DPA on file.
>
> Please send your standard DPA. Operator: Ryder Scott, Florida, USA.
>
> Thanks,
> Ryder

## C4. Email Netlify for DPA

Open https://app.netlify.com → click your profile (top right) → Support → New ticket. Subject: "DPA request". Body:

> Hi, I host https://found.community on Netlify. I need a Data Processing Agreement on file for GDPR compliance. Please send your standard DPA. Operator: Ryder Scott.

Done.

When you get the DPAs back, save the PDFs in `Found.community/security/dpas/`. You sign them and send back.

---

# Also: Create 2 mailboxes (5 min)

In Google Workspace admin (or whatever runs your email):

1. Create `security@found.community` — forward to your main inbox.
2. Create `privacy@found.community` — forward to your main inbox.

Both just need to exist so people can write to them.

---

# Last step: Commit and push

In Terminal:

```bash
cd ~/Developer/found-app
git add .
git commit -m "security: secure storage, EXIF strip, Sentry, CSAM scan migration, CI"
git push
```

Done.

---

# ───── WHAT'S STILL NOT BUILT ─────

These are the things I CANNOT do yet — they need the accounts/agreements above first:

1. **Cloudflare rate-limiting rules**
   Waiting on: you upgrading to Cloudflare Pro (B3).
   Then I give you the 9 rules to paste into their UI.

2. **Thorn Safer live scanning**
   Waiting on: their reply + agreement + API key (C1).
   I already built the Edge Function. It's dormant. When you have the key, you set 4 environment secrets and deploy.

3. **NCMEC reporting workflow**
   Waiting on: Thorn agreement (above). Then you fill the CyberTipline form each time a hit happens. ~3 hits/year for a normal community app.

4. **2-Factor authentication (TOTP) on user accounts**
   Not started. 1 hour of work after the above. I'll write the UI + Supabase MFA code when you say go.

5. **Privacy policy + Terms on the website**
   The files exist already at `Found.community/privacy.html` and `terms.html` — but I drafted updated versions in `Found.community/security/PRIVACY_POLICY.html` and `TERMS_OF_SERVICE.html`. Question: do you want me to replace your current pages with mine, or merge in just the missing pieces (special-category data, CSAM disclosure, NCMEC, retention table)? I need your call on that, then I do it.

6. **Privacy lawyer review** — for when you cross $50k revenue or take outside money. ~$5k one-time, not urgent.

7. **First incident-response tabletop drill** — 30 min of you walking through the IR runbook out loud. Schedule it once Bucket A is done. Catches any gaps before you need them for real.

---

# Order of operations

1. Today: Bucket A (15 min code paste) + Bucket B1 + B2 + B4 (free signups, 20 min)
2. Tomorrow: Bucket C (send 4 emails, 10 min)
3. This week: Bucket B3 (Cloudflare Pro pay)
4. When Thorn replies: tell me, I finish the integration
5. When Cloudflare Pro is live: tell me, I give you the rules

Stop overthinking. Just paste the code, click the buttons, send the emails.
