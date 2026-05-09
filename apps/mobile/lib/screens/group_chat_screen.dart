import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../dialogs/leave_room_dialog.dart';
import '../dialogs/song_dialog.dart';
import '../dialogs/user_profile_dialog.dart';
import '../dialogs/members_list_dialog.dart';

enum _MsgType { warning, system, me, other, card }

class _GroupMsg {
  final _MsgType type;
  final String text;
  final String? sender;
  final String? time;

  const _GroupMsg({
    required this.type,
    required this.text,
    this.sender,
    this.time,
  });
}

class GroupChatScreen extends StatefulWidget {
  const GroupChatScreen({super.key});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  bool isLocked = false;
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final List<String> topics = [
    "What drink do you usually order?\nWhy do you like it?",
    "Is there anything you haven't done\nyet but would like to try?",
    "What is your favorite movie\nand why?",
    "If you could travel anywhere,\nwhere would you go?",
    "What's a hobby you'd love\nto pick up someday?",
  ];

  int _currentTopicIndex = 0;

  void _sendTopicCard() {
    setState(() {
      messages.add(_GroupMsg(
        type: _MsgType.card,
        text: topics[_currentTopicIndex % topics.length],
      ));
    });
    _scrollToBottom();
  }

  void _shuffleTopic() {
    setState(() {
      _currentTopicIndex = (_currentTopicIndex + 1) % topics.length;
      messages.add(const _GroupMsg(
          type: _MsgType.system, text: 'Someone shuffled the topic!'));
      messages.add(_GroupMsg(
          type: _MsgType.card, text: topics[_currentTopicIndex]));
    });
    _scrollToBottom();
  }

