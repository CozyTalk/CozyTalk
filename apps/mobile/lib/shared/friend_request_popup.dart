import 'package:flutter/material.dart';

/// Shows a slide-down friend request banner with Accept / Decline buttons.
/// Does not auto-dismiss — the user must take action or swipe up.
void showFriendRequestPopup(
  BuildContext context, {
  required String requesterName,
  VoidCallback? onAccept,
  VoidCallback? onDecline,
}) {
  final overlay = Overlay.of(context);
  late final OverlayEntry entry;
  late final AnimationController ctrl;

  ctrl = AnimationController(
    vsync: overlay,
    duration: const Duration(milliseconds: 300),
  );

  final slideAnim = Tween<Offset>(
    begin: const Offset(0, -1),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOutCubic));

  void dismiss() {
    if (!ctrl.isAnimating) {
      ctrl.reverse().then((_) {
        entry.remove();
        ctrl.dispose();
      });
    }
  }

  entry = OverlayEntry(
    builder: (_) => _FriendRequestBanner(
      requesterName: requesterName,
      slideAnim: slideAnim,
      onAccept: () {
        dismiss();
        onAccept?.call();
      },
      onDecline: () {
        dismiss();
        onDecline?.call();
      },
      onDismiss: dismiss,
    ),
  );

  overlay.insert(entry);
  ctrl.forward();
}

class _FriendRequestBanner extends StatelessWidget {
  final String requesterName;
  final Animation<Offset> slideAnim;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onDismiss;

  const _FriendRequestBanner({
    required this.requesterName,
    required this.slideAnim,
    required this.onAccept,
    required this.onDecline,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: slideAnim,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onVerticalDragEnd: (d) {
              if ((d.primaryVelocity ?? 0) < -100) onDismiss();
            },
            child: Container(
              margin: EdgeInsets.fromLTRB(16, topPad + 8, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300, width: 1),
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 24,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          requesterName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'wants to add you as a friend',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Accept
                  _actionBtn(
                    label: 'Accept',
                    bg: const Color(0xFFDEF1C2),
                    border: const Color(0xFFC7D2B5),
                    fg: Colors.black,
                    onTap: onAccept,
                  ),
                  const SizedBox(width: 8),
                  // Decline
                  _actionBtn(
                    label: 'Decline',
                    bg: const Color(0xFFCF5733),
                    border: const Color(0xFFA33615),
                    fg: Colors.white,
                    onTap: onDecline,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionBtn({
    required String label,
    required Color bg,
    required Color fg,
    required Color border,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: fg,
          ),
        ),
      ),
    );
  }
}
