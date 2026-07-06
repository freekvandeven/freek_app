import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { REGION } from "./common";

/**
 * Core logic for sending expiry reminder notifications to all users.
 * Returns a summary { usersChecked, notificationsSent }.
 */
async function runExpiryReminderCheck(): Promise<{ usersChecked: number; notificationsSent: number }> {
  const db = getFirestore();
  const messaging = getMessaging();

  const usersSnap = await db.collection("users").get();
  let notificationsSent = 0;

  for (const userDoc of usersSnap.docs) {
    const userData = userDoc.data();
    const settings = userData.settings || {};
    const notificationsEnabled = settings.notificationsEnabled ?? true;
    const fcmTokens: string[] = userData.fcmTokens || [];
    const reminderDays: number[] = settings.expiryReminderDays || [7, 1];

    if (!notificationsEnabled || fcmTokens.length === 0 || reminderDays.length === 0) {
      continue;
    }

    const inventorySnap = await db
      .collection("users")
      .doc(userDoc.id)
      .collection("inventoryItems")
      .where("expiryDate", "!=", null)
      .get();

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const expiringItems: { name: string; daysLeft: number }[] = [];

    for (const itemDoc of inventorySnap.docs) {
      const item = itemDoc.data();
      if (!item.expiryDate) continue;

      const expiryDate = new Date(item.expiryDate);
      expiryDate.setHours(0, 0, 0, 0);
      const diffMs = expiryDate.getTime() - today.getTime();
      const daysLeft = Math.ceil(diffMs / (1000 * 60 * 60 * 24));

      if (reminderDays.includes(daysLeft)) {
        expiringItems.push({ name: item.name || "Unknown item", daysLeft });
      }
    }

    if (expiringItems.length === 0) continue;

    const itemList = expiringItems
      .map((i) =>
        i.daysLeft === 0
          ? `${i.name} expires today`
          : i.daysLeft === 1
            ? `${i.name} expires tomorrow`
            : `${i.name} expires in ${i.daysLeft} days`,
      )
      .join(", ");

    const title =
      expiringItems.length === 1
        ? "Item expiring soon"
        : `${expiringItems.length} items expiring soon`;

    const invalidTokens: string[] = [];
    for (const token of fcmTokens) {
      try {
        await messaging.send({
          token,
          notification: { title, body: itemList },
          data: { type: "expiry_reminder" },
        });
        notificationsSent++;
      } catch (err: unknown) {
        const error = err as { code?: string };
        if (
          error.code === "messaging/registration-token-not-registered" ||
          error.code === "messaging/invalid-registration-token"
        ) {
          invalidTokens.push(token);
        }
      }
    }

    if (invalidTokens.length > 0) {
      await userDoc.ref.update({
        fcmTokens: FieldValue.arrayRemove(invalidTokens),
      });
    }
  }

  return { usersChecked: usersSnap.size, notificationsSent };
}

/**
 * Scheduled function: runs daily at 08:00 CET.
 * Checks each user's inventory items for approaching expiry dates and
 * sends push notifications based on their expiryReminderDays settings.
 */
export const checkExpiryReminders = onSchedule(
  {
    schedule: "0 8 * * *",
    timeZone: "Europe/Amsterdam",
    region: REGION,
  },
  async () => {
    await runExpiryReminderCheck();
  },
);

/**
 * Admin-only callable function: immediately runs the expiry reminder check.
 * Used from the admin panel to verify the notification pipeline is working.
 * Returns { usersChecked, notificationsSent }.
 */
export const triggerExpiryCheck = onCall({ region: REGION }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const callerUid = request.auth.uid;
  const auth = getAuth();
  const callerRecord = await auth.getUser(callerUid);
  if (!callerRecord.customClaims?.admin) {
    throw new HttpsError("permission-denied", "Only admin users can trigger expiry checks.");
  }

  return await runExpiryReminderCheck();
});
