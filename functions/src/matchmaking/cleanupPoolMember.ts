import {onValueDeleted} from "firebase-functions/v2/database";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

export const cleanupPoolMember = onValueDeleted(
  {
    ref: "pool_presence/{uid}",
    region: "asia-southeast1",
    instance: "cozytalk-5d984-default-rtdb",
  },
  async (event) => {
    const {uid} = event.params;
    const poolRef = admin.firestore().collection("waiting_pool").doc(uid);
    const snap = await poolRef.get();
    if (!snap.exists || snap.data()?.status !== "waiting") return;
    await poolRef.delete();
    logger.info("Pool entry cleaned up on disconnect", {uid});
  },
);
