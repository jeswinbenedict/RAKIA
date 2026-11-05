import 'package:flutter/material.dart';

enum ModuleGroup {
  overview('Overview'),
  monitoring('Monitoring'),
  operations('Operations');

  const ModuleGroup(this.label);
  final String label;
}

/// One application module: its route, navigation entry and the copy shown
/// before any data exists. Copy must stay factual (see the research report).
@immutable
class ModuleSpec {
  const ModuleSpec({
    required this.id,
    required this.label,
    required this.shortLabel,
    required this.icon,
    required this.selectedIcon,
    required this.group,
    required this.summary,
    required this.tracks,
    required this.emptyTitle,
    required this.emptyMessage,
    this.note,
  });

  final String id;
  final String label;

  /// Label for the compact bottom bar (keep under ~10 characters).
  final String shortLabel;
  final IconData icon;
  final IconData selectedIcon;
  final ModuleGroup group;
  final String summary;
  final List<String> tracks;
  final String emptyTitle;
  final String emptyMessage;

  /// Scientific or privacy caveat shown with the module.
  final String? note;

  String get path => '/$id';
}

const List<ModuleSpec> kModules = [
  ModuleSpec(
    id: 'mission',
    label: 'Mission overview',
    shortLabel: 'Mission',
    icon: Icons.public_outlined,
    selectedIcon: Icons.public,
    group: ModuleGroup.overview,
    summary:
        'Your health status across every indicator, active alerts and where '
        'the mission timeline stands.',
    tracks: [
      'Status per indicator against your personal baseline',
      'Active alerts and pending self-checks',
      'Mission day, phase and recent events',
      'Data freshness and what the ground has received',
    ],
    emptyTitle: 'No active mission',
    emptyMessage:
        'A mission administrator creates the mission and assigns crew in '
        'Mission administration. Your overview appears once measurements '
        'start arriving.',
  ),
  ModuleSpec(
    id: 'actions',
    label: 'Action center',
    shortLabel: 'Actions',
    icon: Icons.notifications_outlined,
    selectedIcon: Icons.notifications,
    group: ModuleGroup.overview,
    summary:
        'Alerts that explain what changed, by how much, since when, from '
        'which readings, why it matters, and what to check next.',
    tracks: [
      'Explainable alerts ranked by priority',
      'Confirmatory self-checks and their outcomes',
      'Follow-up reminders',
      'Linked, verified evidence for every recommendation',
    ],
    emptyTitle: 'No alerts',
    emptyMessage:
        'Alerts appear only when an indicator departs from your own baseline '
        'and the underlying data passes quality checks.',
    note:
        'RAKIA flags changes; it does not diagnose. Always follow your '
        'flight surgeon and mission medical procedures.',
  ),
  ModuleSpec(
    id: 'cardio',
    label: 'Cardiovascular',
    shortLabel: 'Heart',
    icon: Icons.monitor_heart_outlined,
    selectedIcon: Icons.monitor_heart,
    group: ModuleGroup.monitoring,
    summary:
        'Heart and circulation compared with your own baseline, interpreted '
        'alongside exercise, sleep and mission phase.',
    tracks: [
      'Heart rate and resting heart rate',
      'Heart-rate variability',
      'Blood pressure, where the device supports it',
      'Trends and sustained shifts from your baseline',
    ],
    emptyTitle: 'No cardiovascular data yet',
    emptyMessage:
        'Readings appear here once a wearable or manual entries are connected '
        'in Data management.',
    note:
        'Some devices estimate blood pressure rather than measure it. '
        'RAKIA always labels estimated values.',
  ),
  ModuleSpec(
    id: 'sleep',
    label: 'Sleep & circadian',
    shortLabel: 'Sleep',
    icon: Icons.bedtime_outlined,
    selectedIcon: Icons.bedtime,
    group: ModuleGroup.monitoring,
    summary:
        'Sleep duration, timing and regularity. On-orbit studies report '
        'shorter sleep and circadian misalignment compared with pre-flight.',
    tracks: [
      'Sleep duration and quality',
      'Bed and wake time consistency',
      'Circadian misalignment indicators',
      'Links between sleep and other indicators',
    ],
    emptyTitle: 'No sleep data yet',
    emptyMessage:
        'Sleep episodes appear once a sleep-capable device is connected.',
  ),
  ModuleSpec(
    id: 'physical',
    label: 'Physical & musculoskeletal',
    shortLabel: 'Physical',
    icon: Icons.directions_run_outlined,
    selectedIcon: Icons.directions_run,
    group: ModuleGroup.monitoring,
    summary:
        'Activity and exercise countermeasures, with bone and muscle context '
        'for long-duration microgravity.',
    tracks: [
      'Activity levels and exercise sessions',
      'Exercise adherence over the mission',
      'Imported bone density and muscle assessments',
      'Mission-duration context for bone health',
    ],
    emptyTitle: 'No activity data yet',
    emptyMessage:
        'Activity and exercise sessions appear once a device or manual log is '
        'connected.',
    note:
        'Wearables cannot measure bone density. Bone health is shown only '
        'from imported clinical scans plus mission context, never inferred.',
  ),
  ModuleSpec(
    id: 'behavioural',
    label: 'Behavioural health',
    shortLabel: 'Wellbeing',
    icon: Icons.psychology_outlined,
    selectedIcon: Icons.psychology,
    group: ModuleGroup.monitoring,
    summary:
        'Short self check-ins on mood, stress and alertness, plus brief '
        'cognitive tasks, to help you notice changes in yourself.',
    tracks: [
      'Mood and stress self-assessments',
      'Reaction-time and attention tasks',
      'Isolation and workload self-reports',
      'Links with sleep and workload',
    ],
    emptyTitle: 'No check-ins yet',
    emptyMessage:
        'Your check-ins will appear here after you complete the first one.',
    note:
        'Private by default: check-ins stay on this device unless you '
        'choose to share them. RAKIA does not profile you.',
  ),
  ModuleSpec(
    id: 'environment',
    label: 'Radiation & environment',
    shortLabel: 'Radiation',
    icon: Icons.blur_on_outlined,
    selectedIcon: Icons.blur_on,
    group: ModuleGroup.monitoring,
    summary:
        'Cumulative radiation dose against the NASA-STD-3001 career limit of '
        '600 mSv, and the cabin environment around you.',
    tracks: [
      'Cumulative effective dose and dose rate',
      'Exposure timeline across mission events',
      'Cabin CO₂, oxygen, temperature and humidity',
      'Habitat module readings',
    ],
    emptyTitle: 'No dosimetry or environment data yet',
    emptyMessage:
        'Dose and cabin readings appear once a dosimeter or habitat data '
        'source is connected.',
    note:
        'Only real dosimetry or clearly labelled simulated data is ever '
        'shown. RAKIA never invents radiation values.',
  ),
  ModuleSpec(
    id: 'data',
    label: 'Data management',
    shortLabel: 'Data',
    icon: Icons.storage_outlined,
    selectedIcon: Icons.storage,
    group: ModuleGroup.operations,
    summary:
        'Where every measurement comes from, how good it is, and whether it '
        'has reached the ground.',
    tracks: [
      'Data sources and connected devices',
      'Import and export',
      'Offline sync status',
      'Data quality and provenance for every record',
    ],
    emptyTitle: 'No data sources connected',
    emptyMessage:
        'Data sources, imports and the demonstration simulator are managed '
        'here once data ingestion is available.',
  ),
  ModuleSpec(
    id: 'admin',
    label: 'Mission administration',
    shortLabel: 'Admin',
    icon: Icons.admin_panel_settings_outlined,
    selectedIcon: Icons.admin_panel_settings,
    group: ModuleGroup.operations,
    summary: 'Crew, missions, devices, permissions and the audit log.',
    tracks: [
      'Astronaut and crew management',
      'Mission configuration and phases',
      'Device registry',
      'Role-based permissions and audit log',
    ],
    emptyTitle: 'Sign-in required',
    emptyMessage:
        'Administration is available to mission administrators after '
        'sign-in, which arrives with the authentication feature.',
  ),
];

ModuleSpec? moduleForPath(String path) {
  for (final m in kModules) {
    if (path == m.path || path.startsWith('${m.path}/')) return m;
  }
  return null;
}
