import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

/// Shows the account suspended dialog.
/// [days] = ban duration, [reinstateDate] = human-readable date string.
/// [onBackToLogin] overrides the default nav-to-first-route behaviour —
/// use this when the user is banned while already inside the app so you can
/// sign them out before clearing the stack.
void showAccountSuspendedDialog(
  BuildContext context, {
  int days = 30,
  String reinstateDate = 'May 29, 2026',
  VoidCallback? onBackToLogin,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => _AccountSuspendedDialog(
      days: days,
      reinstateDate: reinstateDate,
      onBackToLogin: onBackToLogin,
    ),
  );
}

class _AccountSuspendedDialog extends StatelessWidget {
  final int days;
  final String reinstateDate;
  final VoidCallback? onBackToLogin;

  const _AccountSuspendedDialog({
    required this.days,
    required this.reinstateDate,
    this.onBackToLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 46),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block, size: 38, color: AppColors.redOrange),
            const SizedBox(height: 8),
            Text(
              'Account suspended',
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.redOrange,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your account has been suspended for $days days due to inappropriate behavior during conversations. Your account will be reinstated on $reinstateDate.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                height: 1.5,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 14),
            Divider(color: Colors.grey.shade300, thickness: 1),
            const SizedBox(height: 10),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  color: Colors.grey.shade600,
                  height: 1.45,
                ),
                children: [
                  const TextSpan(
                    text: "If you'd like to appeal, please contact us\n",
                  ),
                  TextSpan(
                    text: '@cozyTalk',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  const TextSpan(text: ' on Discord'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton(
                onPressed: () {
                  if (onBackToLogin != null) {
                    Navigator.of(context).pop();
                    onBackToLogin!();
                  } else {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.saveBtn,
                  foregroundColor: const Color(0xFF4A553F),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: Color(0xFFC7D2B5), width: 1),
                  ),
                ),
                child: Text(
                  'Back To Log in',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
