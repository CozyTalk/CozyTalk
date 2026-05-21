import {onDocumentCreated} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import {FieldValue} from "firebase-admin/firestore";
import * as logger from "firebase-functions/logger";
import {createRoomWithRetry, generateKey} from "./_utils";
import {
  cosineSimilarity,
  INTEREST_SIMILARITY_THRESHOLD,
  meanVector,
} from "./embeddingService";
import {getBlockedUids} from "../user/_blockUtils";

export const match1v1Users = onDocumentCreated(
  {document: "waiting_pool/{uid}", region: "asia-southeast1", minInstances: 1},
  async (event) => {
    const data = event.data?.data();
    const triggerUid = event.params.uid;

    if (!data || data.mode !== "1v1" || data.status !== "waiting") return;

    const db = admin.firestore();
    const rtdb = admin.database();

    const toVector = (v: unknown): number[] | null =>
      Array.isArray(v) ? (v as number[]) : null;

    const triggerVector = toVector(data.interestVector);

    // Expanded to 20 candidates to give interest-matching a wider field.
    const candidatesSnap = await db
      .collection("waiting_pool")
      .where("mode", "==", "1v1")
      .where("status", "==", "waiting")
      .orderBy("createdAt", "asc")
      .limit(20)
      .get();

    let candidates = candidatesSnap.docs.filter((d) => d.id !== triggerUid);

    // Filter out pairs where either party has blocked the other.
    const triggerBlockedUids = await getBlockedUids(db, triggerUid);
    const blockChecks = await Promise.all(
      candidates.map(async (c) => {
        const cBlockedUids = await getBlockedUids(db, c.id);
        return {
          doc: c,
          blocked:
            triggerBlockedUids.includes(c.id) || cBlockedUids.includes(triggerUid),
        };
      }),
    );
    candidates = blockChecks.filter((r) => !r.blocked).map((r) => r.doc);

    if (candidates.length === 0) {
      logger.debug("No 1v1 partner found yet", {triggerUid});
      return;
    }

    // Sort: interest-compatible candidates first (shuffled for fairness among
    // equal-quality matches), then remaining in original FIFO order.
    if (triggerVector) {
      const interestCandidates: typeof candidates = [];
      const remainingCandidates: typeof candidates = [];
      for (const c of candidates) {
        const cv = c.data().interestVector;
        if (
          Array.isArray(cv) &&
          cosineSimilarity(triggerVector, cv as number[]) >=
            INTEREST_SIMILARITY_THRESHOLD
        ) {
          interestCandidates.push(c);
        } else {
          remainingCandidates.push(c);
        }
      }
      interestCandidates.sort(() => Math.random() - 0.5);
      candidates = [...interestCandidates, ...remainingCandidates];
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

      // Build room interest fields if both users provided interest vectors.
      const candidateVector = toVector(candidate.data().interestVector);
      const memberInterests: Record<string, number[]> | null =
        triggerVector && candidateVector
          ? {[triggerUid]: triggerVector, [candidate.id]: candidateVector}
          : null;
      const roomInterestVector = memberInterests
        ? meanVector(Object.values(memberInterests))
        : null;

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
          ...(memberInterests ? {memberInterests, roomInterestVector} : {}),
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
      // Retry up to 3 times — the first RTDB connection in a cold emulator
      // or a transient network blip can cause the write to fail.
      {
        let lastRtdbErr: unknown;
        let wrote = false;
        for (let attempt = 0; attempt < 3; attempt++) {
          try {
            await Promise.all([
              rtdb.ref(`rooms/${roomId}/members/${triggerUid}`).set(true),
              rtdb.ref(`rooms/${roomId}/members/${candidate.id}`).set(true),
            ]);
            wrote = true;
            break;
          } catch (err) {
            lastRtdbErr = err;
            await new Promise((r) => setTimeout(r, 200 * Math.pow(2, attempt)));
          }
        }
        if (!wrote) {
          // Non-fatal: Firestore state is clean. Flutter clients call
          // registerRoomPresence() on match which sets up their own RTDB entries.
          logger.error("RTDB membership write failed after match", {
            roomId,
            triggerUid,
            candidateId: candidate.id,
            rtdbErr: lastRtdbErr,
          });
        }
      }

      logger.info("1v1 users matched", {
        triggerUid,
        candidateId: candidate.id,
        roomId,
        interestMatched: !!(triggerVector && candidateVector),
      });
      return;
    }

    logger.debug("All candidates were taken concurrently", {triggerUid});
  },
);
