import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class _NotifItem {
  final String imagePath;
  final IconData fallbackIcon;
  final String title;
  final String subtitle;
  final String time;
  final bool isFriendRequest;
  bool accepted = false;
  bool declined;

  _NotifItem({
    required this.imagePath,
    required this.fallbackIcon,
    required this.title,
    required this.subtitle,
    required this.time,
    this.isFriendRequest = false,
    this.declined = false,
  });
}

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final List<_NotifItem> _items = [
    _NotifItem(
      imagePath: 'assets/images/Friends.png', 
      fallbackIcon: Icons.favorite_border,
      title: 'Kaitom wants to be friends',
      subtitle: 'from Koh Tapu',
      time: '10m',
      isFriendRequest: true,
    ),
    _NotifItem(
      imagePath: 'assets/images/Friends.png',
      fallbackIcon: Icons.favorite_border,
      title: 'Mitsuru wants to be friends',
      subtitle: 'from Red Lotus Lake',
      time: '1h',
      isFriendRequest: true,
      declined: true,
    ),
    _NotifItem(
      imagePath: 'assets/images/Settings.png', 
      fallbackIcon: Icons.settings_outlined,
      title: 'update',
      subtitle: 'v.2.9\nfix...',
      time: '20 April 2026',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg, 
      body: Column(
        children: [
          _buildCustomAppBar(),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (_, i) => _buildCard(_items[i], i),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Custom App Bar ──────────────────────────────────────────
  Widget _buildCustomAppBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.brownDeep,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(35),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 90,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 1.5,
                    ),
                  ),
                  child: Image.asset(
                    'assets/images/Back.png',
                    width: 26,
                    height: 26,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.black87,
                      size: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Notifications',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Notification Card ───────────────────────────────────────
  Widget _buildCard(_NotifItem item, int index) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20), 
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.08), 
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 60,
            height: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha:0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ],
              border: Border.all(
                color: Colors.grey.shade200,
                width: 1.5,
              ),
            ),
            child: Image.asset(
              item.imagePath,
              width: 32,
              height: 32,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                item.fallbackIcon,
                color: Colors.black87,
                size: 32,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900, 
                          fontSize: 15,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item.time,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
                
                if (item.isFriendRequest) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (!item.accepted && !item.declined) ...[
                        _buildButton(
                          label: 'Accept',
                          backgroundColor: const Color(0xFFDEF1C2), 
                          borderColor: const Color(0xFFC7D2B5), 
                          textColor: Colors.black,
                          onTap: () {
                            setState(() {
                              _items[index].accepted = true;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildButton(
                          label: 'Decline',
                          backgroundColor: const Color(0xFFCF5733), 
                          borderColor: const Color(0xFFA33615), 
                          textColor: Colors.white,
                          onTap: () {
                            setState(() {
                              _items[index].declined = true;
                            });
                          },
                        ),
                      ]
                      else if (item.accepted) ...[
                        _buildButton(
                          label: 'Accept',
                          backgroundColor: const Color(0xFFE0E0E0),
                          borderColor: Colors.grey.shade400,
                          textColor: Colors.black54,
                          onTap: null,
                        ),
                      ]
                      else if (item.declined) ...[
                        _buildButton(
                          label: 'Decline',
                          backgroundColor: const Color(0xFFE0E0E0),
                          borderColor: Colors.grey.shade400,
                          textColor: Colors.black54,
                          onTap: null,
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Button Widget ───────────────────────────────────────────
  Widget _buildButton({
    required String label,
    required Color backgroundColor,
    required Color textColor,
    Color? borderColor, 
    VoidCallback? onTap, 
  }) {
    return GestureDetector(
      onTap: onTap, 
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20), 
          border: borderColor != null 
              ? Border.all(color: borderColor, width: 1.5) 
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontWeight: FontWeight.w800, 
          ),
        ),
      ),
    );
  }
}