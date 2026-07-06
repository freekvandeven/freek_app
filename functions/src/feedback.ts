import { onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { getFirestore } from "firebase-admin/firestore";
import { REGION } from "./common";

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

/**
 * HTTP endpoint: creates a new feedback document. Intended for use by an
 * AI assistant (e.g. Claude Code) that wants to file a bug / wish /
 * improvement directly into the user's feedback list without going
 * through the app UI.
 *
 * Authentication: Bearer token matching the FEEDBACK_API_KEY secret.
 *
 * POST body:
 *   {
 *     type:        "bug" | "wish" | "improvement",   // required
 *     title:       string,                            // required
 *     description: string,                            // required
 *     isPrivate?:  boolean,                           // defaults to false
 *     userId?:     string,                            // required when isPrivate=true
 *   }
 *
 * Generates a reference ID by scanning existing entries of the same type
 * across both public (`feedback/`) and all user-private
 * (`users/{uid}/feedback/`) collections so IDs don't collide.
 *
 * Returns: { success: true, referenceId, id, collection }
 */
export const createFeedback = onRequest(
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

    const { type, title, description, isPrivate, userId } = req.body ?? {};
    const validTypes = ["bug", "wish", "improvement"];
    if (typeof type !== "string" || !validTypes.includes(type)) {
      res.status(400).json({
        error: `type must be one of: ${validTypes.join(", ")}`,
      });
      return;
    }
    if (typeof title !== "string" || !title.trim()) {
      res.status(400).json({ error: "title is required" });
      return;
    }
    if (typeof description !== "string" || !description.trim()) {
      res.status(400).json({ error: "description is required" });
      return;
    }
    const privateFlag = isPrivate === true;
    if (privateFlag && (typeof userId !== "string" || !userId.trim())) {
      res
        .status(400)
        .json({ error: "userId is required when isPrivate is true" });
      return;
    }

    const db = getFirestore();
    const prefix =
      type === "bug" ? "BUG" : type === "improvement" ? "IMPR" : "WISH";

    // Find the highest existing reference number for this type across both
    // the public collection and every user's private collection so IDs are
    // globally unique within the type.
    let maxNum = 0;
    const scan = (snap: FirebaseFirestore.QuerySnapshot) => {
      for (const doc of snap.docs) {
        const ref = doc.data().referenceId as string | undefined;
        if (typeof ref !== "string") continue;
        const parts = ref.split("-");
        if (parts.length !== 2 || parts[0] !== prefix) continue;
        const n = parseInt(parts[1], 10);
        if (!Number.isNaN(n) && n > maxNum) maxNum = n;
      }
    };

    const publicSnap = await db
      .collection("feedback")
      .where("type", "==", type)
      .get();
    scan(publicSnap);

    const usersSnap = await db.collection("users").get();
    for (const userDoc of usersSnap.docs) {
      const privateSnap = await userDoc.ref
        .collection("feedback")
        .where("type", "==", type)
        .get();
      scan(privateSnap);
    }

    const referenceId = `${prefix}-${(maxNum + 1).toString().padStart(4, "0")}`;
    const now = new Date().toISOString();
    const docData = {
      referenceId,
      type,
      title: title.trim(),
      description: description.trim(),
      status: "open",
      isPrivate: privateFlag,
      isManual: false,
      isWip: false,
      userId: privateFlag ? userId!.trim() : null,
      attachedLogs: null,
      imageUrls: [],
      aiSummary: null,
      createdAt: now,
      updatedAt: now,
    };

    let target: FirebaseFirestore.DocumentReference;
    let collection: string;
    if (privateFlag) {
      target = db
        .collection("users")
        .doc(userId!.trim())
        .collection("feedback")
        .doc();
      collection = `users/${userId!.trim()}/feedback`;
    } else {
      target = db.collection("feedback").doc();
      collection = "feedback";
    }
    await target.set({ ...docData, id: target.id });
    res.json({
      success: true,
      referenceId,
      id: target.id,
      collection,
    });
  },
);
