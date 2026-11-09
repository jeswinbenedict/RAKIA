// The signed-in user's RAKIA account on the API: GET /v1/me reads it,
// POST /v1/me creates it after a Turnstile check.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

@immutable
class MissionRole {
  const MissionRole({
    required this.missionId,
    required this.missionName,
    required this.isSimulation,
    required this.role,
  });
  final String missionId;
  final String missionName;
  final bool isSimulation;
  final String role;
}

@immutable
class RakiaAccount {
  const RakiaAccount({
    required this.id,
    required this.createdAt,
    required this.roles,
  });
  final String id;
  final DateTime createdAt;
  final List<MissionRole> roles;

  factory RakiaAccount.fromJson(Object? json) {
    if (json is! Map<String, Object?> ||
        json['user'] is! Map<String, Object?>) {
      throw const FormatException('account response');
    }
    final user = json['user']! as Map<String, Object?>;
    final id = user['id'];
    final created = DateTime.tryParse('${user['created_at']}');
    if (id is! String || created == null) {
      throw const FormatException('account fields');
    }
    final roles = <MissionRole>[];
    final list = json['memberships'];
    if (list is List) {
      for (final m in list) {
        if (m is! Map<String, Object?>) continue;
        roles.add(
          MissionRole(
            missionId: '${m['mission_id']}',
            missionName: '${m['mission_name']}',
            isSimulation: m['is_simulation'] == true,
            role: '${m['role']}',
          ),
        );
      }
    }
    return RakiaAccount(id: id, createdAt: created, roles: roles);
  }
}

/// No RAKIA account exists for this sign-in yet (GET /v1/me answered 404).
class NoAccountYet implements Exception {
  const NoAccountYet();
}

class AccountApiException implements Exception {
  const AccountApiException(this.message, {this.status});
  final String message;
  final int? status;
  @override
  String toString() => message;
}

class AccountApi {
  AccountApi({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  /// The free host sleeps when idle and can take most of a minute to wake.
  static const Duration timeout = Duration(seconds: 90);

  Future<RakiaAccount> fetch(String idToken) async {
    final res = await _send('GET', idToken);
    if (res.statusCode == 404) throw const NoAccountYet();
    return _account(res);
  }

  Future<RakiaAccount> create(String idToken, {String? turnstileToken}) async =>
      _account(await _send('POST', idToken, turnstileToken: turnstileToken));

  Future<http.Response> _send(
    String method,
    String idToken, {
    String? turnstileToken,
  }) async {
    final req = http.Request(method, Uri.parse('$baseUrl/v1/me'))
      ..headers['Authorization'] = 'Bearer $idToken'
      ..headers['Accept'] = 'application/json';
    if (turnstileToken != null) {
      req.headers['X-Turnstile-Token'] = turnstileToken;
    }
    try {
      return await http.Response.fromStream(
        await _client.send(req).timeout(timeout),
      );
    } on TimeoutException {
      throw const AccountApiException(
        'The RAKIA server did not answer in time.',
      );
    } on Object {
      throw const AccountApiException('The RAKIA server cannot be reached.');
    }
  }

  RakiaAccount _account(http.Response res) {
    if (res.statusCode == 200 || res.statusCode == 201) {
      try {
        return RakiaAccount.fromJson(jsonDecode(res.body));
      } on FormatException {
        throw const AccountApiException(
          'The RAKIA server sent an unexpected answer.',
        );
      }
    }
    String? message;
    try {
      final j = jsonDecode(res.body);
      if (j is Map && j['error'] is Map) {
        final m = (j['error'] as Map)['message'];
        if (m is String) message = m;
      }
    } on FormatException {
      message = null;
    }
    throw AccountApiException(
      message ?? 'The RAKIA server answered with an error (${res.statusCode}).',
      status: res.statusCode,
    );
  }

  void close() => _client.close();
}
