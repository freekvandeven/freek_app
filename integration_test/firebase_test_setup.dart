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
CLOUD_FUNCTIONS_REGION=europe-west4
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

  await FirebaseAuth.instance.useAuthEmulator(emulatorHost, authPort);
  FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, firestorePort);
  await FirebaseStorage.instance.useStorageEmulator(emulatorHost, storagePort);

  _initialized = true;
}

/// Creates a test user by calling the [createUserWithInvite] Cloud Function
/// running in the emulator. The function uses the Admin SDK to create the user,
/// set the `inviteVerified` custom claim, and create the user profile in Firestore.
Future<UserCredential> createTestUser({
  String email = 'test@example.com',
  String password = 'Test123!',
}) async {
  // Each call needs a unique invite code (the function deletes it after use)
  final inviteCode = 'test-invite-${email.hashCode.abs()}';
  await seedInviteCode(inviteCode);

  // Call the createUserWithInvite Cloud Function
  final response = await http.post(
    Uri.parse(
      'http://$emulatorHost:$functionsPort/$projectId/europe-west4/createUserWithInvite',
    ),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'data': {'email': email, 'password': password, 'inviteCode': inviteCode},
    }),
  );

  if (response.statusCode != 200) {
    throw Exception(
      'createUserWithInvite failed: ${response.statusCode} ${response.body}',
    );
  }

  final body = jsonDecode(response.body) as Map<String, dynamic>;
  final token = (body['result'] as Map<String, dynamic>)['token'] as String;

  // Sign in with the custom token returned by the function
  return FirebaseAuth.instance.signInWithCustomToken(token);
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
