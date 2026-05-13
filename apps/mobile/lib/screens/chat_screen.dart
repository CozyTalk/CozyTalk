import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../dialogs/leave_room_dialog.dart';
import '../dialogs/song_dialog.dart';
import '../dialogs/user_profile_dialog.dart';

class ChatMessage {
  final String type; // 'warning', 'system', 'me', 'other', 'card'
  final String text;
  final String? time;
  ChatMessage({required this.type, required this.text, this.time});
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  String friendMood = 'I love TikTok very much.';
  String myMood = 'Feeling cozy today! ☕';

  List<ChatMessage> messages = [
    ChatMessage(
      type: 'warning',
      text:
          'Keep it friendly! Please be respectful and protect your personal info. Report any suspicious behavior to help keep our community safe.',
    ),
    ChatMessage(type: 'system', text: 'Kaitom Hop in', time: '27 April 2026'),
    ChatMessage(type: 'other', text: 'Hello.', time: '10:00 pm'),
    ChatMessage(type: 'me', text: 'Hello 🍪🙏🔥😣', time: '10:00 pm'),
  ];

  final List<String> topics = [
    "What drink do you usually order?\nWhy do you like it?",
    "Is there anything you haven't done\nyet but would like to try?",
    "What is your favorite movie\nand why?",
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
      messages.add(
        ChatMessage(type: 'me', text: _msgController.text, time: 'Now'),
      );
    });
    _msgController.clear();
    _scrollToBottom();
    _focusNode.requestFocus();
  }

  void _sendTopicCard() {
    setState(() {
      messages.add(ChatMessage(type: 'card', text: topics[0]));
    });
    _scrollToBottom();
  }

  void _shuffleTopic() {
    setState(() {
      messages.add(
        ChatMessage(type: 'system', text: 'Kaitom, shuffle the topics!'),
      );
      messages.add(ChatMessage(type: 'card', text: topics[1]));
    });
    _scrollToBottom();
  }

  void _onWillPop() {
    showDialog(context: context, builder: (_) => const LeaveRoomDialog());
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final roomName = args?['roomName'] ?? 'Red Lotus Lake';
    final bgImage =
        args?['bgImage'] ?? 'assets/images/backgrounds/red_lotus_lake.png';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _onWillPop();
      },
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        body: Column(
          children: [
            Container(
              width: double.infinity,
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
                        onTap: () => showDialog(
                          context: context,
                          builder: (_) => const LeaveRoomDialog(),
                        ),
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
                          child: const Icon(
                            Icons.chevron_left,
                            color: Colors.black,
                            size: 30,
                          ),
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
                            const Text(
                              'Room ID: —',
                              style: TextStyle(
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

            SizedBox(
              height: 250,
              width: double.infinity,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      bgImage,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) =>
                          Container(color: Colors.grey.shade400),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _StaticAvatarWithMood(
                          username: 'kaitom',
                          moodText: friendMood,
                          isMe: false,
                        ),
                        const SizedBox(width: 16),
                        _StaticAvatarWithMood(
                          username: 'Me',
                          moodText: myMood,
                          isMe: true,
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Column(
                      children: [
                        _sideButton(
                          Icons.music_note,
                          'Song',
                          () => showDialog(
                            context: context,
                            builder: (_) => const SongDialog(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _sideButton(Icons.style, 'Topic', _sendTopicCard),
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
                  if (msg.type == 'warning') return _buildWarning(msg.text);
                  if (msg.type == 'system') return _buildSystem(msg.text);
                  if (msg.type == 'me') {
                    return _buildBubble(msg.text, msg.time ?? '', true);
                  }
                  if (msg.type == 'other') {
                    return _buildBubble(msg.text, msg.time ?? '', false);
                  }
                  if (msg.type == 'card') return _buildCard(msg.text);
                  return const SizedBox();
                },
              ),
            ),

            Container(
              padding: const EdgeInsets.all(16).copyWith(bottom: 32),
              color: const Color(0xFF6B5E5B),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      focusNode: _focusNode,
                      decoration: InputDecoration(
                        hintText: 'Type here ...',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAC163),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.send, color: Color(0xFF6B5E5B)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sideButton(IconData icon, String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
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
            Icon(icon, color: Colors.black, size: 24),
            Text(
              text,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
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
          fontWeight: FontWeight.w500,
        ),
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
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ),
    );
  }

  Widget _buildBubble(String text, String time, bool isMe) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe)
            GestureDetector(
              onTap: () => showDialog(
                context: context,
                builder: (_) => const UserProfileDialog(username: 'kaitom'),
              ),
              child: const CircleAvatar(
                backgroundColor: Colors.white,
                radius: 20,
                backgroundImage: AssetImage('assets/images/UserAvatar.png'),
              ),
            ),
          if (!isMe) const SizedBox(width: 8),
          if (isMe)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                time,
                style: const TextStyle(fontSize: 10, color: Colors.black54),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFFF1CEE4) : const Color(0xFFDCEBCE),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(text, style: const TextStyle(fontSize: 15)),
          ),
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                time,
                style: const TextStyle(fontSize: 10, color: Colors.black54),
              ),
            ),
          if (isMe) const SizedBox(width: 8),
          if (isMe)
            const CircleAvatar(
              backgroundColor: Colors.white,
              radius: 20,
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
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 4),
              ],
            ),
            child: const Text(
              'shuffle',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF6B5E5B),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StaticAvatarWithMood extends StatelessWidget {
  final String username;
  final String moodText;
  final bool isMe;

  const _StaticAvatarWithMood({
    required this.username,
    required this.moodText,
    required this.isMe,
  });

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
                builder: (_) => UserProfileDialog(username: username),
              ),
              child: Image.asset(
                'assets/images/UserAvatar.png',
                height: 90,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned(
            bottom: 75,
            left: isMe ? 15 : 0,
            right: isMe ? 0 : 15,
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
