/**
 * Script to update the appConfig/version document in Firestore.
 *
 * Usage:
 *   npx ts-node src/update-version.ts <version> [--min-required <version>] [--update-url <url>]
 *
 * Examples:
 *   npx ts-node src/update-version.ts 0.6.0
 *   npx ts-node src/update-version.ts 0.7.0 --min-required 0.5.0
 *   npx ts-node src/update-version.ts 0.7.0 --min-required 0.5.0 --update-url https://example.com/app.apk
 *
 * Prerequisites:
 *   - Run from the personal_app/functions/ directory
 *   - Authenticate via: gcloud auth application-default login
 *     OR set GOOGLE_APPLICATION_CREDENTIALS to a service account key file
 */

import { initializeApp, applicationDefault } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

function parseArgs(args: string[]): {
  version: string;
  minRequired?: string;
  updateUrl?: string;
} {
  if (args.length < 1) {
    console.error(
      "Usage: npx ts-node src/update-version.ts <version> [--min-required <version>] [--update-url <url>]"
    );
    process.exit(1);
  }

  const version = args[0];
  let minRequired: string | undefined;
  let updateUrl: string | undefined;

  for (let i = 1; i < args.length; i++) {
    if (args[i] === "--min-required" && args[i + 1]) {
      minRequired = args[++i];
    } else if (args[i] === "--update-url" && args[i + 1]) {
      updateUrl = args[++i];
    }
  }

  return { version, minRequired, updateUrl };
}

async function main() {
  const args = process.argv.slice(2);
  const { version, minRequired, updateUrl } = parseArgs(args);

  initializeApp({
    credential: applicationDefault(),
    projectId: "freek-personal-app",
  });

  const db = getFirestore();
  const docRef = db.collection("appConfig").doc("version");

  const updateData: Record<string, string> = { latest: version };
  if (minRequired) updateData.minRequired = minRequired;
  if (updateUrl) updateData.updateUrl = updateUrl;

  try {
    await docRef.set(updateData, { merge: true });
    console.log(`✅ Updated appConfig/version:`);
    console.log(`   latest: ${version}`);
    if (minRequired) console.log(`   minRequired: ${minRequired}`);
    if (updateUrl) console.log(`   updateUrl: ${updateUrl}`);
  } catch (error) {
    console.error("❌ Failed to update Firestore:", error);
    process.exit(1);
  }

  process.exit(0);
}

void main();
