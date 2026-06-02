import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/avatar/presentation/providers/avatar_decoration_provider.dart';
import '../features/friends/domain/entities/friend_message.dart';
import '../features/block/presentation/providers/block_provider.dart';
import '../features/friends/presentation/providers/friend_chat_provider.dart';
import '../features/friends/presentation/providers/friends_provider.dart';
import '../features/profile/presentation/providers/profile_provider.dart';
import '../shared/avatar_overlay.dart';
import '../theme/app_colors.dart';
import '../theme/app_routes.dart';
import '../theme/room_themes.dart';
import '../features/friends/domain/entities/friend_room_status.dart';
import '../models/friend.dart';
import '../dialogs/report_dialog.dart';
import '../shared/gif_picker.dart';
import '../shared/layered_avatar.dart';
import 'friend_profile_dialog.dart';
import 'widgets.dart';

class FriendChatScreen extends ConsumerStatefulWidget {
  const FriendChatScreen({super.key});

  @override
  ConsumerState<FriendChatScreen> createState() => _FriendChatScreenState();
}

class _FriendChatScreenState extends ConsumerState<FriendChatScreen> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  late final FriendChatNotifier _chatNotifier;
  late Friend _friend;
  bool _initialized = false;
  Timer? _typingTimer;
  String? _pendingGifUrl;

  @override
  void initState() {
    super.initState();
    _chatNotifier = ref.read(friendChatNotifierProvider.notifier);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is! Friend) {
        Navigator.pop(context);
        return;
      }
      _friend = args;
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _chatNotifier.enterChat(_friend.chatRoomId, _friend.username);
      });
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _chatNotifier.leaveChat();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onTypingChanged(String text) {
    _typingTimer?.cancel();
    if (text.isNotEmpty) {
      _chatNotifier.setTyping(true);
      _typingTimer = Timer(const Duration(seconds: 3), () {
        _chatNotifier.setTyping(false);
      });
    } else {
      _chatNotifier.setTyping(false);
    }
  }

  Future<void> _sendMessage() async {
    bool sent = false;
    if (_pendingGifUrl != null) {
      final url = _pendingGifUrl!;
      setState(() => _pendingGifUrl = null);
      await _chatNotifier.sendMessage(url);
      sent = true;
    }
    if (!mounted) return;
    final text = _inputCtrl.text.trim();
    if (text.isNotEmpty) {
      _inputCtrl.clear();
      await _chatNotifier.sendMessage(text);
      _chatNotifier.setTyping(false);
      _typingTimer?.cancel();
      sent = true;
    }
    if (sent) _scrollToBottom();
  }

  void _sendGif(String gifUrl) {
    setState(() => _pendingGifUrl = gifUrl);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour > 12
        ? dt.hour - 12
        : dt.hour == 0
        ? 12
        : dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'pm' : 'am';
    return '$h:$m $ampm';
  }

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  String _dateLabel(DateTime dt) =>
      '${dt.day} ${_months[dt.month - 1]} ${dt.year}';

  // Returns a flat list of items: either a DateTime (date separator)
  // or a FriendMessage. Used by ListView.builder for lazy rendering.
  List<Object> _buildItemList(List<FriendMessage> messages) {
    if (messages.isEmpty) return [DateTime.now()];
    final items = <Object>[];
    DateTime? lastDate;
    for (final m in messages) {
      final msgDay = DateTime(
        m.timestamp.year,
        m.timestamp.month,
        m.timestamp.day,
      );
      if (lastDate == null || msgDay != lastDate) {
        lastDate = msgDay;
        items.add(msgDay);
      }
      items.add(m);
    }
    return items;
  }

  Widget _buildDateSeparator(DateTime dt) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Text(
          _dateLabel(dt),
          style: Theme.of(context).textTheme.bodySmall!.copyWith(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(friendChatNotifierProvider);
    final currentUid = ref.watch(
      authNotifierProvider.select((s) => s.user?.uid ?? ''),
    );

    // Derive partner UID from chatRoomId (friendshipId = "uid1_uid2" sorted).
    final partnerUid = _friend.chatRoomId
        .split('_')
        .firstWhere((uid) => uid != currentUid, orElse: () => '');

    // Live partner data — overrides stale friendship-doc values.
    final partnerProfile = ref
        .watch(profileByUidProvider(partnerUid))
        .asData
        ?.value;
    final partnerDecoration = ref
        .watch(avatarDecorationByUidProvider(partnerUid))
        .asData
        ?.value;
    final isOnline = ref.watch(
      friendsNotifierProvider.select(
        (s) => s.presenceMap[partnerUid] ?? _friend.isOnline,
      ),
    );
    final iBlockedPartner = ref.watch(
      blockNotifierProvider.select(
        (s) => s.blockedUsers.any((u) => u.uid == partnerUid),
      ),
    );
    final partnerBlockedMe = ref
        .watch(isBlockedByProvider(partnerUid))
        .when(data: (v) => v, loading: () => false, error: (_, _) => false);
    final isBlocked = iBlockedPartner || partnerBlockedMe;
    final displayName = partnerProfile?.displayName ?? _friend.displayName;
    final partnerMoodOverlay =
        AvatarOverlays.mood[partnerDecoration?.moodKey ?? ''];
    final partnerAccessoryOverlay =
        AvatarOverlays.accessory[partnerDecoration?.hatKey ?? ''];
    final myDecoration = currentUid.isEmpty
        ? null
        : ref.watch(avatarDecorationByUidProvider(currentUid)).asData?.value;
    final myMoodOverlay = AvatarOverlays.mood[myDecoration?.moodKey ?? ''];
    final myAccessoryOverlay =
        AvatarOverlays.accessory[myDecoration?.hatKey ?? ''];

    ref.listen<FriendChatState>(friendChatNotifierProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.error!)));
      }
      if ((prev?.messages.length ?? 0) < next.messages.length) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          _buildHeader(
            context,
            displayName,
            isOnline,
            partnerMoodOverlay,
            partnerAccessoryOverlay,
            partnerProfile?.interest,
            partnerUid,
          ),
          if (chatState.isLoading)
            const LinearProgressIndicator()
          else
            _buildRoomBanner(context, partnerUid, isOnline, isBlocked),
          Expanded(
            child: Builder(
              builder: (context) {
                final msgItems = _buildItemList(chatState.messages);
                // index 0 = safety notice, 1 = spacer,
                // 2..n-1 = date separators / message bubbles,
                // last = typing indicator (if visible)
                final extraHead = 2;
                final typingCount = chatState.isPartnerTyping ? 1 : 0;
                final total = extraHead + msgItems.length + typingCount;
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: total,
                  itemBuilder: (context, i) {
                    if (i == 0) return _buildSafetyNotice();
                    if (i == 1) return const SizedBox(height: 8);
                    final msgIndex = i - extraHead;
                    if (msgIndex < msgItems.length) {
                      final item = msgItems[msgIndex];
                      if (item is DateTime) return _buildDateSeparator(item);
                      return _buildMessageBubble(
                        item as FriendMessage,
                        currentUid,
                        myMoodOverlay,
                        myAccessoryOverlay,
                        partnerMoodOverlay,
                        partnerAccessoryOverlay,
                      );
                    }
                    return const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: _FriendTypingIndicator(),
                    );
                  },
                );
              },
            ),
          ),
          if (isBlocked)
            _buildBlockedBar()
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_pendingGifUrl != null) _buildGifPreview(),
                _buildInputBar(chatState),
              ],
            ),
        ],
      ),
    );
  }

  // ─── Room banner ───
  RoomInfo _toRoomInfo(FriendRoomStatus s) {
    final theme = resolveRoomTheme(s.backgroundTheme, mode: s.mode);
    return RoomInfo(
      roomId: s.roomId,
      name: theme.title,
      thumbnail: theme.thumbnail,
      current: s.memberCount,
      max: s.maxUsers,
      isLocked: s.isLocked,
    );
  }

  Widget _buildRoomBanner(
    BuildContext context,
    String partnerUid,
    bool isOnline,
    bool isBlocked,
  ) {
    final roomStatus = ref.watch(
      friendsNotifierProvider.select((s) => s.roomMap[partnerUid]),
    );
    if (roomStatus == null || !isOnline) return const SizedBox.shrink();
    final room = _toRoomInfo(roomStatus);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: FriendRoomCard(
        room: room,
        showLabel: true,
        backgroundColor: Colors.white,
        blocked: isBlocked,
        onJoin: (room.canJoin && !isBlocked)
            ? () => Navigator.pushNamed(
                context,
                AppRoutes.findingRoom,
                arguments: {
                  'roomType': 'joinById',
                  'roomId': room.roomId,
                  'isGroup': true,
                  'roomName': room.name,
                  'bgImage': room.thumbnail,
                },
              )
            : null,
      ),
    );
  }

  // ─── Header ───
  Widget _buildHeader(
    BuildContext context,
    String displayName,
    bool isOnline,
    AvatarOverlay? moodOverlay,
    AvatarOverlay? accessoryOverlay,
    String? interest,
    String reportedUserId,
  ) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.brownDeep,
        borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 80,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Back
                Semantics(
                  label: 'Go back',
                  button: true,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1.5,
                        ),
                      ),
                      child: SvgPicture.asset(
                        'assets/images/icons/Back.svg',
                        width: 24,
                        height: 24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Avatar — tappable to show profile
                Semantics(
                  label: 'View user profile',
                  button: true,
                  child: GestureDetector(
                    onTap: () => showFriendProfileDialog(
                      context: context,
                      friend: _friend,
                      onNoteSaved: (newNote) => setState(
                        () =>
                            _friend.note = newNote.isNotEmpty ? newNote : null,
                      ),
                    ),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.grey.shade300,
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
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 7),
                          child: Center(
                            child: LayeredAvatar(
                              boxSize: 34,
                              moodOverlay: moodOverlay,
                              accessoryOverlay: accessoryOverlay,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Name + online status (not tappable)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isOnline
                                  ? const Color(0xFF86BA73)
                                  : Colors.grey.shade300,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isOnline
                                    ? const Color(0xFF72A161)
                                    : Colors.grey.shade400,
                                width: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isOnline ? 'Online' : 'Offline',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Report button
                Semantics(
                  label: 'Report user',
                  button: true,
                  child: GestureDetector(
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => ReportDialog(
                        sessionId: _friend.chatRoomId,
                        reportedUserId: reportedUserId,
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFCCAA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFCF5733),
                          width: 1.5,
                        ),
                      ),
                      child: SvgPicture.asset(
                        'assets/images/icons/Report.svg',
                        width: 22,
                        height: 22,
                        colorFilter: const ColorFilter.mode(
                          Color(0xFFCF5733),
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Date label ───

  // ─── Safety notice banner ───
  Widget _buildSafetyNotice() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.peachWarm,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.redOrange.withValues(alpha: 0.7),
          width: 1.5,
        ),
      ),
      child: Text(
        'Keep it friendly! Please be respectful and protect your personal info.\n'
        'Report any suspicious behavior to help keep our community safe.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
          fontSize: 13,
          color: AppColors.brownDeep,
          height: 1.5,
        ),
      ),
    );
  }

  // ─── Message bubble ───
  Widget _buildMessageBubble(
    FriendMessage message,
    String currentUid,
    AvatarOverlay? myMoodOverlay,
    AvatarOverlay? myAccessoryOverlay,
    AvatarOverlay? partnerMoodOverlay,
    AvatarOverlay? partnerAccessoryOverlay,
  ) {
    final isMe = message.senderId == currentUid;
    final isGif = message.text.contains('giphy.com');
    final maxW = MediaQuery.of(context).size.width * 0.62;
    final bubbleColor = isMe
        ? const Color(0xFFF1CEE4)
        : const Color(0xFFDCEBCE);
    final moodOverlay = isMe ? myMoodOverlay : partnerMoodOverlay;
    final accessoryOverlay = isMe
        ? myAccessoryOverlay
        : partnerAccessoryOverlay;

    final timeWidget = Text(
      _formatTime(message.timestamp),
      style: Theme.of(context).textTheme.labelSmall!.copyWith(
        fontSize: 10,
        color: Colors.black.withValues(alpha: 0.60),
      ),
    );

    final content = isGif
        ? Container(
            constraints: BoxConstraints(maxWidth: maxW),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                message.text,
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
          )
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            constraints: BoxConstraints(maxWidth: maxW),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              message.text,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge!.copyWith(fontSize: 15, height: 1.6),
            ),
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
            LayeredAvatar(
              boxSize: 40,
              moodOverlay: moodOverlay,
              accessoryOverlay: accessoryOverlay,
            ),
            const SizedBox(width: 8),
            content,
            const SizedBox(width: 6),
            timeWidget,
          ] else ...[
            timeWidget,
            const SizedBox(width: 6),
            content,
            const SizedBox(width: 8),
            LayeredAvatar(
              boxSize: 40,
              moodOverlay: moodOverlay,
              accessoryOverlay: accessoryOverlay,
            ),
          ],
        ],
      ),
    );
  }

  // ─── GIF preview strip ───
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
          Text(
            'GIF ready to send',
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const Spacer(),
          Semantics(
            label: 'Close GIF preview',
            button: true,
            child: GestureDetector(
              onTap: () => setState(() => _pendingGifUrl = null),
              child: const Icon(Icons.close, color: Colors.white54, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Blocked bar ───
  Widget _buildBlockedBar() {
    return Container(
      decoration: const BoxDecoration(color: AppColors.brownDeep),
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        MediaQuery.of(context).padding.bottom + 14,
      ),
      child: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        alignment: Alignment.centerLeft,
        child: Text(
          'You can no longer send messages in this chat.',
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey.shade400,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ─── Bottom input bar ───
  Widget _buildInputBar(FriendChatState chatState) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      color: const Color(0xFF6B5E5B),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: TextField(
                controller: _inputCtrl,
                minLines: 1,
                maxLines: 5,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge!.copyWith(fontSize: 15),
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
                onChanged: _onTypingChanged,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Semantics(
            label: 'Send message',
            button: true,
            child: GestureDetector(
              onTap: chatState.isSending ? null : _sendMessage,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAC163),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: chatState.isSending
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : SvgPicture.asset(
                        'assets/images/icons/sent.svg',
                        width: 24,
                        height: 24,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Typing indicator (three bouncing dots) ────────────────────────────────────
class _FriendTypingIndicator extends StatefulWidget {
  const _FriendTypingIndicator();

  @override
  State<_FriendTypingIndicator> createState() => _FriendTypingIndicatorState();
}

class _FriendTypingIndicatorState extends State<_FriendTypingIndicator>
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
        duration: const Duration(milliseconds: 400),
      ),
    );
    _anims = _controllers
        .map(
          (c) => Tween<double>(
            begin: 0,
            end: -6,
          ).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)),
        )
        .toList();
    _startLoop();
  }

  Future<void> _startLoop() async {
    while (mounted) {
      for (int i = 0; i < _controllers.length; i++) {
        if (!mounted) return;
        await _controllers[i].forward();
        await _controllers[i].reverse();
        await Future.delayed(const Duration(milliseconds: 100));
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.person, color: Colors.grey, size: 24),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFDEF1C2),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFC7D2B5), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
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
    );
  }
}
