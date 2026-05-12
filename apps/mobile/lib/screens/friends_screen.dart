import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_routes.dart';
import '../models/friend.dart';
import '../shared/layered_avatar.dart';
import 'friend_profile_dialog.dart';
import 'block_dialogs.dart';

// Mock friend list — swap with API response when backend is ready
final List<Friend> _mockFriends = [
  Friend(
    name: 'Nong Prae',
    username: 'kaitom',
    lastMessage: 'Hello',
    isOnline: true,
    unreadCount: 1,
    isInRoom: true,
    avatar: 'assets/images/UserAvatar.png',
    interest: 'Cats',
  ),
  Friend(
    name: 'Somjeed',
    username: 'somjeed123',
    lastMessage: 'How are you?',
    isOnline: false,
    unreadCount: 2,
    isInRoom: false,
    avatar: 'assets/images/UserAvatar.png',
    interest: 'Music',
  ),
  Friend(
    name: 'Platoo',
    username: 'platoo_99',
    lastMessage: 'How are you?',
    isOnline: false,
    unreadCount: 0,
    isInRoom: false,
    avatar: 'assets/images/UserAvatar.png',
    interest: 'Gaming',
  ),
];

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  // Local copy so edits don't mutate the global mock
  late List<Friend> _friends;

  @override
  void initState() {
    super.initState();
    _friends = List<Friend>.from(_mockFriends);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              itemCount: _friends.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) =>
                  _buildFriendCard(_friends[index], index),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Friend card ───
  Widget _buildFriendCard(Friend friend, int index) {
    return GestureDetector(
      onTap: () {
        setState(() => _friends[index].unreadCount = 0);
        Navigator.pushNamed(
          context,
          AppRoutes.friendChat,
          arguments: _friends[index],
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // ── Avatar + online dot ──
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 65,
                  height: 65,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Center(
                        child: friend.avatar.isNotEmpty
                            ? LayeredAvatar(boxSize: 48)
                            : const Icon(Icons.person, color: Colors.grey, size: 35),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -4,
                  right: -4,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: friend.isOnline
                          ? const Color(0xFF86BA73)
                          : Colors.grey.shade300,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: friend.isOnline
                            ? const Color(0xFF72A161)
                            : Colors.grey.shade400,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            // ── Name + last message ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    friend.lastMessage,
                    style: TextStyle(
                      fontSize: 14,
                      color: friend.unreadCount > 0
                          ? Colors.black
                          : Colors.grey.shade500,
                      fontWeight: friend.unreadCount > 0
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            // ── Actions: [⋯] on top, [Join][badge] below ──
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildMoreButton(friend, index),
                if (friend.isInRoom || friend.unreadCount > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (friend.isInRoom) ...[
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(
                            context,
                            AppRoutes.groupChatScreen,
                            arguments: {
                              'roomName': "${friend.name}'s Room",
                              'bgImage': 'assets/images/kao_tapu.png',
                            },
                          ),
                          child: _buildJoinButton(),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (friend.unreadCount > 0)
                        _buildUnreadBadge(friend.unreadCount),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Join pill ───
  Widget _buildJoinButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFDEF1C2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFC7D2B5), width: 1.5),
      ),
      child: const Text(
        'Join',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: Color(0xFF4A553F),
        ),
      ),
    );
  }

  // ─── Unread badge ───
  Widget _buildUnreadBadge(int count) {
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.redOrange,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFA33615), width: 1.5),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ─── Three-dot popup menu ───
  Widget _buildMoreButton(Friend friend, int index) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: SvgPicture.asset(
        'assets/images/ThreeDot.svg',
        width: 36,
        height: 36,
      ),
      color: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300, width: 1.5),
      ),
      offset: const Offset(0, 36),
      onSelected: (value) {
        switch (value) {
          case 'Edit':
            showFriendProfileDialog(
              context: context,
              friend: friend,
              onNoteSaved: (newNote) {
                setState(() => _friends[index].note = newNote.isNotEmpty ? newNote : null);
              },
            );
          case 'Block':
            showConfirmBlockDialog(
              context: context,
              username: friend.displayName,
              onConfirm: () => setState(() => _friends.removeAt(index)),
            );
          case 'Unfriend':
            showRemoveConfirmDialog(
              context: context,
              friend: friend,
              onConfirm: () => setState(() => _friends.removeAt(index)),
            );
        }
      },
      itemBuilder: (_) => [
        _popupItem('Edit'),
        _divider(),
        _popupItem('Block'),
        _divider(),
        _popupItem('Unfriend'),
      ],
    );
  }

  PopupMenuEntry<String> _divider() {
    return PopupMenuItem<String>(
      enabled: false,
      height: 1,
      padding: EdgeInsets.zero,
      child: Divider(height: 1, thickness: 1, color: Colors.grey.shade300),
    );
  }

  PopupMenuItem<String> _popupItem(String label) {
    return PopupMenuItem<String>(
      value: label,
      padding: EdgeInsets.zero,
      child: SizedBox(
        width: 110,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Header ───
  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.brownDeep,
        borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 90,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
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
                      border: Border.all(color: Colors.grey.shade300, width: 1.5),
                    ),
                    child: SvgPicture.asset('assets/images/Back.svg', width: 26, height: 26),
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Friends',
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
      ),
    );
  }
}
