import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/chat/domain/entities/chat_message.dart' as chat_entity;
import '../features/chat/domain/entities/session_status.dart';
import '../features/chat/presentation/providers/chat_provider.dart';
import '../features/matchmaking/domain/entities/matchmaking_status.dart';
import '../features/matchmaking/presentation/providers/matchmaking_provider.dart';
import '../theme/app_colors.dart';
import '../dialogs/leave_room_dialog.dart';
import '../dialogs/song_dialog.dart';
import '../features/jukebox/presentation/providers/jukebox_provider.dart';
import '../features/jukebox/presentation/widgets/jukebox_chat_player.dart';
import '../dialogs/user_profile_dialog.dart';
import '../shared/avatar_overlay.dart';
import '../shared/layered_avatar.dart';
import '../shared/press_bounce_btn.dart';
import '../shared/gif_picker.dart';
import '../shared/info_dialog.dart';
import '../features/avatar/presentation/providers/avatar_decoration_provider.dart';
import '../features/friends/domain/entities/app_user.dart';
import '../features/friends/presentation/providers/friends_provider.dart';
import '../features/profile/presentation/providers/profile_provider.dart';

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

// ── Message model ──────────────────────────────────────────────────────────
class ChatMessage {
  final String
  type; // 'warning' | 'system' | 'me' | 'other' | 'card' | 'gif' | 'gif_other'
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
  final bool _isBlocked = false;
  Timer? _typingTimer;

  late final JukeboxNotifier _jukeboxNotifier;

  // ── Song panel animation ──
  bool _songPanelOpen = false;
  late final AnimationController _songCtrl;
  late final Animation<Offset> _songSlide;

  bool _friendRequestSent = false;
  String? _partnerUid;
  String _myThoughts = 'Care to share?';
  String _myDisplayName = '';
  String _myInterest = '';
  final List<({ChatMessage msg, int seq})> _localMessages = [];
  final List<ChatMessage> _optimisticMessages = [];
  String? _pendingGifUrl;

