import {onDocumentDeleted} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import {deleteSubcollection} from "../matchmaking/_utils";

export const onFriendshipDeleted = onDocumentDeleted(
  {document: "friendships/{friendshipId}", region: "us-central1"},
  async (event) => {
    const {friendshipId} = event.params;
    const db = admin.firestore();
    await deleteSubcollection(
      db,
      db.collection("friend_messages").doc(friendshipId).collection("messages"),
    );
    logger.info("Cleaned up friend messages on friendship delete", {
      friendshipId,
    });
  },
);
