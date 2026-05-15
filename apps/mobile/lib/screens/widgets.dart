import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_colors.dart';
import '../models/friend.dart';

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
            color: AppColors.brownDeep.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Room card shown inside friend cards and friend chat screen.
/// [showLabel] = true → shows "CURRENTLY IN" label above room name (chat style).
class FriendRoomCard extends StatelessWidget {
  final RoomInfo room;
  final bool showLabel;
  final VoidCallback? onJoin;
  final Color backgroundColor;

  const FriendRoomCard({
    super.key,
    required this.room,
    this.showLabel = false,
    this.onJoin,
    this.backgroundColor = AppColors.scaffoldBg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gray.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              room.thumbnail,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 44,
                height: 44,
                color: Colors.grey.shade200,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showLabel)
                  const Text(
                    'CURRENTLY IN',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brownDeep,
                      letterSpacing: 0.5,
                    ),
                  ),
                if (showLabel) const SizedBox(height: 2),
                Text(
                  room.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    SvgPicture.asset(
                      room.isOneOnOne
                          ? 'assets/images/icons/1on1.svg'
                          : 'assets/images/icons/Group.svg',
                      width: 13,
                      height: 13,
                      colorFilter: const ColorFilter.mode(AppColors.brownDeep, BlendMode.srcIn),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${room.current}/${room.max}',
                      style: const TextStyle(fontSize: 12, color: AppColors.brownDeep),
                    ),
                    if (!room.isOneOnOne && room.isLocked) ...[
                      const Text('  ·  ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      _StatusPill(room: room),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (!room.isOneOnOne) _ActionButton(room: room, onJoin: onJoin),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final RoomInfo room;
  const _StatusPill({required this.room});

  @override
  Widget build(BuildContext context) {
    if (room.isLocked) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFF0E6DC),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/images/icons/Lock.svg',
              width: 10,
              height: 10,
              colorFilter: const ColorFilter.mode(AppColors.brownDeep, BlendMode.srcIn),
            ),
            const SizedBox(width: 3),
            const Text('Locked', style: TextStyle(fontSize: 11, color: AppColors.brownDeep, fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text('Full', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w700)),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final RoomInfo room;
  final VoidCallback? onJoin;
  const _ActionButton({required this.room, this.onJoin});

  @override
  Widget build(BuildContext context) {
    if (room.canJoin) {
      return GestureDetector(
        onTap: onJoin,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFDEF1C2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFC7D2B5), width: 1.5),
          ),
          child: const Text('Join', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF4A553F))),
        ),
      );
    }
    if (room.isLocked) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
      ),
      child: Text(
        'Join',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.grey.shade400),
      ),
    );
  }
}

/// SVG icon button used in Mood/DressUp screens (undo, redo, delete)
class AvatarActionButton extends StatelessWidget {
  final String svgPath;
  final bool enabled;
  final VoidCallback onTap;

  const AvatarActionButton({
    super.key,
    required this.svgPath,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.35,
        child: SvgPicture.asset(
          svgPath,
          width: 28,
          height: 28,
          colorFilter: const ColorFilter.mode(AppColors.brownDeep, BlendMode.srcIn),
        ),
      ),
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
      errorBuilder: (_, _, _) =>
          Icon(Icons.person, size: size, color: AppColors.brownDeep),
    );
  }
}
