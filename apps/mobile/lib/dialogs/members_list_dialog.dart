import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_colors.dart';
import '../shared/avatar_overlay.dart';
import '../shared/layered_avatar.dart';
import 'report_dialog.dart';

/// The visual content of the members slide-down panel.
/// Rendered inside a Stack in GroupChatScreen so the header stays on top.
class MembersPanelBody extends StatelessWidget {
  final List<String> members;
  final VoidCallback onClose;
  final String currentUser;
  final AvatarState avatarState;
  final Map<String, bool> friendRequestSent;
  final void Function(String name) onAddFriend;
  final void Function(String name) onCancelRequest;

  const MembersPanelBody({
    super.key,
    required this.members,
    required this.onClose,
    required this.onAddFriend,
    required this.onCancelRequest,
    this.currentUser = 'Me',
    this.avatarState = const AvatarState(),
    this.friendRequestSent = const {},
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.brownDeep,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: members.map((name) => _buildRow(context, name)).toList(),
      ),
    );
  }

  Widget _buildRow(BuildContext context, String name) {
    final bool isMe = name == currentUser;
    final bool isAdded = friendRequestSent[name] == true;

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
            child: isMe
                ? LayeredAvatar(
                    boxSize: 46,
                    moodOverlay: avatarState.mood,
                    accessoryOverlay: avatarState.accessory,
                  )
                : LayeredAvatar(boxSize: 46),
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
            // Add / Cancel friend request
            GestureDetector(
              onTap: () => isAdded ? onCancelRequest(name) : onAddFriend(name),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isAdded
                      ? Colors.grey.shade300
                      : const Color(0xFFDCEBCE),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isAdded
                        ? Colors.grey.shade400
                        : const Color(0xFFC7D2B5),
                  ),
                ),
                child: Center(
                  child: SvgPicture.asset(
                    'assets/images/icons/add_friend.svg',
                    width: 22,
                    height: 22,
                    colorFilter: isAdded
                        ? ColorFilter.mode(
                            Colors.grey.shade500,
                            BlendMode.srcIn,
                          )
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Report
            GestureDetector(
              onTap: () {
                onClose();
                showDialog(
                  context: context,
                  builder: (_) => const ReportDialog(),
                );
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
