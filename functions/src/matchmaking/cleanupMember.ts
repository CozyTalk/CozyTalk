import {onValueDeleted} from "firebase-functions/v2/database";
import * as admin from "firebase-admin";
import {FieldValue, Timestamp} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {PADDING_MINUTES} from "./_utils";

export const cleanupMember = onValueDeleted(
  {
    ref: "rooms/{roomId}/members/{uid}",
    region: "asia-southeast1",
    instance: "cozytalk-5d984-default-rtdb",
  },
  async (event) => {
    const {roomId, uid} = event.params;
    const db = admin.firestore();
    const roomRef = db.collection("rooms").doc(roomId);

    let requeueUid: string | null = null;

    await db.runTransaction(async (tx) => {
      const snap = await tx.get(roomRef);
      if (!snap.exists) return;

      const data = snap.data()!;
      if (!(data.users as string[]).includes(uid)) return;

      const newCount = Math.max(0, (data.memberCount as number) - 1);
      const update: Record<string, unknown> = {
        users: FieldValue.arrayRemove(uid),
        memberCount: newCount,
      };

      if (newCount === 0) {
        update.status = "padding";
        // Preserve a shorter paddingUntil already set by leaveRoom (e.g. the
        // 30-second 1v1 window). Only write paddingUntil on a fresh transition
        // from active → padding; don't overwrite a tighter deadline.
        if (data.status !== "padding") {
          update.paddingUntil = Timestamp.fromMillis(
            Date.now() + PADDING_MINUTES * 60 * 1000,
          );
        }
      } else if (data.mode === "1v1" && newCount === 1) {
        // Partner disconnected from a 1v1 room — signal the remaining user by
        // setting padding so their app detects the state change and re-queues.
        update.status = "padding";
        update.paddingUntil = Timestamp.fromMillis(Date.now() + 30 * 1000);
        requeueUid = (data.users as string[]).find((u) => u !== uid) ?? null;
      }

      tx.update(roomRef, update);
    });

    // Re-queue the remaining 1v1 user so match1v1Users can match them again.
    if (requeueUid) {
      const rtdb = admin.database();
      // Delete first so the subsequent set() triggers onDocumentCreated,
      // firing match1v1Users immediately for the re-queued user.
      const requeueRef = db.collection("waiting_pool").doc(requeueUid);
      await requeueRef.delete();
      await requeueRef.set({
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        status: "waiting",
        mode: "1v1",
        roomId: null,
      });
      // Remove the remaining user's RTDB membership so a second cleanupMember
      // invocation decrements memberCount to 0, letting expireRooms clean up.
      await Promise.all([
        rtdb.ref(`rooms/${roomId}/members/${requeueUid}`).remove(),
        rtdb.ref(`typing/${roomId}/${requeueUid}`).remove(),
        rtdb.ref(`presence/${roomId}/${requeueUid}`).remove(),
      ]);
      logger.info("Re-queued remaining 1v1 user after partner disconnect", {
        requeueUid,
        roomId,
      });
    }

    logger.info("Cleaned up disconnected member", {uid, roomId});
  },
);
