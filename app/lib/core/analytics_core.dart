import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:rakia_core/rakia_core.dart';

/// State of librakia, RAKIA's analytics core, in this app session.
sealed class AnalyticsCoreState {
  const AnalyticsCoreState();
}

final class AnalyticsCoreLoading extends AnalyticsCoreState {
  const AnalyticsCoreLoading();
}

final class AnalyticsCoreReady extends AnalyticsCoreState {
  const AnalyticsCoreReady(this.core, this.selfTest);
  final RakiaCore core;
  final SelfTestResult selfTest;
}

final class AnalyticsCoreUnavailable extends AnalyticsCoreState {
  const AnalyticsCoreUnavailable(this.reason);
  final String reason;
}

/// Outcome of checking the loaded core against published reference values.
final class SelfTestResult {
  const SelfTestResult(this.failures);

  /// Names of the checks that did not match; empty when all passed.
  final List<String> failures;
  bool get passed => failures.isEmpty;
}

/// Runs known-answer checks: FIPS 180-4 SHA-256 vector and the ledger record
/// hash from librakia's golden chain (core/tests/test_ledger.c).
SelfTestResult runSelfTest(RakiaCore core) {
  final failures = <String>[];
  String hex(List<int> b) =>
      b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  try {
    if (hex(core.sha256('abc'.codeUnits)) !=
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad') {
      failures.add('SHA-256');
    }
    final record = LedgerRecord(
      id: Uint8List.fromList(List.generate(16, (i) => i)),
      subjectId: Uint8List.fromList(List.generate(16, (i) => 16 + i)),
      metricCode: 'heart_rate.resting',
      value: 62.5,
      unit: '/min',
      observedAtUs: 1762387200000000,
      method: MeasurementMethod.measured,
      provenance: Provenance.simulated,
      clientSeq: 1,
      prevHash: Uint8List(32),
    );
    if (hex(core.recordHash(record)) !=
        'e9e40565746a10e6b782260284dd52fcead9cc9233bbb6c99368bf2596cca03d') {
      failures.add('Ledger record hash');
    }
  } on Object catch (e) {
    failures.add('Self-test error: $e');
  }
  return SelfTestResult(failures);
}

typedef AnalyticsCoreLoader = Future<RakiaCore> Function();

class AnalyticsCoreController extends ChangeNotifier {
  AnalyticsCoreController({AnalyticsCoreLoader? loader})
    : _loader = loader ?? loadRakiaCore;

  final AnalyticsCoreLoader _loader;
  AnalyticsCoreState _state = const AnalyticsCoreLoading();
  bool _disposed = false;

  AnalyticsCoreState get state => _state;

  Future<void> load() async {
    AnalyticsCoreState next;
    try {
      final core = await _loader();
      next = AnalyticsCoreReady(core, runSelfTest(core));
    } on Object catch (e) {
      next = AnalyticsCoreUnavailable('$e');
    }
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class AnalyticsCoreScope extends InheritedNotifier<AnalyticsCoreController> {
  const AnalyticsCoreScope({
    super.key,
    required AnalyticsCoreController controller,
    required super.child,
  }) : super(notifier: controller);

  static AnalyticsCoreState of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AnalyticsCoreScope>();
    assert(scope != null, 'AnalyticsCoreScope is missing from the tree');
    return scope!.notifier!.state;
  }
}
