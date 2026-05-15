import {onDocumentCreated} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import {FieldValue} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {createRoomWithRetry, generateKey} from "./_utils";

export const match1v1Users = onDocumentCreated(
  {document: "waiting_pool/{uid}", region: "asia-southeast1", minInstances: 1},
  async (event) => {
    const data = event.data?.data();
    const triggerUid = event.params.uid;

    if (!data || data.mode !== "1v1" || data.status !== "waiting") return;

    const db = admin.firestore();
    const rtdb = admin.database();

    // Find waiting partners (oldest first for fairness).
    const candidatesSnap = await db
      .collection("waiting_pool")
      .where("mode", "==", "1v1")
      .where("status", "==", "waiting")
      .orderBy("createdAt", "asc")
      .limit(6)
      .get();

    const candidates = candidatesSnap.docs.filter((d) => d.id !== triggerUid);
    if (candidates.length === 0) {
      logger.debug("No 1v1 partner found yet", {triggerUid});
      return;
    }

    for (const candidate of candidates) {
      const candidateRef = db.collection("waiting_pool").doc(candidate.id);
      const triggerRef = db.collection("waiting_pool").doc(triggerUid);

      // Phase 1: atomically claim the candidate by marking them 'matching'.
      // This prevents a concurrent trigger from also picking this candidate.
      let claimSucceeded = false;
      try {
        await db.runTransaction(async (tx) => {
          const snap = await tx.get(candidateRef);
          if (!snap.exists || snap.data()?.status !== "waiting") {
            throw new Error("CANDIDATE_UNAVAILABLE");
          }
          tx.update(candidateRef, {status: "matching"});
          claimSucceeded = true;
        });
      } catch (err) {
        logger.warn("Phase 1 claim failed, trying next candidate", {
          candidateId: candidate.id,
          err,
        });
        continue; // Candidate was taken — try next.
      }

      if (!claimSucceeded) continue;

      let roomId: string;
      try {
        // Phase 2: create the room (outside any transaction — uses atomic create()).
        roomId = await createRoomWithRetry(db, {
          roomType: "public",
          mode: "1v1",
          status: "active",
          maxUsers: 2,
          memberCount: 2,
          users: [triggerUid, candidate.id],
          isLocked: false,
          createdAt: FieldValue.serverTimestamp(),
          paddingUntil: null,
          encryptionKey: generateKey(),
        });
      } catch (e) {
        // Room creation failed — undo the claim so the candidate can be rematched.
        await candidateRef
          .update({status: "waiting"})
          .catch((err) => logger.error("Failed to undo claim", {err}));
        logger.error("Room creation failed during 1v1 match", {e});
        return;
      }

      // Phase 3: finalize both users atomically.
      try {
        await db.runTransaction(async (tx) => {
          const triggerSnap = await tx.get(triggerRef);
          const candidateSnap = await tx.get(candidateRef);

          // If the triggering user was already matched by another concurrent
          // trigger, abandon this match and clean up.
          if (!triggerSnap.exists || triggerSnap.data()?.status !== "waiting") {
            throw new Error("TRIGGER_GONE");
          }
          if (
            !candidateSnap.exists ||
            candidateSnap.data()?.status !== "matching"
          ) {
            throw new Error("CANDIDATE_GONE");
          }

          tx.update(triggerRef, {status: "matched", roomId});
          tx.update(candidateRef, {status: "matched", roomId});
        });
      } catch (e) {
        // Finalization failed — tombstone the prematurely-created room and retry.
        await db
          .collection("rooms")
          .doc(roomId)
          .set(
            {
              status: "expired",
              expiredAt: FieldValue.serverTimestamp(),
              users: [],
            },
            {merge: false},
          )
          .catch((err) =>
            logger.error("Failed to tombstone orphan room", {err}),
          );
        // Reset candidate claim so expireRooms stale-check doesn't need to.
        await candidateRef
          .update({status: "waiting"})
          .catch((err) => logger.error("Failed to reset candidate", {err}));
        logger.warn("1v1 finalization failed", {
          triggerUid,
          candidateId: candidate.id,
          e,
        });
        return;
      }

      // Write RTDB membership for both so they can stream presence/typing.
      try {
        await Promise.all([
          rtdb.ref(`rooms/${roomId}/members/${triggerUid}`).set(true),
          rtdb.ref(`rooms/${roomId}/members/${candidate.id}`).set(true),
        ]);
      } catch (rtdbErr) {
        // Non-fatal: Firestore state is clean. Flutter clients call
        // registerRoomPresence() on match which sets up their own RTDB entries.
        logger.error("RTDB membership write failed after match — clients will self-heal", {
          roomId,
          triggerUid,
          candidateId: candidate.id,
          rtdbErr,
        });
      }

      logger.info("1v1 users matched", {
        triggerUid,
        candidateId: candidate.id,
        roomId,
      });
      return;
    }

    logger.debug("All candidates were taken concurrently", {triggerUid});
  },
);
