import 'package:flutter/material.dart';

const bool turnstileSupported = false;

Widget buildTurnstile(
  BuildContext context, {
  required String siteKey,
  required ValueChanged<String?> onToken,
}) => Text(
  key: const Key('turnstile-unsupported'),
  'The bot check that protects account creation runs in the RAKIA web '
  'app. Create your account there, then sign in here.',
  style: Theme.of(context).textTheme.bodyMedium,
);
