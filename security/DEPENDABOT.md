# Dependabot — Copy-Paste Config

Drop this at `.github/dependabot.yml` in the found-app repo. Dependabot auto-opens PRs when one of your dependencies has a published vulnerability or a non-breaking update.

```yaml
version: 2
updates:
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
      time: "09:00"
      timezone: "America/Chicago"
    open-pull-requests-limit: 5
    versioning-strategy: "increase"
    labels:
      - "dependencies"
    commit-message:
      prefix: "deps"
      include: "scope"
    groups:
      expo:
        patterns:
          - "expo"
          - "expo-*"
          - "@expo/*"
      react-native:
        patterns:
          - "react-native"
          - "react-native-*"
          - "@react-navigation/*"
      supabase:
        patterns:
          - "@supabase/*"
      dev-tooling:
        dependency-type: "development"
    ignore:
      # Pin major React Native bumps to manual — Expo SDK upgrades require coordination
      - dependency-name: "react-native"
        update-types: ["version-update:semver-major"]
      - dependency-name: "expo"
        update-types: ["version-update:semver-major"]

  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    commit-message:
      prefix: "ci"
```

---

## What this does

- Scans your `package.json` every Monday morning at 9am Central.
- Groups Expo, RN, and Supabase updates so you don't get 12 separate PRs for one SDK bump.
- Auto-PRs minor + patch updates.
- Skips major version bumps for `react-native` and `expo` — those need you to upgrade Expo SDK as a coordinated whole.
- Also scans the GitHub Actions you reference in workflows.

---

## Also enable in GitHub UI

Settings → Code security and analysis → enable:
- ✅ Dependency graph (free, on by default for public; turn on for private)
- ✅ Dependabot alerts (free)
- ✅ Dependabot security updates (free — auto-PRs fixes to known CVEs)
- ✅ Secret scanning (free for public, $4/mo Pro for private)
- ✅ Push protection (blocks secret pushes before they hit the repo)

---

## How to triage Dependabot PRs

1. CI passes → merge if it's a patch.
2. CI passes → eyeball the changelog if it's a minor (`yarn why <pkg>` or read the linked release notes).
3. CI fails → either fix forward or close with `@dependabot ignore this minor version` until the breakage is resolved upstream.

For security-flagged PRs, prioritize. Anything labeled "critical" or "high" should ship within 48 hours.
