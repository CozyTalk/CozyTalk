import 'package:flutter/material.dart';

import '../../../../dialogs/report_dialog.dart';

class ReportTestScreen extends StatefulWidget {
  const ReportTestScreen({super.key});

  @override
  State<ReportTestScreen> createState() => _ReportTestScreenState();
}

class _ReportTestScreenState extends State<ReportTestScreen> {
  final _sessionIdController = TextEditingController();
  final _reportedUserIdController = TextEditingController();

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
                labelText: 'Session ID (must exist in Firestore)',
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
              onPressed: _openReportDialog,
              icon: const Icon(Icons.flag_outlined),
              label: const Text('Open Report Dialog'),
            ),
          ],
        ),
      ),
    );
  }

  void _openReportDialog() {
    final sessionId = _sessionIdController.text.trim();
    final reportedUserId = _reportedUserIdController.text.trim();
    if (sessionId.isEmpty || reportedUserId.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (_) =>
          ReportDialog(sessionId: sessionId, reportedUserId: reportedUserId),
    );
  }
}
