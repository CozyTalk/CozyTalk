import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {FieldValue} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {
  getBlockedUids,
  isBlockedByRoom,
  mergeIntoBlockList,
  type BlockListEntry,
} from "../user/_blockUtils";

const ROOM_ID_PATTERN = /^[A-Za-z0-9]{5}$/;

export const joinRoomById = onCall(
  {invoker: "public", cors: true},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }

    const {roomId} = request.data as {roomId?: unknown};
    if (typeof roomId !== "string" || !ROOM_ID_PATTERN.test(roomId)) {
      throw new HttpsError(
        "invalid-argument",
        "roomId must be a 5-character alphanumeric string.",
      );
    }

    const uid = request.auth.uid;
    const db = admin.firestore();
    const rtdb = admin.database();
    const roomRef = db.collection("rooms").doc(roomId);

    let roomMode: string;
    let roomType: string;
    let alreadyMember = false;

    const callerBlockedUids = await getBlockedUids(db, uid);

    await db.runTransaction(async (tx) => {
      const snap = await tx.get(roomRef);
      if (!snap.exists) throw new HttpsError("not-found", "Room not found.");

      const d = snap.data()!;
      if (d.status === "expired") {
        throw new HttpsError("failed-precondition", "Room has expired.");
      }
      if (d.status === "padding") {
        throw new HttpsError(
          "failed-precondition",
          "Room is no longer available.",
        );
      }
      if (d.isLocked) {
        throw new HttpsError("failed-precondition", "Room is locked.");
      }

      roomMode = d.mode as string;
      roomType = d.roomType as string;

      if ((d.users as string[]).includes(uid)) {
        alreadyMember = true;
        return;
      }
      if (d.memberCount >= d.maxUsers) {
        throw new HttpsError("resource-exhausted", "Room is full.");
      }

      const roomBlockList = (d.blockList as BlockListEntry[] | undefined) ?? [];
      if (isBlockedByRoom(roomBlockList, uid)) {
        throw new HttpsError(
          "permission-denied",
          "You are blocked from this room.",
        );
      }
      if ((d.users as string[]).some((u) => callerBlockedUids.includes(u))) {
        throw new HttpsError(
          "permission-denied",
          "A room member is on your block list.",
        );
      }

      tx.update(roomRef, {
        users: FieldValue.arrayUnion(uid),
        memberCount: FieldValue.increment(1),
        status: "active",
        paddingUntil: null,
        blockList: mergeIntoBlockList(roomBlockList, uid, callerBlockedUids),
      });
    });

    if (!alreadyMember) {
      // Retry the RTDB write up to 3 times. The Firestore transaction has already
      // committed at this point; a permanent failure here would leave the user in
      // users[] with no RTDB entry for cleanupMember to fire on. Three fast
      // retries cover transient connectivity blips without meaningfully delaying
      // the response.
      let rtdbOk = false;
      for (let attempt = 0; attempt < 3 && !rtdbOk; attempt++) {
        try {
          await rtdb.ref(`rooms/${roomId}/members/${uid}`).set(true);
          rtdbOk = true;
        } catch (rtdbErr) {
          if (attempt === 2) {
            logger.warn("RTDB member write failed after 3 attempts", {
              uid,
              roomId,
              err: rtdbErr,
            });
          }
        }
      }
    }
    logger.info("User joined room by ID", {uid, roomId});
    return {roomId, mode: roomMode!, roomType: roomType!};
  },
);
