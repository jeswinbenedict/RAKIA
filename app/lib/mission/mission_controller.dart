import 'package:flutter/widgets.dart';
import 'package:rakia_core/rakia_core.dart';

import '../analytics/metric_insight.dart';
import '../components/health_status.dart';
import '../simulation/simulated_mission.dart';

/// The analysed state of the active mission.
@immutable
class MissionSnapshot {
  const MissionSnapshot({required this.mission, required this.insights});

  final SimulatedMission mission;

  /// One entry per indicator, in display order.
  final List<MetricInsight> insights;

  /// Always true today: the only mission source is the simulator. Real
  /// missions arrive with data ingestion, and the two are never mixed.
  bool get isSimulation => true;

  List<MetricInsight> forModule(String moduleId) =>
      insights.where((i) => i.metric.moduleId == moduleId).toList();

  /// Indicators that need attention, most severe first: Act, Watch, then
  /// data-quality problems.
  List<MetricInsight> get alerts {
    int rank(HealthStatus s) => switch (s) {
      HealthStatus.act => 0,
      HealthStatus.watch => 1,
      HealthStatus.dataQuality => 2,
      _ => 3,
    };
    final list = insights.where((i) => rank(i.status) < 3).toList()
      ..sort((a, b) => rank(a.status).compareTo(rank(b.status)));
    return list;
  }

  int count(HealthStatus s) => insights.where((i) => i.status == s).length;
}

/// Holds whether the user has started the simulation mission. Starting it is
/// always an explicit choice; the app never shows simulated data by default.
class MissionController extends ChangeNotifier {
  MissionSnapshot? _snapshot;

  MissionSnapshot? get snapshot => _snapshot;
  bool get isActive => _snapshot != null;

  /// Generates the simulation mission and analyses it with [core].
  void startSimulation(RakiaCore core, {int seed = 20261106}) {
    final mission = SimulatedMission.generate(seed: seed);
    _snapshot = MissionSnapshot(
      mission: mission,
      insights: [for (final s in mission.series) analyse(core, s)],
    );
    notifyListeners();
  }

  void endSimulation() {
    if (_snapshot == null) return;
    _snapshot = null;
    notifyListeners();
  }
}

class MissionScope extends InheritedNotifier<MissionController> {
  const MissionScope({
    super.key,
    required MissionController controller,
    required super.child,
  }) : super(notifier: controller);

  static MissionController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<MissionScope>();
    assert(scope != null, 'MissionScope is missing from the widget tree');
    return scope!.notifier!;
  }

  /// The active mission, or null when none is running.
  static MissionSnapshot? snapshotOf(BuildContext context) =>
      of(context).snapshot;
}
