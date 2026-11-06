import 'dart:math';
import 'dart:typed_data';

/// UUID version 7 (RFC 9562): a 48-bit Unix millisecond timestamp followed by
/// 74 random bits, so identifiers sort by creation time.
Uint8List uuidV7({DateTime? now, Random? random}) {
  final rng = random ?? Random.secure();
  final ms = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
  final b = Uint8List(16);
  // 48-bit big-endian timestamp, written without 64-bit shifts so it is
  // exact on the web, where integers are doubles.
  var t = ms;
  for (var i = 5; i >= 0; i--) {
    b[i] = t % 256;
    t ~/= 256;
  }
  for (var i = 6; i < 16; i++) {
    b[i] = rng.nextInt(256);
  }
  b[6] = 0x70 | (b[6] & 0x0F); // version 7
  b[8] = 0x80 | (b[8] & 0x3F); // RFC 9562 variant
  return b;
}

/// Canonical lower-case 8-4-4-4-12 form.
String uuidToString(List<int> b) {
  if (b.length != 16) {
    throw ArgumentError.value(b.length, 'length', 'a UUID has 16 bytes');
  }
  final hex = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
