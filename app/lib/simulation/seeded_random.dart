/// Deterministic pseudo-random numbers for the simulation mission.
///
/// splitmix64 with an Irwin-Hall normal, the same generator as librakia's C
/// test suite (core/tests/rk_test.h). Implemented with 32-bit halves and
/// 16-bit limb multiplication so every platform, including the web where
/// Dart integers are doubles, produces the same sequence. The same seed
/// therefore gives the same simulated mission on every device.
class SeededRandom {
  SeededRandom(int seed) : _hi = (seed ~/ _two32) % _two32, _lo = seed % _two32;

  static const int _two32 = 4294967296;
  int _hi;
  int _lo;
  int _rHi = 0;
  int _rLo = 0;

  void _next() {
    var lo = _lo + 0x7F4A7C15;
    final carry = lo >= _two32 ? 1 : 0;
    lo -= carry * _two32;
    final hi = (_hi + 0x9E3779B9 + carry) % _two32;
    _hi = hi;
    _lo = lo;
    _xorShift(hi, lo, 30);
    _mul(_rHi, _rLo, 0xBF58476D, 0x1CE4E5B9);
    _xorShift(_rHi, _rLo, 27);
    _mul(_rHi, _rLo, 0x94D049BB, 0x133111EB);
    _xorShift(_rHi, _rLo, 31);
  }

  void _xorShift(int hi, int lo, int s) {
    final p = 1 << (32 - s);
    final shLo = (lo >>> s) + (hi % (1 << s)) * p;
    final shHi = hi >>> s;
    _rHi = (hi ^ shHi) >>> 0;
    _rLo = (lo ^ shLo) >>> 0;
  }

  void _mul(int aHi, int aLo, int bHi, int bLo) {
    final a = [aLo & 0xFFFF, aLo >>> 16, aHi & 0xFFFF, aHi >>> 16];
    final b = [bLo & 0xFFFF, bLo >>> 16, bHi & 0xFFFF, bHi >>> 16];
    final r = [0, 0, 0, 0];
    var carry = 0;
    for (var k = 0; k < 4; k++) {
      var sum = carry;
      for (var i = 0; i <= k; i++) {
        sum += a[i] * b[k - i];
      }
      r[k] = sum % 65536;
      carry = (sum - r[k]) ~/ 65536;
    }
    _rLo = r[0] + r[1] * 65536;
    _rHi = r[2] + r[3] * 65536;
  }

  /// Uniform in (0, 1).
  double uniform() {
    _next();
    final top53 = _rHi * 2097152 + (_rLo >>> 11);
    return (top53.toDouble() + 0.5) * (1.0 / 9007199254740992.0);
  }

  /// Approximately standard normal (sum of 12 uniforms minus 6).
  double normal() {
    var s = 0.0;
    for (var i = 0; i < 12; i++) {
      s += uniform();
    }
    return s - 6.0;
  }
}
