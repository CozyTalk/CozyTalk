import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../features/friends/domain/entities/friend_request.dart';
import '../features/friends/presentation/providers/friends_provider.dart';
import '../theme/app_colors.dart';

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(friendsNotifierProvider);

    ref.listen<FriendsState>(friendsNotifierProvider, (_, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: Colors.red),
        );
        ref.read(friendsNotifierProvider.notifier).clearError();
      }
    });

    // incomingRequests already sorted newest-first and capped at 10 by the notifier.
    final displayed = state.incomingRequests;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        ref.read(friendsNotifierProvider.notifier).commitPendingActions();
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        body: Column(
          children: [
            _buildCustomAppBar(),
            Expanded(
              child: displayed.isEmpty
                  ? const Center(
                      child: Text(
                        'No notifications',
                        style: TextStyle(color: Colors.black54, fontSize: 15),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: displayed.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 16),
                      itemBuilder: (_, i) {
                        final req = displayed[i];
                        final action = state.pendingActions[req.id];
                        return _buildCard(req, action);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  // ─── Custom App Bar ──────────────────────────────────────────
  Widget _buildCustomAppBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.brownDeep,
        borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
      ),
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 90,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Semantics(
                label: 'Go back',
                button: true,
                child: GestureDetector(
                  onTap: () {
                    ref
                        .read(friendsNotifierProvider.notifier)
                        .commitPendingActions();
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 1.5,
                      ),
                    ),
                    child: SvgPicture.asset(
                      'assets/images/icons/Back.svg',
                      width: 26,
                      height: 26,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Notifications',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Notification Card ───────────────────────────────────────
  Widget _buildCard(FriendRequest request, String? action) {
    const imagePath = 'assets/images/icons/Friends.svg';
    final name = request.fromDisplayName.isNotEmpty
        ? request.fromDisplayName
        : 'Unknown';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 60,
            height: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
              border: Border.all(color: Colors.grey.shade200, width: 1.5),
            ),
            child: SvgPicture.asset(imagePath, width: 32, height: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '$name wants to be friends',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(request.createdAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: _buildButtons(request, action),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildButtons(FriendRequest request, String? action) {
    // 'undoing' = undo Firestore write in-flight → show Accept/Decline optimistically.
    // null + pending status = not yet touched → Accept/Decline.
    final isPending = request.status == FriendRequestStatus.pending;
    if (action == 'undoing' || (action == null && isPending)) {
      return [
        _buildButton(
          label: 'Accept',
          backgroundColor: const Color(0xFFDEF1C2),
          borderColor: const Color(0xFFC7D2B5),
          textColor: Colors.black,
          onTap: () =>
              ref.read(friendsNotifierProvider.notifier).queueAccept(request),
        ),
        const SizedBox(width: 8),
        _buildButton(
          label: 'Decline',
          backgroundColor: const Color(0xFFCF5733),
          borderColor: const Color(0xFFA33615),
          textColor: Colors.white,
          onTap: () =>
              ref.read(friendsNotifierProvider.notifier).queueDecline(request),
        ),
      ];
    }

    // Grey button: label = what was chosen (queued or committed).
    final label = action == 'accepted'
        ? 'Accept'
        : action == 'declined'
        ? 'Decline'
        : request.status == FriendRequestStatus.accepted
        ? 'Accept'
        : 'Decline';

    return [
      _buildButton(
        label: label,
        backgroundColor: Colors.grey.shade300,
        borderColor: Colors.grey.shade400,
        textColor: Colors.black54,
        onTap: () {
          final notifier = ref.read(friendsNotifierProvider.notifier);
          if (action == 'accepted' || action == 'declined') {
            // Not committed yet — undo locally.
            notifier.undoPendingAction(request.id);
          } else {
            // Already committed to Firestore — revert via Firestore.
            notifier.undoCommittedAction(request);
          }
        },
      ),
    ];
  }

  // ─── Button Widget ───────────────────────────────────────────
  Widget _buildButton({
    required String label,
    required Color backgroundColor,
    required Color textColor,
    Color? borderColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: borderColor != null
              ? Border.all(color: borderColor, width: 1.5)
              : null,
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
            color: textColor,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
