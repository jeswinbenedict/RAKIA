// Settings fixed when the app is built, with --dart-define. None of these is
// a secret: they are public identifiers that every copy of the app carries.
// Secrets (the Turnstile secret key, database passwords) live only on the
// server.

/// The RAKIA API's base URL, e.g. https://rakia-api-staging.onrender.com.
/// Empty: this build has no server connection (no live data, no sign-in).
const String kApiUrl = String.fromEnvironment('RAKIA_API_URL');

/// The Firebase project's Web API key: a public identifier for Firebase
/// Authentication's REST API (not a secret; access is controlled by the
/// project's sign-in settings and the API's token checks). Empty: sign-in is
/// not available in this build.
const String kFirebaseApiKey = String.fromEnvironment('RAKIA_FIREBASE_API_KEY');

/// host:port of a local Firebase Auth emulator, for development only. Set,
/// sign-in talks to the emulator instead of Google.
const String kFirebaseAuthEmulatorHost = String.fromEnvironment(
  'RAKIA_FIREBASE_AUTH_EMULATOR_HOST',
);

/// The Cloudflare Turnstile site key (public) for the site this build is
/// served from. Needed to create an account.
const String kTurnstileSiteKey = String.fromEnvironment(
  'RAKIA_TURNSTILE_SITE_KEY',
);
