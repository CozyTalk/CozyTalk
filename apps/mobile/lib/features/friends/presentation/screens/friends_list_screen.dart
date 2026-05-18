import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/friend.dart';
import '../../domain/entities/friend_request.dart';
import '../providers/friends_provider.dart';
import 'friend_direct_chat_screen.dart';

class FriendsListScreen extends ConsumerStatefulWidget {
  const FriendsListScreen({super.key});

  @override
  ConsumerState<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends ConsumerState<FriendsListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(friendsNotifierProvider);

    ref.listen<FriendsState>(friendsNotifierProvider, (_, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: Colors.red),
        );
        ref.read(friendsNotifierProvider.notifier).clearError();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            const Tab(text: 'Friends'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Requests'),
                  if (state.incomingRequests.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Badge(label: Text('${state.incomingRequests.length}')),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _FriendsTab(friends: state.friends, isLoading: state.isLoading),
          _RequestsTab(
            requests: state.incomingRequests,
            isLoading: state.isLoading,
            onAccept: (r) =>
                ref.read(friendsNotifierProvider.notifier).acceptRequest(r),
            onDecline: (id) =>
                ref.read(friendsNotifierProvider.notifier).declineRequest(id),
          ),
        ],
      ),
    );
  }
}

class _FriendsTab extends StatelessWidget {
  final List<Friend> friends;
  final bool isLoading;

  const _FriendsTab({required this.friends, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    if (friends.isEmpty) {
      return const Center(child: Text('No friends yet — send some requests!'));
    }

    return ListView.builder(
      itemCount: friends.length,
      itemBuilder: (context, i) {
        final friend = friends[i];
        return ListTile(
          leading: CircleAvatar(
            child: Text(friend.friendDisplayName[0].toUpperCase()),
          ),
          title: Text(friend.friendDisplayName),
          subtitle: Text(
            'Since ${_formatDate(friend.friendedAt)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          trailing: const Icon(Icons.chat_bubble_outline),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => FriendDirectChatScreen(
                chatRoomId: friend.chatRoomId,
                friendDisplayName: friend.friendDisplayName,
                friendshipId: friend.friendshipId,
              ),
            ),
          ),
          onLongPress: () => _confirmRemove(context, friend),
        );
      },
    );
  }

  void _confirmRemove(BuildContext context, Friend friend) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove friend?'),
        content: Text(
          'Remove ${friend.friendDisplayName} from your friends list?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Access provider via the closest ProviderScope
              ProviderScope.containerOf(context)
                  .read(friendsNotifierProvider.notifier)
                  .removeFriend(friend.friendshipId);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
}

class _RequestsTab extends StatelessWidget {
  final List<FriendRequest> requests;
  final bool isLoading;
  final void Function(FriendRequest) onAccept;
  final void Function(String) onDecline;

  const _RequestsTab({
    required this.requests,
    required this.isLoading,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const Center(child: Text('No pending friend requests.'));
    }

    return ListView.builder(
      itemCount: requests.length,
      itemBuilder: (context, i) {
        final req = requests[i];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(child: Text(req.fromDisplayName[0].toUpperCase())),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        req.fromDisplayName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        req.fromUid,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: isLoading ? null : () => onAccept(req),
                      icon: const Icon(Icons.check_circle_outline),
                      color: Colors.green,
                      tooltip: 'Accept',
                    ),
                    IconButton(
                      onPressed: isLoading ? null : () => onDecline(req.id),
                      icon: const Icon(Icons.cancel_outlined),
                      color: Colors.red,
                      tooltip: 'Decline',
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
