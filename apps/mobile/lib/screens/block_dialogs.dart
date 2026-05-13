import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../shared/pill_button.dart';

// ─── Confirm Block ────────────────────────────────────────────────

void showConfirmBlockDialog({
  required BuildContext context,
  required String username,
  required VoidCallback onConfirm,
}) {
  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => _ConfirmDialog(
      title: 'Block "$username"',
      body: TextSpan(
        style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
        children: [
          const TextSpan(text: 'Are you sure you want to block\n'),
          TextSpan(text: '"$username"', style: const TextStyle(fontWeight: FontWeight.bold)),
          const TextSpan(text: '?\nThey will no longer be able to contact you.'),
        ],
      ),
      confirmLabel: 'Block',
      confirmBgColor: AppColors.redOrange,
      confirmBorderColor: const Color(0xFFA33615),
      confirmTextColor: Colors.white,
      onConfirm: onConfirm,
    ),
  );
}

// ─── Confirm Unblock ──────────────────────────────────────────────

void showConfirmUnblockDialog({
  required BuildContext context,
  required String username,
  required VoidCallback onConfirm,
}) {
  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => _ConfirmDialog(
      title: 'Unblock "$username"',
      body: TextSpan(
        style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
        children: [
          const TextSpan(text: 'Are you sure you want to unblock\n'),
          TextSpan(text: '"$username"', style: const TextStyle(fontWeight: FontWeight.bold)),
          const TextSpan(text: '?'),
        ],
      ),
      confirmLabel: 'Unblock',
      confirmBgColor: AppColors.greenLight,
      confirmBorderColor: const Color(0xFFC7D2B5),
      confirmTextColor: Colors.black87,
      onConfirm: onConfirm,
    ),
  );
}

// ─── Shared dialog widget ─────────────────────────────────────────

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final InlineSpan body;
  final String confirmLabel;
  final Color confirmBgColor;
  final Color confirmBorderColor;
  final Color confirmTextColor;
  final VoidCallback onConfirm;

  const _ConfirmDialog({
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.confirmBgColor,
    required this.confirmBorderColor,
    required this.confirmTextColor,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.grey.shade300, width: 1.5),
      ),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 48),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            RichText(
              textAlign: TextAlign.center,
              text: body,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PillButton(
                  label: 'Cancel',
                  bgColor: Colors.grey.shade200,
                  borderColor: const Color(0xFFB7B4B4),
                  textColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  constraints: null,
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(width: 12),
                PillButton(
                  label: confirmLabel,
                  bgColor: confirmBgColor,
                  borderColor: confirmBorderColor,
                  textColor: confirmTextColor,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  constraints: null,
                  onTap: () {
                    Navigator.pop(context);
                    onConfirm();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

