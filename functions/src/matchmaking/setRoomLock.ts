import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

export const setRoomLock = onCall(
  {invoker: "public", cors: true},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }

    const {roomId, isLocked} = request.data as {
      roomId?: unknown;
      isLocked?: unknown;
    };

    if (typeof roomId !== "string" || roomId.length === 0) {
      throw new HttpsError("invalid-argument", "roomId is required.");
    }
    if (roomId.includes("/")) {
      throw new HttpsError("invalid-argument", "Invalid roomId.");
    }
    if (typeof isLocked !== "boolean") {
      throw new HttpsError("invalid-argument", "isLocked must be a boolean.");
    }

    const uid = request.auth.uid;
    const db = admin.firestore();
    const roomRef = db.collection("rooms").doc(roomId);

    const roomSnap = await roomRef.get();
    if (!roomSnap.exists) {
      throw new HttpsError("not-found", "Room not found.");
    }

    const data = roomSnap.data()!;
    if (data.status === "expired") {
      throw new HttpsError("failed-precondition", "Room has expired.");
    }
    if (data.roomType !== "custom") {
      throw new HttpsError(
        "failed-precondition",
        "Only custom rooms can be locked.",
      );
    }
    if (!(data.users as string[]).includes(uid)) {
      throw new HttpsError(
        "permission-denied",
        "Must be a room member to change lock state.",
      );
    }

    await roomRef.update({isLocked});
    logger.info("Room lock toggled", {uid, roomId, isLocked});
    return {success: true};
  },
);
