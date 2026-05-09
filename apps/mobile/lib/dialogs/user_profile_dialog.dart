import 'package:flutter/material.dart';
import 'report_dialog.dart';

class UserProfileDialog extends StatefulWidget {
  final String username;
  const UserProfileDialog({super.key, required this.username});

  @override
  State<UserProfileDialog> createState() => _UserProfileDialogState();
}

class _UserProfileDialogState extends State<UserProfileDialog> {
  bool isFriendAdded = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF6B5E5B),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Close row ──
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.close, size: 20, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // ── Profile card ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar + action buttons
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.grey.shade200, width: 1.5),
                          ),
                          child: const Icon(Icons.person,
                              color: Colors.grey, size: 40),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            // Add friend button
                            GestureDetector(
                              onTap: () =>
                                  setState(() => isFriendAdded = true),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isFriendAdded
                                      ? Colors.grey.shade300
                                      : const Color(0xFFDEF1C2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isFriendAdded
                                        ? Colors.grey.shade400
                                        : const Color(0xFFC7D2B5),
                                    width: 1.5,
                                  ),
                                ),
                                child: Icon(
                                  isFriendAdded
                                      ? Icons.person
                                      : Icons.person_add_alt_1,
                                  color: isFriendAdded
                                      ? Colors.grey.shade600
                                      : const Color(0xFF4A553F),
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Report button
                            GestureDetector(
                              onTap: () => showDialog(
                                  context: context,
                                  builder: (_) => const ReportDialog()),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFCCAA),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFCF5733),
                                    width: 1.5,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.flag_outlined,
                                  color: Color(0xFFCF5733),
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    // Name + interest
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Username',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.username,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Colors.black),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Interest',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'I love TikTok very much.\nTikTok is the best\napplication in the world.',
                            style: TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                                height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
