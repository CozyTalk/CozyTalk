import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_colors.dart';
import '../shared/avatar_overlay.dart';
import '../shared/layered_avatar.dart';
import 'user_profile_dialog.dart' show AddFriendStatus;

/// The visual content of the members slide-down panel.
/// Rendered inside a Stack in GroupChatScreen so the header stays on top.
class MembersPanelBody extends StatelessWidget {
  final List<String> members;
  // Parallel list of UIDs matching members (null for self slot).
  final List<String?> memberUids;
  final VoidCallback onClose;
  final String currentUser;
  final AvatarState avatarState;
  // UIDs for which the current user has a pending outgoing request.
  final Set<String> pendingUids;
  // UIDs that are already friends with the current user.
  final Set<String> friendUids;
  // Called with the UID of the member to add.
  final void Function(String uid) onAddFriend;
  // Called with the UID of the member to cancel the pending request.
  final void Function(String uid) onCancelRequest;
  // Called with the UID of the member to unfriend.
  final void Function(String uid)? onUnfriend;
  // Called with the UID of the member to report.
  final void Function(String uid)? onReport;
  final Map<String, AvatarState> memberAvatarStates;

  const MembersPanelBody({
    super.key,
    required this.members,
    required this.onClose,
    required this.onAddFriend,
    required this.onCancelRequest,
    this.onUnfriend,
    this.onReport,
    this.memberUids = const [],
    this.currentUser = 'Me',
    this.avatarState = const AvatarState(),
    this.pendingUids = const {},
    this.friendUids = const {},
    this.memberAvatarStates = const {},
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.brownDeep,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          members.length,
          (i) => _buildRow(
            context,
            members[i],
            i < memberUids.length ? memberUids[i] : null,
          ),
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, String name, String? uid) {
    final bool isMe = name == currentUser;
    final AddFriendStatus status = uid == null
        ? AddFriendStatus.notAdded
        : friendUids.contains(uid)
        ? AddFriendStatus.friends
        : pendingUids.contains(uid)
        ? AddFriendStatus.pending
        : AddFriendStatus.notAdded;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LayeredAvatar(
              boxSize: 46,
              moodOverlay:
                  (memberAvatarStates[name] ??
                          (isMe ? avatarState : const AvatarState()))
                      .mood,
              accessoryOverlay:
                  (memberAvatarStates[name] ??
                          (isMe ? avatarState : const AvatarState()))
                      .accessory,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.black,
              ),
            ),
          ),
          if (!isMe) ...[
            // Add / pending (cancel) / friends (unfriend) button
            GestureDetector(
              onTap: uid == null
                  ? null
                  : switch (status) {
                      AddFriendStatus.friends =>
                        onUnfriend != null ? () => onUnfriend!(uid) : null,
                      AddFriendStatus.pending => () => onCancelRequest(uid),
                      AddFriendStatus.notAdded => () => onAddFriend(uid),
                    },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: switch (status) {
                    AddFriendStatus.notAdded => const Color(0xFFDCEBCE),
                    AddFriendStatus.pending => const Color(0xFFFFF3E0),
                    AddFriendStatus.friends => const Color(0xFFF6D4E5),
                  },
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: switch (status) {
                      AddFriendStatus.notAdded => const Color(0xFFC7D2B5),
                      AddFriendStatus.pending => const Color(0xFFFFCC80),
                      AddFriendStatus.friends => const Color(0xFFF0BFD6),
                    },
                  ),
                ),
                child: Center(
                  child: SvgPicture.asset(
                    'assets/images/icons/add_friend.svg',
                    width: 22,
                    height: 22,
                    colorFilter: switch (status) {
                      AddFriendStatus.notAdded => null,
                      AddFriendStatus.pending => const ColorFilter.mode(
                        Color(0xFFE67E22),
                        BlendMode.srcIn,
                      ),
                      AddFriendStatus.friends => const ColorFilter.mode(
                        Color(0xFFCC8AAE),
                        BlendMode.srcIn,
                      ),
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Report
            GestureDetector(
              onTap: uid == null
                  ? null
                  : () {
                      onClose();
                      onReport?.call(uid);
                    },
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFDBC8),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFA33615)),
                ),
                child: Center(
                  child: SvgPicture.asset(
                    'assets/images/icons/Report.svg',
                    width: 17,
                    height: 17,
                    colorFilter: const ColorFilter.mode(
                      Color(0xFFD4633A),
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Stub kept so any leftover import doesn't break.
class MembersListDialog extends StatelessWidget {
  const MembersListDialog({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
