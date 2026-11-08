import 'package:flutter/foundation.dart';

/// One self-report question with its response options, worded as the
/// instrument's authors published them (or, for [mood], plainly labelled as
/// not a validated scale).
@immutable
class Instrument {
  const Instrument({
    required this.id,
    required this.title,
    required this.question,
    required this.options,
    required this.source,
    required this.validated,
  });

  final String id;
  final String title;
  final String question;

  /// Response labels; option i has the value i + 1.
  final List<String> options;

  /// Where the instrument comes from, shown with the question.
  final String source;

  /// Whether this is a published, validated instrument.
  final bool validated;

  int get min => 1;
  int get max => options.length;

  String label(int value) => options[value - 1];
}

/// Karolinska Sleepiness Scale (KSS), all nine steps labelled.
const Instrument sleepinessScale = Instrument(
  id: 'sleepiness',
  title: 'Sleepiness',
  question: 'How sleepy have you felt over the last few minutes?',
  options: [
    'Extremely alert',
    'Very alert',
    'Alert',
    'Rather alert',
    'Neither alert nor sleepy',
    'Some signs of sleepiness',
    'Sleepy, but no effort to keep awake',
    'Sleepy, some effort to keep awake',
    'Very sleepy, great effort to keep awake, fighting sleep',
  ],
  source:
      'Karolinska Sleepiness Scale (Akerstedt and Gillberg, 1990), '
      'used in spaceflight and aviation fatigue research.',
  validated: true,
);

/// Single-item measure of stress symptoms.
const Instrument stressScale = Instrument(
  id: 'stress',
  title: 'Stress',
  question:
      'Stress means a situation in which a person feels tense, restless, '
      'nervous or anxious, or is unable to sleep at night because their mind '
      'is troubled all the time. Do you feel this kind of stress these days?',
  options: [
    'Not at all',
    'Only a little',
    'To some extent',
    'Rather much',
    'Very much',
  ],
  source:
      'Single-item measure of stress symptoms (Elo, Leppanen and Jahkola, '
      '2003), with gender-neutral wording.',
  validated: true,
);

/// A plain mood self-rating. Not a validated instrument.
const Instrument moodScale = Instrument(
  id: 'mood',
  title: 'Mood',
  question: 'How would you rate your mood right now?',
  options: ['Very low', 'Low', 'Neither low nor good', 'Good', 'Very good'],
  source:
      'A simple self-rating to help you notice changes in yourself. It is not '
      'a validated clinical scale.',
  validated: false,
);

const List<Instrument> kCheckInInstruments = [
  sleepinessScale,
  stressScale,
  moodScale,
];

/// One completed check-in.
@immutable
class CheckIn {
  const CheckIn({
    required this.id,
    required this.recordedAt,
    required this.sleepiness,
    required this.stress,
    required this.mood,
  });

  final String id;
  final DateTime recordedAt;
  final int sleepiness;
  final int stress;
  final int mood;

  int valueOf(Instrument i) => switch (i.id) {
    'sleepiness' => sleepiness,
    'stress' => stress,
    'mood' => mood,
    _ => throw ArgumentError.value(i.id, 'instrument'),
  };
}

/// Psychomotor vigilance test parameters, after the 3-minute PVT-B
/// (Basner, Mollicone and Dinges, 2011).
abstract final class Pvt {
  static const Duration duration = Duration(minutes: 3);

  /// Inter-stimulus interval, drawn uniformly from this range.
  static const Duration minInterval = Duration(seconds: 1);
  static const Duration maxInterval = Duration(seconds: 4);

  /// Responses faster than this are anticipations (false starts).
  static const int falseStartMs = 100;

  /// Responses this slow or slower are lapses (PVT-B threshold).
  static const int lapseMs = 355;

  /// A stimulus nobody responds to within this time ends as a lapse.
  static const int timeoutMs = 30000;
}

/// The outcome of one reaction-time test, computed from its raw responses.
@immutable
class ReactionTestResult {
  const ReactionTestResult({
    this.id,
    required this.recordedAt,
    required this.duration,
    required this.stimuli,
    required this.responses,
    required this.medianRtMs,
    required this.meanSpeed,
    required this.lapses,
    required this.falseStarts,
    required this.device,
  });

  /// Scores a test from the response time of each stimulus (null when the
  /// stimulus timed out) and the number of false starts.
  factory ReactionTestResult.score({
    required DateTime recordedAt,
    required Duration duration,
    required List<int?> responseTimesMs,
    required int falseStarts,
    required String device,
  }) {
    final valid = [
      for (final rt in responseTimesMs)
        if (rt != null && rt >= Pvt.falseStartMs) rt,
    ]..sort();
    final anticipations = responseTimesMs
        .where((rt) => rt != null && rt < Pvt.falseStartMs)
        .length;
    final lapses =
        valid.where((rt) => rt >= Pvt.lapseMs).length +
        responseTimesMs.where((rt) => rt == null).length;
    double? median;
    double? speed;
    if (valid.isNotEmpty) {
      final mid = valid.length ~/ 2;
      median = valid.length.isOdd
          ? valid[mid].toDouble()
          : (valid[mid - 1] + valid[mid]) / 2;
      speed =
          valid.map((rt) => 1000 / rt).reduce((a, b) => a + b) / valid.length;
    }
    return ReactionTestResult(
      recordedAt: recordedAt,
      duration: duration,
      stimuli: responseTimesMs.length,
      responses: valid.length,
      medianRtMs: median,
      meanSpeed: speed,
      lapses: lapses,
      falseStarts: falseStarts + anticipations,
      device: device,
    );
  }

  /// Set once the result is stored.
  final String? id;
  final DateTime recordedAt;
  final Duration duration;
  final int stimuli;
  final int responses;
  final double? medianRtMs;

  /// Mean of 1/RT, in responses per second.
  final double? meanSpeed;
  final int lapses;
  final int falseStarts;
  final String device;

  ReactionTestResult withId(String id) => ReactionTestResult(
    id: id,
    recordedAt: recordedAt,
    duration: duration,
    stimuli: stimuli,
    responses: responses,
    medianRtMs: medianRtMs,
    meanSpeed: meanSpeed,
    lapses: lapses,
    falseStarts: falseStarts,
    device: device,
  );
}
