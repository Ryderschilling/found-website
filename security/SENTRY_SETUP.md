# Sentry — Copy-Paste Setup

Why: right now if the app crashes in production, you have no idea. Apple/Google crash reports are slow and lossy. Sentry catches JS errors, native crashes, and unhandled promise rejections with full stack traces, user breadcrumbs, and release tags. Free tier is plenty for FOUND's scale.

---

## 1. Sign up + install

1. Create an account at https://sentry.io (free, no card).
2. Create a React Native project. Copy the DSN it gives you.
3. In your repo:

```bash
npx @sentry/wizard@latest -i reactNative
```

The wizard auto-edits `metro.config.js`, adds source map upload, and wires native iOS/Android.

If you want to skip the wizard and do it manually:

```bash
npx expo install @sentry/react-native
```

---

## 2. Add DSN to env

In `.env.local`:

```
EXPO_PUBLIC_SENTRY_DSN=https://yourkey@oXXXXX.ingest.sentry.io/XXXXX
```

`.env.example` should have:

```
EXPO_PUBLIC_SENTRY_DSN=
```

(empty — never commit the real DSN).

---

## 3. New file: `src/lib/sentry.js`

```js
// ─────────────────────────────────────────────────────────────────────────
// sentry.js
//
// Initialize Sentry as early as possible (before any React render).
// Imported once from App.js. Safe to call multiple times — Sentry guards it.
// ─────────────────────────────────────────────────────────────────────────

import * as Sentry from '@sentry/react-native';
import Constants from 'expo-constants';

const DSN = process.env.EXPO_PUBLIC_SENTRY_DSN;

if (DSN) {
  Sentry.init({
    dsn: DSN,
    environment: __DEV__ ? 'development' : 'production',
    release: Constants.expoConfig?.version ?? '0.0.0',

    // Performance sampling — keep low until you have traffic
    tracesSampleRate: __DEV__ ? 1.0 : 0.1,

    // Strip anything that looks like PII before sending
    beforeSend(event) {
      if (event.user) {
        // Keep user id for grouping, drop email / IP
        event.user = { id: event.user.id };
      }
      // Scrub any string field that looks like a JWT or supabase anon key
      const scrub = (s) =>
        typeof s === 'string'
          ? s.replace(/eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}/g, '[redacted-jwt]')
          : s;
      if (event.message) event.message = scrub(event.message);
      if (event.exception?.values) {
        for (const ex of event.exception.values) {
          if (ex.value) ex.value = scrub(ex.value);
        }
      }
      return event;
    },
  });
}

export { Sentry };

/** Wrap an async function so any throw is sent to Sentry and rethrown. */
export function trackAsync(fn) {
  return async (...args) => {
    try {
      return await fn(...args);
    } catch (e) {
      if (DSN) Sentry.captureException(e);
      throw e;
    }
  };
}

/** Set the signed-in user id so events group by user. Never pass email. */
export function setSentryUser(userId) {
  if (!DSN) return;
  if (!userId) {
    Sentry.setUser(null);
    return;
  }
  Sentry.setUser({ id: String(userId) });
}
```

---

## 4. Patch `App.js`

At the very top of `App.js`, **before any other import that does work**:

```js
import './src/lib/sentry'; // init Sentry as early as possible
```

Then wherever your auth state listener fires (where you currently load the profile after sign-in), add:

```js
import { setSentryUser } from './src/lib/sentry';

// inside onAuthStateChange:
setSentryUser(session?.user?.id ?? null);
```

---

## 5. Wrap the root component

In `App.js`, change:

```js
export default function App() { ... }
```

to:

```js
import { Sentry } from './src/lib/sentry';

function App() { ... }

export default Sentry.wrap(App);
```

`Sentry.wrap` adds an error boundary + native crash hooks.

---

## 6. Verify

After rebuild, drop a deliberate error in any screen:

```js
throw new Error('sentry smoke test');
```

Open the screen → app shows error → Sentry dashboard receives event within ~30 seconds. Remove the test throw.

---

## 7. What this catches

- JS exceptions (uncaught + manually captured)
- Unhandled promise rejections
- Native iOS/Android crashes
- Slow renders (when `tracesSampleRate > 0`)
- HTTP errors if you instrument the supabase client (optional, add later)

## 8. What this does NOT catch

- Supabase server-side errors (those live in the Supabase logs dashboard)
- Auth failures that are returned as `{error}` objects, not thrown — wrap those manually with `Sentry.captureMessage('login failed', { extra: ... })` where useful.

## 9. Cost

Free tier: 5k errors/mo, 10k performance events/mo. Plenty until you cross ~10k DAU. After that, $26/mo Team plan.
