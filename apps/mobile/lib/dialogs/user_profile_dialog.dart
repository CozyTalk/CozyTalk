import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/avatar/presentation/providers/avatar_decoration_provider.dart';
import '../shared/avatar_overlay.dart';
import '../shared/layered_avatar.dart';
import 'report_dialog.dart';

class UserProfileDialog extends ConsumerStatefulWidget {
  final String username;
  final bool isMe;
  final bool initialAdded;
  final VoidCallback? onAddFriend;
  final VoidCallback? onCancelRequest;
  const UserProfileDialog({
    super.key,
    required this.username,
    this.isMe = false,
    this.initialAdded = false,
    this.onAddFriend,
    this.onCancelRequest,
  });

  @override
  ConsumerState<UserProfileDialog> createState() => _UserProfileDialogState();
}

class _UserProfileDialogState extends ConsumerState<UserProfileDialog> {
  late bool _friendAdded;

  @override
  void initState() {
    super.initState();
    _friendAdded = widget.initialAdded;
  }

  @override
  Widget build(BuildContext context) {
    final myDisplayName =
        ref.watch(authNotifierProvider).user?.displayName ?? '';
    final decoState = ref.watch(avatarDecorationNotifierProvider);
    final moodOverlay =
        AvatarOverlays.mood[decoState.decoration?.moodKey ?? ''];
    final accessoryOverlay =
        AvatarOverlays.accessory[decoState.decoration?.hatKey ?? ''];

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
                            moodOverlay: widget.isMe ? moodOverlay : null,
                            accessoryOverlay: widget.isMe
                                ? accessoryOverlay
                                : null,
                          ),
                        ),
                      ),
                      // Action buttons (only for others)
                      if (!widget.isMe) ...[
                        const SizedBox(height: 14),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Add friend / cancel request
                            GestureDetector(
                              onTap: _friendAdded
                                  ? () {
                                      Navigator.pop(context);
                                      widget.onCancelRequest?.call();
                                    }
                                  : () {
                                      setState(() => _friendAdded = true);
                                      Navigator.pop(context);
                                      widget.onAddFriend?.call();
                                    },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: _friendAdded
                                      ? Colors.grey.shade200
                                      : const Color(0xFFDCEBCE),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _friendAdded
                                        ? Colors.grey.shade400
                                        : const Color(0xFFC7D2B5),
                                    width: 1,
                                  ),
                                ),
                                child: Center(
                                  child: SvgPicture.asset(
                                    'assets/images/icons/add_friend.svg',
                                    width: 24,
                                    height: 24,
                                    colorFilter: _friendAdded
                                        ? ColorFilter.mode(
                                            Colors.grey.shade500,
                                            BlendMode.srcIn,
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Report
                            GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                                showDialog(
                                  context: context,
                                  builder: (_) => const ReportDialog(),
                                );
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
                          widget.isMe ? myDisplayName : widget.username,
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
                          // TODO: pass real interest as param once self/partner profile loading is separated
                          'No interest set yet.',
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
