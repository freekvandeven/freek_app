import { onCall, onRequest, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";

initializeApp();

/**
 * NOTE: blockDirectSignup (beforeUserCreated) requires Firebase Identity
 * Platform (GCIP), a paid upgrade. Security is still enforced because all
 * Firestore rules require the `inviteVerified` custom claim — users created
 * outside this flow have no claim and can't access any data.
 */

/**
 * Callable function: creates a new user with a valid invite code.
 *
 * Expects: { email: string, password: string, inviteCode: string }
 * Returns: { token: string } — a custom token for the client to sign in with.
 *
 * Flow:
 * 1. Validates the invite code exists in the `inviteCodes` collection
 * 2. Creates the Firebase Auth user via Admin SDK (bypasses blockDirectSignup)
 * 3. Sets the `inviteVerified` custom claim on the user
 * 4. Creates the user profile document in Firestore
 * 5. Deletes the used invite code (single-use)
 * 6. Returns a custom token for client sign-in
 */
export const createUserWithInvite = onCall(async (request) => {
  const { email, password, inviteCode } = request.data;

  // --- Input validation ---
  if (
    typeof email !== "string" ||
    typeof password !== "string" ||
    typeof inviteCode !== "string"
  ) {
    throw new HttpsError("invalid-argument", "Missing required fields.");
  }

  const trimmedEmail = email.trim().toLowerCase();
  const trimmedCode = inviteCode.trim();

  if (!trimmedEmail || !password || !trimmedCode) {
    throw new HttpsError("invalid-argument", "Fields must not be empty.");
  }

  if (password.length < 6) {
    throw new HttpsError(
      "invalid-argument",
      "Password must be at least 6 characters."
    );
  }

  // --- Validate invite code ---
  const db = getFirestore();
  const inviteRef = db.collection("inviteCodes").doc(trimmedCode);
  const inviteDoc = await inviteRef.get();

  if (!inviteDoc.exists) {
    throw new HttpsError("permission-denied", "Invalid invite code.");
  }

  // --- Create user via Admin SDK (bypasses blocking function) ---
  const auth = getAuth();
  let uid: string;

  try {
    const userRecord = await auth.createUser({
      email: trimmedEmail,
      password: password,
    });
    uid = userRecord.uid;
  } catch (error: unknown) {
    const firebaseError = error as { code?: string; message?: string };
    if (firebaseError.code === "auth/email-already-exists") {
      throw new HttpsError(
        "already-exists",
        "An account with this email already exists."
      );
    }
    throw new HttpsError(
      "internal",
      firebaseError.message ?? "Failed to create user."
    );
  }

  // --- Set custom claims (used by Firestore security rules) ---
  await auth.setCustomUserClaims(uid, { inviteVerified: true });

  // --- Create user profile in Firestore ---
  const now = new Date().toISOString();
  await db
    .collection("users")
    .doc(uid)
    .set({
      id: uid,
      email: trimmedEmail,
      displayName: null,
      bio: null,
      phone: null,
      createdAt: now,
      updatedAt: now,
      settings: {
        themeMode: "system",
        notificationsEnabled: true,
        defaultCurrency: "EUR",
        biometricEnabled: false,
      },
    });

  // --- Delete invite code (single-use) ---
  await inviteRef.delete();

  // --- Generate custom token for client sign-in ---
  const token = await auth.createCustomToken(uid);

  return { token };
});

/**
 * Admin utility: set inviteVerified claim on an existing user.
 * Only callable by an already-verified admin user.
 *
 * Expects: { targetUid: string }
 */
export const setInviteVerifiedClaim = onCall(async (request) => {
  // Only allow authenticated users who are already invite-verified
  if (!request.auth || !request.auth.token.inviteVerified) {
    throw new HttpsError(
      "permission-denied",
      "Only verified administrators can call this function."
    );
  }

  const { targetUid } = request.data;
  if (typeof targetUid !== "string" || !targetUid.trim()) {
    throw new HttpsError("invalid-argument", "targetUid is required.");
  }

  // Check that the caller is an admin (first user or manually flagged)
  const callerRecord = await getAuth().getUser(request.auth.uid);
  if (!callerRecord.customClaims?.admin) {
    throw new HttpsError(
      "permission-denied",
      "Only admin users can set claims on other users."
    );
  }

  await getAuth().setCustomUserClaims(targetUid.trim(), {
    inviteVerified: true,
  });

  return { success: true };
});

// --- Feedback AI Summary ---

const feedbackApiKey = defineSecret("FEEDBACK_API_KEY");

/**
 * HTTP endpoint: updates a feedback document with an AI-generated summary.
 *
 * Authentication: Bearer token matching the FEEDBACK_API_KEY secret.
 *
 * POST body: { referenceId: string, summary: string }
 *
 * Searches both public (`feedback/`) and all user-private
 * (`users/{uid}/feedback/`) collections for a document whose
 * `referenceId` field matches the provided value.
 */
export const updateFeedbackSummary = onRequest(
  { secrets: [feedbackApiKey] },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({ error: "Method not allowed" });
      return;
    }

    const auth = req.headers.authorization;
    if (!auth || auth !== `Bearer ${feedbackApiKey.value()}`) {
      res.status(401).json({ error: "Unauthorized" });
      return;
    }

    const { referenceId, summary } = req.body;
    if (
      typeof referenceId !== "string" ||
      !referenceId.trim() ||
      typeof summary !== "string" ||
      !summary.trim()
    ) {
      res
        .status(400)
        .json({ error: "referenceId and summary are required strings." });
      return;
    }

    const db = getFirestore();
    const trimmedRef = referenceId.trim();
    const trimmedSummary = summary.trim();

    // Search public feedback collection first.
    const publicSnap = await db
      .collection("feedback")
      .where("referenceId", "==", trimmedRef)
      .limit(1)
      .get();

    if (!publicSnap.empty) {
      const docRef = publicSnap.docs[0].ref;
      await docRef.update({
        aiSummary: trimmedSummary,
        updatedAt: new Date().toISOString(),
      });
      res.json({ success: true, collection: "feedback", id: docRef.id });
      return;
    }

    // Search all users' private feedback collections.
    const usersSnap = await db.collection("users").get();
    for (const userDoc of usersSnap.docs) {
      const privateSnap = await userDoc.ref
        .collection("feedback")
        .where("referenceId", "==", trimmedRef)
        .limit(1)
        .get();

      if (!privateSnap.empty) {
        const docRef = privateSnap.docs[0].ref;
        await docRef.update({
          aiSummary: trimmedSummary,
          updatedAt: new Date().toISOString(),
        });
        res.json({
          success: true,
          collection: `users/${userDoc.id}/feedback`,
          id: docRef.id,
        });
        return;
      }
    }

    res.status(404).json({ error: `No feedback found with referenceId: ${trimmedRef}` });
  }
);
