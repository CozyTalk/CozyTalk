import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/app_user.dart';
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
  final bool isLoading;
  final VoidCallback onAdd;

  const _UserTile({
    required this.user,
    required this.isFriend,
    required this.isLoading,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(child: Text(user.displayName[0].toUpperCase())),
      title: Text(user.displayName),
      subtitle: Text(user.uid, style: Theme.of(context).textTheme.bodySmall),
      trailing: isFriend
          ? const Chip(label: Text('Friends'))
          : OutlinedButton(
              onPressed: isLoading ? null : onAdd,
              child: const Text('Add'),
            ),
    );
  }
}
