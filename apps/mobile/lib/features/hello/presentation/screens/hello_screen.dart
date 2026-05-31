import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/avatar/presentation/screens/avatar_picker_screen.dart';
import '../../../../features/friends/presentation/screens/friends_test_screen.dart';
import '../../../../features/matchmaking/presentation/screens/matchmaking_test_screen.dart';
import '../../../../features/profile/presentation/screens/profile_screen.dart';
import '../../../../features/report/presentation/screens/report_test_screen.dart';
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
      body: SingleChildScrollView(
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
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const MatchmakingTestScreen(),
                ),
              ),
              icon: const Icon(Icons.shuffle_rounded),
              label: const Text('Test Matchmaking'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const ReportTestScreen(),
                ),
              ),
              icon: const Icon(Icons.flag_outlined),
              label: const Text('Test Report'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AvatarPickerScreen()),
              ),
              icon: const Icon(Icons.face),
              label: const Text('Test avatar picker'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
              icon: const Icon(Icons.person_outline),
              label: const Text('Edit profile'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const FriendsTestScreen(),
                ),
              ),
              icon: const Icon(Icons.people_outline),
              label: const Text('Test Friends'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _promptCrash,
              icon: const Icon(Icons.bug_report),
              label: const Text('Test Crashlytics'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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

  Future<void> _promptCrash() async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Test Crashlytics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ask Oakar',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => Navigator.pop(ctx, true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Crash'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (ctrl.text != 'CrashPassword') {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Wrong password')));
      return;
    }
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
    FirebaseCrashlytics.instance.crash();
  }

  void _submit() {
    if (ref.read(helloNotifierProvider).isLoading) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    ref.read(helloNotifierProvider.notifier).callHello(text);
  }
}
