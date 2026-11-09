import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../components/empty_state.dart';
import '../features/about_page.dart';
import '../features/account_page.dart';
import '../features/actions_page.dart';
import '../features/check_in_page.dart';
import '../features/data_page.dart';
import '../features/mission_page.dart';
import '../features/module_page.dart';
import '../features/monitoring_page.dart';
import '../features/page_frame.dart';
import '../features/reaction_test_page.dart';
import '../features/record_page.dart';
import '../features/space_weather_view.dart';
import '../features/wellbeing_page.dart';
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
            pageBuilder: (context, state) =>
                NoTransitionPage(key: state.pageKey, child: pageFor(m)),
            routes: [
              if (m.id == 'behavioural') ...[
                GoRoute(
                  path: 'check-in',
                  pageBuilder: (context, state) => NoTransitionPage(
                    key: state.pageKey,
                    child: const CheckInPage(),
                  ),
                ),
                GoRoute(
                  path: 'reaction-test',
                  pageBuilder: (context, state) => NoTransitionPage(
                    key: state.pageKey,
                    child: const ReactionTestPage(),
                  ),
                ),
              ],
            ],
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

/// The page for a module. Modules without a dedicated view yet show their
/// factual empty state.
Widget pageFor(ModuleSpec m) => switch (m.id) {
  'mission' => MissionPage(module: m),
  'actions' => ActionsPage(module: m),
  'data' => DataPage(module: m),
  'behavioural' => WellbeingPage(module: m),
  'record' => RecordPage(module: m),
  'account' => AccountPage(module: m),
  'environment' => ModulePage(module: m, header: const SpaceWeatherSection()),
  _ when m.group == ModuleGroup.monitoring => MonitoringPage(module: m),
  _ => ModulePage(module: m),
};
