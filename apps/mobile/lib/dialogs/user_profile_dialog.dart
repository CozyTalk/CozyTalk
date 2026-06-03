import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/avatar/presentation/providers/avatar_decoration_provider.dart';
import '../features/profile/presentation/providers/profile_provider.dart';
import '../shared/avatar_overlay.dart';
import '../shared/layered_avatar.dart';

enum AddFriendStatus { notAdded, pending, friends }

class UserProfileDialog extends ConsumerStatefulWidget {
  final String username;
  final String? interest;
  final bool isMe;
  final AddFriendStatus friendStatus;
  final VoidCallback? onAddFriend;
  final VoidCallback? onCancelRequest;
  final VoidCallback? onUnfriend;

  /// Called after the dialog is closed when the user taps Report.
  /// If null, falls back to the design-only ReportDialog.
  final VoidCallback? onReport;

  /// Pre-resolved avatar overlays for this user.
  final AvatarState? avatarState;

  /// UID of the user being displayed. When provided the dialog watches
  /// [profileByUidProvider] and [avatarDecorationByUidProvider] directly.
  final String? uid;

  // Partner-only fields — shown when isMe is false.
  final AvatarOverlay? partnerMoodOverlay;
  final AvatarOverlay? partnerAccessoryOverlay;
  final String? partnerInterest;
  // Required to submit a report — omit when isMe is true or sessionId unknown.
  final String? sessionId;
  final String? reportedUserId;

  const UserProfileDialog({
    super.key,
    required this.username,
    this.interest,
    this.isMe = false,
    this.friendStatus = AddFriendStatus.notAdded,
    this.onAddFriend,
    this.onCancelRequest,
    this.onUnfriend,
    this.onReport,
    this.avatarState,
    this.uid,
    this.partnerMoodOverlay,
    this.partnerAccessoryOverlay,
    this.partnerInterest,
    this.sessionId,
    this.reportedUserId,
  });

  @override
  ConsumerState<UserProfileDialog> createState() => _UserProfileDialogState();
}

