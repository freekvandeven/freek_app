# Freek App

A personal Flutter app with Firebase backend, supporting Android, iOS, Web, and Windows.

## Region & Infrastructure

This app is primarily used from the **Netherlands**. All Google Cloud / Firebase resources should be created in **Western Europe** to minimise latency:

| Resource | Region | Location |
|----------|--------|----------|
| Cloud Functions | `europe-west4` | Netherlands |
| Firestore | `eur3` | Multi-region Europe |
| Cloud Storage | `eur4` | Dual-region (NL + Finland) |

When creating new Firebase or GCP resources, prefer `europe-west4` (Netherlands) as the primary region.

## Getting Started

### Prerequisites

- Flutter SDK 3.41+
- Firebase CLI (`npm install -g firebase-tools`)
- A Firebase project with Authentication, Firestore, and Cloud Functions enabled

### Environment Setup

Copy `dotenv.example` to `dotenv` and fill in the required values:

```
FIREBASE_API_KEY=...
FIREBASE_APP_ID=...
FIREBASE_MESSAGING_SENDER_ID=...
FIREBASE_PROJECT_ID=...
FIREBASE_AUTH_DOMAIN=...
FIREBASE_STORAGE_BUCKET=...
CLOUD_FUNCTIONS_REGION=europe-west4
```

### Running the App

```bash
flutter run
```

## Firebase Administration

### Security Model

All users must be registered through the invite-code system. The `createUserWithInvite` Cloud Function validates an invite code, creates the user via Admin SDK, and sets the `inviteVerified` custom claim. Firestore security rules require this claim on every read/write operation, so users created outside this flow cannot access any data.

### Managing Invite Codes

Invite codes live in the `inviteCodes` Firestore collection. Client access is **denied** — codes can only be managed via the Firebase Console or Admin SDK.

**To create an invite code:**

1. Open the [Firebase Console](https://console.firebase.google.com) → Firestore Database
2. Navigate to (or create) the `inviteCodes` collection
3. Click **Add document**
4. Set the **Document ID** to the invite code string (e.g. `my-invite-code-123`). This is what the user will enter during signup.
5. Optionally add a `createdAt` field (type: `timestamp`) for bookkeeping
6. Click **Save**

Each code is **single-use** — it is automatically deleted after a successful registration.

### Cloud Functions

| Function | Purpose |
|----------|---------|
| `createUserWithInvite` | Validates invite code, creates user, sets `inviteVerified` claim, deletes code |
| `setInviteVerifiedClaim` | Admin utility to grant `inviteVerified` to an existing user (requires `admin` claim) |

### Deploying

```bash
# Deploy Cloud Functions
firebase deploy --only functions

# Deploy Firestore rules
firebase deploy --only firestore:rules

# Deploy everything
firebase deploy
```

## Local Development with Firebase Emulators

Run the app against local Firebase emulators instead of the production project:

```bash
# Start emulators (Auth:9099, Firestore:8080, Storage:9199, Functions:5001, UI:4000)
firebase emulators:start

# In another terminal, run the app with the emulator dotenv
flutter run --dart-define-from-file=dotenv.emulator
```

Or copy `dotenv.emulator` to `dotenv` to use emulators as the default backend.

The Emulator UI is available at http://localhost:4000.

## Testing

### Unit / Widget Tests

```bash
flutter test
```

### Integration Tests (Firebase Emulators)

Integration tests run against the local Firebase emulators and exercise auth, Firestore, security rules, and the Cloud Function signup flow.

```bash
# Start emulators + run integration tests in one command
firebase emulators:exec "flutter test integration_test/ -d chrome"

# Or with flutter drive (used in CI)
chromedriver --port=4444 &
firebase emulators:exec \
  "flutter drive --driver=test_driver/integration_test.dart \
   --target=integration_test/app_test.dart -d web-server"
```

## Pre-commit Hook

A pre-commit hook runs `dart format`, `flutter analyze`, and `flutter test` before each commit.

```bash
# Install the hook (run once after cloning)
bash scripts/setup-hooks.sh
```

## CI/CD

GitHub Actions runs on every push/PR to `master`:

- **quality** job: format check, `flutter analyze`, unit tests
- **integration** job: starts Firebase emulators, runs integration tests on Chrome

## Android Release Signing

Release builds are signed with a local keystore that is **not** checked into git. The keystore and its passwords are excluded via `android/.gitignore` (`key.properties`, `**/*.jks`, `**/*.keystore`).

### Files involved

| File | Purpose | In git? |
|------|---------|---------|
| `android/app/release-keystore.jks` | Release keystore (RSA 2048-bit, valid ~27 years) | No |
| `android/key.properties` | Passwords and path for Gradle to find the keystore | No |
| `android/app/build.gradle.kts` | Reads `key.properties` and configures the `release` signing config | Yes |

### Release fingerprints

These fingerprints are needed when configuring Firebase, Google Sign-In, or Play App Signing:

```
SHA-1:   09:1A:99:D0:E8:E3:36:E8:4F:34:55:E1:94:16:B8:12:6C:8A:F4:37
SHA-256: 58:B7:AB:1D:A9:84:E9:CA:DE:95:1A:43:83:00:0A:73:13:66:41:3C:D7:CB:84:D4:D5:99:03:88:3B:B5:71:18
```

Add the SHA-1 fingerprint to the Firebase Console under **Project Settings → Your Apps → Android app → SHA certificate fingerprints** (required for Google Sign-In and other Google APIs).

### Re-generating a keystore (new machine / lost key)

If you need to set up release signing from scratch:

```bash
# 1. Generate a new keystore
keytool -genkey -v \
  -keystore android/app/release-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias release

# 2. Create android/key.properties with your chosen passwords:
#    storePassword=<password>
#    keyPassword=<password>
#    keyAlias=release
#    storeFile=app/release-keystore.jks

# 3. Print the new fingerprints
keytool -list -v \
  -keystore android/app/release-keystore.jks \
  -alias release

# 4. Update the SHA-1 fingerprint in Firebase Console
```

> **Important:** If you re-generate the keystore, existing installations signed with the old key cannot be updated in-place. For Play Store apps, use Play App Signing to avoid this.