  @override
  void initState() {
    super.initState();
    _jukeboxNotifier = ref.read(jukeboxNotifierProvider.notifier);
    _songCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _songSlide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _songCtrl, curve: Curves.easeOutCubic));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
      final matchState = ref.read(matchmakingNotifierProvider);
      final authUser = ref.read(authNotifierProvider).user;
      final roomId = matchState.roomId;
      if (authUser == null || roomId == null) return;
      ref
          .read(chatNotifierProvider.notifier)
          .enterSession(
            sessionId: roomId,
            currentUserId: authUser.uid,
            currentUserDisplayName: authUser.displayName,
          );
      _jukeboxNotifier.enterRoom(roomId);
      if (ref.read(avatarDecorationNotifierProvider).decoration == null) {
        ref.read(avatarDecorationNotifierProvider.notifier).load(authUser.uid);
      }
      // Set partnerUid early to prevent currentRoom listener from double-loading
      final room = ref.read(matchmakingNotifierProvider).currentRoom;
      final partnerUid = room?.users.firstWhere(
        (uid) => uid != authUser.uid,
        orElse: () => '',
      );
      if (partnerUid != null && partnerUid.isNotEmpty) {
        _partnerUid = partnerUid;
      }
      // Load own profile (ensures latest data), snapshot, then load partner
      ref.read(profileNotifierProvider.notifier).load(authUser.uid).then((_) {
        if (!mounted) return;
        final own = ref.read(profileNotifierProvider).profile;
        if (own?.uid == authUser.uid) {
          bool changed = false;
          if (own?.thoughts?.isNotEmpty == true) {
            _myThoughts = own!.thoughts!;
            changed = true;
          }
          if (own?.displayName?.isNotEmpty == true) {
            _myDisplayName = own!.displayName!;
            changed = true;
          }
          if (own?.interest?.isNotEmpty == true) {
            _myInterest = own!.interest!;
            changed = true;
          }
          if (changed) setState(() {});
        }
        if (_partnerUid != null && _partnerUid!.isNotEmpty) {
          ref.read(profileNotifierProvider.notifier).load(_partnerUid!);
        }
      });
    });
    // TODO: show real incoming friend message popup from friendChatNotifierProvider
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _songCtrl.dispose();
    _jukeboxNotifier.leaveRoom();
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

  Future<void> _sendMessage() async {
    if (ref.read(chatNotifierProvider).isSending) return;
    final notifier = ref.read(chatNotifierProvider.notifier);
    bool sent = false;
    if (_pendingGifUrl != null) {
      final url = _pendingGifUrl!;
      setState(() {
        _pendingGifUrl = null;
        _optimisticMessages.add(ChatMessage(type: 'gif', text: url));
      });
      await notifier.sendMessage(url);
      sent = true;
    }
    final text = _msgController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _optimisticMessages.add(ChatMessage(type: 'me', text: text));
      });
      notifier.sendMessage(text);
      notifier.setTyping(false);
      _typingTimer?.cancel();
      _msgController.clear();
      _focusNode.requestFocus();
      sent = true;
    }
    if (sent) _scrollToBottom();
  }

  void _sendTopicCard() {
    final cardPath = _pickCard();
    setState(
      () => _optimisticMessages.add(ChatMessage(type: 'card', text: cardPath)),
    );
    _scrollToBottom();
    ref.read(chatNotifierProvider.notifier).sendMessage('card::$cardPath');
  }

  void _sendGif(String url) {
    setState(() => _pendingGifUrl = url);
  }

  void _sendFriendRequest([String name = '']) {
    if (_friendRequestSent) return;
    final targetName = name.isNotEmpty ? name : 'your match';
    setState(() => _friendRequestSent = true);
    if (_partnerUid != null && _partnerUid!.isNotEmpty) {
      ref
          .read(friendsNotifierProvider.notifier)
          .sendFriendRequest(
            AppUser(uid: _partnerUid!, displayName: targetName),
          );
    }
    showInfoDialog(
      context,
      type: InfoDialogType.info,
      title: 'Friend Request Sent',
      message:
          'Your friend request has been sent to $targetName.\nWaiting for them to accept.',
    );
  }

  void _cancelFriendRequest([String name = '']) {
    setState(() => _friendRequestSent = false);
    showInfoDialog(
      context,
      type: InfoDialogType.info,
      title: 'Request Cancelled',
      message:
          'Your friend request to ${name.isNotEmpty ? name : 'your match'} has been cancelled.',
    );
  }

  void _shuffleTopic() {
    final cardPath = _pickCard();
    final seq = ref.read(chatNotifierProvider).messages.length;
    setState(() {
      _localMessages.add((
        msg: ChatMessage(type: 'system', text: 'Someone shuffled the topic!'),
        seq: seq,
      ));
      _optimisticMessages.add(ChatMessage(type: 'card', text: cardPath));
    });
    _scrollToBottom();
    ref.read(chatNotifierProvider.notifier).sendMessage('card::$cardPath');
  }

  void _onWillPop() {
    final notifier = ref.read(chatNotifierProvider.notifier);
    showDialog(
      context: context,
      builder: (_) => LeaveRoomDialog(onLeave: () => notifier.endSession()),
    );
  }

  // TODO: implement _showLeaveForFriendChat — navigate to /friends/chat with real Friend
  // from friendsNotifierProvider; triggered by incoming friend message popup

  static const _kWarning =
      'Keep it friendly! Please be respectful and protect your personal info.\n'
      'Report any suspicious behavior to help keep our community safe.';

  static String _formatTime(DateTime t) {
    final tod = TimeOfDay.fromDateTime(t);
    final h = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final m = tod.minute.toString().padLeft(2, '0');
    return '$h:$m ${tod.period.name}';
  }

  ChatMessage _toDisplay(chat_entity.ChatMessage msg, String? myUid) {
    final isMe = msg.senderId == myUid;
    if (msg.text.startsWith('card::')) {
      return ChatMessage(type: 'card', text: msg.text.substring(6));
    }
    if (msg.text.startsWith('system::')) {
      return ChatMessage(type: 'system', text: msg.text.substring(8));
    }
    final isGif = msg.text.contains('giphy.com');
    return ChatMessage(
      type: isGif ? (isMe ? 'gif' : 'gif_other') : (isMe ? 'me' : 'other'),
      text: msg.text,
      time: _formatTime(msg.timestamp),
    );
  }

  String? _findPartnerDisplayName(ChatState chatState) {
    final myUid = chatState.currentUserId ?? '';
    for (final m in chatState.messages) {
      if (m.senderId != myUid) return m.displayName;
    }
    return null;
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

    final decoState = ref.watch(avatarDecorationNotifierProvider);
    final avatarState = AvatarState(
      mood: AvatarOverlays.mood[decoState.decoration?.moodKey ?? ''],
      accessory: AvatarOverlays.accessory[decoState.decoration?.hatKey ?? ''],
    );
    final chatState = ref.watch(chatNotifierProvider);
    final profileState = ref.watch(profileNotifierProvider);
    final isPartnerProfileLoaded = profileState.profile?.uid == _partnerUid;
    final partnerName = isPartnerProfileLoaded
        ? (profileState.profile?.displayName ??
              _findPartnerDisplayName(chatState) ??
              '')
        : (_findPartnerDisplayName(chatState) ?? '');
    final partnerThought = isPartnerProfileLoaded
        ? (profileState.profile?.thoughts ?? 'Care to share?')
        : 'Care to share?';
    final myUsername = _myDisplayName.isNotEmpty
        ? _myDisplayName
        : (ref.watch(authNotifierProvider).user?.displayName ?? '');
    final partnerInterest = isPartnerProfileLoaded
        ? (profileState.profile?.interest ?? '')
        : '';

    ref.listen(chatNotifierProvider.select((s) => s.status), (_, next) {
      if (next == SessionStatus.disconnected) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });

    // Fallback: load partner profile if currentRoom became available after initState
    ref.listen(matchmakingNotifierProvider.select((s) => s.currentRoom), (
      _,
      room,
    ) {
      if (room == null || _partnerUid != null) return;
      final myUid = ref.read(authNotifierProvider).user?.uid;
      if (myUid == null) return;
      final uid = room.users.firstWhere((u) => u != myUid, orElse: () => '');
      if (uid.isEmpty) return;
      _partnerUid = uid;
      ref.read(profileNotifierProvider.notifier).load(uid);
    });

    ref.listen(matchmakingNotifierProvider.select((s) => s.status), (
      prev,
      next,
    ) {
      if (prev == MatchmakingStatus.matched &&
          next != MatchmakingStatus.matched &&
          ref.read(chatNotifierProvider).status == SessionStatus.chatting) {
        ref.read(chatNotifierProvider.notifier).forceDisconnect();
      }
    });

    ref.listen(chatNotifierProvider.select((s) => s.messages.length), (
      prev,
      next,
    ) {
      if ((prev ?? 0) < next) {
        if (_optimisticMessages.isNotEmpty) {
          setState(() => _optimisticMessages.clear());
        }
        _scrollToBottom();
      }
    });

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
                          _myThoughts,
                          myUsername,
                          partnerName,
                          partnerThought,
                          _myInterest,
                          partnerInterest,
                        ),
                        Expanded(
                          child: Stack(
                            children: [
                              _buildMessageList(
                                avatarState,
                                chatState,
                                partnerName,
                                _myInterest,
                                partnerInterest,
                              ),
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
                    // Floating YouTube player (hidden widget; overlay renders the video)
                    JukeboxChatPlayer(roomId: roomId),
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
                        child: SongPanelBody(
                          onClose: _closeSongPanel,
                          roomId: roomId,
                        ),
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
    String myThoughts,
    String myUsername,
    String partnerName,
    String partnerThought,
    String myInterest,
    String partnerInterest,
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
            child: LayoutBuilder(
              builder: (_, c) {
                final eachW = ((c.maxWidth - 20) / 2).clamp(80.0, 120.0);
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _StaticAvatar(
                      username: partnerName,
                      moodText: partnerThought,
                      isMe: false,
                      interest: partnerInterest,
                      boxWidth: eachW,
                      onFriendRequest: _sendFriendRequest,
                      onCancelRequest: _cancelFriendRequest,
                      friendRequestSent: _friendRequestSent,
                    ),
                    const SizedBox(width: 20),
                    _StaticAvatar(
                      username: myUsername,
                      moodText: myThoughts,
                      isMe: true,
                      interest: myInterest,
                      avatarState: avatarState,
                      boxWidth: eachW,
                    ),
                  ],
                );
              },
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
  Widget _buildMessageList(
    AvatarState avatarState,
    ChatState chatState,
    String partnerName,
    String myInterest,
    String partnerInterest,
  ) {
    final backendMsgs = chatState.messages
        .map((m) => _toDisplay(m, chatState.currentUserId))
        .toList();
    final merged = <ChatMessage>[ChatMessage(type: 'warning', text: _kWarning)];
    int localIdx = 0;
    for (int i = 0; i <= backendMsgs.length; i++) {
      while (localIdx < _localMessages.length &&
          _localMessages[localIdx].seq <= i) {
        merged.add(_localMessages[localIdx].msg);
        localIdx++;
      }
      if (i < backendMsgs.length) merged.add(backendMsgs[i]);
    }
    final displayMessages = [...merged, ..._optimisticMessages];
    final isTyping = chatState.typingUsers.isNotEmpty;
    final itemCount = displayMessages.length + (isTyping ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: itemCount,
      itemBuilder: (context, i) {
        if (i == displayMessages.length && isTyping) {
          return const _TypingIndicator();
        }
        final msg = displayMessages[i];
        return switch (msg.type) {
          'warning' => _buildWarning(msg.text),
          'system' => _buildSystem(msg),
          'me' => _buildBubble(
            msg,
            isMe: true,
            avatarState: avatarState,
            partnerName: partnerName,
            interest: myInterest,
          ),
          'other' => _buildBubble(
            msg,
            isMe: false,
            partnerName: partnerName,
            interest: partnerInterest,
          ),
          'card' => _buildCard(msg.text),
          'gif' => _buildGifBubble(
            msg,
            isMe: true,
            avatarState: avatarState,
            partnerName: partnerName,
            interest: myInterest,
          ),
          'gif_other' => _buildGifBubble(
            msg,
            isMe: false,
            partnerName: partnerName,
            interest: partnerInterest,
          ),
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
    String partnerName = '',
    String interest = '',
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
                builder: (_) => UserProfileDialog(
                  username: partnerName,
                  interest: interest,
                  initialAdded: _friendRequestSent,
                  onAddFriend: () => _sendFriendRequest(partnerName),
                  onCancelRequest: () => _cancelFriendRequest(partnerName),
                ),
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

  Widget _buildGifBubble(
    ChatMessage msg, {
    required bool isMe,
    AvatarState? avatarState,
    String partnerName = '',
    String interest = '',
  }) {
    final maxW = MediaQuery.of(context).size.width * 0.55;
    final gifWidget = Container(
      constraints: BoxConstraints(maxWidth: maxW),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFFF1CEE4) : const Color(0xFFDCEBCE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          msg.text,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'GIF',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: Color(0xFF4A3228),
              ),
            ),
          ),
        ),
      ),
    );
    final timestamp = Text(
      msg.time ?? '',
      style: const TextStyle(fontSize: 10, color: Colors.black45),
    );
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
                builder: (_) => UserProfileDialog(
                  username: partnerName,
                  interest: interest,
                  initialAdded: _friendRequestSent,
                  onAddFriend: () => _sendFriendRequest(partnerName),
                  onCancelRequest: () => _cancelFriendRequest(partnerName),
                ),
              ),
              child: LayeredAvatar(boxSize: 40),
            ),
            const SizedBox(width: 8),
            gifWidget,
            const SizedBox(width: 6),
            timestamp,
          ] else ...[
            timestamp,
            const SizedBox(width: 6),
            gifWidget,
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

  // ── GIF preview strip ─────────────────────────────────────────────────────
  Widget _buildGifPreview() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      color: const Color(0xFF6B5E5B),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              _pendingGifUrl!,
              width: 80,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 80,
                height: 60,
                color: Colors.white12,
                alignment: Alignment.center,
                child: const Text(
                  'GIF',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'GIF ready to send',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _pendingGifUrl = null),
            child: const Icon(Icons.close, color: Colors.white54, size: 20),
          ),
        ],
      ),
    );
  }

  // ── Input bar ─────────────────────────────────────────────────────────────
  Widget _buildInputBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_pendingGifUrl != null) _buildGifPreview(),
        _buildInputRow(),
      ],
    );
  }

  Widget _buildInputRow() {
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
                onChanged: (text) {
                  _typingTimer?.cancel();
                  final notifier = ref.read(chatNotifierProvider.notifier);
                  if (text.isNotEmpty) {
                    notifier.setTyping(true);
                    _typingTimer = Timer(const Duration(seconds: 3), () {
                      notifier.setTyping(false);
                    });
                  } else {
                    notifier.setTyping(false);
                  }
                },
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
    this.interest,
    this.avatarState,
    this.boxWidth = 120,
    this.onFriendRequest,
    this.onCancelRequest,
    this.friendRequestSent = false,
  });

  final String username;
  final String moodText;
  final bool isMe;
  final String? interest;
  final AvatarState? avatarState;
  final VoidCallback? onFriendRequest;
  final VoidCallback? onCancelRequest;
  final bool friendRequestSent;
  final double boxWidth;

  @override
  Widget build(BuildContext context) {
    final s = boxWidth / 120;
    return SizedBox(
      width: boxWidth,
      height: 190 * s,
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
                builder: (_) => UserProfileDialog(
                  username: username,
                  interest: interest,
                  isMe: isMe,
                  initialAdded: !isMe && friendRequestSent,
                  onAddFriend: isMe ? null : onFriendRequest,
                  onCancelRequest: isMe ? null : onCancelRequest,
                ),
              ),
              child: LayeredAvatar(
                boxSize: 90 * s,
                moodOverlay: isMe ? avatarState?.mood : null,
                accessoryOverlay: isMe ? avatarState?.accessory : null,
              ),
            ),
          ),
          Positioned(
            bottom: 80 * s,
            left: (boxWidth - 92 * s) / 2,
            child: Container(
              width: 92 * s,
              height: 104 * s,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/chat_t_bubble.png'),
                  fit: BoxFit.contain,
                ),
              ),
              padding: EdgeInsets.all(10 * s),
              alignment: Alignment.center,
              child: Text(
                moodText,
                style: TextStyle(
                  fontSize: (9 * s).clamp(7.0, 9.0),
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
