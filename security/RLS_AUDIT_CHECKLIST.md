# FOUND — RLS Audit Checklist v1

Run through this every time you add or modify a table or policy. Current state shown where known. Run this against your production Supabase project before relying on it.

---

## Current Inventory (as of 2026-05-25)

**Tables with RLS enabled (25):**
activities, churches, community_goals, connections, family_values, group_activities, group_join_requests, group_members, group_posts, groups, life_stages, love_languages, messages, notifications, photos, profile_activities, profile_goals, profile_values, profiles, push_tokens, reports, saved_profiles, school_types, thread_participants, threads.

**Total CREATE POLICY statements across migrations:** 58.

**Tables with `is_admin` / suspension fields:** profiles (added 0038).

**Admin enforcement pattern:** `_require_admin()` guard on every `admin_*` SECURITY DEFINER RPC. ✅ Correct.

**`raw_user_meta_data` in RLS USING/WITH CHECK clauses:** None found. ✅ Correct (only used in INSERT triggers).

---

## Per-Table Checks

For every table, verify all six items:

### 1. RLS Enabled
```sql
SELECT relname, relrowsecurity, relforcerowsecurity
FROM pg_class
WHERE relnamespace = 'public'::regnamespace AND relkind = 'r'
ORDER BY relname;
```
Every row should show `relrowsecurity = true`. If any table shows `false`, that's a gap.

### 2. Every CRUD Operation Has An Explicit Policy

```sql
SELECT schemaname, tablename, cmd, count(*) AS n_policies
FROM pg_policies
WHERE schemaname = 'public'
GROUP BY schemaname, tablename, cmd
ORDER BY tablename, cmd;
```
For tables users can write to, expect a row for SELECT, INSERT, UPDATE, DELETE. If a cmd is missing, no one (not even the owner) can perform that op — usually intentional, sometimes a bug. Verify each absence is deliberate.

### 3. Indexes On Every Column Referenced in Policies

For each policy, identify the columns in `USING` and `WITH CHECK`, and confirm each has an index. Missing indexes cause 100–200x slowdowns at scale.

```sql
-- List every policy expression
SELECT tablename, policyname, qual, with_check
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;
```

Common FOUND columns that need indexes:
- `profiles.id` (PK, already indexed)
- `profiles.user_id` if present
- `messages.sender_id`, `messages.recipient_id`, `messages.thread_id`
- `connections.from_profile`, `connections.to_profile`, `connections.kind`
- `thread_participants.thread_id`, `thread_participants.profile_id`
- `group_members.group_id`, `group_members.profile_id`
- `reports.reporter_id`, `reports.target_kind + target_id`

### 4. No `raw_user_meta_data` In Authz

```sql
SELECT tablename, policyname, qual, with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND (qual LIKE '%raw_user_meta_data%' OR with_check LIKE '%raw_user_meta_data%');
```
Should return 0 rows. Anything here is a self-promotion vulnerability.

### 5. Storage Bucket Policies

```sql
SELECT bucket_id, name, public
FROM storage.buckets;

SELECT policyname, definition
FROM pg_policies
WHERE schemaname = 'storage' AND tablename = 'objects';
```

For each bucket:
- `avatars` — public read OK (industry standard). Confirm filenames use UUIDs, not predictable patterns.
- `group-photos` and `group-post-photos` — public read currently. Consider restricting to group members for private groups (already partially done — verify).
- Any future `profile-photos` bucket — should NOT be public read. Force private + signed URLs.

### 6. SECURITY DEFINER Function Audit

```sql
SELECT proname, prosecdef
FROM pg_proc
WHERE pronamespace = 'public'::regnamespace AND prosecdef = true
ORDER BY proname;
```
Every SECURITY DEFINER function should:
- Have `SET search_path = public` (prevents schema-shadowing attacks).
- Either be unconditionally safe (read-only) or check `auth.uid()` / `_require_admin()` at the top.
- Not accept arbitrary SQL or table names as text parameters.

---

## Red Flags To Look For

1. **Policy uses `true` in USING** without further qualification = anyone authenticated can do this. Often intentional for read-mostly reference tables (life_stages, churches). Verify it is intentional.
2. **Policy references a function that isn't SECURITY DEFINER and reads cross-user data** — can leak via slow-path queries.
3. **No DELETE policy** = no one can delete = orphan rows forever. Or DELETE allowed broadly = griefing.
4. **Mixed `auth.uid()` and `(SELECT id FROM profiles WHERE user_id = auth.uid())`** patterns in the same project — pick one convention and stick with it.

---

## Quarterly Sign-Off

Date | Reviewer | Tables added since last review | Findings | Resolved
---|---|---|---|---
2026-05-25 | Ryder | All 25 baseline | See `ACTION_REPORT.md` | In progress
