import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../shared/pill_button.dart';

void showRemoveConfirmDialog({
  required BuildContext context,
  required String friendName,
  required VoidCallback onConfirm,
}) {
  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) =>
        _RemoveConfirmDialog(friendName: friendName, onConfirm: onConfirm),
  );
}

class _RemoveConfirmDialog extends StatelessWidget {
  final String friendName;
  final VoidCallback onConfirm;

  const _RemoveConfirmDialog({
    required this.friendName,
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
              'Remove "$friendName"',
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
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.5,
                ),
                children: [
                  const TextSpan(text: 'Are you sure you want to remove\n'),
                  TextSpan(
                    text: '"$friendName"',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: ' from your friends'),
                ],
              ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 12,
                  ),
                  constraints: null,
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(width: 12),
                PillButton(
                  label: 'Remove',
                  bgColor: AppColors.redOrange,
                  borderColor: const Color(0xFFA33615),
                  textColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 12,
                  ),
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
