import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/avatar/presentation/providers/avatar_decoration_provider.dart';
import '../features/chat/domain/entities/chat_message.dart' as chat_entity;
import '../features/chat/domain/entities/session_status.dart';
import '../features/chat/presentation/providers/chat_provider.dart';
import '../features/friends/domain/entities/app_user.dart';
import '../features/friends/presentation/providers/friends_provider.dart';
import '../features/jukebox/presentation/providers/jukebox_provider.dart';
import '../features/matchmaking/presentation/providers/matchmaking_provider.dart';
import '../features/profile/presentation/providers/profile_provider.dart';
import '../dialogs/report_dialog.dart';
import '../theme/app_colors.dart';
import '../dialogs/leave_room_dialog.dart';
import '../dialogs/members_list_dialog.dart';
import '../dialogs/song_dialog.dart';
import '../dialogs/user_profile_dialog.dart'
    show AddFriendStatus, UserProfileDialog;
import '../shared/avatar_overlay.dart';
import '../shared/gif_picker.dart';
import '../shared/info_dialog.dart';
import '../shared/layered_avatar.dart';
import '../shared/press_bounce_btn.dart';
import '../theme/room_themes.dart';
import '../features/report/presentation/screens/report_sheet.dart';

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
enum _MsgType { warning, system, me, other, card, gif, gifOther }

class _GroupMsg {
  final _MsgType type;
  final String text; // for card = asset path
  final String? sender;
  final String? time;
  final String?
  shufflerName; // for card type: display name of who sent the card
  const _GroupMsg({
    required this.type,
    required this.text,
    this.sender,
    this.time,
    this.shufflerName,
  });
}

// ── Avatar layout presets (leftFrac, bottomPx, sizePx) per member count ────
// leftFrac: fraction of total banner width (0.0–1.0); side buttons occupy ~0.20 on right
typedef _AvatarPos = ({double x, double bottom, double size});

const List<List<_AvatarPos>> _layouts = [
  [], // 0 members — unused
  [
    // 1 member — center
    (x: 0.36, bottom: 14, size: 88),
  ],
  [
    // 2 members
    (x: 0.10, bottom: 12, size: 80),
    (x: 0.55, bottom: 12, size: 80),
  ],
  [
    // 3 members — staggered (matches design)
    (x: 0.04, bottom: 8, size: 75),
    (x: 0.34, bottom: 32, size: 75),
    (x: 0.60, bottom: 8, size: 75),
  ],
  [
    // 4 members
    (x: 0.02, bottom: 8, size: 65),
    (x: 0.23, bottom: 28, size: 65),
    (x: 0.44, bottom: 28, size: 65),
    (x: 0.64, bottom: 8, size: 65),
  ],
  [
    // 5 members
    (x: 0.01, bottom: 8, size: 55),
    (x: 0.17, bottom: 26, size: 55),
    (x: 0.33, bottom: 8, size: 55),
    (x: 0.50, bottom: 26, size: 55),
    (x: 0.66, bottom: 8, size: 55),
  ],
];

// ── Screen ─────────────────────────────────────────────────────────────────
class GroupChatScreen extends ConsumerStatefulWidget {
  const GroupChatScreen({super.key});

  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  Timer? _typingTimer;

  late final JukeboxNotifier _jukeboxNotifier;

  // ── Members panel animation ──
  bool _panelOpen = false;
  late final AnimationController _panelCtrl;
  late final Animation<Offset> _panelSlide;

  // ── Song panel animation ──
  bool _songPanelOpen = false;
  late final AnimationController _songCtrl;
  late final Animation<Offset> _songSlide;

  String _myThoughts = 'Care to share?';
  String _myDisplayName = '';
  String _myInterest = '';
  // Accumulates uid→displayName from messages + typing events so names persist
  // even before a member sends their first message.
  final Map<String, String> _memberNameCache = {};
  // uid→interest loaded from Firestore profiles.
  final Map<String, String> _memberInterestCache = {};
  // uid→thoughts (status message) loaded from Firestore profiles.
  final Map<String, String> _memberThoughtsCache = {};
  // uid→AvatarState populated while the member is live; persists after they leave
  // so message avatars retain their mood/hat overlays even when the sender is gone.
  final Map<String, AvatarState> _memberAvatarCache = {};
  // displayName→uid reverse index so bubble taps can resolve interest.
  final Map<String, String> _uidByDisplayName = {};
  // Pending hop-in UIDs whose display names aren't known yet.
  // Key = uid, value = seq (message count) at the moment they were detected,
  // so the hop-in bubble is inserted at the right position once the name arrives.
  final Map<String, int> _pendingJoinUids = {};
  final List<({_GroupMsg msg, int seq})> _localMessages = [];
  final List<_GroupMsg> _optimisticMessages = [];
  String? _pendingGifUrl;

