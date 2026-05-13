import 'package:flutter/material.dart';
import 'report_dialog.dart';

class MembersListDialog extends StatefulWidget {
  const MembersListDialog({super.key});

  @override
  State<MembersListDialog> createState() => _MembersListDialogState();
}

class _MembersListDialogState extends State<MembersListDialog> {
  final Map<int, bool> _friendsAdded = {0: false, 1: false, 2: false};
  final List<String> members = ['Somtum', 'Kaitom', 'Somjeed'];

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
            children: List.generate(members.length, (index) {
              bool isAdded = _friendsAdded[index] ?? false;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
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
                  children: [
                    Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        members[index],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _friendsAdded[index] = true),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isAdded
                              ? Colors.grey.shade300
                              : const Color(0xFFDEF1C2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isAdded
                                ? Colors.grey.shade400
                                : const Color(0xFFC7D2B5),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          isAdded ? Icons.person : Icons.person_add_alt_1,
                          color: isAdded
                              ? Colors.grey.shade600
                              : const Color(0xFF4A553F),
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => showDialog(
                        context: context,
                        builder: (_) => const ReportDialog(),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(6),
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
              );
            }),
          ),
        ),
      ),
    );
  }
}
