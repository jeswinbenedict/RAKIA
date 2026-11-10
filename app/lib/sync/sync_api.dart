// POST /v1/sync/batches: uploads a batch of the signed-in user's own
// hash-chained readings. The server recomputes every hash with librakia
// before storing anything.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

@immutable
class SyncAck {
  const SyncAck({required this.ackedThroughSeq, required this.accepted});

  /// The server holds every record of this device up to this sequence.
  final int ackedThroughSeq;

  /// Records stored by this request.
  final int accepted;
}

/// A refusal or failure. [code] is the API's error code when it answered;
/// null when it could not be reached.
class SyncException implements Exception {
  const SyncException(this.message, {this.code, this.status});
  final String message;
  final String? code;
  final int? status;
  @override
  String toString() => message;
}

class SyncApi {
  SyncApi({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  /// The free host sleeps when idle and can take most of a minute to wake.
  static const Duration timeout = Duration(seconds: 90);

  Future<SyncAck> send(String idToken, Map<String, Object?> batch) async {
    final http.Response res;
    try {
      res = await _client
          .post(
            Uri.parse('$baseUrl/v1/sync/batches'),
            headers: {
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(batch),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const SyncException('The RAKIA server did not answer in time.');
    } on Object {
      throw const SyncException('The RAKIA server cannot be reached.');
    }
    Object? json;
    try {
      json = jsonDecode(res.body);
    } on FormatException {
      json = null;
    }
    if (res.statusCode == 200 && json is Map<String, Object?>) {
      final acked = json['acked_through_seq'];
      final accepted = json['accepted'];
      if (acked is int && accepted is int && acked >= 0) {
        return SyncAck(ackedThroughSeq: acked, accepted: accepted);
      }
      throw const SyncException('The RAKIA server sent an unexpected answer.');
    }
    String? code;
    String? message;
    if (json is Map && json['error'] is Map) {
      final e = json['error'] as Map;
      if (e['code'] is String) code = e['code'] as String;
      if (e['message'] is String) message = e['message'] as String;
    }
    throw SyncException(
      message ?? 'The RAKIA server answered with an error (${res.statusCode}).',
      code: code ?? 'http_${res.statusCode}',
      status: res.statusCode,
    );
  }

  void close() => _client.close();
}
