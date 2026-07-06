import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { REGION } from "./common";

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

// --- Admin: Check Admin Status ---

/**
 * Admin-only callable function: check whether a target user has admin privileges.
 *
 * Expects: { targetUid: string }
 * Returns: { isAdmin: boolean }
 */
export const checkAdminStatus = onCall({ region: REGION }, async (request) => {
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
      "Only admin users can check admin status."
    );
  }

  const { targetUid } = request.data;
  if (typeof targetUid !== "string" || !targetUid.trim()) {
    throw new HttpsError("invalid-argument", "targetUid is required.");
  }

  const targetRecord = await getAuth().getUser(targetUid.trim());
  return { isAdmin: targetRecord.customClaims?.admin === true };
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

  // Also flag the user as admin in their public profile for UI display
  await getFirestore()
    .collection("publicProfiles")
    .doc(trimmedUid)
    .set({ isAdmin: true }, { merge: true });

  return { success: true };
});
