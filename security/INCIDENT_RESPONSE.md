# FOUND — Incident Response Runbook v1

Last updated: 2026-05-25 · Primary contact: Ryder (Ryderscott33@icloud.com)

If a security incident is confirmed or suspected, follow this runbook. The GDPR 72-hour breach notification window starts the moment you have enough evidence to reasonably conclude personal data was compromised.

---

## Severity Levels

| Severity | Examples | Response time |
|---|---|---|
| **SEV-1** | Service_role key leaked, full DB dump, CSAM detected, user data publicly exposed | Immediate (< 1 hr) |
| **SEV-2** | Single-user account takeover, RLS policy bypass on one table, vendor breach affecting FOUND data | Same day |
| **SEV-3** | Suspicious access patterns, failed-login spikes, low-confidence anomaly | Next business day |
| **SEV-4** | Bug bounty report, theoretical vulnerability | Within 7 days |

---

## Hour 0–1: Detect & Triage

1. **Confirm the signal.** Don't act on rumor. Verify with logs (Sentry, Supabase dashboard, Cloudflare).
2. **Scope it.**
   - How many users affected?
   - What data — profiles, messages, photos, religious affiliation, location?
   - Time window — when did it start, has it stopped?
3. **Classify severity** (table above).
4. **Open an incident log.** New file: `/Found.community/security/incidents/YYYY-MM-DD-short-name.md`. Append timestamped notes as you go.

## Hour 1–6: Contain & Preserve Evidence

5. **Preserve evidence before remediating.** Snapshot the Supabase DB (Settings → Backups → Manual). Export Cloudflare logs for the time window. Export Sentry events.
6. **Contain.**
   - If service_role key suspected leaked → rotate immediately in Supabase dashboard.
   - If specific user account compromised → revoke session, force password reset.
   - If a malicious actor is enumerating → add Cloudflare WAF rule to block their IP range or ASN.
   - If CSAM detected → quarantine the file, do not store it, prepare CyberTipline report.
7. **Identify root cause.** Stolen key? Misconfigured RLS? Malicious dependency? Phishing?
8. **Patch the vulnerability.** Don't wait to notify — patch first, then notify in parallel.

## Hour 6–24: Notification Prep

9. **Determine reportability.**
   - GDPR: yes if any EU user PII affected AND there's risk to rights/freedoms.
   - CCPA: yes if any California resident PII affected.
   - REPORT Act / 18 U.S.C. § 2258A: yes if CSAM was involved (file CyberTipline with NCMEC).
   - Apple/Google: notify per their developer policies if app store data flow affected.
10. **Identify affected users.** Run a query against the DB. Capture user_id list.
11. **Draft user notification.** Template below.
12. **Brief counsel.** If you don't have a privacy lawyer yet — get one on retainer this week ($5k flat fee, see action report).

## Hour 24–72: Regulatory + User Notification

13. **GDPR (EU):** Notify the relevant Data Protection Authority in writing within 72 hours of becoming aware. Then notify affected users "without undue delay."
14. **CCPA (California):** Notify affected California residents.
15. **NCMEC (CSAM):** File CyberTipline report immediately (not in 72-hour window — federal law requires "as soon as reasonably possible," which means hours).
16. **Post-incident page.** Publish a transparent incident report at https://found.community/security/incidents/.

## After 72 hours: Postmortem

17. **Write the postmortem.** Timeline, root cause (5-whys), what was affected, what was done, what's changed. Public if user impact; internal if not.
18. **Update threat model + risk register.** New threats? Risks re-ranked?
19. **Run a tabletop drill on the same scenario** in 90 days to confirm fixes hold.

---

## User Notification Template

```
Subject: Important security notice for your FOUND account

Hi [name],

On [date], we discovered [brief plain-language description of what happened — be honest, no spin].

What happened:
[1-3 sentences. What did the attacker do or potentially do?]

What information was involved:
[Specific data types: email, profile info, location, religious affiliation, etc. Be precise.]

What we've done:
- [Containment action 1, e.g., rotated affected credentials]
- [Containment action 2, e.g., reset all user sessions]
- [Long-term fix, e.g., enabled rate limiting on the affected endpoint]

What you should do:
- Change your FOUND password.
- Review your account for unfamiliar activity.
- If you reused your FOUND password anywhere else, change it there too.
- Enable two-factor authentication in Settings.

If you have any questions, email security@found.community. We will respond within 24 hours.

— Ryder Scott, founder of FOUND
```

---

## Contacts (Fill In)

- **Supabase support:** support@supabase.io · https://supabase.com/dashboard/support
- **Resend support:** support@resend.com
- **Netlify support:** https://www.netlify.com/support/
- **Privacy lawyer:** [hire this week]
- **Cyber liability insurer:** [get a quote at $10k+ ARR]
- **NCMEC CyberTipline:** https://report.cybertip.org/

---

## What NOT to Do

- Don't notify users before you've contained the issue (gives attacker a warning).
- Don't make confident public statements before you understand scope.
- Don't promise things you can't verify ("no data was accessed" — if you don't know, say you don't know).
- Don't delete logs to "clean up" — preserve everything until counsel says otherwise.
- Don't hand over data to anyone claiming to be law enforcement by phone or email. Require a warrant or subpoena, verified through a separate channel.
- Don't blame engineers / vendors publicly until the postmortem is complete and accurate.

---

## Tabletop Drill Cadence

Run a 30-minute tabletop quarterly. Pick a scenario from the threat model, walk through this runbook, identify gaps. First drill recommended within 30 days of this doc being signed off.