  final List<_GroupMsg> messages = [
    const _GroupMsg(
      type: _MsgType.warning,
      text:
          'Keep it friendly! Please be respectful and protect your personal info. Report any suspicious behavior to help keep our community safe.',
    ),
    const _GroupMsg(type: _MsgType.system, text: 'Kaitom Hop in'),
    const _GroupMsg(
        type: _MsgType.other,
        sender: 'Kaitom',
        text: 'Hellooooooooooooooo\noooooooooooooooo.',
        time: '10:00 pm'),
    const _GroupMsg(
        type: _MsgType.other,
        sender: 'Somjeed',
        text: 'Hello.',
        time: '10:05 pm'),
    const _GroupMsg(
        type: _MsgType.me,
        sender: 'Me',
        text: 'Hello 🍪🙏🔥😣',
        time: '10:10 pm'),
  ];

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    if (_msgController.text.trim().isEmpty) return;
    setState(() {
      messages.add(_GroupMsg(
        type: _MsgType.me,
        sender: 'Me',
        text: _msgController.text,
        time: 'Now',
      ));
    });
    _msgController.clear();
    _scrollToBottom();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final roomName = args?['roomName'] ?? 'Room Name';
    final bgImage = args?['bgImage'] ?? 'assets/images/kao_tapu.png';

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppColors.brownDeep,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(35),
              ),
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
                      onTap: () => showDialog(
                          context: context,
                          builder: (_) => const LeaveRoomDialog()),
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
                              color: Colors.grey.shade300, width: 1.5),
                        ),
                        child: const Icon(Icons.chevron_left,
                            color: Colors.black, size: 30),
                      ),
                    ),
                    const SizedBox(width: 12),
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
                                fontWeight: FontWeight.bold),
                          ),
                          const Text('Room ID: ABP8C',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => isLocked = !isLocked),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 65,
                            height: 35,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
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
                                    width: 28,
                                    height: 28,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                            color: Colors.black12,
                                            blurRadius: 4)
                                      ],
                                    ),
                                    child: Icon(
                                      isLocked
                                          ? Icons.lock_rounded
                                          : Icons.lock_open_rounded,
                                      size: 18,
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
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => showDialog(
                              context: context,
                              builder: (_) => const MembersListDialog()),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 4)
                              ],
                            ),
                            child: const Icon(Icons.groups_rounded,
                                color: Colors.black, size: 28),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            height: 250,
            width: double.infinity,
            child: Stack(
              children: [
                Positioned.fill(child: Image.asset(bgImage, fit: BoxFit.cover)),
                Positioned(
                  top: 15,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(20)),
                      child: const Text('3 / 5',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                _buildAvatar(bottom: 20, left: 30, username: 'Somtum'),
                _buildAvatar(bottom: 40, left: 140, username: 'Kaitom'),
                _buildAvatar(bottom: 10, right: 150, username: 'Somjeed'),
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: Column(
                    children: [
                      _sidebarBtn(
                          Icons.music_note,
                          'Song',
                          () => showDialog(
                              context: context,
                              builder: (_) => const SongDialog())),
                      const SizedBox(height: 10),
                      _sidebarBtn(Icons.style, 'Topic', _sendTopicCard),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                if (msg.type == _MsgType.warning) return _buildWarning(msg.text);
                if (msg.type == _MsgType.system) return _buildSystem(msg.text);
                if (msg.type == _MsgType.card) return _buildCard(msg.text);
                return _buildChatBubble(msg);
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16).copyWith(bottom: 30),
            color: const Color(0xFF6B5E5B),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: 'Type here...',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 55,
                    height: 55,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAC163),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.send_rounded,
                        color: Color(0xFF6B5E5B), size: 28),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(
      {double? bottom, double? left, double? right, required String username}) {
    return Positioned(
      bottom: bottom,
      left: left,
      right: right,
      child: GestureDetector(
        onTap: () => showDialog(
            context: context,
            builder: (_) => UserProfileDialog(username: username)),
        child: Image.asset('assets/images/UserAvatar.png', width: 75),
      ),
    );
  }

  Widget _sidebarBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: Colors.black),
            Text(label,
                style:
                    const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBubble(_GroupMsg msg) {
    final isMe = msg.type == _MsgType.me;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe)
            GestureDetector(
              onTap: () => showDialog(
                  context: context,
                  builder: (_) =>
                      UserProfileDialog(username: msg.sender ?? '')),
              child: const CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white,
                backgroundImage: AssetImage('assets/images/UserAvatar.png'),
              ),
            ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMe)
                Text(msg.sender ?? '',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isMe)
                    Text(msg.time ?? '',
                        style:
                            const TextStyle(fontSize: 10, color: Colors.grey)),
                  if (isMe) const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.6),
                    decoration: BoxDecoration(
                      color: isMe
                          ? const Color(0xFFF1CEE4)
                          : const Color(0xFFDCEBCE),
                      borderRadius: BorderRadius.circular(18),
                      border: isMe ? null : Border.all(color: Colors.black12),
                    ),
                    child:
                        Text(msg.text, style: const TextStyle(fontSize: 15)),
                  ),
                  if (!isMe) const SizedBox(width: 8),
                  if (!isMe)
                    Text(msg.time ?? '',
                        style:
                            const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ],
          ),
          if (isMe) const SizedBox(width: 8),
          if (isMe)
            const CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white,
              backgroundImage: AssetImage('assets/images/UserAvatar.png'),
            ),
        ],
      ),
    );
  }

  Widget _buildCard(String text) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          width: 180,
          height: 260,
          decoration: BoxDecoration(
            color: const Color(0xFFF2E9DD),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF5A443A), width: 4),
          ),
          child: Column(
            children: [
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5A443A),
                    height: 1.4,
                  ),
                ),
              ),
              const Spacer(),
              const Text(
                'COZY',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF5A443A),
                  letterSpacing: 2,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        GestureDetector(
          onTap: _shuffleTopic,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEAC163),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: const Text(
              'shuffle',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Color(0xFF6B5E5B)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWarning(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
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
            fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildSystem(String text) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
            border: Border.all(color: Colors.black26),
            borderRadius: BorderRadius.circular(20)),
        child: Text(text,
            style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ),
    );
  }
}
