import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_colors.dart';
import '../dialogs/leave_room_dialog.dart';
import '../dialogs/song_dialog.dart';
import '../dialogs/user_profile_dialog.dart';
import '../shared/avatar_overlay.dart';
import '../shared/layered_avatar.dart';
import '../shared/press_bounce_btn.dart';
import '../shared/user_profile.dart';
import '../shared/friend_message_popup.dart';
import '../theme/app_routes.dart';
import '../models/friend.dart';
import '../shared/gif_picker.dart';

// ── Card assets ────────────────────────────────────────────────────────────
const _cardAssets = [
  'assets/images/cards/card1.png',
  'assets/images/cards/card2.png',
  'assets/images/cards/card3.png',
  'assets/images/cards/card4.png',
  'assets/images/cards/card5.png',
  'assets/images/cards/card6.png',
];

String _pickCard() => _cardAssets[Random().nextInt(_cardAssets.length)];

String _nowTime() {
  final t = TimeOfDay.fromDateTime(DateTime.now());
  final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.period.name}';
}

// ── Message model ──────────────────────────────────────────────────────────
class ChatMessage {
  final String type; // 'warning' | 'system' | 'me' | 'other' | 'card' | 'gif'
  final String text; // for 'card' = asset image path
  final String? time;
  ChatMessage({required this.type, required this.text, this.time});
}

