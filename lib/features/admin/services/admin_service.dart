import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../../config/app_config.dart';

class InviteCode {
  final String code;
  final String? createdAt;
  final String? createdBy;

  const InviteCode({required this.code, this.createdAt, this.createdBy});

  factory InviteCode.fromMap(Map<String, dynamic> map) {
    return InviteCode(
      code: map['code'] as String,
      createdAt: map['createdAt'] as String?,
      createdBy: map['createdBy'] as String?,
    );
  }
}

class AdminService {
  final FirebaseAuth _auth;

  AdminService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  String get _functionsBaseUrl {
    final projectId = AppConfig.firebaseProjectId;
    final region = AppConfig.cloudFunctionsRegion;
    if (AppConfig.useEmulators) {
      final host = AppConfig.emulatorHost;
      return 'http://$host:5001/$projectId/$region';
    }
    return 'https://$region-$projectId.cloudfunctions.net';
  }

  Future<bool> get isAdmin async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final result = await user.getIdTokenResult(true);
    return result.claims?['admin'] == true;
  }

  Future<Map<String, dynamic>> _call(Map<String, dynamic> data) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final token = await user.getIdToken();
    final response = await http.post(
      Uri.parse('$_functionsBaseUrl/manageInviteCodes'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'data': data}),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      final error = body['error'] as Map<String, dynamic>?;
      final message = error?['message'] as String? ?? 'Admin operation failed.';
      throw Exception(message);
    }

    return body['result'] as Map<String, dynamic>;
  }

  Future<List<InviteCode>> listInviteCodes() async {
    final result = await _call({'action': 'list'});
    final codes = (result['codes'] as List<dynamic>?) ?? [];
    return codes
        .map((c) => InviteCode.fromMap(c as Map<String, dynamic>))
        .toList();
  }

  Future<String> createInviteCode({String? code}) async {
    final data = <String, dynamic>{'action': 'create'};
    if (code != null && code.trim().isNotEmpty) {
      data['code'] = code.trim();
    }
    final result = await _call(data);
    return result['code'] as String;
  }

  Future<void> deleteInviteCode(String code) async {
    await _call({'action': 'delete', 'code': code});
  }

  Future<void> updateStorageLimit({
    required String targetUserId,
    required int storageLimitBytes,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final token = await user.getIdToken();
    final response = await http.post(
      Uri.parse('$_functionsBaseUrl/updateStorageLimit'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'data': {
          'targetUserId': targetUserId,
          'storageLimitBytes': storageLimitBytes,
        },
      }),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      final error = body['error'] as Map<String, dynamic>?;
      final message =
          error?['message'] as String? ?? 'Failed to update storage limit.';
      throw Exception(message);
    }
  }

  Future<void> setAdminClaim({required String targetUid}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final token = await user.getIdToken();
    final response = await http.post(
      Uri.parse('$_functionsBaseUrl/setAdminClaim'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'data': {'targetUid': targetUid},
      }),
    );

    final body2 = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      final error = body2['error'] as Map<String, dynamic>?;
      final message =
          error?['message'] as String? ?? 'Failed to grant admin privileges.';
      throw Exception(message);
    }
  }

  Future<bool> checkAdminStatus({required String targetUid}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final token = await user.getIdToken();
    final response = await http.post(
      Uri.parse('$_functionsBaseUrl/checkAdminStatus'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'data': {'targetUid': targetUid},
      }),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      final error = body['error'] as Map<String, dynamic>?;
      final message =
          error?['message'] as String? ?? 'Failed to check admin status.';
      throw Exception(message);
    }

    final result = body['result'] as Map<String, dynamic>;
    return result['isAdmin'] as bool? ?? false;
  }
}
