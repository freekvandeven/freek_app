import { onObjectFinalized, onObjectDeleted } from "firebase-functions/v2/storage";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { REGION } from "./common";

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
