// SPDX-License-Identifier: Apache-2.0
//
// Selected only on platforms with neither dart:ffi nor dart:js_interop.

import 'dart:typed_data';

import 'backend.dart';

Future<RakiaBackend> openBackend({Uri? wasmUri, Uint8List? wasmBytes}) =>
    throw UnsupportedError('librakia is not available on this platform');
