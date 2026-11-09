import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

const bool turnstileSupported = true;

/// Cloudflare's script, loaded on first use ("explicit" rendering, so it
/// renders only where RAKIA asks). Allowed by script-src and frame-src in
/// web/_headers.
const String _scriptUrl =
    'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit';

/// The action the API expects for account creation.
const String _action = 'create-account';

Completer<void>? _loading;

Future<void> _loadScript() {
  final existing = _loading;
  if (existing != null) return existing.future;
  final done = _loading = Completer<void>();
  if (globalContext.has('turnstile')) {
    done.complete();
    return done.future;
  }
  final script = web.HTMLScriptElement()
    ..src = _scriptUrl
    ..async = true
    ..crossOrigin = 'anonymous';
  script.onload = ((web.Event _) => done.complete()).toJS;
  script.onerror = ((web.Event _) {
    _loading = null;
    done.completeError(StateError('The bot check could not be loaded.'));
  }).toJS;
  web.document.head!.append(script);
  return done.future;
}

Widget buildTurnstile(
  BuildContext context, {
  required String siteKey,
  required ValueChanged<String?> onToken,
}) => _TurnstileView(siteKey: siteKey, onToken: onToken);

class _TurnstileView extends StatefulWidget {
  const _TurnstileView({required this.siteKey, required this.onToken});
  final String siteKey;
  final ValueChanged<String?> onToken;

  @override
  State<_TurnstileView> createState() => _TurnstileViewState();
}

class _TurnstileViewState extends State<_TurnstileView> {
  String? _problem;
  JSString? _widgetId;

  Future<void> _render(web.HTMLElement element) async {
    try {
      await _loadScript();
    } on Object catch (e) {
      if (mounted) setState(() => _problem = '$e');
      return;
    }
    if (!mounted) return;
    final turnstile = globalContext['turnstile'] as JSObject?;
    if (turnstile == null) {
      setState(() => _problem = 'The bot check could not be loaded.');
      return;
    }
    final options = JSObject()
      ..['sitekey'] = widget.siteKey.toJS
      ..['action'] = _action.toJS
      ..['theme'] = 'auto'.toJS
      ..['callback'] = ((JSString token) => widget.onToken(token.toDart)).toJS
      ..['expired-callback'] = (() => widget.onToken(null)).toJS
      ..['error-callback'] = ((JSAny? _) {
        widget.onToken(null);
        if (mounted) {
          setState(
            () => _problem =
                'The bot check could not be completed. Reload the page and '
                'try again.',
          );
        }
      }).toJS;
    _widgetId = turnstile.callMethod<JSString?>(
      'render'.toJS,
      element,
      options,
    );
  }

  @override
  void dispose() {
    final id = _widgetId;
    final turnstile = globalContext['turnstile'] as JSObject?;
    if (id != null && turnstile != null) {
      turnstile.callMethod<JSAny?>('remove'.toJS, id);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        key: const Key('turnstile'),
        width: 300,
        height: 70,
        child: HtmlElementView.fromTagName(
          tagName: 'div',
          onElementCreated: (Object e) => _render(e as web.HTMLElement),
        ),
      ),
      if (_problem case final p?)
        Text(p, style: Theme.of(context).textTheme.bodyMedium),
    ],
  );
}
