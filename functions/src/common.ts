import { initializeApp } from "firebase-admin/app";

// Initialize the Admin SDK exactly once for the whole functions codebase.
// Every domain module imports from here, so this runs before any handler
// executes regardless of which function is invoked.
initializeApp();

// Deploy all functions in europe-west4 (Netherlands).
// The storage bucket is in eur4 (dual-region: NL + Finland), so storage
// triggers must also be in a region within that dual-region.
export const REGION = "europe-west4";
