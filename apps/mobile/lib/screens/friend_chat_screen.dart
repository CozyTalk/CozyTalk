import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/friend.dart';
import '../dialogs/report_dialog.dart';

// Mock conversation history per friend name — ready to swap with real API
final Map<String, List<ChatMessage>> _mockConversations = {
  'Nong Prae': [
    const ChatMessage(text: 'Hello', isMe: false, time: '10:00 pm'),
    const ChatMessage(text: 'Hello 😊🔥💕😊', isMe: true, time: '10:00 pm'),
  ],
  'Somjeed': [
    const ChatMessage(text: 'How are you?', isMe: false, time: '9:30 am'),
    const ChatMessage(text: "I'm good, thanks!", isMe: true, time: '9:31 am'),
    const ChatMessage(text: 'How are you?', isMe: false, time: '9:32 am'),
  ],
  'Platoo': [
    const ChatMessage(text: 'How are you?', isMe: false, time: '8:00 pm'),
  ],
};

class FriendChatScreen extends StatefulWidget {
  const FriendChatScreen({super.key});

  @override
  State<FriendChatScreen> createState() => _FriendChatScreenState();
}

class _FriendChatScreenState extends State<FriendChatScreen> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  late Friend _friend;
  late List<ChatMessage> _messages;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _friend = ModalRoute.of(context)!.settings.arguments as Friend;
      _messages = List<ChatMessage>.from(
        _mockConversations[_friend.name] ??
            [
              ChatMessage(
                text: _friend.lastMessage,
                isMe: false,
                time: _formatNow(),
              ),
            ],
      );
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(ChatMessage(text: text, isMe: true, time: _formatNow()));
      _inputCtrl.clear();
    });
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

  String _formatNow() {
    final now = DateTime.now();
    final h = now.hour > 12
        ? now.hour - 12
        : now.hour == 0
        ? 12
        : now.hour;
    final m = now.minute.toString().padLeft(2, '0');
    final ampm = now.hour >= 12 ? 'pm' : 'am';
    return '$h:$m $ampm';
  }

  String _chatDateLabel() {
    final now = DateTime.now();
    const months = [
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
    return '${now.day} ${months[now.month - 1]} ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: ListView(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                _buildDateLabel(),
                _buildSafetyNotice(),
                const SizedBox(height: 8),
                ..._messages.map(_buildMessageBubble),
              ],
            ),
          ),
          _buildInputBar(),
        ],
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
          height: 80,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Back
                GestureDetector(
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
                    child: Image.asset(
                      'assets/images/Back.png',
                      width: 24,
                      height: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Avatar
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade300, width: 1.5),
                  ),
                  child: _friend.avatar.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            _friend.avatar,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.person,
                              color: Colors.grey,
                              size: 28,
                            ),
                          ),
                        )
                      : const Icon(Icons.person, color: Colors.grey, size: 28),
                ),
                const SizedBox(width: 10),
                // Name + online status
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _friend.name,
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
                              color: _friend.isOnline
                                  ? const Color(0xFF8DBB6F)
                                  : Colors.grey.shade400,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _friend.isOnline ? 'Online' : 'Offline',
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
                GestureDetector(
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) => const ReportDialog(),
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
                    child: const Icon(
                      Icons.flag_outlined,
                      color: Color(0xFFCF5733),
                      size: 22,
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
  Widget _buildDateLabel() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Text(
          _chatDateLabel(),
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
      ),
    );
  }

  // ─── Safety notice banner ───
  Widget _buildSafetyNotice() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.redOrange.withValues(alpha: 0.7),
          width: 1.5,
        ),
      ),
      child: const Text(
        'Keep it friendly! Please be respectful and protect your personal info.\n'
        'Report any suspicious behavior to help keep our community safe.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.5),
      ),
    );
  }

  // ─── Message bubble ───
  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: message.isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.65,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: message.isMe
                  ? const Color(0xFFF0BFD6) // pink – outgoing
                  : const Color(0xFFDEF1C2), // green – incoming
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: message.isMe
                    ? const Radius.circular(18)
                    : const Radius.circular(4),
                bottomRight: message.isMe
                    ? const Radius.circular(4)
                    : const Radius.circular(18),
              ),
            ),
            child: Text(
              message.text,
              style: const TextStyle(fontSize: 15, color: Colors.black87),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message.time,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  // ─── Bottom input bar ───
  Widget _buildInputBar() {
    return Container(
      color: AppColors.brownDeep,
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _inputCtrl,
                decoration: const InputDecoration(
                  hintText: 'Type here ...',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 50,
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.yellowWarm,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
