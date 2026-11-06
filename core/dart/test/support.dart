// SPDX-License-Identifier: Apache-2.0

import 'package:rakia_core/rakia_core.dart';

/// Opens librakia for tests. On the web the module is served by the test
/// runner from the package root (built by tool/build_wasm.sh).
Future<RakiaCore> openCore() =>
    loadRakiaCore(wasmUri: Uri.base.resolve('../build/wasm/rakia.wasm'));

String hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// splitmix64 + Irwin-Hall normal, a bit-exact port of core/tests/rk_test.h.
///
/// Uses only operations that are exact on every Dart platform (32-bit halves,
/// 16-bit limb multiplication), so it also runs correctly when compiled to
/// JavaScript, where Dart integers are doubles.
final class SplitMix64 {
  SplitMix64(int seedHi, int seedLo) : _hi = seedHi, _lo = seedLo;

  static const _two32 = 4294967296;
  int _hi;
  int _lo;

  // Returns the next value as (hi, lo) in _rHi/_rLo.
  int _rHi = 0, _rLo = 0;

  void _next() {
    // state += 0x9E3779B97F4A7C15
    var lo = _lo + 0x7F4A7C15;
    final carry = lo >= _two32 ? 1 : 0;
    lo -= carry * _two32;
    var hi = _hi + 0x9E3779B9 + carry;
    hi %= _two32;
    _hi = hi;
    _lo = lo;
    // z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9
    _xorShift(hi, lo, 30);
    _mul(_rHi, _rLo, 0xBF58476D, 0x1CE4E5B9);
    // z = (z ^ (z >> 27)) * 0x94D049BB133111EB
    _xorShift(_rHi, _rLo, 27);
    _mul(_rHi, _rLo, 0x94D049BB, 0x133111EB);
    // z ^ (z >> 31)
    _xorShift(_rHi, _rLo, 31);
  }

  /// (hi:lo) ^ ((hi:lo) >> s) for 0 < s < 32.
  void _xorShift(int hi, int lo, int s) {
    final p = 1 << (32 - s); // 2^(32-s), exact
    final shLo = (lo >>> s) + (hi % (1 << s)) * p;
    final shHi = hi >>> s;
    _rHi = (hi ^ shHi) >>> 0;
    _rLo = (lo ^ shLo) >>> 0;
  }

  /// (aHi:aLo) * (bHi:bLo) mod 2^64 using 16-bit limbs.
  void _mul(int aHi, int aLo, int bHi, int bLo) {
    final a = [aLo & 0xFFFF, aLo >>> 16, aHi & 0xFFFF, aHi >>> 16];
    final b = [bLo & 0xFFFF, bLo >>> 16, bHi & 0xFFFF, bHi >>> 16];
    final r = [0, 0, 0, 0];
    var carry = 0;
    for (var k = 0; k < 4; k++) {
      var sum = carry;
      for (var i = 0; i <= k; i++) {
        sum += a[i] * b[k - i]; // each product < 2^32, sum < 2^35
      }
      r[k] = sum % 65536;
      carry = (sum - r[k]) ~/ 65536;
    }
    _rLo = r[0] + r[1] * 65536;
    _rHi = r[2] + r[3] * 65536;
  }

  /// Uniform in (0, 1): ((x >> 11) + 0.5) / 2^53.
  double uniform() {
    _next();
    final top53 = _rHi * 2097152 + (_rLo >>> 11); // hi * 2^21 + lo >> 11
    return (top53.toDouble() + 0.5) * (1.0 / 9007199254740992.0);
  }

  double normal() {
    var s = 0.0;
    for (var i = 0; i < 12; i++) {
      s += uniform();
    }
    return s - 6.0;
  }
}
