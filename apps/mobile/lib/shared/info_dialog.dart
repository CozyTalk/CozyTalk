import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum InfoDialogType { success, error, warning, info }

void showInfoDialog(
  BuildContext context, {
  required InfoDialogType type,
  required String title,
  required String message,
  String confirmLabel = 'OK',
  VoidCallback? onConfirm,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => _InfoDialog(
      type: type,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      onConfirm: onConfirm,
    ),
  );
}

class _InfoDialog extends StatelessWidget {
  final InfoDialogType type;
  final String title;
  final String message;
  final String confirmLabel;
  final VoidCallback? onConfirm;

  const _InfoDialog({
    required this.type,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.onConfirm,
  });

  static const _icons = {
    InfoDialogType.success: (Icons.check_circle_rounded, Color(0xFF6B8F4E)),
    InfoDialogType.error: (Icons.cancel_rounded, AppColors.redOrange),
    InfoDialogType.warning: (Icons.warning_amber_rounded, Color(0xFFB07D10)),
    InfoDialogType.info: (Icons.info_rounded, AppColors.brownDeep),
  };

  @override
  Widget build(BuildContext context) {
    final (icon, iconColor) = _icons[type]!;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 80),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 40, color: iconColor),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.brownDeep,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.grayDark,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      onConfirm?.call();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: AppColors.greenLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.tanGreen,
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        confirmLabel,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
