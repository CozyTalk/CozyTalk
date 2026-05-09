import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Standard back-arrow AppBar used by all sub-screens
PreferredSizeWidget buildAppBar(BuildContext context, String title) {
  return AppBar(
    leading: IconButton(
      icon: const Icon(Icons.chevron_left, size: 30),
      onPressed: () => Navigator.pop(context),
    ),
    title: Text(title),
  );
}

/// Small pill-shaped action button (Accept / Decline / Unblock)
class PillButton extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback onTap;

  const PillButton({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// White rounded card container
class CozyCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;

  const CozyCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: AppColors.brownDeep.withValues(alpha:0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// User avatar - shows asset if available, fallback to icon
class UserAvatarWidget extends StatelessWidget {
  final double size;
  const UserAvatarWidget({super.key, this.size = 80});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/UserAvatar.png',
      height: size,
      errorBuilder: (_, __, ___) => Icon(
        Icons.person,
        size: size,
        color: AppColors.brownDeep,
      ),
    );
  }
}
