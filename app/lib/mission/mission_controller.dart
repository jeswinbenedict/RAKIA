import 'package:flutter/widgets.dart';
import 'package:rakia_core/rakia_core.dart';

import '../analytics/metric_insight.dart';
import '../components/health_status.dart';
import '../simulation/simulated_mission.dart';
import '../storage/local_store.dart';

/// The analysed state of the active mission.
@immutable
class MissionSnapshot {
  const MissionSnapshot({
    required this.mission,
    required this.insights,
    this.persistence,
  });

  final SimulatedMission mission;

  /// How the mission is stored; null when it lives in memory only.
  final MissionPersistence? persistence;

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

/// Where the active mission is kept and whether its ledger verified.
@immutable
class MissionPersistence {
  const MissionPersistence({
    required this.missionId,
    required this.kind,
    required this.records,
    required this.ledger,
  });

  final String missionId;
  final StorageKind kind;

  /// Records stored for the mission.
  final int records;

  /// librakia's re-verification of the stored hash chain.
  final LedgerCheck ledger;
}

/// Holds whether the user has started the simulation mission. Starting it is
/// always an explicit choice; the app never shows simulated data by default.
///
/// Without a store the mission lives in memory. Once a store is attached the
/// mission is written to it, analysed as read back, restored on the next
/// launch and deleted when the user ends it.
class MissionController extends ChangeNotifier {
  MissionSnapshot? _snapshot;
  LocalStore? _store;
  String? _activity;
  String? _error;
  bool _disposed = false;

  MissionSnapshot? get snapshot => _snapshot;
  bool get isActive => _snapshot != null;

  /// True while the mission is being saved, loaded or removed.
  bool get busy => _activity != null;

  /// What is in progress, in words, while [busy].
  String? get activity => _activity;

  /// What went wrong in the last operation, if anything.
  String? get error => _error;

  /// Whether missions are kept by an attached store.
  bool get hasStore => _store != null;

  /// Uses [store] from now on and restores the simulation mission saved in
  /// it, unless a mission is already active in memory.
  Future<void> attach(LocalStore store, RakiaCore core) async {
    _store = store;
    if (_snapshot != null) return;
    await _run(
      'Loading the saved simulation mission.',
      'The saved simulation mission could not be loaded',
      () async {
        final stored = await store.activeSimulation();
        if (stored != null) _snapshot = await _fromStore(stored, store, core);
      },
    );
  }

  /// Generates the simulation mission and analyses it with [core].
  Future<void> startSimulation(
    RakiaCore core, {
    int seed = 20261106,
    DateTime? now,
  }) async {
    if (busy) return;
    final mission = SimulatedMission.generate(seed: seed);
    final store = _store;
    if (store == null) {
      _error = null;
      _snapshot = _analyse(core, mission, null);
      notifyListeners();
      return;
    }
    await _run(
      'Saving the simulation mission.',
      'The simulation mission could not be saved',
      () async {
        final stored = await store.saveSimulation(mission, core, now: now);
        _snapshot = await _fromStore(stored, store, core);
      },
    );
  }

  /// Ends the simulation and removes every simulated value, including the
  /// stored copy.
  Future<void> endSimulation() async {
    final current = _snapshot;
    if (current == null || busy) return;
    final store = _store;
    final id = current.persistence?.missionId;
    if (store == null || id == null) {
      _error = null;
      _snapshot = null;
      notifyListeners();
      return;
    }
    await _run(
      'Removing the simulation mission.',
      'The simulation mission could not be removed',
      () async {
        await store.deleteSimulation(id);
        _snapshot = null;
      },
    );
  }

  static MissionSnapshot _analyse(
    RakiaCore core,
    SimulatedMission mission,
    MissionPersistence? persistence,
  ) => MissionSnapshot(
    mission: mission,
    insights: [for (final s in mission.series) analyse(core, s)],
    persistence: persistence,
  );

  static Future<MissionSnapshot> _fromStore(
    StoredSimulation stored,
    LocalStore store,
    RakiaCore core,
  ) async {
    final ledger = await store.verifyLedger(stored.missionId, core);
    return _analyse(
      core,
      stored.mission,
      MissionPersistence(
        missionId: stored.missionId,
        kind: store.kind,
        records: stored.records,
        ledger: ledger,
      ),
    );
  }

  Future<void> _run(
    String activity,
    String failure,
    Future<void> Function() body,
  ) async {
    _activity = activity;
    _error = null;
    notifyListeners();
    try {
      await body();
    } on Object catch (e) {
      _error = '$failure: $e';
    }
    _activity = null;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
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
