import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/chat/presentation/screens/chat_screen.dart';
import '../providers/hello_provider.dart';

class HelloScreen extends ConsumerStatefulWidget {
  const HelloScreen({super.key});

  @override
  ConsumerState<HelloScreen> createState() => _HelloScreenState();
}

class _HelloScreenState extends ConsumerState<HelloScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(helloNotifierProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('CozyTalk')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Type a message',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: state.isLoading ? null : _submit,
              child: const Text('Send to server'),
            ),
            const SizedBox(height: 16),
            // TODO: remove — prototype shortcut to ChatScreen
            OutlinedButton.icon(
              onPressed: () {
                final user = ref.read(authNotifierProvider).user;
                if (user == null) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      sessionId: 'proto-session-001',
                      currentUserId: user.uid,
                      currentUserDisplayName: user.displayName ?? user.email ?? 'You',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Open prototype chat'),
            ),
            const SizedBox(height: 32),
            if (state.isLoading)
              const CircularProgressIndicator()
            else if (state.error != null)
              Text(
                'Error: ${state.error}',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              )
            else if (state.result != null)
              Text(
                state.result!.message,
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (ref.read(helloNotifierProvider).isLoading) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    ref.read(helloNotifierProvider.notifier).callHello(text);
  }
}
