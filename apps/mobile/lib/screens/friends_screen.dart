import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_routes.dart';
import '../models/friend.dart';
import '../shared/layered_avatar.dart';
import 'friend_profile_dialog.dart';
import 'remove_friend_dialog.dart';
import 'block_dialogs.dart';
import 'widgets.dart';

final List<Friend> _mockFriends = [
  Friend(
    name: 'Nong Prae',
    username: 'kaitom',
    lastMessage: 'Hello',
    isOnline: true,
    unreadCount: 1,
    room: const RoomInfo(
      name: 'Red Lotus Lake',
      thumbnail: 'assets/images/backgrounds/red_lotus_lake.png',
      current: 2,
      max: 2,
    ),
    avatar: 'assets/images/UserAvatar.png',
    interest: 'Cats',
  ),
  Friend(
    name: 'Somjeed',
    username: 'somjeed123',
    lastMessage: 'How are you?',
    isOnline: false,
    unreadCount: 2,
    avatar: 'assets/images/UserAvatar.png',
    interest: 'Music',
  ),
  Friend(
    name: 'Kaitom',
    username: 'kaitom99',
    lastMessage: 'See you later!',
    isOnline: true,
    unreadCount: 0,
    room: const RoomInfo(
      name: 'Lumphini Park',
      thumbnail: 'assets/images/backgrounds/lumphini_park.png',
      current: 3,
      max: 5,
      isLocked: true,
    ),
    avatar: 'assets/images/UserAvatar.png',
    interest: 'Sports',
  ),
  Friend(
    name: 'Mitsuru',
    username: 'mitsuru_m',
    lastMessage: 'Busy now',
    isOnline: true,
    unreadCount: 0,
    room: const RoomInfo(
      name: 'Sea of Cloud',
      thumbnail: 'assets/images/backgrounds/sea_of_cloud.png',
      current: 5,
      max: 5,
    ),
    avatar: 'assets/images/UserAvatar.png',
    interest: 'Art',
  ),
  Friend(
    name: 'Somying',
    username: 'somying_s',
    lastMessage: 'Come join us!',
    isOnline: true,
    unreadCount: 0,
    room: const RoomInfo(
      name: 'Kao Tapu',
      thumbnail: 'assets/images/backgrounds/kao_tapu.png',
      current: 3,
      max: 5,
    ),
    avatar: 'assets/images/UserAvatar.png',
    interest: 'Travel',
  ),
  Friend(
    name: 'Platoo',
    username: 'platoo_99',
    lastMessage: 'How are you?',
    isOnline: false,
    unreadCount: 0,
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
  late List<Friend> _friends;
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _friends = List<Friend>.from(_mockFriends);
    _searchCtrl.addListener(
      () => setState(() => _query = _searchCtrl.text.trim().toLowerCase()),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Friend> get _filtered => _query.isEmpty
      ? _friends
      : _friends
            .where(
              (f) =>
                  f.displayName.toLowerCase().contains(_query) ||
                  f.username.toLowerCase().contains(_query),
            )
            .toList();

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              itemCount: filtered.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) return _buildSearchBar();
                final friend = filtered[index - 1];
                final originalIndex = _friends.indexOf(friend);
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: _buildFriendCard(friend, originalIndex),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          SvgPicture.asset(
            'assets/images/icons/Search.svg',
            width: 18,
            height: 18,
            colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.srcIn),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Search your friends...',
                hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendCard(Friend friend, int index) {
    final showRoom = friend.room != null && friend.isOnline;
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
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, showRoom ? 8 : 16),
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
                          border: Border.all(
                            color: Colors.grey.shade200,
                            width: 1.5,
                          ),
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
                                  : const Icon(
                                      Icons.person,
                                      color: Colors.grey,
                                      size: 35,
                                    ),
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
                  // ── Actions ──
                  SizedBox(
                    height: 75,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildMoreButton(friend, index),
                        if (friend.unreadCount > 0)
                          _buildUnreadBadge(friend.unreadCount)
                        else
                          const SizedBox.shrink(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (showRoom) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: FriendRoomCard(
                  room: friend.room!,
                  onJoin: friend.room!.canJoin
                      ? () => Navigator.pushNamed(
                          context,
                          AppRoutes.groupChatScreen,
                          arguments: {
                            'roomName': friend.room!.name,
                            'bgImage': friend.room!.thumbnail,
                          },
                        )
                      : null,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

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

  Widget _buildMoreButton(Friend friend, int index) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: SvgPicture.asset(
        'assets/images/icons/ThreeDot.svg',
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
                setState(
                  () => _friends[index].note = newNote.isNotEmpty
                      ? newNote
                      : null,
                );
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
