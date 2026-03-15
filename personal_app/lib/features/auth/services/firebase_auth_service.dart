import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../../../config/app_config.dart';
import '../models/user_profile.dart';
import 'auth_service.dart';

class FirebaseAuthService implements AuthService {
  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final _authStateController = StreamController<UserProfile?>.broadcast();

  UserProfile? _currentUser;

  FirebaseAuthService({fb.FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? fb.FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  /// Cloud Functions callable URL base.
  /// Gen 2 callable functions are accessible at the standard Firebase URL.
  /// When emulators are active, routes to the local Functions emulator.
  String get _functionsBaseUrl {
    final projectId = AppConfig.firebaseProjectId;
    final region = AppConfig.cloudFunctionsRegion;
    if (AppConfig.useEmulators) {
      final host = AppConfig.emulatorHost;
      return 'http://$host:5001/$projectId/$region';
    }
    return 'https://$region-$projectId.cloudfunctions.net';
  }

  @override
  Future<void> init() async {
    final fbUser = _auth.currentUser;
    if (fbUser != null) {
      _currentUser = await _loadProfile(fbUser.uid);
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
    try {
      // Call the createUserWithInvite Cloud Function via HTTP
      // This works on all platforms (Android, iOS, Web, Windows, macOS, Linux)
      final response = await http.post(
        Uri.parse('$_functionsBaseUrl/createUserWithInvite'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'data': {
            'email': email,
            'password': password,
            'inviteCode': inviteCode,
          },
        }),
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200) {
        final error = body['error'] as Map<String, dynamic>?;
        final message = error?['message'] as String? ?? 'Registration failed.';
        throw AuthException(message);
      }

      final result = body['result'] as Map<String, dynamic>;
      final token = result['token'] as String;

      // Sign in with the custom token returned by the Cloud Function
      await _auth.signInWithCustomToken(token);

      final fbUser = _auth.currentUser!;
      _currentUser = await _loadProfile(fbUser.uid);
      if (_currentUser == null) {
        throw const AuthException('User profile not found after signup.');
      }
      _authStateController.add(_currentUser);
      return _currentUser!;
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('Registration failed: $e');
    }
  }

  @override
  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final profile = await _loadProfile(credential.user!.uid);
      if (profile == null) {
        throw const AuthException('User profile not found.');
      }
      _currentUser = profile;
      _authStateController.add(profile);
      return profile;
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e.code));
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    _currentUser = null;
    _authStateController.add(null);
  }

  @override
  Future<void> resetPassword({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e.code));
    }
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final fbUser = _auth.currentUser;
      if (fbUser == null || fbUser.email == null) {
        throw const AuthException('No user is signed in.');
      }

      // Re-authenticate before changing password (Firebase requirement)
      final credential = fb.EmailAuthProvider.credential(
        email: fbUser.email!,
        password: currentPassword,
      );
      await fbUser.reauthenticateWithCredential(credential);

      // Update the password
      await fbUser.updatePassword(newPassword);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e.code));
    }
  }

  @override
  Future<void> updateProfile(UserProfile profile) async {
    await _saveProfile(profile);
    if (_currentUser?.id == profile.id) {
      _currentUser = profile;
      _authStateController.add(profile);
    }
  }

  Future<UserProfile?> _loadProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserProfile.fromMap(doc.data()!);
  }

  Future<void> _saveProfile(UserProfile profile) async {
    await _firestore.collection('users').doc(profile.id).set(profile.toMap());
  }

  @override
  void dispose() {
    _authStateController.close();
  }

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'weak-password':
        return 'The password is too weak.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      default:
        return 'Authentication failed: $code';
    }
  }
}
