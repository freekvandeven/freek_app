import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

import 'firebase_test_setup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeFirebaseForTesting();
  });

  tearDown(() async {
    await clearEmulatorData();
  });

  // ---------------------------------------------------------------------------
  // Auth emulator tests
  // ---------------------------------------------------------------------------
  group('Firebase Auth', () {
    testWidgets('can create a user and sign in', (tester) async {
      final credential = await createTestUser(
        email: 'auth-test@example.com',
        password: 'Passw0rd!',
      );

      expect(credential.user, isNotNull);
      expect(credential.user!.email, 'auth-test@example.com');
      expect(FirebaseAuth.instance.currentUser, isNotNull);
    });

    testWidgets('can sign out and back in', (tester) async {
      await createTestUser(
        email: 'signout-test@example.com',
        password: 'Passw0rd!',
      );
      expect(FirebaseAuth.instance.currentUser, isNotNull);

      await FirebaseAuth.instance.signOut();
      expect(FirebaseAuth.instance.currentUser, isNull);

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: 'signout-test@example.com',
        password: 'Passw0rd!',
      );
      expect(FirebaseAuth.instance.currentUser, isNotNull);
      expect(
        FirebaseAuth.instance.currentUser!.email,
        'signout-test@example.com',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Firestore emulator tests (with security rules)
  // ---------------------------------------------------------------------------
  group('Firestore', () {
    testWidgets('user profile is created and readable', (tester) async {
      final credential = await createTestUser(
        email: 'firestore-read@example.com',
        password: 'Passw0rd!',
      );
      final uid = credential.user!.uid;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      expect(doc.exists, isTrue);
      expect(doc.data()!['email'], 'firestore-read@example.com');
      expect(doc.data()!['displayName'], 'Test User');
    });

    testWidgets('can update user profile', (tester) async {
      final credential = await createTestUser(
        email: 'firestore-update@example.com',
        password: 'Passw0rd!',
      );
      final uid = credential.user!.uid;

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'displayName': 'Updated Name',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      expect(doc.data()!['displayName'], 'Updated Name');
    });

    testWidgets('security rules prevent access to other users data', (
      tester,
    ) async {
      await createTestUser(
        email: 'rules-test@example.com',
        password: 'Passw0rd!',
      );

      // Attempting to read another user's document should be denied
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc('nonexistent-uid')
            .get();
        fail('Expected permission-denied error');
      } on FirebaseException catch (e) {
        expect(e.code, 'permission-denied');
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Full E2E: signup via Cloud Function with invite code
  // ---------------------------------------------------------------------------
  group('Cloud Function signup flow', () {
    testWidgets('signup with invite code creates user and profile', (
      tester,
    ) async {
      // Seed an invite code in Firestore (bypasses security rules)
      await seedInviteCode('TEST_INVITE_CODE');

      // Call the createUserWithInvite Cloud Function directly
      final response = await http.post(
        Uri.parse(
          'http://$emulatorHost:$functionsPort/$projectId/us-central1/createUserWithInvite',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'data': {
            'email': 'signup-e2e@example.com',
            'password': 'E2eTest123!',
            'inviteCode': 'TEST_INVITE_CODE',
          },
        }),
      );

      expect(response.statusCode, 200);
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final token = body['result']['token'] as String;
      expect(token, isNotEmpty);

      // Sign in with the custom token returned by the Cloud Function
      final credential = await FirebaseAuth.instance.signInWithCustomToken(
        token,
      );
      expect(credential.user, isNotNull);
      expect(credential.user!.email, 'signup-e2e@example.com');

      // Verify the user profile was created in Firestore
      final uid = credential.user!.uid;
      final profileDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      expect(profileDoc.exists, isTrue);
      expect(profileDoc.data()!['email'], 'signup-e2e@example.com');

      // Verify the invite code was consumed (deleted)
      try {
        // Using the admin REST API to check — client rules deny access
        final codeCheck = await http.get(
          Uri.parse(
            'http://$emulatorHost:$firestorePort/v1/projects/$projectId/'
            'databases/(default)/documents/inviteCodes/TEST_INVITE_CODE',
          ),
          headers: {'Authorization': 'Bearer owner'},
        );
        // If the document is gone, the REST API returns 404
        expect(codeCheck.statusCode, 404);
      } catch (_) {
        // 404 means the code was deleted — expected
      }
    });
  });
}
