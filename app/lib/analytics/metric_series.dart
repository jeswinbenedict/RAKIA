import 'package:flutter/foundation.dart';

import 'metric_definitions.dart';

/// One indicator as daily values: a reference window (the baseline) and a
/// monitoring window. Used for real records and simulations alike; only a
/// simulation carries a [scenario] and an injected [changeDay].
@immutable
class MetricSeries {
  const MetricSeries({
    required this.metric,
    required this.reference,
    required this.monitoring,
    required this.sensorFlags,
    this.scenario,
    this.changeDay,
  });

  final MetricDefinition metric;

  /// One value per reference day; NaN where no reading was recorded.
  final List<double> reference;

  /// One value per monitoring day; NaN where no reading was recorded.
  final List<double> monitoring;

  /// Non-zero where the device reported a sensor problem.
  final List<int> sensorFlags;

  /// For a simulation: plain-language description of what was simulated.
  final String? scenario;

  /// For a simulation: day (1-based) on which the injected change starts.
  final int? changeDay;
}
