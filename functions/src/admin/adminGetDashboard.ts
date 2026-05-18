import {onCall} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import {requireAdmin} from "./_utils";

/**
 * Returns aggregate stats for the admin dashboard header.
 * @return {{ pendingReports: number, onlineUsers: number, bannedUsers: number }}
 */
export const adminGetDashboard = onCall(
  {invoker: "public", cors: true},
  async (request) => {
    await requireAdmin(request);

    const db = admin.firestore();
    const rtdb = admin.database();

    const [pendingSnap, bannedSnap, poolSnap, activeRoomsSnap] =
      await Promise.all([
        db.collection("reports").where("status", "==", "pending").count().get(),
        db.collection("users").where("banned", "==", true).count().get(),
        rtdb.ref("pool_presence").once("value"),
        db.collection("rooms").where("status", "==", "active").get(),
      ]);

    const pendingReports = pendingSnap.data().count;
    const bannedUsers = bannedSnap.data().count;

    const onlineUids = new Set<string>();
    if (poolSnap.exists()) {
      const pool = poolSnap.val() as Record<string, unknown>;
      Object.keys(pool).forEach((uid) => onlineUids.add(uid));
    }
    for (const roomDoc of activeRoomsSnap.docs) {
      const users = roomDoc.data().users as string[] | undefined;
      if (Array.isArray(users)) {
        users.forEach((uid) => onlineUids.add(uid));
      }
    }
    const onlineUsers = onlineUids.size;

    logger.info("adminGetDashboard", {pendingReports, onlineUsers, bannedUsers});
    return {pendingReports, onlineUsers, bannedUsers};
  },
);