class _UserProfileDialogState extends ConsumerState<UserProfileDialog> {
  @override
  Widget build(BuildContext context) {
    // ── Own user ──────────────────────────────────────────────────────────────
    // profileNotifierProvider is always primed by initState before any tap.
    // updateDisplayName writes Firestore only — Firebase Auth displayName is
    // stale after a rename and null for anonymous users.
    final ownProfileName = widget.isMe
        ? (ref.watch(profileNotifierProvider).profile?.displayName ?? '')
        : '';
    final myDisplayName = ownProfileName.isNotEmpty
        ? ownProfileName
        : (ref.watch(authNotifierProvider).user?.displayName ?? '');

    // ── Other user ────────────────────────────────────────────────────────────
    // When a uid is provided, watch the per-uid providers directly so the
    // dialog is self-sufficient regardless of whether the caller pre-loaded the
    // data. Falls back to the caller-supplied fields if uid is absent.
    final otherProfile = (!widget.isMe && widget.uid != null)
        ? ref.watch(profileByUidProvider(widget.uid!)).asData?.value
        : null;
    final otherDeco = (!widget.isMe && widget.uid != null)
        ? ref.watch(avatarDecorationByUidProvider(widget.uid!)).asData?.value
        : null;

    final resolvedUsername = widget.isMe
        ? (widget.username.isNotEmpty ? widget.username : myDisplayName)
        : (otherProfile?.displayName?.isNotEmpty == true
              ? otherProfile!.displayName!
              : widget.username);
    final resolvedInterest = widget.isMe
        ? widget.interest
        : (otherProfile?.interest?.isNotEmpty == true
              ? otherProfile!.interest
              : widget.interest);

    // ── Avatar overlays ───────────────────────────────────────────────────────
    // Use the caller-supplied AvatarState when available. Fall back to the
    // singleton notifier for own user (avatar-dress-up screen live source of
    // truth), or to the per-uid decoration for other users.
    final AvatarState resolvedAvatar;
    if (widget.avatarState != null) {
      resolvedAvatar = widget.avatarState!;
    } else if (widget.isMe) {
      final decoState = ref.watch(avatarDecorationNotifierProvider);
      resolvedAvatar = AvatarState(
        mood: AvatarOverlays.mood[decoState.decoration?.moodKey ?? ''],
        accessory: AvatarOverlays.accessory[decoState.decoration?.hatKey ?? ''],
      );
    } else if (otherDeco != null) {
      resolvedAvatar = AvatarState(
        mood: AvatarOverlays.mood[otherDeco.moodKey ?? ''],
        accessory: AvatarOverlays.accessory[otherDeco.hatKey ?? ''],
      );
    } else {
      resolvedAvatar = const AvatarState();
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 20,
              spreadRadius: 0,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Content row with close button ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Left column: avatar + action buttons ──
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Avatar
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(17),
                          child: LayeredAvatar(
                            boxSize: 100,
                            moodOverlay: resolvedAvatar.mood,
                            accessoryOverlay: resolvedAvatar.accessory,
                          ),
                        ),
                      ),
                      // Action buttons (only for others)
                      if (!widget.isMe) ...[
                        const SizedBox(height: 14),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Add friend / pending (cancel) / friends (unfriend)
                            Semantics(
                              label: switch (widget.friendStatus) {
                                AddFriendStatus.notAdded => 'Add friend',
                                AddFriendStatus.pending =>
                                  'Cancel friend request',
                                AddFriendStatus.friends => 'Remove friend',
                              },
                              button: true,
                              child: GestureDetector(
                                onTap: switch (widget.friendStatus) {
                                  AddFriendStatus.friends =>
                                    widget.onUnfriend != null
                                        ? () {
                                            Navigator.pop(context);
                                            widget.onUnfriend!();
                                          }
                                        : null,
                                  AddFriendStatus.pending => () {
                                    Navigator.pop(context);
                                    widget.onCancelRequest?.call();
                                  },
                                  AddFriendStatus.notAdded => () {
                                    Navigator.pop(context);
                                    widget.onAddFriend?.call();
                                  },
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: switch (widget.friendStatus) {
                                      AddFriendStatus.notAdded => const Color(
                                        0xFFDCEBCE,
                                      ),
                                      AddFriendStatus.pending => const Color(
                                        0xFFFFF3E0,
                                      ),
                                      AddFriendStatus.friends => const Color(
                                        0xFFFFEBEE,
                                      ),
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: switch (widget.friendStatus) {
                                        AddFriendStatus.notAdded => const Color(
                                          0xFFC7D2B5,
                                        ),
                                        AddFriendStatus.pending => const Color(
                                          0xFFFFCC80,
                                        ),
                                        AddFriendStatus.friends => const Color(
                                          0xFFFFCDD2,
                                        ),
                                      },
                                      width: 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: SvgPicture.asset(
                                      'assets/images/icons/add_friend.svg',
                                      width: 24,
                                      height: 24,
                                      colorFilter:
                                          switch (widget.friendStatus) {
                                            AddFriendStatus.notAdded => null,
                                            AddFriendStatus.pending =>
                                              const ColorFilter.mode(
                                                Color(0xFFE67E22),
                                                BlendMode.srcIn,
                                              ),
                                            AddFriendStatus.friends =>
                                              const ColorFilter.mode(
                                                Color(0xFFCF5733),
                                                BlendMode.srcIn,
                                              ),
                                          },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Report
                            GestureDetector(
                              onTap: widget.onReport == null
                                  ? null
                                  : () {
                                      Navigator.pop(context);
                                      widget.onReport!();
                                    },
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFDBC8),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFA33615),
                                    width: 1,
                                  ),
                                ),
                                child: Center(
                                  child: SvgPicture.asset(
                                    'assets/images/icons/Report.svg',
                                    width: 20,
                                    height: 20,
                                    colorFilter: const ColorFilter.mode(
                                      Color(0xFFD4633A),
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(width: 18),
                  // ── Right column: info + close button ──
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Username row with close button
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Expanded(
                              child: Text(
                                'Username',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: const Icon(
                                Icons.close,
                                size: 28,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          resolvedUsername.isNotEmpty
                              ? resolvedUsername
                              : myDisplayName,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Interest',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          resolvedInterest?.isNotEmpty == true
                              ? resolvedInterest!
                              : 'No interest set yet.',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
