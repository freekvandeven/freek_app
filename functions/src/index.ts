import { onCall, onRequest, HttpsError } from "firebase-functions/v2/https";
import { onObjectFinalized, onObjectDeleted } from "firebase-functions/v2/storage";
import { defineSecret } from "firebase-functions/params";
import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

initializeApp();

// Deploy all functions in europe-west4 (Netherlands).
// The storage bucket is in eur4 (dual-region: NL + Finland), so storage
// triggers must also be in a region within that dual-region.
const REGION = "europe-west4";

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
export const createUserWithInvite = onCall({ region: REGION }, async (request) => {
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
  const defaultStorageLimitBytes = 100 * 1024 * 1024; // 100 MB
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
      storageUsedBytes: 0,
      storageLimitBytes: defaultStorageLimitBytes,
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
export const setInviteVerifiedClaim = onCall({ region: REGION }, async (request) => {
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

// --- Admin: Invite Code Management ---

/**
 * Admin-only callable function: manage invite codes.
 *
 * Requires authenticated user with `inviteVerified` and `admin` custom claims.
 *
 * Actions:
 * - { action: "list" } → returns all invite codes
 * - { action: "create", code?: string } → creates a new invite code
 * - { action: "delete", code: string } → deletes an invite code
 */
export const manageInviteCodes = onCall({ region: REGION }, async (request) => {
  if (!request.auth || !request.auth.token.inviteVerified) {
    throw new HttpsError("permission-denied", "Authentication required.");
  }

  const callerRecord = await getAuth().getUser(request.auth.uid);
  if (!callerRecord.customClaims?.admin) {
    throw new HttpsError(
      "permission-denied",
      "Only admin users can manage invite codes."
    );
  }

  const { action } = request.data;
  const db = getFirestore();

  switch (action) {
    case "list": {
      const snapshot = await db.collection("inviteCodes").get();
      const codes = snapshot.docs.map((doc) => ({
        code: doc.id,
        ...doc.data(),
      }));
      return { codes };
    }

    case "create": {
      let { code } = request.data;
      if (typeof code !== "string" || !code.trim()) {
        // Generate a random 8-character alphanumeric code
        const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
        code = "";
        for (let i = 0; i < 8; i++) {
          code += chars.charAt(Math.floor(Math.random() * chars.length));
        }
      } else {
        code = code.trim();
      }

      const existing = await db.collection("inviteCodes").doc(code).get();
      if (existing.exists) {
        throw new HttpsError("already-exists", "Invite code already exists.");
      }

      await db.collection("inviteCodes").doc(code).set({
        createdAt: new Date().toISOString(),
        createdBy: request.auth.uid,
      });

      return { code };
    }

    case "delete": {
      const { code } = request.data;
      if (typeof code !== "string" || !code.trim()) {
        throw new HttpsError("invalid-argument", "code is required.");
      }

      const docRef = db.collection("inviteCodes").doc(code.trim());
      const doc = await docRef.get();
      if (!doc.exists) {
        throw new HttpsError("not-found", "Invite code not found.");
      }

      await docRef.delete();
      return { success: true };
    }

    default:
      throw new HttpsError(
        "invalid-argument",
        "Invalid action. Use 'list', 'create', or 'delete'."
      );
  }
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
  { region: REGION, secrets: [feedbackApiKey] },
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

// --- Admin: Update Storage Limit ---

/**
 * Admin-only callable function: update a user's storage limit.
 * Expects: { targetUserId: string, storageLimitBytes: number }
 */
export const updateStorageLimit = onCall({ region: REGION }, async (request) => {
  if (!request.auth || !request.auth.token.inviteVerified) {
    throw new HttpsError(
      "permission-denied",
      "Only verified users can call this function."
    );
  }

  const callerRecord = await getAuth().getUser(request.auth.uid);
  if (!callerRecord.customClaims?.admin) {
    throw new HttpsError(
      "permission-denied",
      "Only admin users can update storage limits."
    );
  }

  const { targetUserId, storageLimitBytes } = request.data;
  if (typeof targetUserId !== "string" || !targetUserId.trim()) {
    throw new HttpsError("invalid-argument", "targetUserId is required.");
  }
  if (typeof storageLimitBytes !== "number" || storageLimitBytes < 0) {
    throw new HttpsError(
      "invalid-argument",
      "storageLimitBytes must be a non-negative number."
    );
  }

  const db = getFirestore();
  const userRef = db.collection("users").doc(targetUserId.trim());
  const userDoc = await userRef.get();
  if (!userDoc.exists) {
    throw new HttpsError("not-found", "User not found.");
  }

  await userRef.update({
    storageLimitBytes: storageLimitBytes,
  });

  return { success: true, storageLimitBytes };
});

// --- Admin: Set Admin Claim ---

/**
 * Admin-only callable function: grant admin custom claim to another user.
 * Can only grant admin (set admin: true), cannot revoke.
 *
 * Expects: { targetUid: string }
 */
export const setAdminClaim = onCall({ region: REGION }, async (request) => {
  if (!request.auth || !request.auth.token.inviteVerified) {
    throw new HttpsError(
      "permission-denied",
      "Only verified users can call this function."
    );
  }

  const callerRecord = await getAuth().getUser(request.auth.uid);
  if (!callerRecord.customClaims?.admin) {
    throw new HttpsError(
      "permission-denied",
      "Only admin users can grant admin privileges."
    );
  }

  const { targetUid } = request.data;
  if (typeof targetUid !== "string" || !targetUid.trim()) {
    throw new HttpsError("invalid-argument", "targetUid is required.");
  }

  const trimmedUid = targetUid.trim();

  // Verify the target user exists
  const targetRecord = await getAuth().getUser(trimmedUid);

  // Merge admin: true into the user's existing custom claims
  const existingClaims = targetRecord.customClaims ?? {};
  await getAuth().setCustomUserClaims(trimmedUid, {
    ...existingClaims,
    admin: true,
  });

  return { success: true };
});

// --- Storage usage tracking ---

/**
 * Extracts the userId from a Storage object path.
 * Expected path: users/{userId}/...
 * Returns null if path doesn't match.
 */
function extractUserIdFromPath(filePath: string): string | null {
  const parts = filePath.split("/");
  if (parts.length >= 2 && parts[0] === "users") {
    return parts[1];
  }
  return null;
}

/**
 * Storage trigger: when a file is uploaded, increment the user's storageUsedBytes.
 */
export const onFileUploaded = onObjectFinalized({ region: REGION }, async (event) => {
  const filePath = event.data.name;
  const fileSize = Number(event.data.size);

  if (!filePath || !fileSize || fileSize <= 0) return;

  const userId = extractUserIdFromPath(filePath);
  if (!userId) return;

  const db = getFirestore();
  await db.collection("users").doc(userId).update({
    storageUsedBytes: FieldValue.increment(fileSize),
  });
});

/**
 * Storage trigger: when a file is deleted, decrement the user's storageUsedBytes.
 */
export const onFileDeleted = onObjectDeleted({ region: REGION }, async (event) => {
  const filePath = event.data.name;
  const fileSize = Number(event.data.size);

  if (!filePath || !fileSize || fileSize <= 0) return;

  const userId = extractUserIdFromPath(filePath);
  if (!userId) return;

  const db = getFirestore();
  await db.collection("users").doc(userId).update({
    storageUsedBytes: FieldValue.increment(-fileSize),
  });
});
