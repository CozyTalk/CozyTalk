/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

import {setGlobalOptions} from "firebase-functions/v2";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";

admin.initializeApp();

setGlobalOptions({maxInstances: 10});

export {sendMessage} from "./chat/sendMessage";
export {endSession} from "./chat/endSession";
export {reportSession} from "./chat/reportSession";
// setTyping: no Cloud Function — clients write directly to RTDB.

// ── ONE-TIME SETUP: remove after TTL policy is configured ───────────────────
export {seedTtlCollections} from "./dev/seedTtlCollections";

export const helloWorld = onCall({invoker: "public"}, (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const input = request.data?.message;
  if (typeof input !== "string" || input.trim() === "") {
    throw new HttpsError(
      "invalid-argument",
      "A non-empty message string is required.",
    );
  }
  logger.info("Echo request", {message: input, structuredData: true});
  return {message: input};
});
