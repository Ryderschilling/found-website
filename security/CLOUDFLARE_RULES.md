# FOUND — Cloudflare WAF & Rate Limiting Config

This is the exact rule set to deploy on Cloudflare Pro ($20/mo) in front of your Supabase project. Cloudflare cannot proxy `*.supabase.co` directly — instead, set up a custom domain in Supabase (Settings → Custom Domains) so your API is `api.found.community`, then put Cloudflare in front of that.

---

## Setup Order

1. In Supabase: Settings → Custom Domains → `api.found.community`. Follow Supabase's CNAME instructions.
2. In Cloudflare DNS: confirm `api.found.community` CNAME → `cname.supabase.com` (or whatever Supabase tells you), proxy ON (orange cloud).
3. In your mobile app's `.env`: change `EXPO_PUBLIC_SUPABASE_URL` from `https://<project>.supabase.co` to `https://api.found.community`. Rebuild and redeploy.
4. Configure the rules below in Cloudflare Dashboard → Security → WAF → Rate limiting rules.
5. Test with a script that hits each endpoint at 2x the limit. Confirm 429 responses.

---

## Rate Limiting Rules (Cloudflare Pro)

### Rule 1 — Signup throttle
**Match:** URI path contains `/auth/v1/signup`
**Action:** Block
**Rate:** 10 requests per 10 minutes per IP
**Notes:** Prevents signup farms. Tune up if you run referral campaigns.

### Rule 2 — Login brute-force
**Match:** URI path contains `/auth/v1/token` AND method is POST
**Action:** Block
**Rate:** 10 requests per 10 minutes per IP
**Counting key:** IP + body hash (limits per credential pair, not per IP alone)

### Rule 3 — Magic link / OTP send
**Match:** URI path contains `/auth/v1/otp` OR `/auth/v1/magiclink`
**Action:** Block
**Rate:** 3 requests per hour per IP

### Rule 4 — Profile enumeration
**Match:** URI path contains `/rest/v1/profiles`
**Action:** Block
**Rate:** 100 requests per minute per authenticated user
**Counting key:** Authorization header (per JWT)

### Rule 5 — Message send
**Match:** URI path contains `/rest/v1/messages` AND method is POST
**Action:** Block
**Rate:** 50 requests per day per authenticated user

### Rule 6 — Message read bulk
**Match:** URI path contains `/rest/v1/messages` AND method is GET
**Action:** Block
**Rate:** 200 requests per minute per authenticated user

### Rule 7 — Storage upload
**Match:** URI path contains `/storage/v1/object` AND method is POST
**Action:** Block
**Rate:** 20 requests per hour per authenticated user (separate per-day MB cap enforced server-side)

### Rule 8 — Report flood
**Match:** URI path contains `/rest/v1/rpc/report_content`
**Action:** Block
**Rate:** 10 requests per day per authenticated user

### Rule 9 — Admin RPC (defense in depth — the function itself checks is_admin)
**Match:** URI path contains `/rest/v1/rpc/admin_`
**Action:** JS Challenge
**Rate:** 60 requests per minute per IP (admins shouldn't be hammering)

---

## WAF Custom Rules (Free or Pro)

### Block known bad ASNs
**Match:** IP ASN in {known scraping ASNs — DigitalOcean, OVH residential, etc.}
**Action:** Managed Challenge
**Notes:** Add ASN numbers as you observe abuse. Don't blanket-block cloud ASNs — many legit users use VPNs.

### Require User-Agent on API
**Match:** URI path starts with `/rest/v1/` AND User-Agent is empty
**Action:** Block
**Notes:** Trivial bots often omit User-Agent. Catches the lazy ones.

### Block requests to PostgREST schema introspection
**Match:** URI path matches `/rest/v1/?$` exactly (root listing)
**Action:** Block
**Notes:** Prevents schema dump.

---

## Cloudflare Bot Fight Mode

In Security → Bots:
- Enable **Bot Fight Mode** (free).
- At $10k+ ARR, upgrade to **Super Bot Fight Mode** ($20/mo Pro plan includes basic) for verified bot allow-listing (Googlebot, Apple's bot, etc.) and JS-challenge on unknown bots.

---

## DDoS Protection

Cloudflare DDoS protection is automatic on all plans. No config needed. Confirm in Security → DDoS that it's enabled (it is by default).

---

## Verification Script (Bash)

```bash
# Test that rate limiting is active. Replace with your API URL.
API=https://api.found.community

echo "=== Hammering signup endpoint (should 429 after 10) ==="
for i in {1..15}; do
  curl -s -o /dev/null -w "%{http_code}\n" \
    -X POST "$API/auth/v1/signup" \
    -H "apikey: $EXPO_PUBLIC_SUPABASE_ANON_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"test$i@example.com\",\"password\":\"Test12345!\"}"
done
```

Expect: first ~10 return 200/400 (or whatever the legit response is), then 429 (rate limited).

---

## Cost Reality

- Cloudflare Free: covers DNS, basic DDoS, basic WAF. Rate limiting limited to 1 rule.
- Cloudflare Pro ($20/mo): unlocks 5 rate-limiting rules, more WAF custom rules. **Recommended starting tier.**
- Cloudflare Business ($200/mo): 15 rate-limiting rules, API Shield. Wait until $50k+ ARR.
