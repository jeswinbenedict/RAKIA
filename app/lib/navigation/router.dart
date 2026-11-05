import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../components/empty_state.dart';
import '../features/about_page.dart';
import '../features/module_page.dart';
import '../features/page_frame.dart';
import 'adaptive_shell.dart';
import 'modules.dart';

GoRouter buildRouter({String initialLocation = '/mission'}) => GoRouter(
  initialLocation: initialLocation,
  redirect: (context, state) => state.uri.path == '/' ? '/mission' : null,
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          AdaptiveShell(location: state.uri.path, child: child),
      routes: [
        for (final m in kModules)
          GoRoute(
            path: m.path,
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: ModulePage(module: m),
            ),
          ),
        GoRoute(
          path: kAboutPath,
          pageBuilder: (context, state) =>
              NoTransitionPage(key: state.pageKey, child: const AboutPage()),
        ),
      ],
    ),
  ],
  errorBuilder: (context, state) => AdaptiveShell(
    location: state.uri.path,
    child: PageFrame(
      title: 'Page not found',
      eyebrow: 'RAKIA',
      summary: 'There is no page at ${state.uri.path}.',
      body: EmptyState(
        icon: Icons.explore_off_outlined,
        title: 'Nothing here',
        message: 'Use the navigation to choose a module.',
        action: FilledButton(
          onPressed: () => context.go('/mission'),
          child: const Text('Go to mission overview'),
        ),
      ),
    ),
  ),
);