  @override
  void initState() {
    super.initState();
    _jukeboxNotifier = ref.read(jukeboxNotifierProvider.notifier);
    _panelCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _panelSlide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _panelCtrl, curve: Curves.easeOutCubic));
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
      // Load profiles for all members already in the room.
      final initialUsers =
          ref.read(matchmakingNotifierProvider).currentRoom?.users ?? [];
      if (initialUsers.isNotEmpty) _loadMemberProfiles(initialUsers);

      // Load own profile (ensures latest data after any edits) then snapshot
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
            // Flush a deferred self hop-in that was parked because _myDisplayName
            // was empty when the currentRoom.users listener first fired.
            // _loadMemberProfiles skips self, and the message/typing listeners
            // gate on _memberInterestCache which is never set for self, so this
            // is the only path that can resolve a pending self hop-in.
            if (_pendingJoinUids.containsKey(authUser.uid)) {
              _localMessages.add((
                msg: _GroupMsg(
                  type: _MsgType.system,
                  text: '$_myDisplayName hop in',
                ),
                seq: _pendingJoinUids[authUser.uid]!,
              ));
              _pendingJoinUids.remove(authUser.uid);
            }
          }
          if (own?.interest?.isNotEmpty == true) {
            _myInterest = own!.interest!;
            changed = true;
          }
          if (changed) setState(() {});
        }
      });
    });
    // TODO: show real incoming friend message popup from friendChatNotifierProvider
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _panelCtrl.dispose();
    _songCtrl.dispose();
    _jukeboxNotifier.leaveRoom();
    _msgController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _openPanel() {
    if (_songPanelOpen) _closeSongPanel();
    setState(() => _panelOpen = true);
    _panelCtrl.forward();
  }

  void _closePanel() {
    _panelCtrl.reverse().then((_) {
      if (mounted) setState(() => _panelOpen = false);
    });
  }

  void _openSongPanel() {
    if (_panelOpen) _closePanel();
    setState(() => _songPanelOpen = true);
    _songCtrl.forward();
  }

  void _closeSongPanel() {
    _songCtrl.reverse().then((_) {
      if (mounted) setState(() => _songPanelOpen = false);
    });
  }

  // Fetches Firestore profiles for the given UIDs and populates the interest
  // and reverse-name caches. Always prefers the profile username over any
  // auth display name that may have arrived via messages first.
  Future<void> _loadMemberProfiles(List<String> uids) async {
    if (!mounted) return;
    final myUid = ref.read(authNotifierProvider).user?.uid ?? '';
    for (final uid in uids) {
      // Re-check before every ref.read — the widget may be disposed between
      // iterations because each profileByUidProvider await suspends the loop.
      if (!mounted) return;
      if (uid == myUid || _memberInterestCache.containsKey(uid)) continue;
      try {
        final profile = await ref.read(profileByUidProvider(uid).future);
        if (!mounted || profile == null) continue;
        final name = profile.displayName ?? '';
        setState(() {
          _memberInterestCache[uid] = profile.interest ?? '';
          _memberThoughtsCache[uid] = profile.thoughts ?? '';
          if (name.isNotEmpty) {
            // Always overwrite with profile username — it's the value the user
            // set intentionally, unlike the auth display name (often a Gmail).
            _memberNameCache[uid] = name;
            _uidByDisplayName[name] = uid;
            // Flush any hop-in that was waiting for this member's name.
            if (_pendingJoinUids.containsKey(uid)) {
              _localMessages.add((
                msg: _GroupMsg(type: _MsgType.system, text: '$name hop in'),
                seq: _pendingJoinUids[uid]!,
              ));
              _pendingJoinUids.remove(uid);
            }
          }
        });
      } catch (_) {}
    }
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
        _optimisticMessages.add(_GroupMsg(type: _MsgType.gif, text: url));
      });
      await notifier.sendMessage(url);
      sent = true;
    }
    final text = _msgController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _optimisticMessages.add(_GroupMsg(type: _MsgType.me, text: text));
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
      () => _optimisticMessages.add(
        _GroupMsg(type: _MsgType.card, text: cardPath),
      ),
    );
    _scrollToBottom();
    ref.read(chatNotifierProvider.notifier).sendMessage('card::$cardPath');
  }

  void _sendGif(String url) {
    setState(() => _pendingGifUrl = url);
  }

  void _openReport(String reportedUserId) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final sessionId =
        ref.read(chatNotifierProvider).sessionId ??
        (args is Map<String, dynamic> ? args['roomId'] as String? : null) ??
        '';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          ReportSheet(sessionId: sessionId, reportedUserId: reportedUserId),
    );
  }

  void _addFriend(String uid, String displayName) {
    ref
        .read(friendsNotifierProvider.notifier)
        .sendFriendRequest(AppUser(uid: uid, displayName: displayName));
    showInfoDialog(
      context,
      type: InfoDialogType.info,
      title: 'Friend Request Sent',
      message:
          'Your friend request has been sent to $displayName.\nWaiting for them to accept.',
    );
  }

  void reportUser(String targetName) {
    final sessionId = ref.read(matchmakingNotifierProvider).roomId ?? '';
    if (sessionId.isEmpty) return;
    // Resolve UID from roomUsers cache — same lookup as _sendFriendRequest.
    final myUid = ref.read(authNotifierProvider).user?.uid;
    final roomUsers =
        ref.read(matchmakingNotifierProvider).currentRoom?.users ?? [];
    String reportedUid = '';
    for (final uid in roomUsers) {
      if (uid == myUid) continue;
      if ((_memberNameCache[uid] ?? 'User') == targetName) {
        reportedUid = uid;
        break;
      }
    }
    if (reportedUid.isEmpty) {
      final chatState = ref.read(chatNotifierProvider);
      reportedUid =
          chatState.messages
              .cast<chat_entity.ChatMessage?>()
              .firstWhere(
                (m) => m?.displayName == targetName,
                orElse: () => null,
              )
              ?.senderId ??
          '';
    }
    if (reportedUid.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (_) =>
          ReportDialog(sessionId: sessionId, reportedUserId: reportedUid),
    );
  }

  void _cancelFriendRequest(String uid, String displayName) {
    ref.read(friendsNotifierProvider.notifier).cancelFriendRequest(uid);
    showInfoDialog(
      context,
      type: InfoDialogType.info,
      title: 'Request Cancelled',
      message: 'Your friend request to $displayName has been cancelled.',
    );
  }

  AddFriendStatus _friendStatus(String uid) {
    final s = ref.read(friendsNotifierProvider);
    if (s.isFriend(uid)) return AddFriendStatus.friends;
    // Mutual pending: both sent requests → treat as friends (disabled).
    if (s.hasSentRequestTo(uid) &&
        s.incomingRequests.any((r) => r.fromUid == uid)) {
      return AddFriendStatus.friends;
    }
    if (s.hasSentRequestTo(uid)) return AddFriendStatus.pending;
    return AddFriendStatus.notAdded;
  }

  void shuffleTopic() {
    final cardPath = _pickCard();
    setState(() {
      _optimisticMessages.add(_GroupMsg(type: _MsgType.card, text: cardPath));
    });
    _scrollToBottom();
    ref.read(chatNotifierProvider.notifier).sendMessage('card::$cardPath');
  }

  // TODO: implement _showLeaveForFriendChat — navigate to /friends/chat with real Friend
  // from friendsNotifierProvider; triggered by incoming friend message popup

  final kWarning =
      'Keep it friendly! Please be respectful and protect your personal info.\n'
      'Report any suspicious behavior to help keep our community safe.';

  String formatTime(DateTime t) {
    final tod = TimeOfDay.fromDateTime(t);
    final h = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final m = tod.minute.toString().padLeft(2, '0');
    return '$h:$m ${tod.period.name}';
  }

  _GroupMsg toGroupDisplay(chat_entity.ChatMessage msg, String? myUid) {
    final isMe = msg.senderId == myUid;
    if (msg.text.startsWith('card::')) {
      return _GroupMsg(
        type: _MsgType.card,
        text: msg.text.substring(6),
        shufflerName: isMe ? null : msg.displayName,
      );
    }
    if (msg.text.startsWith('system::')) {
      return _GroupMsg(type: _MsgType.system, text: msg.text.substring(8));
    }
    final isGif = msg.text.contains('giphy.com');
    return _GroupMsg(
      type: isGif
          ? (isMe ? _MsgType.gif : _MsgType.gifOther)
          : (isMe ? _MsgType.me : _MsgType.other),
      text: msg.text,
      sender: isMe ? 'Me' : msg.displayName,
      time: formatTime(msg.timestamp),
    );
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final maxMembers = args?['maxMembers'] as int? ?? 5;

    final decoState = ref.watch(avatarDecorationNotifierProvider);
    final avatarState = AvatarState(
      mood: AvatarOverlays.mood[decoState.decoration?.moodKey ?? ''],
      accessory: AvatarOverlays.accessory[decoState.decoration?.hatKey ?? ''],
    );
    final chatState = ref.watch(chatNotifierProvider);
    final roomType = args?['roomType'] as String?;
    final matchState = ref.watch(matchmakingNotifierProvider);
    final roomId = matchState.roomId ?? args?['roomId'] as String? ?? 'ABP8C';
    final liveThemeId = matchState.currentRoom?.backgroundTheme;
    final liveTheme = resolveRoomTheme(liveThemeId, mode: 'group');
    final roomName = liveThemeId != null
        ? liveTheme.title
        : (args?['roomName'] as String? ?? 'Group Room');
    final bgImage = liveThemeId != null
        ? liveTheme.thumbnail
        : (args?['bgImage'] as String? ??
              'assets/images/backgrounds/kao_tapu.png');
    final isLocked = matchState.currentRoom?.isLocked ?? (roomType == 'create');

    final myUid =
        chatState.currentUserId ??
        ref.watch(authNotifierProvider).user?.uid ??
        '';
    final myDisplayName = _myDisplayName.isNotEmpty
        ? _myDisplayName
        : (ref.watch(authNotifierProvider).user?.displayName ?? '');

    final roomUsers = matchState.currentRoom?.users ?? [];
    // Filter to live users only. When presenceMembers is null (subscription not
    // yet delivered), fall back to the full list to avoid an empty banner flash.
    final presenceMembers = chatState.presenceMembers;
    final liveUsers = presenceMembers == null
        ? roomUsers
        : roomUsers.where((uid) => presenceMembers.contains(uid)).toList();
    final members = liveUsers.isEmpty
        ? ['Me']
        : roomUsers
              .map(
                (uid) =>
                    uid == myUid ? 'Me' : (_memberNameCache[uid] ?? 'User'),
              )
              .toList();

    // Load each non-self member's avatar decoration reactively. The provider
    // is autoDispose+family so each slot is independent and cleans up on leave.
    final memberAvatarStates = <String, AvatarState>{};
    // Display-name keyed variant for MembersPanelBody (which works with names).
    final memberAvatarByName = <String, AvatarState>{};
    for (final uid in roomUsers) {
      final displayName = uid == myUid
          ? 'Me'
          : (_memberNameCache[uid] ?? 'User');
      if (uid == myUid) {
        memberAvatarByName[displayName] = avatarState;
        continue;
      }
      final deco = ref.watch(avatarDecorationByUidProvider(uid)).asData?.value;
      final state = AvatarState(
        mood: AvatarOverlays.mood[deco?.moodKey ?? ''],
        accessory: AvatarOverlays.accessory[deco?.hatKey ?? ''],
      );
      if (deco != null) _memberAvatarCache[uid] = state;
      memberAvatarStates[uid] = state;
      memberAvatarByName[displayName] = state;
    }

    ref.listen(chatNotifierProvider.select((s) => s.status), (_, next) {
      if (next == SessionStatus.disconnected) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });

    // Accumulate names from incoming messages into the persistent cache.
    // Also flush any pending hop-in bubbles that were waiting for a name.
    ref.listen(chatNotifierProvider.select((s) => s.messages), (_, msgs) {
      bool changed = false;
      for (final m in msgs) {
        // Skip email-like strings — Firebase Auth may use the Gmail address as
        // the displayName before the user sets a profile username. The profile
        // load (which always wins) will overwrite with the real username once
        // it arrives. Showing 'User' is better than showing an email address.
        if (m.senderId != myUid &&
            m.displayName.isNotEmpty &&
            !m.displayName.contains('@') &&
            !_memberInterestCache.containsKey(m.senderId)) {
          _memberNameCache[m.senderId] = m.displayName;
          _uidByDisplayName[m.displayName] = m.senderId;
          changed = true;
        }
      }
      for (final uid in List<String>.from(_pendingJoinUids.keys)) {
        final name = _memberNameCache[uid];
        if (name != null &&
            name.isNotEmpty &&
            _memberInterestCache.containsKey(uid)) {
          _localMessages.add((
            msg: _GroupMsg(type: _MsgType.system, text: '$name hop in'),
            seq: _pendingJoinUids[uid]!,
          ));
          _pendingJoinUids.remove(uid);
          changed = true;
        }
      }
      if (changed) setState(() {});
    });

    // Accumulate names from typing events (transient, but populates early).
    // Also flush pending hop-ins whose name just became known.
    ref.listen(chatNotifierProvider.select((s) => s.typingUsers), (_, users) {
      bool changed = false;
      for (final u in users) {
        if (u.displayName.isNotEmpty &&
            !u.displayName.contains('@') &&
            !_memberInterestCache.containsKey(u.uid)) {
          _memberNameCache[u.uid] = u.displayName;
          _uidByDisplayName[u.displayName] = u.uid;
          changed = true;
        }
      }
      for (final uid in List<String>.from(_pendingJoinUids.keys)) {
        final name = _memberNameCache[uid];
        if (name != null &&
            name.isNotEmpty &&
            _memberInterestCache.containsKey(uid)) {
          _localMessages.add((
            msg: _GroupMsg(type: _MsgType.system, text: '$name hop in'),
            seq: _pendingJoinUids[uid]!,
          ));
          _pendingJoinUids.remove(uid);
          changed = true;
        }
      }
      if (changed) setState(() {});
    });

    // Detect new members joining (including self) and show hop-in bubbles.
    // Self is included so the current user sees their own name appear when they
    // first enter the room, and sees pre-existing members' names too (the
    // listener fires with prevSet = {} on the initial users snapshot).
    ref.listen(
      matchmakingNotifierProvider.select(
        (s) => s.currentRoom?.users ?? const <String>[],
      ),
      (prev, next) {
        final prevSet = (prev ?? const []).toSet();
        final newUidList = next.where((uid) => !prevSet.contains(uid)).toList();
        if (newUidList.isEmpty) return;
        // Load Firestore profiles for non-self newcomers so interest/thoughts
        // are available on tap and the correct username overwrites any interim
        // auth display name.
        _loadMemberProfiles(newUidList.where((uid) => uid != myUid).toList());
        bool changed = false;
        for (final uid in newUidList) {
          final seq = ref.read(chatNotifierProvider).messages.length;
          if (uid == myUid) {
            // Own hop-in. Prefer _myDisplayName (Firestore profile — always
            // reflects the latest username change). Firebase Auth displayName
            // is NOT updated by updateDisplayName, so it may be stale or null
            // for anonymous users. If neither is ready, park in _pendingJoinUids
            // so the initState profile-load callback can flush it with the
            // correct, fresh name.
            final name = _myDisplayName.isNotEmpty ? _myDisplayName : '';
            if (name.isNotEmpty) {
              _localMessages.add((
                msg: _GroupMsg(type: _MsgType.system, text: '$name hop in'),
                seq: seq,
              ));
              changed = true;
            } else {
              _pendingJoinUids[uid] = seq;
            }
          } else {
            final name = _memberNameCache[uid];
            // Only show hop-in immediately when we already have the profile
            // username (indicated by _memberInterestCache having an entry).
            // Otherwise park in _pendingJoinUids; _loadMemberProfiles will
            // flush it once the Firestore profile arrives, ensuring we never
            // display a Gmail / auth display-name.
            if (name != null &&
                name.isNotEmpty &&
                _memberInterestCache.containsKey(uid)) {
              _localMessages.add((
                msg: _GroupMsg(type: _MsgType.system, text: '$name hop in'),
                seq: seq,
              ));
              changed = true;
            } else {
              _pendingJoinUids[uid] = seq;
            }
          }
        }
        if (changed) {
          setState(() {});
          _scrollToBottom();
        }
      },
    );

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
        if (!didPop) {
          showDialog(
            context: context,
            builder: (_) => LeaveRoomDialog(
              onLeave: () {
                ref.read(matchmakingNotifierProvider.notifier).leaveRoom();
                ref.read(chatNotifierProvider.notifier).forceDisconnect();
              },
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        body: Column(
          children: [
            // ── Header always rendered last in layout = visually on top ──
            buildHeader(roomName, roomId, isLocked),
            // ── Content + slide-down panel clipped together ──
            Expanded(
              child: ClipRect(
                child: Stack(
                  children: [
                    // Main content
                    Column(
                      children: [
                        buildBanner(
                          bgImage,
                          maxMembers,
                          avatarState,
                          myDisplayName,
                          members,
                          _myInterest,
                          roomUsers,
                          memberAvatarStates,
                        ),
                        Expanded(
                          child: Stack(
                            children: [
                              buildMessageList(
                                avatarState,
                                chatState,
                                memberAvatarStates,
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
                        buildInputBar(),
                      ],
                    ),
                    // Barrier — tap outside to close whichever panel is open
                    if (_panelOpen || _songPanelOpen)
                      ExcludeSemantics(
                        child: GestureDetector(
                          onTap: _panelOpen ? _closePanel : _closeSongPanel,
                          behavior: HitTestBehavior.opaque,
                          child: AnimatedOpacity(
                            opacity: 1.0,
                            duration: const Duration(milliseconds: 260),
                            child: Container(color: Colors.black26),
                          ),
                        ),
                      ),
                    // Slide-down members panel
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SlideTransition(
                        position: _panelSlide,
                        child: MembersPanelBody(
                          members: members,
                          memberUids: roomUsers,
                          onClose: _closePanel,
                          avatarState: avatarState,
                          pendingUids: ref
                              .watch(friendsNotifierProvider)
                              .outgoingRequests
                              .map((r) => r.toUid)
                              .toSet(),
                          friendUids: ref
                              .watch(friendsNotifierProvider)
                              .friends
                              .map((f) => f.friendUid)
                              .toSet(),
                          onAddFriend: (uid) {
                            final name = _memberNameCache[uid] ?? 'User';
                            _addFriend(uid, name);
                          },
                          onCancelRequest: (uid) {
                            final name = _memberNameCache[uid] ?? 'User';
                            _cancelFriendRequest(uid, name);
                          },
                          onReport: _openReport,
                          memberAvatarStates: memberAvatarByName,
                        ),
                      ),
                    ),
                    // Song panel — always in tree so audio survives panel close.
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SlideTransition(
                        position: _songSlide,
                        child: SongPanelBody(
                          onClose: _closeSongPanel,
                          roomId: roomId,
                          isVisible: _songPanelOpen,
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
  Widget buildHeader(String roomName, String roomId, bool isLocked) {
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
                // Back button
                Semantics(
                  label: 'End chat',
                  button: true,
                  child: headerBtn(
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => LeaveRoomDialog(
                        onLeave: () {
                          ref
                              .read(matchmakingNotifierProvider.notifier)
                              .leaveRoom();
                          ref
                              .read(chatNotifierProvider.notifier)
                              .forceDisconnect();
                        },
                      ),
                    ),
                    child: SvgPicture.asset(
                      'assets/images/icons/Back.svg',
                      width: 24,
                      height: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Room name + ID
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        roomName,
                        style: Theme.of(context).textTheme.titleLarge!.copyWith(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Room ID:   $roomId',
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Lock toggle
                Semantics(
                  label: 'Toggle room lock',
                  button: true,
                  child: GestureDetector(
                    onTap: () {
                      ref
                          .read(matchmakingNotifierProvider.notifier)
                          .setRoomLock(isLocked: !isLocked);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 60,
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: isLocked
                            ? const Color(0xFFBA5F3A)
                            : const Color(0xFFD9D9D9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Stack(
                        children: [
                          AnimatedAlign(
                            duration: const Duration(milliseconds: 200),
                            alignment: isLocked
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Icon(
                                isLocked
                                    ? Icons.lock_rounded
                                    : Icons.lock_open_rounded,
                                size: 16,
                                color: isLocked
                                    ? const Color(0xFFBA5F3A)
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Member list button
                Semantics(
                  label: 'View member list',
                  button: true,
                  child: headerBtn(
                    onTap: _panelOpen ? _closePanel : _openPanel,
                    child: SvgPicture.asset(
                      'assets/images/icons/memberlist.svg',
                      width: 26,
                      height: 26,
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

  Widget headerBtn({required Widget child, required VoidCallback onTap}) {
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

  // ── Banner with dynamic avatars ────────────────────────────────────────────
  Widget buildBanner(
    String bgImage,
    int maxMembers,
    AvatarState avatarState,
    String myDisplayName,
    List<String> members,
    String myInterest,
    List<String> roomUsers,
    Map<String, AvatarState> memberAvatarStates,
  ) {
    final count = members.length.clamp(1, 5);
    final preset = _layouts[count];

    final bannerHeight = count >= 5 ? 270.0 : 250.0;
    return SizedBox(
      height: bannerHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          return Stack(
            children: [
              // Background image
              Positioned.fill(
                child: Image.asset(
                  bgImage,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      Container(color: Colors.grey.shade300),
                ),
              ),
              // Member count badge
              Positioned(
                top: 14,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${members.length} / $maxMembers',
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
              // Avatars + thought bubbles — positioned by layout preset
              ...List.generate(count, (i) {
                final pos = preset[i];
                final username = members[i];
                final isMe = username == 'Me';
                final displayName = isMe ? myDisplayName : username;
                final memberUid = i < roomUsers.length ? roomUsers[i] : null;
                final thought = isMe
                    ? _myThoughts
                    : (memberUid != null &&
                              _memberThoughtsCache[memberUid]?.isNotEmpty ==
                                  true
                          ? _memberThoughtsCache[memberUid]!
                          : 'Care to share?');
                final rawScale = pos.size / 90;
                final scale = rawScale.clamp(0.78, 1.0);
                final bubbleW = 84 * scale;
                final bubbleH = 94 * scale;
                return Positioned(
                  left: w * pos.x,
                  bottom: pos.bottom,
                  child: SizedBox(
                    width: pos.size,
                    height: pos.size + bubbleH * 0.75,
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
                                username: displayName,
                                isMe: isMe,
                                interest: isMe
                                    ? myInterest
                                    : (memberUid != null
                                          ? _memberInterestCache[memberUid]
                                          : null),
                                friendStatus: (!isMe && memberUid != null)
                                    ? _friendStatus(memberUid)
                                    : AddFriendStatus.notAdded,
                                onAddFriend: (isMe || memberUid == null)
                                    ? null
                                    : () => _addFriend(memberUid, displayName),
                                onCancelRequest: (isMe || memberUid == null)
                                    ? null
                                    : () => _cancelFriendRequest(
                                        memberUid,
                                        displayName,
                                      ),
                                onReport: isMe
                                    ? null
                                    : () => reportUser(displayName),
                                avatarState: isMe
                                    ? avatarState
                                    : (memberUid != null
                                          ? memberAvatarStates[memberUid]
                                          : null),
                                uid: isMe ? null : memberUid,
                              ),
                            ),
                            child: LayeredAvatar(
                              boxSize: pos.size,
                              moodOverlay: isMe
                                  ? avatarState.mood
                                  : (memberUid != null
                                        ? memberAvatarStates[memberUid]?.mood
                                        : null),
                              accessoryOverlay: isMe
                                  ? avatarState.accessory
                                  : (memberUid != null
                                        ? memberAvatarStates[memberUid]
                                              ?.accessory
                                        : null),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: pos.size * 0.94,
                          left: (pos.size - bubbleW) / 2,
                          child: Container(
                            width: bubbleW,
                            height: bubbleH,
                            decoration: const BoxDecoration(
                              image: DecorationImage(
                                image: AssetImage(
                                  'assets/images/chat_t_bubble.png',
                                ),
                                fit: BoxFit.contain,
                              ),
                            ),
                            padding: EdgeInsets.all(9 * scale),
                            alignment: Alignment.center,
                            child: Text(
                              thought,
                              style: TextStyle(
                                fontSize: (10 * scale).clamp(8.0, 11.0),
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
                  ),
                );
              }),
              // Song / Topic buttons
              Positioned(
                bottom: 10,
                right: 10,
                child: Column(
                  children: [
                    sideBtn(
                      'Song',
                      'assets/images/icons/song.svg',
                      _openSongPanel,
                    ),
                    const SizedBox(height: 10),
                    sideBtn(
                      'Topic',
                      'assets/images/icons/card.svg',
                      _sendTopicCard,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget sideBtn(String label, String svgPath, VoidCallback onTap) {
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
              style: Theme.of(context).textTheme.labelSmall!.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Message list ──────────────────────────────────────────────────────────
  Widget buildMessageList(
    AvatarState avatarState,
    ChatState chatState,
    Map<String, AvatarState> memberAvatarStates,
  ) {
    final backendMsgs = chatState.messages
        .map((m) => toGroupDisplay(m, chatState.currentUserId))
        .toList();
    final merged = <_GroupMsg>[
      _GroupMsg(type: _MsgType.warning, text: kWarning),
    ];
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
          return const _GroupTypingIndicator();
        }
        final msg = displayMessages[i];
        return switch (msg.type) {
          _MsgType.warning => buildWarning(msg.text),
          _MsgType.system => buildSystem(msg),
          _MsgType.card => buildCard(msg.text, shufflerName: msg.shufflerName),
          _MsgType.gif => buildGifBubble(
            msg,
            avatarState,
            memberAvatarStates,
            isMe: true,
          ),
          _MsgType.gifOther => buildGifBubble(
            msg,
            avatarState,
            memberAvatarStates,
            isMe: false,
          ),
          _ => buildChatBubble(msg, avatarState, memberAvatarStates),
        };
      },
    );
  }

  Widget buildWarning(String text) {
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
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
          color: const Color(0xFF836151),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget buildSystem(_GroupMsg msg) {
    return Column(
      children: [
        if (msg.time != null) ...[
          const SizedBox(height: 8),
          Text(
            msg.time!,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              fontSize: 12,
              color: Colors.black.withValues(alpha: 0.60),
            ),
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
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget buildChatBubble(
    _GroupMsg msg,
    AvatarState avatarState,
    Map<String, AvatarState> memberAvatarStates,
  ) {
    final isMe = msg.type == _MsgType.me;
    final maxW = MediaQuery.of(context).size.width * 0.60;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar (others only)
          if (!isMe) ...[
            Builder(
              builder: (ctx) {
                final senderUid = _uidByDisplayName[msg.sender ?? ''];
                final memberState = senderUid != null
                    ? (memberAvatarStates[senderUid] ??
                          _memberAvatarCache[senderUid])
                    : null;
                return GestureDetector(
                  onTap: () => showDialog(
                    context: ctx,
                    builder: (_) {
                      final profileName = senderUid != null
                          ? (_memberNameCache[senderUid] ?? msg.sender ?? '')
                          : (msg.sender ?? '');
                      return UserProfileDialog(
                        username: profileName,
                        interest: senderUid != null
                            ? _memberInterestCache[senderUid]
                            : null,
                        avatarState: memberState,
                        uid: senderUid,
                        friendStatus: senderUid != null
                            ? _friendStatus(senderUid)
                            : AddFriendStatus.notAdded,
                        onAddFriend: senderUid != null
                            ? () => _addFriend(senderUid, profileName)
                            : null,
                        onCancelRequest: senderUid != null
                            ? () => _cancelFriendRequest(senderUid, profileName)
                            : null,
                        onReport: () => reportUser(msg.sender ?? ''),
                      );
                    },
                  ),
                  child: LayeredAvatar(
                    boxSize: 40,
                    moodOverlay: memberState?.mood,
                    accessoryOverlay: memberState?.accessory,
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
          ],
          // Bubble + timestamp
          Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (!isMe)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    msg.sender ?? '',
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isMe) ...[
                    Text(
                      msg.time ?? '',
                      style: Theme.of(context).textTheme.labelSmall!.copyWith(
                        fontSize: 10,
                        color: Colors.black.withValues(alpha: 0.60),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    constraints: BoxConstraints(maxWidth: maxW),
                    clipBehavior: Clip.hardEdge,
                    decoration: BoxDecoration(
                      color: isMe
                          ? const Color(0xFFF1CEE4)
                          : const Color(0xFFDCEBCE),
                      borderRadius: BorderRadius.circular(18),
                      border: isMe ? null : Border.all(color: Colors.black12),
                    ),
                    child: Text(
                      msg.text,
                      style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                        fontSize: 15,
                        height: 1.6,
                      ),
                    ),
                  ),
                  if (!isMe) ...[
                    const SizedBox(width: 6),
                    Text(
                      msg.time ?? '',
                      style: Theme.of(context).textTheme.labelSmall!.copyWith(
                        fontSize: 10,
                        color: Colors.black.withValues(alpha: 0.60),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          // My avatar (right side)
          if (isMe) ...[
            const SizedBox(width: 8),
            LayeredAvatar(
              boxSize: 40,
              moodOverlay: avatarState.mood,
              accessoryOverlay: avatarState.accessory,
            ),
          ],
        ],
      ),
    );
  }

  Widget buildCard(String assetPath, {String? shufflerName}) {
    return _TopicCard(
      assetPath: assetPath,
      onShuffle: shuffleTopic,
      shufflerName: shufflerName,
    );
  }

  Widget buildGifBubble(
    _GroupMsg msg,
    AvatarState avatarState,
    Map<String, AvatarState> memberAvatarStates, {
    required bool isMe,
  }) {
    final maxW = MediaQuery.of(context).size.width * 0.55;
    final gifImage = ClipRRect(
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
    );
    final gifContainer = Container(
      constraints: BoxConstraints(maxWidth: maxW),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFFF1CEE4) : const Color(0xFFDCEBCE),
        borderRadius: BorderRadius.circular(18),
        border: isMe ? null : Border.all(color: Colors.black12),
      ),
      child: gifImage,
    );
    final timestamp = Text(
      msg.time ?? '',
      style: Theme.of(context).textTheme.labelSmall!.copyWith(
        fontSize: 10,
        color: Colors.black.withValues(alpha: 0.60),
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
            GestureDetector(
              onTap: () => showDialog(
                context: context,
                builder: (_) {
                  final senderUid = _uidByDisplayName[msg.sender ?? ''];
                  final profileName = senderUid != null
                      ? (_memberNameCache[senderUid] ?? msg.sender ?? '')
                      : (msg.sender ?? '');
                  return UserProfileDialog(
                    username: profileName,
                    interest: senderUid != null
                        ? _memberInterestCache[senderUid]
                        : null,
                    avatarState: senderUid != null
                        ? memberAvatarStates[senderUid]
                        : null,
                    uid: senderUid,
                    friendStatus: senderUid != null
                        ? _friendStatus(senderUid)
                        : AddFriendStatus.notAdded,
                    onAddFriend: senderUid != null
                        ? () => _addFriend(senderUid, profileName)
                        : null,
                    onCancelRequest: senderUid != null
                        ? () => _cancelFriendRequest(senderUid, profileName)
                        : null,
                    onReport: () => reportUser(msg.sender ?? ''),
                  );
                },
              ),
              child: LayeredAvatar(boxSize: 40),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    msg.sender ?? '',
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [gifContainer, const SizedBox(width: 6), timestamp],
                ),
              ],
            ),
          ] else ...[
            timestamp,
            const SizedBox(width: 6),
            gifContainer,
            const SizedBox(width: 8),
            LayeredAvatar(
              boxSize: 40,
              moodOverlay: avatarState.mood,
              accessoryOverlay: avatarState.accessory,
            ),
          ],
        ],
      ),
    );
  }

  // ── Input bar ─────────────────────────────────────────────────────────────
  Widget buildInputBar() {
    return Container(
      color: const Color(0xFF6B5E5B),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_pendingGifUrl != null) buildGifPreview(),
          buildInputRow(),
        ],
      ),
    );
  }

  Widget buildGifPreview() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              _pendingGifUrl!,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox(
                width: 60,
                height: 60,
                child: Icon(Icons.gif, color: Colors.white, size: 32),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'GIF ready to send',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Semantics(
            label: 'Close GIF preview',
            button: true,
            child: GestureDetector(
              onTap: () => setState(() => _pendingGifUrl = null),
              child: const Icon(Icons.close, color: Colors.white70, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildInputRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
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
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge!.copyWith(fontSize: 15),
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
          Semantics(
            label: 'Send message',
            button: true,
            child: GestureDetector(
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
  final String? shufflerName;
  const _TopicCard({
    required this.assetPath,
    required this.onShuffle,
    this.shufflerName,
  });

  @override
  State<_TopicCard> createState() => _TopicCardState();
}

class _TopicCardState extends State<_TopicCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController ctrl;
  late final Animation<double> scale;
  late final Animation<double> rotate;

  @override
  void initState() {
    super.initState();
    ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.90), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 0.90, end: 1.06), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.06, end: 1.00), weight: 25),
    ]).animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOut));
    rotate = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.04), weight: 30),
      TweenSequenceItem(tween: Tween(begin: -0.04, end: 0.04), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.04, end: 0.0), weight: 30),
    ]).animate(CurvedAnimation(parent: ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  void handleShuffle() {
    ctrl.forward(from: 0);
    widget.onShuffle();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 8),
          if (widget.shufflerName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${widget.shufflerName} shuffled the card',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9E8272),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          AnimatedBuilder(
            animation: ctrl,
            builder: (_, child) => Transform.rotate(
              angle: rotate.value,
              child: Transform.scale(scale: scale.value, child: child),
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
            onTap: handleShuffle,
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

// ── Group typing indicator ────────────────────────────────────────────────
class _GroupTypingIndicator extends StatefulWidget {
  const _GroupTypingIndicator();

  @override
  State<_GroupTypingIndicator> createState() => _GroupTypingIndicatorState();
}

class _GroupTypingIndicatorState extends State<_GroupTypingIndicator>
    with TickerProviderStateMixin {
  late final List<AnimationController> controllers;
  late final List<Animation<double>> anims;

  @override
  void initState() {
    super.initState();
    controllers = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 380),
      ),
    );
    anims = controllers
        .map(
          (c) => Tween<double>(
            begin: 0,
            end: -7,
          ).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)),
        )
        .toList();
    startLoop();
  }

  Future<void> startLoop() async {
    while (mounted) {
      for (int i = 0; i < 3; i++) {
        if (!mounted) return;
        await controllers[i].forward();
        if (!mounted) return;
        await controllers[i].reverse();
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  @override
  void dispose() {
    for (final c in controllers) {
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
                  animation: anims[i],
                  builder: (_, _) => Transform.translate(
                    offset: Offset(0, anims[i].value),
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
