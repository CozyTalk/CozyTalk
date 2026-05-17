import 'package:flutter/material.dart';

import 'report_sheet.dart';

class ReportTestScreen extends StatefulWidget {
  const ReportTestScreen({super.key});

  @override
  State<ReportTestScreen> createState() => _ReportTestScreenState();
}

class _ReportTestScreenState extends State<ReportTestScreen> {
  final _sessionIdController = TextEditingController(text: 'test-session-001');
  final _reportedUserIdController = TextEditingController(
    text: 'test-user-abc',
  );

  @override
  void dispose() {
    _sessionIdController.dispose();
    _reportedUserIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test Report')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _sessionIdController,
              decoration: const InputDecoration(
                labelText: 'Session ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reportedUserIdController,
              decoration: const InputDecoration(
                labelText: 'Reported User ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _openReportSheet,
              icon: const Icon(Icons.flag_outlined),
              label: const Text('Open Report Sheet'),
            ),
          ],
        ),
      ),
    );
  }

  void _openReportSheet() {
    final sessionId = _sessionIdController.text.trim();
    final reportedUserId = _reportedUserIdController.text.trim();
    if (sessionId.isEmpty || reportedUserId.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          ReportSheet(sessionId: sessionId, reportedUserId: reportedUserId),
    );
  }
}
