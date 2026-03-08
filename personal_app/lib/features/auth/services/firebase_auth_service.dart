import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile.dart';
import 'auth_service.dart';

class FirebaseAuthService implements AuthService {
  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final _authStateController = StreamController<UserProfile?>.broadcast();

  UserProfile? _currentUser;

  FirebaseAuthService({
    fb.FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? fb.FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance {
    _auth.authStateChanges().listen((fbUser) async {
      if (fbUser == null) {
        _currentUser = null;
        _authStateController.add(null);
      } else {
        _currentUser = await _loadProfile(fbUser.uid);
        _authStateController.add(_currentUser);
      }
    });
  }

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
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final now = DateTime.now();
      final profile = UserProfile(
        id: credential.user!.uid,
        email: email,
        createdAt: now,
        updatedAt: now,
      );
      await _saveProfile(profile);
      _currentUser = profile;
      _authStateController.add(profile);
      return profile;
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e.code));
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
