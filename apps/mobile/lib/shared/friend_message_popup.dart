import 'package:flutter/material.dart';

/// Shows a slide-down notification banner when a friend sends a message.
/// Call [showFriendMessagePopup] from any screen — the overlay auto-dismisses.
void showFriendMessagePopup(
  BuildContext context, {
  required String friendName,
  required String message,
  VoidCallback? onTap,
  Duration duration = const Duration(seconds: 3),
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

  var dismissed = false;
  void dismiss() {
    if (dismissed) return;
    dismissed = true;
    ctrl.reverse().then((_) {
      entry.remove();
      ctrl.dispose();
    });
  }

  entry = OverlayEntry(
    builder: (context) => _PopupBanner(
      friendName: friendName,
      message: message,
      slideAnim: slideAnim,
      onTap: () {
        dismiss();
        onTap?.call();
      },
      onDismiss: dismiss,
    ),
  );

  overlay.insert(entry);
  ctrl.forward();

  Future.delayed(duration, () {
    if (ctrl.isAnimating || ctrl.isCompleted) dismiss();
  });
}

class _PopupBanner extends StatelessWidget {
  final String friendName;
  final String message;
  final Animation<Offset> slideAnim;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _PopupBanner({
    required this.friendName,
    required this.message,
    required this.slideAnim,
    required this.onTap,
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
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: GestureDetector(
                onTap: onTap,
                onVerticalDragEnd: (details) {
                  if (details.primaryVelocity != null &&
                      details.primaryVelocity! < -100) {
                    onDismiss();
                  }
                },
                child: Container(
                  margin: EdgeInsets.fromLTRB(16, topPad + 8, 16, 0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
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
                    children: [
                      // Avatar placeholder
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.person,
                          size: 24,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Name + message
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              friendName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              message,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
