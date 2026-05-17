import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/profile_user.dart';
import '../providers/profile_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _usernameController = TextEditingController();
  final _interestController = TextEditingController();
  final _thoughtsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final existing = ref.read(profileNotifierProvider).profile;
      if (existing != null) _prefillControllers(existing);
      _loadProfile();
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _interestController.dispose();
    _thoughtsController.dispose();
    super.dispose();
  }

  void _loadProfile() {
    final uid = ref.read(authNotifierProvider).user?.uid;
    if (uid == null) return;
    ref.read(profileNotifierProvider.notifier).load(uid);
  }

  void _prefillControllers(ProfileUser profile) {
    _usernameController.text = profile.displayName ?? '';
    _interestController.text = profile.interest ?? '';
    _thoughtsController.text = profile.thoughts ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileNotifierProvider);
    final uid = ref.watch(authNotifierProvider).user?.uid;

    ref.listen(profileNotifierProvider, (prev, next) {
      if (next.profile != null && next.profile != prev?.profile) {
        _prefillControllers(next.profile!);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.isLoading && state.profile == null)
              const Center(child: CircularProgressIndicator())
            else ...[
              _ProfileField(
                label: 'Username',
                hint: 'Max 20 characters',
                controller: _usernameController,
                maxLength: 20,
                isLoading: state.isLoading,
                successField: state.successField,
                fieldKey: 'username',
                onSave: uid == null
                    ? null
                    : () {
                        final v = _usernameController.text.trim();
                        if (v.isEmpty || v.length > 20) return;
                        ref
                            .read(profileNotifierProvider.notifier)
                            .updateDisplayName(uid, v);
                      },
              ),
              const SizedBox(height: 24),
              _ProfileField(
                label: 'Interest',
                hint: 'Max 200 characters',
                controller: _interestController,
                maxLength: 200,
                isLoading: state.isLoading,
                successField: state.successField,
                fieldKey: 'interest',
                onSave: uid == null
                    ? null
                    : () {
                        final v = _interestController.text.trim();
                        if (v.isEmpty || v.length > 200) return;
                        ref
                            .read(profileNotifierProvider.notifier)
                            .updateInterest(uid, v);
                      },
              ),
              const SizedBox(height: 24),
              _ProfileField(
                label: 'Current Thoughts',
                hint: 'Max 50 characters',
                controller: _thoughtsController,
                maxLength: 50,
                isLoading: state.isLoading,
                successField: state.successField,
                fieldKey: 'thoughts',
                onSave: uid == null
                    ? null
                    : () {
                        final v = _thoughtsController.text.trim();
                        if (v.isEmpty || v.length > 50) return;
                        ref
                            .read(profileNotifierProvider.notifier)
                            .updateThoughts(uid, v);
                      },
              ),
              const SizedBox(height: 24),
              if (state.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (state.error != null)
                Text(
                  'Error: ${state.error}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final int maxLength;
  final bool isLoading;
  final String? successField;
  final String fieldKey;
  final VoidCallback? onSave;

  const _ProfileField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.maxLength,
    required this.isLoading,
    required this.successField,
    required this.fieldKey,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final saved = successField == fieldKey;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          maxLength: maxLength,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => onSave?.call(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: isLoading ? null : onSave,
                child: Text('Save $label'),
              ),
            ),
            if (saved) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check_circle, color: Colors.green),
            ],
          ],
        ),
      ],
    );
  }
}
