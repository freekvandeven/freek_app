# Freek App

A personal Flutter app with Firebase backend, supporting Android, iOS, Web, and Windows.

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
CLOUD_FUNCTIONS_REGION=us-central1
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
