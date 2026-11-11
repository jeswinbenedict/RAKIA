import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'crew_scene.dart';

/// web/crew/crew.js, a module served from this origin (script-src 'self').
const String _moduleUrl = 'crew/crew.js';

Completer<void>? _loading;

/// Loads the crew module once; completes when window.rakiaCrew exists.
Future<void> _loadModule() {
  final existing = _loading;
  if (existing != null) return existing.future;
  final done = _loading = Completer<void>();
  if (globalContext.has('rakiaCrew')) {
    done.complete();
    return done.future;
  }
  void ready() {
    if (!done.isCompleted) done.complete();
  }

  web.window.addEventListener(
    'rakia-crew-ready',
    ((web.Event _) => ready()).toJS,
  );
  final script = web.HTMLScriptElement()
    ..type = 'module'
    ..src = _moduleUrl;
  script.onerror = ((web.Event _) {
    _loading = null;
    if (!done.isCompleted) {
      done.completeError(StateError('The 3D crew could not be loaded.'));
    }
  }).toJS;
  web.document.head!.append(script);
  return done.future.timeout(
    const Duration(seconds: 20),
    onTimeout: () {
      _loading = null;
      throw StateError('The 3D crew took too long to load.');
    },
  );
}

Widget buildCrewScene(BuildContext context, {required bool compact}) =>
    _CrewView(compact: compact);

class _CrewView extends StatefulWidget {
  const _CrewView({required this.compact});
  final bool compact;

  @override
  State<_CrewView> createState() => _CrewViewState();
}

class _CrewViewState extends State<_CrewView> {
  JSObject? _handle;
  bool _ready = false;
  String? _problem;

  Future<void> _mount(web.HTMLElement element) async {
    element.style
      ..width = '100%'
      ..height = '100%';
    try {
      await _loadModule();
      if (!mounted) return;
      final crew = globalContext['rakiaCrew'] as JSObject?;
      if (crew == null) throw StateError('The 3D crew is unavailable.');
      final options = JSObject()..['compact'] = widget.compact.toJS;
      _handle = crew.callMethod<JSObject?>('mount'.toJS, element, options);
      if (mounted) setState(() => _ready = true);
    } on Object {
      // No WebGL, a blocked script or a failed load: a still panel.
      if (mounted) {
        setState(
          () => _problem = widget.compact
              ? ''
              : 'The 3D crew cannot be shown in this browser.',
        );
      }
    }
  }

  @override
  void dispose() {
    _handle?.callMethod<JSAny?>('dispose'.toJS);
    _handle = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      if (_problem == null)
        HtmlElementView.fromTagName(
          key: const Key('crew-scene'),
          tagName: 'div',
          onElementCreated: (Object e) => _mount(e as web.HTMLElement),
        ),
      if (!_ready || _problem != null)
        CrewBackdrop(
          key: Key(_problem == null ? 'crew-loading' : 'crew-fallback'),
          loading: _problem == null,
          message: _problem == null
              ? (widget.compact ? null : 'Bringing the crew aboard')
              : (_problem!.isEmpty ? null : _problem),
        ),
    ],
  );
}
