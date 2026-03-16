import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

const emulatorHost = 'localhost';
const authPort = 9099;
const firestorePort = 8080;
const storagePort = 9199;
const functionsPort = 5001;
const projectId = 'freek-personal-app';

bool _initialized = false;

/// Initializes Firebase and connects to local emulators for testing.
/// Safe to call multiple times — only initializes once.
Future<void> initializeFirebaseForTesting() async {
  if (_initialized) return;

  dotenv.testLoad(
    fileInput:
        '''
APP_NAME=Personal App (Test)
STORAGE_BACKEND=firebase
USE_EMULATORS=true
EMULATOR_HOST=$emulatorHost
FIREBASE_API_KEY=fake-api-key
FIREBASE_AUTH_DOMAIN=$projectId.firebaseapp.com
FIREBASE_PROJECT_ID=$projectId
FIREBASE_STORAGE_BUCKET=$projectId.firebasestorage.app
FIREBASE_MESSAGING_SENDER_ID=90391184253
FIREBASE_APP_ID=test-app-id
FIREBASE_MEASUREMENT_ID=test-measurement-id
GEMINI_API_KEY=fake-gemini-key
CLOUD_FUNCTIONS_REGION=us-central1
''',
  );

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'fake-api-key',
      appId: 'test-app-id',
      messagingSenderId: '90391184253',
      projectId: projectId,
      storageBucket: '$projectId.firebasestorage.app',
    ),
  );

  FirebaseAuth.instance.useAuthEmulator(emulatorHost, authPort);
  FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, firestorePort);
  FirebaseStorage.instance.useStorageEmulator(emulatorHost, storagePort);

  _initialized = true;
}

/// Creates a test user directly in the Auth emulator, sets the inviteVerified
/// custom claim via the emulator REST API, and seeds a user profile in Firestore.
Future<UserCredential> createTestUser({
  String email = 'test@example.com',
  String password = 'Test123!',
}) async {
  // Create user via Firebase Auth
  final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
    email: email,
    password: password,
  );
  final uid = credential.user!.uid;

  // Set inviteVerified custom claim via Auth emulator internal REST API.
  // The emulator exposes a PATCH endpoint to update user accounts directly,
  // including custom claims (which the Identity Toolkit REST API does not support).
  final claimResponse = await http.patch(
    Uri.parse(
      'http://$emulatorHost:$authPort/emulator/v1/projects/$projectId/accounts/$uid',
    ),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer owner',
    },
    body: jsonEncode({
      'customAttributes': jsonEncode({'inviteVerified': true}),
    }),
  );

  if (claimResponse.statusCode != 200) {
    throw Exception(
      'Failed to set custom claims: ${claimResponse.statusCode} ${claimResponse.body}',
    );
  }

  // Sign out and back in to get a fresh ID token with the new claim
  await FirebaseAuth.instance.signOut();
  final freshCredential = await FirebaseAuth.instance
      .signInWithEmailAndPassword(email: email, password: password);

  // Seed user profile in Firestore (security rules now allow this)
  await FirebaseFirestore.instance.collection('users').doc(uid).set({
    'id': uid,
    'email': email,
    'displayName': 'Test User',
    'bio': null,
    'phone': null,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
    'settings': {
      'themeMode': 'system',
      'notificationsEnabled': true,
      'defaultCurrency': 'EUR',
      'biometricEnabled': false,
    },
  });

  return freshCredential;
}

/// Seeds an invite code document in the Firestore emulator.
/// Uses the `Authorization: Bearer owner` header to bypass security rules.
Future<void> seedInviteCode(String code) async {
  final url = Uri.parse(
    'http://$emulatorHost:$firestorePort/v1/projects/$projectId/'
    'databases/(default)/documents/inviteCodes/$code',
  );
  final response = await http.patch(
    url,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer owner',
    },
    body: jsonEncode({'fields': {}}),
  );
  if (response.statusCode != 200) {
    throw Exception(
      'Failed to seed invite code: ${response.statusCode} ${response.body}',
    );
  }
}

/// Clears all emulator data (auth accounts + Firestore documents).
Future<void> clearEmulatorData() async {
  try {
    await FirebaseAuth.instance.signOut();
  } catch (_) {}

  await http.delete(
    Uri.parse(
      'http://$emulatorHost:$authPort/emulator/v1/projects/$projectId/accounts',
    ),
  );
  await http.delete(
    Uri.parse(
      'http://$emulatorHost:$firestorePort/emulator/v1/projects/$projectId/'
      'databases/(default)/documents',
    ),
  );
}
