# Known Limitations

RAKIA is research software. These limitations are deliberate, documented, and shown in the product where relevant.

## Scientific

- **Not clinically validated.** Anomaly, trend and onset detection are evaluated only on synthetic scenarios with known ground truth. Those results are engineering metrics, not clinical sensitivity or specificity.
- **No real astronaut data.** Individual in-flight astronaut data is not publicly available at the needed granularity. Demonstrations use clearly labelled simulated data.
- **Indirect domains.** Bone density, immune status and neuro-ocular changes (SANS) cannot be measured by wearables. RAKIA shows them only as imported clinical or lab records plus mission context, and never infers them from vital signs.
- **The simulation mission is not a physiological model.** Its daily values come from simple statistical models with deliberately injected changes (a step, a gradual drift, a sensor outage). It exists to demonstrate and test the analytics, which run exactly as they would on real data. Its values say nothing about real astronauts.
- **Gradual changes may not raise an alert.** In the simulation, a decline of one baseline standard deviation over 30 days does not trigger the sustained-shift detector; it shows up only as a significant Theil-Sen trend. This is by design (the detector is tuned for a low false-alarm rate), and the UI reports the trend rather than a stronger signal.
- **Small-sample science.** Much spaceflight evidence comes from small cohorts. Any population-derived "expected adaptation" reference is approximate and labelled as such.

## Technical

- **Simulation state is not persisted.** Starting the simulation mission is per session; it ends when the app restarts. Persistence arrives with the local store.
- **iOS** builds are verified only in CI on macOS runners (unsigned); the primary development machine is Windows.
- **Dart bindings:** `rakia_chain_verify` and `rakia_record_encode` are not exposed to Dart yet. Ledger timestamps and sequence numbers passed from Dart must lie within ±(2^53 − 1) to stay exact on the web.
- **Web analytics core:** the web build depends on a WebAssembly module that must be compiled with Emscripten. If the module is missing or fails to load, the app says so on the About page and runs no analytics.
- **Web storage** cannot be strongly encrypted at rest in the browser. Native targets use encrypted SQLite.
- **Local PostgreSQL is not Supabase.** Supabase-specific services (PostgREST, Realtime, Storage) are not available in local development unless the optional Docker-based Supabase stack is running.
- **Phone OTP on web** requires Firebase's reCAPTCHA verifier in addition to Cloudflare Turnstile.
