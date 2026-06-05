import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../features/friends/domain/entities/friend_request.dart';
import '../features/friends/presentation/providers/friends_provider.dart';
import '../shared/web_content_box.dart';
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

    // datasource filters to pending only; also hide requests from users we are
    // already friends with (handles race where the other side accepted first).
    final displayed = state.incomingRequests
        .where((r) => !state.isFriend(r.fromUid))
        .toList();

    return Scaffold(
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
                : WebContentBox(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: displayed.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 16),
                      itemBuilder: (_, i) => _buildCard(displayed[i]),
                    ),
                  ),
          ),
        ],
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
                  onTap: () => Navigator.pop(context),
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
  Widget _buildCard(FriendRequest request) {
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
                  children: _buildButtons(request),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildButtons(FriendRequest request) {
    final notifier = ref.read(friendsNotifierProvider.notifier);
    return [
      _buildButton(
        label: 'Accept',
        backgroundColor: const Color(0xFFDEF1C2),
        borderColor: const Color(0xFFC7D2B5),
        textColor: Colors.black,
        onTap: () => notifier.acceptRequest(request),
      ),
      const SizedBox(width: 8),
      _buildButton(
        label: 'Decline',
        backgroundColor: const Color(0xFFCF5733),
        borderColor: const Color(0xFFA33615),
        textColor: Colors.white,
        onTap: () => notifier.declineRequest(request),
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
