import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/friend_request.dart' show FriendRequestStatus;
import '../providers/friends_provider.dart';
import 'friends_list_screen.dart';

class FriendsTestScreen extends ConsumerWidget {
  const FriendsTestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final friendsState = ref.watch(friendsNotifierProvider);

    ref.listen<FriendsState>(friendsNotifierProvider, (_, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: Colors.red),
        );
        ref.read(friendsNotifierProvider.notifier).clearError();
      }
    });

    final friendUids = friendsState.friends.map((f) => f.friendUid).toSet();
    final incomingUids = friendsState.incomingRequests
        .where((r) => r.status == FriendRequestStatus.pending)
        .map((r) => r.fromUid)
        .toSet();

    return Scaffold(
      appBar: AppBar(title: const Text('Friends — Dev Test')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(label: 'Signed-in as'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    authState.user?.displayName ?? 'Anonymous',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    authState.user?.uid ?? '—',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const FriendsListScreen(),
              ),
            ),
            icon: const Icon(Icons.people),
            label: Text(
              'My Friends & Requests'
              '  (${friendsState.friends.length} friends'
              ' · ${friendsState.incomingRequests.length} pending)',
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader(label: 'All users — tap to send friend request'),
          if (friendsState.allUsers.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No other users found.'),
            )
          else
            ...friendsState.allUsers.map(
              (user) => _UserTile(
                user: user,
                isFriend: friendUids.contains(user.uid),
                hasIncoming: incomingUids.contains(user.uid),
                isLoading: friendsState.isLoading,
                onAdd: () => ref
                    .read(friendsNotifierProvider.notifier)
                    .sendFriendRequest(user),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final AppUser user;
  final bool isFriend;
  final bool hasIncoming;
  final bool isLoading;
  final VoidCallback onAdd;

  const _UserTile({
    required this.user,
    required this.isFriend,
    required this.hasIncoming,
    required this.isLoading,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final name = user.displayName.isNotEmpty ? user.displayName : 'Unknown';
    final Widget trailing;
    if (isFriend) {
      trailing = const Chip(label: Text('Friends'));
    } else if (hasIncoming) {
      trailing = const Chip(label: Text('Respond'));
    } else {
      trailing = OutlinedButton(
        onPressed: isLoading ? null : onAdd,
        child: const Text('Add'),
      );
    }
    return ListTile(
      leading: CircleAvatar(child: Text(name[0].toUpperCase())),
      title: Text(name),
      subtitle: Text(user.uid, style: Theme.of(context).textTheme.bodySmall),
      trailing: trailing,
    );
  }
}
