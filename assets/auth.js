// =============================================================================
// auth.js — shared Supabase auth client + helpers + header session swap
//
// Load this on every page AFTER the Supabase UMD bundle:
//   <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/..."></script>
//   <script src="/assets/auth.js"></script>
//
// Exposes:
//   window._supabase            — the shared Supabase client
//   window.foundAuth.getSession()
//   window.foundAuth.signIn({email, password})
//   window.foundAuth.signUp({email, password, fullName, phone, zip, city, state})
//   window.foundAuth.signInWithMagicLink({email})
//   window.foundAuth.signOut()
//   window.foundAuth.applyHeaderSession()   — swaps "Get Early Access" CTA
//                                             for "Open app" + initials avatar
//                                             when logged in
// =============================================================================

(function () {
  const SUPABASE_URL  = 'https://froqanfagdkjmfrmpfye.supabase.co';
  const SUPABASE_ANON = 'sb_publishable_TWr-nQ9gwyvuxUsdtR49hA_dkk2TNLO';

  // Reuse if index.html already initialized one
  if (!window._supabase) {
    const { createClient } = window.supabase;
    window._supabase = createClient(SUPABASE_URL, SUPABASE_ANON, {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: true, // handles magic-link callback hash
      },
    });
  }

  const sb = window._supabase;

  async function getSession() {
    const { data } = await sb.auth.getSession();
    return data.session ?? null;
  }

  async function signIn({ email, password }) {
    const { data, error } = await sb.auth.signInWithPassword({ email, password });
    if (error) throw error;
    return data;
  }

  async function signUp({ email, password, fullName, phone, zip, city, state, lat, lng }) {
    const { data, error } = await sb.auth.signUp({
      email,
      password,
      options: {
        // Stored on auth.users.raw_user_meta_data — read by the handle_new_user
        // trigger (migration 0030) to populate the profiles row INCLUDING the
        // PostGIS location point. Keys must match app/src/auth/AuthContext.js
        // exactly so app + web signups are byte-identical to the trigger.
        data: {
          // Normalize at the source so the stored name is always clean.
          full_name: titleCaseName(fullName),
          phone:     phone ?? '',
          zip:       zip ?? '',
          city:      city ?? '',
          state:     (state ?? '').toUpperCase(),
          // lat/lng come from the ZIP lookup (Zippopotam.us returns coords).
          // Sent as strings; the trigger nullifs empties and parses real numbers.
          // Absent/empty => trigger writes a NULL location (won't fail signup).
          lat:       lat != null ? String(lat) : '',
          lng:       lng != null ? String(lng) : '',
        },
        // The confirmation email's link lands them here — clicking it both
        // confirms their email AND drops them into the profile questions.
        emailRedirectTo: `${window.location.origin}/complete-profile.html`,
      },
    });
    if (error) throw error;
    return data;
  }

  async function signInWithMagicLink({ email }) {
    const { error } = await sb.auth.signInWithOtp({
      email,
      options: { emailRedirectTo: `${window.location.origin}/account.html` },
    });
    if (error) throw error;
  }

  async function signOut() {
    await sb.auth.signOut();
  }

  // Title-case a person's name so it always displays cleanly, no matter how
  // they typed it. "ryder" -> "Ryder", "ryder scott" -> "Ryder Scott",
  // "RYDER" -> "Ryder". Intentional mixed-case is preserved: "McDonald" and
  // "O'Brien" are left alone. Hyphens/apostrophes/spaces all start a new word.
  function titleCaseName(raw) {
    const name = (raw || '').trim();
    if (!name) return '';
    return name.replace(/[A-Za-zÀ-ÿ]+/g, (word) => {
      const uniformCase =
        word === word.toLowerCase() || word === word.toUpperCase();
      // Mixed case = the user cased it deliberately — don't touch it.
      if (!uniformCase) return word;
      return word[0].toUpperCase() + word.slice(1).toLowerCase();
    });
  }

  function initialsFrom(name, email) {
    const src = (name || email || '').trim();
    if (!src) return '··';
    const parts = src.split(/\s+/);
    if (parts.length > 1) {
      return ((parts[0][0] || '') + (parts[parts.length - 1][0] || '')).toUpperCase();
    }
    return (src[0] || '·').toUpperCase();
  }

  // Replace any [data-cta-when-logged-out] CTA with an [data-cta-when-logged-in]
  // version: "Open app" + initials avatar. Re-runs on auth state changes.
  //
  // Tailwind gotcha: `hidden` sets display:none. When we remove `hidden`, the
  // element falls back to its default `display` — for an <a>, that's `inline`,
  // which kills `items-center` / `gap-*` (those require flex). So we explicitly
  // toggle `inline-flex` to make the pill lay out correctly.
  async function applyHeaderSession() {
    const session = await getSession();
    const loggedOutEls = document.querySelectorAll('[data-cta-when-logged-out]');
    const loggedInEls  = document.querySelectorAll('[data-cta-when-logged-in]');

    if (session) {
      const fullName = session.user?.user_metadata?.full_name;
      const initials = initialsFrom(fullName, session.user?.email);
      loggedInEls.forEach((el) => {
        el.classList.remove('hidden');
        el.classList.add('inline-flex');
        const slot = el.querySelector('[data-initials]');
        if (slot) slot.textContent = initials;
      });
      loggedOutEls.forEach((el) => el.classList.add('hidden'));
    } else {
      loggedInEls.forEach((el) => {
        el.classList.add('hidden');
        el.classList.remove('inline-flex');
      });
      loggedOutEls.forEach((el) => el.classList.remove('hidden'));
    }
  }

  // Auto-refresh header on auth state change (sign in, sign out, token refresh)
  sb.auth.onAuthStateChange(() => {
    applyHeaderSession();
  });

  window.foundAuth = {
    getSession,
    signIn,
    signUp,
    signInWithMagicLink,
    signOut,
    initialsFrom,
    titleCaseName,
    applyHeaderSession,
  };
})();
