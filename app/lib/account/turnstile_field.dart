// The Cloudflare Turnstile check shown before an account is created. The
// token it produces is verified by the RAKIA API with Cloudflare; the app
// only passes it on. On the web the widget is Cloudflare's own; other
// platforms have no Turnstile, so accounts are created in the web app.
import 'package:flutter/widgets.dart';

import 'turnstile_field_stub.dart'
    if (dart.library.js_interop) 'turnstile_field_web.dart'
    as impl;

/// Whether this platform can show the Turnstile check.
bool get turnstileSupported => impl.turnstileSupported;

/// Renders the check for [siteKey] and reports each new token (null when a
/// token expires or the check fails, so a stale one is never sent).
class TurnstileField extends StatelessWidget {
  const TurnstileField({
    super.key,
    required this.siteKey,
    required this.onToken,
  });

  final String siteKey;
  final ValueChanged<String?> onToken;

  @override
  Widget build(BuildContext context) =>
      impl.buildTurnstile(context, siteKey: siteKey, onToken: onToken);
}