// ── Screen ─────────────────────────────────────────────────────────────────
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _isOtherTyping = false;
  final bool _isBlocked = false;
  Timer? _typingTimer;
  Timer? _friendMsgTimer;

  // ── Song panel animation ──
  bool _songPanelOpen = false;
  late final AnimationController _songCtrl;
  late final Animation<Offset> _songSlide;

  String friendMood = 'I love TikTok very much.';

  final List<ChatMessage> messages = [
    ChatMessage(
      type: 'warning',
      text:
          'Keep it friendly! Please be respectful and protect your personal info.\nReport any suspicious behavior to help keep our community safe.',
    ),
    ChatMessage(type: 'system', text: 'Kaitom Hop in', time: '27 April 2026'),
    ChatMessage(type: 'other', text: 'Hello.', time: '10:00 pm'),
    ChatMessage(type: 'me', text: 'Hello 🍪🙏🔥😣', time: '10:00 pm'),
  ];

  @override
  void initState() {
    super.initState();
    _songCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _songSlide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _songCtrl, curve: Curves.easeOutCubic));
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    // Mock: friend sends a message after 3 seconds
    _friendMsgTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      showFriendMessagePopup(
        context,
        friendName: 'Nong Prae',
        message: 'Hey! Are you free tonight? 🍕',
        onTap: () => _showLeaveForFriendChat(),
      );
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _friendMsgTimer?.cancel();
    _songCtrl.dispose();
    _msgController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _openSongPanel() {
    setState(() => _songPanelOpen = true);
    _songCtrl.forward();
  }

  void _closeSongPanel() {
    _songCtrl.reverse().then((_) {
      if (mounted) setState(() => _songPanelOpen = false);
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      });
    });
    // Correct position after images/layout settle — jumpTo avoids conflicting with animateTo
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted || !_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      if (_scrollController.offset < max - 5) {
        _scrollController.jumpTo(max);
      }
    });
  }

  void _sendMessage() {
    if (_msgController.text.trim().isEmpty) return;
    setState(() {
      messages.add(
        ChatMessage(
          type: 'me',
          text: _msgController.text.trim(),
          time: _nowTime(),
        ),
      );
      _isOtherTyping = true;
    });
    _msgController.clear();
    _focusNode.requestFocus();
    _scrollToBottom();
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isOtherTyping = false);
    });
  }

  void _sendTopicCard() {
    setState(() {
      messages.add(ChatMessage(type: 'card', text: _pickCard()));
    });
    _scrollToBottom();
  }

  void _sendGif(String label) {
    setState(() {
      messages.add(ChatMessage(type: 'gif', text: label, time: _nowTime()));
    });
    _scrollToBottom();
  }

  void _shuffleTopic() {
    setState(() {
      messages.add(
        ChatMessage(type: 'system', text: 'Kaitom, shuffle the topics!'),
      );
      messages.add(ChatMessage(type: 'card', text: _pickCard()));
    });
    _scrollToBottom();
  }

  void _onWillPop() {
    showDialog(context: context, builder: (_) => const LeaveRoomDialog());
  }

  void _showLeaveForFriendChat() {
    final mockFriend = Friend(
      name: 'Nong Prae',
      username: 'kaitom',
      lastMessage: 'Hey! Are you free tonight? 🍕',
      isOnline: true,
      avatar: 'assets/images/UserAvatar.png',
      interest: 'Cats',
    );
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.white,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Leave this room?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'You will leave this room and won\'t\nbe able to come back.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.3,
                  color: Colors.black87,
                  decoration: TextDecoration.none,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogCtx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD9D5D1),
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: const BorderSide(color: Color(0xFFC8C3BE)),
                          ),
                        ),
                        child: const Text(
                          'Stay',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(dialogCtx);
                          // Clear stack back to home, then push Friends → Friend Chat
                          Navigator.popUntil(context, (route) => route.isFirst);
                          Navigator.pushNamed(context, AppRoutes.friends);
                          Navigator.pushNamed(
                            context,
                            AppRoutes.friendChat,
                            arguments: mockFriend,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD86A3B),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text(
                          'Leave',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
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

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final roomName = args?['roomName'] as String? ?? 'Red Lotus Lake';
    final roomId = args?['roomId'] as String? ?? 'AWD3V';
    final bgImage =
        args?['bgImage'] as String? ??
        'assets/images/backgrounds/red_lotus_lake.png';
    final blocked = args?['isBlocked'] as bool? ?? _isBlocked;

    final avatarState = ref.watch(avatarProvider);
    final userProfile = ref.watch(userProfileProvider);
    final myMood = userProfile.thought.isNotEmpty
        ? userProfile.thought
        : 'Care to share?';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _onWillPop();
      },
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        body: Column(
          children: [
            _buildHeader(roomName, roomId),
            Expanded(
              child: ClipRect(
                child: Stack(
                  children: [
                    // Main content
                    Column(
                      children: [
                        _buildBanner(
                          bgImage,
                          avatarState,
                          myMood,
                          userProfile.username,
                        ),
                        Expanded(
                          child: Stack(
                            children: [
                              _buildMessageList(avatarState),
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: IgnorePointer(
                                  child: Container(
                                    height: 18,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.black.withValues(alpha: 0.13),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        blocked ? _buildBlockedBar() : _buildInputBar(),
                      ],
                    ),
                    // Barrier
                    if (_songPanelOpen)
                      GestureDetector(
                        onTap: _closeSongPanel,
                        behavior: HitTestBehavior.opaque,
                        child: Container(color: Colors.black26),
                      ),
                    // Slide-down song panel
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SlideTransition(
                        position: _songSlide,
                        child: SongPanelBody(onClose: _closeSongPanel),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(String roomName, String roomId) {
    return Container(
      width: double.infinity,
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _headerBtn(
                  onTap: _onWillPop,
                  child: SvgPicture.asset(
                    'assets/images/icons/Back.svg',
                    width: 24,
                    height: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        roomName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Room ID:   $roomId',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _headerBtn({required Widget child, required VoidCallback onTap}) {
    return PressBounceBtn(
      onTap: onTap,
      scale: 0.90,
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
        ),
        child: child,
      ),
    );
  }

  // ── Banner ────────────────────────────────────────────────────────────────
  Widget _buildBanner(
    String bgImage,
    AvatarState avatarState,
    String myMood,
    String myUsername,
  ) {
    return SizedBox(
      height: 250,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              bgImage,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(color: Colors.grey.shade400),
            ),
          ),
          // Avatars — shifted left to avoid Song/Topic buttons
          Positioned(
            bottom: 0,
            left: 0,
            right: 70,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _StaticAvatar(
                  username: 'kaitom',
                  moodText: friendMood,
                  isMe: false,
                ),
                const SizedBox(width: 20),
                _StaticAvatar(
                  username: myUsername,
                  moodText: myMood,
                  isMe: true,
                  avatarState: avatarState,
                ),
              ],
            ),
          ),
          // Side buttons
          Positioned(
            bottom: 10,
            right: 10,
            child: Column(
              children: [
                _sideBtn(
                  'Song',
                  'assets/images/icons/song.svg',
                  _openSongPanel,
                ),
                const SizedBox(height: 10),
                _sideBtn(
                  'Topic',
                  'assets/images/icons/card.svg',
                  _sendTopicCard,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sideBtn(String label, String svgPath, VoidCallback onTap) {
    return PressBounceBtn(
      onTap: onTap,
      child: Container(
        width: 60,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
            ),
          ],
        ),
        child: Column(
          children: [
            SvgPicture.asset(svgPath, width: 26, height: 26),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // ── Message list ──────────────────────────────────────────────────────────
  Widget _buildMessageList(AvatarState avatarState) {
    final itemCount = messages.length + (_isOtherTyping ? 1 : 0);
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: itemCount,
      itemBuilder: (context, i) {
        if (i == messages.length && _isOtherTyping) {
          return const _TypingIndicator();
        }
        final msg = messages[i];
        return switch (msg.type) {
          'warning' => _buildWarning(msg.text),
          'system' => _buildSystem(msg),
          'me' => _buildBubble(msg, isMe: true, avatarState: avatarState),
          'other' => _buildBubble(msg, isMe: false),
          'card' => _buildCard(msg.text),
          'gif' => _buildGifBubble(msg, avatarState: avatarState),
          _ => const SizedBox.shrink(),
        };
      },
    );
  }

  Widget _buildWarning(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3D4BA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC87A5B)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF836151),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSystem(ChatMessage msg) {
    return Column(
      children: [
        if (msg.time != null) ...[
          const SizedBox(height: 8),
          Text(
            msg.time!,
            style: const TextStyle(fontSize: 12, color: Colors.black45),
          ),
          const SizedBox(height: 6),
        ],
        Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            msg.text,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildBubble(
    ChatMessage msg, {
    required bool isMe,
    AvatarState? avatarState,
  }) {
    final maxW = MediaQuery.of(context).size.width * 0.62;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            GestureDetector(
              onTap: () => showDialog(
                context: context,
                builder: (_) => UserProfileDialog(username: 'kaitom'),
              ),
              child: LayeredAvatar(boxSize: 40),
            ),
            const SizedBox(width: 8),
          ],
          if (isMe) ...[
            Text(
              msg.time ?? '',
              style: const TextStyle(fontSize: 10, color: Colors.black45),
            ),
            const SizedBox(width: 6),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            constraints: BoxConstraints(maxWidth: maxW),
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFFF1CEE4) : const Color(0xFFDCEBCE),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              msg.text,
              style: const TextStyle(fontSize: 15, height: 1.6),
            ),
          ),
          if (!isMe) ...[
            const SizedBox(width: 6),
            Text(
              msg.time ?? '',
              style: const TextStyle(fontSize: 10, color: Colors.black45),
            ),
          ],
          if (isMe) ...[
            const SizedBox(width: 8),
            LayeredAvatar(
              boxSize: 40,
              moodOverlay: avatarState?.mood,
              accessoryOverlay: avatarState?.accessory,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCard(String assetPath) {
    return _TopicCard(assetPath: assetPath, onShuffle: _shuffleTopic);
  }

  Widget _buildGifBubble(ChatMessage msg, {AvatarState? avatarState}) {
    final maxW = MediaQuery.of(context).size.width * 0.55;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            msg.time ?? '',
            style: const TextStyle(fontSize: 10, color: Colors.black45),
          ),
          const SizedBox(width: 6),
          Container(
            constraints: BoxConstraints(maxWidth: maxW),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1CEE4),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  msg.text,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Color(0xFF4A3228),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.yellowWarm,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'GIF',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4A3228),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          LayeredAvatar(
            boxSize: 40,
            moodOverlay: avatarState?.mood,
            accessoryOverlay: avatarState?.accessory,
          ),
        ],
      ),
    );
  }

  // ── Blocked bar ───────────────────────────────────────────────────────────
  Widget _buildBlockedBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      color: const Color(0xFF6B5E5B),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(24),
        ),
        alignment: Alignment.center,
        child: Text(
          'You can no longer send messages in this chat.',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ── Input bar ─────────────────────────────────────────────────────────────
  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      color: const Color(0xFF6B5E5B),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: TextField(
                controller: _msgController,
                focusNode: _focusNode,
                minLines: 1,
                maxLines: 5,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(fontSize: 15),
                strutStyle: const StrutStyle(
                  fontSize: 15,
                  height: 1.6,
                  forceStrutHeight: true,
                ),
                decoration: InputDecoration(
                  hintText: 'Type here ...',
                  hintStyle: const TextStyle(color: Colors.black38),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  suffixIcon: GestureDetector(
                    onTap: () async {
                      final gif = await showGifPicker(context);
                      if (!mounted) return;
                      if (gif != null) _sendGif(gif);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 12,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.yellowWarm,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'GIF',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            color: Color(0xFF4A3228),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFEAC163),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: SvgPicture.asset(
                'assets/images/icons/sent.svg',
                width: 24,
                height: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Topic card with shuffle animation ────────────────────────────────────
class _TopicCard extends StatefulWidget {
  final String assetPath;
  final VoidCallback onShuffle;
  const _TopicCard({required this.assetPath, required this.onShuffle});

  @override
  State<_TopicCard> createState() => _TopicCardState();
}

class _TopicCardState extends State<_TopicCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _rotate;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.90), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 0.90, end: 1.06), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.06, end: 1.00), weight: 25),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _rotate = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.04), weight: 30),
      TweenSequenceItem(tween: Tween(begin: -0.04, end: 0.04), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.04, end: 0.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleShuffle() {
    _ctrl.forward(from: 0); // animation plays independently
    widget.onShuffle(); // new card + scroll fires immediately
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, child) => Transform.rotate(
              angle: _rotate.value,
              child: Transform.scale(scale: _scale.value, child: child),
            ),
            child: Image.asset(
              widget.assetPath,
              width: 180,
              errorBuilder: (_, _, _) => Container(
                width: 180,
                height: 260,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2E9DD),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF5A443A), width: 4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          PressBounceBtn(
            onTap: _handleShuffle,
            scale: 0.92,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEAC163),
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 4),
                ],
              ),
              child: const Text(
                'shuffle',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFF6B5E5B),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Typing indicator ──────────────────────────────────────────────────────
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 380),
      ),
    );
    _anims = _controllers
        .map(
          (c) => Tween<double>(
            begin: 0,
            end: -7,
          ).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)),
        )
        .toList();
    _startLoop();
  }

  Future<void> _startLoop() async {
    while (mounted) {
      for (int i = 0; i < 3; i++) {
        if (!mounted) return;
        await _controllers[i].forward();
        if (!mounted) return;
        await _controllers[i].reverse();
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          LayeredAvatar(boxSize: 40),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFDCEBCE),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(
                3,
                (i) => AnimatedBuilder(
                  animation: _anims[i],
                  builder: (_, _) => Transform.translate(
                    offset: Offset(0, _anims[i].value),
                    child: Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: const BoxDecoration(
                        color: Color(0xFF6B5E5B),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Avatar widget ──────────────────────────────────────────────────────────
class _StaticAvatar extends StatelessWidget {
  const _StaticAvatar({
    required this.username,
    required this.moodText,
    required this.isMe,
    this.avatarState,
  });

  final String username;
  final String moodText;
  final bool isMe;
  final AvatarState? avatarState;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 190,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: GestureDetector(
              onTap: () => showDialog(
                context: context,
                builder: (_) =>
                    UserProfileDialog(username: username, isMe: isMe),
              ),
              child: LayeredAvatar(
                boxSize: 90,
                moodOverlay: isMe ? avatarState?.mood : null,
                accessoryOverlay: isMe ? avatarState?.accessory : null,
              ),
            ),
          ),
          Positioned(
            bottom: 75,
            left: isMe ? 25 : -15,
            right: isMe ? -15 : 25,
            child: Container(
              width: 95,
              height: 105,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/ThinkBubble.png'),
                  fit: BoxFit.contain,
                ),
              ),
              padding: const EdgeInsets.only(bottom: 12, left: 15, right: 10),
              alignment: Alignment.center,
              child: Text(
                moodText,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
