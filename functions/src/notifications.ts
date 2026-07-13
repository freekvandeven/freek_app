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
      .collection("inventory")
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
        fcmTokens: FieldValue.arrayRemove(...invalidTokens),
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
    const summary = await runExpiryReminderCheck();
    console.log(
      `Expiry check: ${summary.usersChecked} users checked, ` +
        `${summary.notificationsSent} notifications sent.`,
    );
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

/** Today's date as YYYY-MM-DD in the Amsterdam timezone (WISH-0087). */
function todayInAmsterdam(): string {
  // en-CA formats as YYYY-MM-DD, which matches the lexicographic prefix
  // of the naive ISO strings the app stores for dates.
  return new Date().toLocaleDateString("en-CA", { timeZone: "Europe/Amsterdam" });
}

/** The day after [ymd], also as YYYY-MM-DD (for range queries). */
function nextDay(ymd: string): string {
  const d = new Date(`${ymd}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + 1);
  return d.toISOString().substring(0, 10);
}

/**
 * Core logic for the morning daily-agenda notification (WISH-0087):
 * for each user, collect the tasks due today and the calendar events
 * happening today (local app data only — events that live solely in
 * Google Calendar are not stored in Firestore and thus excluded), and
 * send a summary push. Users with nothing on their plate get no
 * notification. Returns { usersChecked, notificationsSent }.
 */
async function runDailyAgenda(): Promise<{ usersChecked: number; notificationsSent: number }> {
  const db = getFirestore();
  const messaging = getMessaging();

  const today = todayInAmsterdam();
  const tomorrow = nextDay(today);

  const usersSnap = await db.collection("users").get();
  let notificationsSent = 0;

  for (const userDoc of usersSnap.docs) {
    const userData = userDoc.data();
    const settings = userData.settings || {};
    const notificationsEnabled = settings.notificationsEnabled ?? true;
    const fcmTokens: string[] = userData.fcmTokens || [];

    if (!notificationsEnabled || fcmTokens.length === 0) continue;

    // Tasks due today. isCompleted is filtered in code so the range
    // query on dueDate doesn't need a composite index.
    const tasksSnap = await db
      .collection("users")
      .doc(userDoc.id)
      .collection("tasks")
      .where("dueDate", ">=", today)
      .where("dueDate", "<", tomorrow)
      .get();
    const taskTitles = tasksSnap.docs
      .filter((d) => d.data().isCompleted !== true)
      .map((d) => d.data().title || "Untitled task");

    // Events starting today…
    const eventsRef = db.collection("users").doc(userDoc.id).collection("calendar_events");
    const startsTodaySnap = await eventsRef
      .where("date", ">=", today)
      .where("date", "<", tomorrow)
      .get();
    // …plus multi-day events that started earlier and are still running.
    const spanningSnap = await eventsRef.where("endDate", ">=", today).get();

    const eventDocs = new Map<string, FirebaseFirestore.DocumentData>();
    for (const d of startsTodaySnap.docs) eventDocs.set(d.id, d.data());
    for (const d of spanningSnap.docs) {
      const data = d.data();
      if (typeof data.date === "string" && data.date < tomorrow) {
        eventDocs.set(d.id, data);
      }
    }
    const eventTitles = [...eventDocs.values()]
      .filter((e) => e.type !== "googleCalendar")
      .map((e) => e.title || "Untitled event");

    if (taskTitles.length === 0 && eventTitles.length === 0) continue;

    const parts: string[] = [];
    if (taskTitles.length > 0) parts.push(`Tasks: ${taskTitles.join(", ")}`);
    if (eventTitles.length > 0) parts.push(`Events: ${eventTitles.join(", ")}`);
    const body = parts.join(" · ");

    const summaryBits: string[] = [];
    if (taskTitles.length > 0) {
      summaryBits.push(`${taskTitles.length} task${taskTitles.length === 1 ? "" : "s"}`);
    }
    if (eventTitles.length > 0) {
      summaryBits.push(`${eventTitles.length} event${eventTitles.length === 1 ? "" : "s"}`);
    }
    const title = `Today: ${summaryBits.join(", ")}`;

    const invalidTokens: string[] = [];
    for (const token of fcmTokens) {
      try {
        await messaging.send({
          token,
          notification: { title, body },
          data: { type: "daily_agenda" },
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
        fcmTokens: FieldValue.arrayRemove(...invalidTokens),
      });
    }
  }

  return { usersChecked: usersSnap.size, notificationsSent };
}

/**
 * Scheduled function: runs daily at 06:00 Amsterdam time (CET/CEST
 * follows automatically). Sends each user a summary of the tasks due
 * today and today's calendar events (WISH-0087).
 */
export const dailyAgendaNotification = onSchedule(
  {
    schedule: "0 6 * * *",
    timeZone: "Europe/Amsterdam",
    region: REGION,
  },
  async () => {
    const summary = await runDailyAgenda();
    console.log(
      `Daily agenda: ${summary.usersChecked} users checked, ` +
        `${summary.notificationsSent} notifications sent.`,
    );
  },
);

/**
 * Admin-only callable function: immediately runs the daily agenda
 * notification — mirrors triggerExpiryCheck (WISH-0087).
 * Returns { usersChecked, notificationsSent }.
 */
export const triggerDailyAgenda = onCall({ region: REGION }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const callerUid = request.auth.uid;
  const auth = getAuth();
  const callerRecord = await auth.getUser(callerUid);
  if (!callerRecord.customClaims?.admin) {
    throw new HttpsError("permission-denied", "Only admin users can trigger the daily agenda.");
  }

  return await runDailyAgenda();
});
