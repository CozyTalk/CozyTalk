import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/friend_chat_provider.dart';
import '../providers/friends_provider.dart';

class FriendDirectChatScreen extends ConsumerStatefulWidget {
  final String chatRoomId;
  final String friendDisplayName;
  final String friendshipId;

  const FriendDirectChatScreen({
    super.key,
    required this.chatRoomId,
    required this.friendDisplayName,
    required this.friendshipId,
  });

  @override
  ConsumerState<FriendDirectChatScreen> createState() =>
      _FriendDirectChatScreenState();
}

class _FriendDirectChatScreenState
    extends ConsumerState<FriendDirectChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late final FriendChatNotifier _chatNotifier;

  @override
  void initState() {
    super.initState();
    _chatNotifier = ref.read(friendChatNotifierProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatNotifier.enterChat(widget.chatRoomId, widget.friendDisplayName);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _chatNotifier.leaveChat();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    _chatNotifier.sendMessage(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(friendChatNotifierProvider);
    final currentUid = ref.watch(authNotifierProvider).user?.uid ?? '';

    ref.listen<FriendChatState>(friendChatNotifierProvider, (prev, next) {
      if (next.messages.length != (prev?.messages.length ?? 0)) {
        _scrollToBottom();
      }
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: Colors.red),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.friendDisplayName),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'remove') {
                _confirmRemove(context);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'remove',
                child: Text('Remove friend'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (state.isLoading) const LinearProgressIndicator(),
          Expanded(
            child: state.messages.isEmpty && !state.isLoading
                ? const Center(child: Text('No messages yet. Say hello!'))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: state.messages.length,
                    itemBuilder: (context, i) {
                      final msg = state.messages[i];
                      final isMine = msg.senderId == currentUid;
                      return _MessageBubble(
                        text: msg.text,
                        senderName: msg.senderDisplayName,
                        timestamp: msg.timestamp,
                        isMine: isMine,
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.only(
              left: 12,
              right: 8,
              top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Message…',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: state.isSending ? null : (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: state.isSending ? null : _send,
                  icon: state.isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmRemove(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove friend?'),
        content: Text(
          'Remove ${widget.friendDisplayName} from your friends list?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(friendsNotifierProvider.notifier)
                  .removeFriend(widget.friendshipId);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final String senderName;
  final DateTime timestamp;
  final bool isMine;

  const _MessageBubble({
    required this.text,
    required this.senderName,
    required this.timestamp,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bubbleColor = isMine
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest;
    final textColor = isMine ? scheme.onPrimaryContainer : scheme.onSurface;
    final timeStr =
        '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!isMine)
              Text(
                senderName,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: scheme.primary,
                ),
              ),
            Text(text, style: TextStyle(color: textColor)),
            const SizedBox(height: 2),
            Text(
              timeStr,
              style: TextStyle(
                fontSize: 10,
                color: textColor.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
