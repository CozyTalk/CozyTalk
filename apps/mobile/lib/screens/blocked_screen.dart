import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/friend.dart';
import '../shared/layered_avatar.dart';
import 'friend_profile_dialog.dart';
import 'block_dialogs.dart';

class BlockedScreen extends StatefulWidget {
  const BlockedScreen({super.key});

  @override
  State<BlockedScreen> createState() => _BlockedScreenState();
}

class _BlockedScreenState extends State<BlockedScreen> {
  static const int _maxBlocked = 5;
  final List<Friend> _blocked = [
    Friend(
      name: 'Somchai',
      username: 'somchai99',
      lastMessage: '',
      isOnline: false,
      isInRoom: false,
      avatar: 'assets/images/UserAvatar.png',
      interest: '',
    ),
    Friend(
      name: 'Somying',
      username: 'somying55',
      lastMessage: '',
      isOnline: false,
      isInRoom: false,
      avatar: 'assets/images/UserAvatar.png',
      interest: '',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          _buildCustomAppBar(context),
          Padding(
            padding: const EdgeInsets.only(top: 20, right: 30, bottom: 10),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${_blocked.length}/$_maxBlocked',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
          Expanded(
            child: _blocked.isEmpty
                ? const Center(
                    child: Text(
                      'No blocked users',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _blocked.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, i) =>
                        _buildBlockedCard(context, _blocked[i], i),
                  ),
          ),
        ],
      ),
    );
  }

  // ─── Custom App Bar ───
  Widget _buildCustomAppBar(BuildContext context) {
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
              GestureDetector(
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
                    border: Border.all(color: Colors.grey.shade300, width: 1.5),
                  ),
                  child: SvgPicture.asset(
                    'assets/images/icons/Back.svg',
                    width: 26,
                    height: 26,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Blocked',
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

  // ─── Blocked User Card ───
  Widget _buildBlockedCard(BuildContext context, Friend friend, int index) {
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
        children: [
          // ── Avatar (tappable → profile dialog) ──
          GestureDetector(
            onTap: () => showFriendProfileDialog(
              context: context,
              friend: friend,
              onNoteSaved: (note) =>
                  setState(() => friend.note = note.isNotEmpty ? note : null),
            ),
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(color: Colors.grey.shade200, width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(child: LayeredAvatar(boxSize: 44)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // ── Username ──
          Expanded(
            child: Text(
              friend.displayName,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: Colors.black,
              ),
            ),
          ),
          // ── Unblock button ──
          GestureDetector(
            onTap: () => showConfirmUnblockDialog(
              context: context,
              username: friend.displayName,
              onConfirm: () => setState(() => _blocked.removeAt(index)),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFDEDEDE),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade400, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                'Unblock',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
