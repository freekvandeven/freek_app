import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/user_profile.dart';

abstract class AuthService {
  Future<void> init();
  void dispose();
  Stream<UserProfile?> get authStateChanges;
  UserProfile? get currentUser;
  Future<UserProfile> signUp({
    required String email,
    required String password,
    required String inviteCode,
  });
  Future<UserProfile> signIn({required String email, required String password});
  Future<void> signOut();
  Future<void> resetPassword({required String email});
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
  Future<void> updateProfile(UserProfile profile);
}

class MockAuthService implements AuthService {
  final SharedPreferencesAsync _prefs;
  final _authStateController = StreamController<UserProfile?>.broadcast();
  UserProfile? _currentUser;

  static const _usersKey = 'mock_auth_users';
  static const _currentUserKey = 'mock_auth_current_user';

  MockAuthService(this._prefs);

  @override
  Future<void> init() async {
    final currentUserId = await _prefs.getString(_currentUserKey);
    if (currentUserId != null) {
      final users = await _loadUsers();
      _currentUser = users[currentUserId];
      _authStateController.add(_currentUser);
    }
  }

  @override
  Stream<UserProfile?> get authStateChanges => _authStateController.stream;

  @override
  UserProfile? get currentUser => _currentUser;

  @override
  Future<UserProfile> signUp({
    required String email,
    required String password,
    required String inviteCode,
  }) async {
    final users = await _loadUsers();
    final existing = users.values.where((u) => u.email == email);
    if (existing.isNotEmpty) {
      throw AuthException('An account with this email already exists.');
    }

    final now = DateTime.now();
    final profile = UserProfile(
      id: const Uuid().v4(),
      email: email,
      createdAt: now,
      updatedAt: now,
    );

    users[profile.id] = profile;
    await _saveUsers(users);
    await _setCurrentUser(profile);
    return profile;
  }

  @override
  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async {
    final users = await _loadUsers();
    final match = users.values.where((u) => u.email == email);
    if (match.isEmpty) {
      throw AuthException('No account found with this email.');
    }
    final profile = match.first;
    await _setCurrentUser(profile);
    return profile;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    await _prefs.remove(_currentUserKey);
    _authStateController.add(null);
  }

  @override
  Future<void> resetPassword({required String email}) async {
    // Mock: no-op, just simulate success
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    // Mock: no-op, just simulate success
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<void> updateProfile(UserProfile profile) async {
    final users = await _loadUsers();
    users[profile.id] = profile;
    await _saveUsers(users);
    if (_currentUser?.id == profile.id) {
      _currentUser = profile;
      _authStateController.add(profile);
    }
  }

  Future<Map<String, UserProfile>> _loadUsers() async {
    final json = await _prefs.getString(_usersKey);
    if (json == null) return {};
    final map = jsonDecode(json) as Map<String, dynamic>;
    return map.map(
      (key, value) =>
          MapEntry(key, UserProfile.fromMap(value as Map<String, dynamic>)),
    );
  }

  Future<void> _saveUsers(Map<String, UserProfile> users) async {
    final map = users.map((key, value) => MapEntry(key, value.toMap()));
    await _prefs.setString(_usersKey, jsonEncode(map));
  }

  Future<void> _setCurrentUser(UserProfile profile) async {
    _currentUser = profile;
    await _prefs.setString(_currentUserKey, profile.id);
    _authStateController.add(profile);
  }

  @override
  void dispose() {
    _authStateController.close();
  }
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}
