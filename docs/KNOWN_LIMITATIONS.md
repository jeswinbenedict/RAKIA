# Known Limitations

RAKIA is research software. These limitations are deliberate, documented, and shown in the product where relevant.

## Scientific

- **Not clinically validated.** Anomaly, trend and onset detection are evaluated only on synthetic scenarios with known ground truth. Those results are engineering metrics, not clinical sensitivity or specificity.
- **No real astronaut data.** Individual in-flight astronaut data is not publicly available at the needed granularity. Demonstrations use clearly labelled simulated data.
- **Indirect domains.** Bone density, immune status and neuro-ocular changes (SANS) cannot be measured by wearables. RAKIA shows them only as imported clinical or lab records plus mission context, and never infers them from vital signs.
- **Small-sample science.** Much spaceflight evidence comes from small cohorts. Any population-derived "expected adaptation" reference is approximate and labelled as such.

## Technical

- **iOS** builds are verified only in CI on macOS runners (unsigned); the primary development machine is Windows.
- **Web storage** cannot be strongly encrypted at rest in the browser. Native targets use encrypted SQLite.
- **Local PostgreSQL is not Supabase.** Supabase-specific services (PostgREST, Realtime, Storage) are not available in local development unless the optional Docker-based Supabase stack is running.
- **Phone OTP on web** requires Firebase's reCAPTCHA verifier in addition to Cloudflare Turnstile.
