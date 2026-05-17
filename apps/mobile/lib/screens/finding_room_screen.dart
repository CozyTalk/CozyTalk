import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_routes.dart';

// ── Tuk-tuk frame assets ───────────────────────────────────────────────────
// Place frame images in assets/images/tuktuk/ named frame1.png, frame2.png, ...
const _frames = [
  'assets/images/tuktuk/tuk_tuk_0.png',
  'assets/images/tuktuk/tuk_tuk_1.png',
  'assets/images/tuktuk/tuk_tuk_2.png',
  'assets/images/tuktuk/tuk_tuk_3.png',
  'assets/images/tuktuk/tuk_tuk_4.png',
  'assets/images/tuktuk/tuk_tuk_5.png',
  'assets/images/tuktuk/tuk_tuk_6.png',
];

class FindingRoomScreen extends StatefulWidget {
  const FindingRoomScreen({super.key});

  @override
  State<FindingRoomScreen> createState() => _FindingRoomScreenState();
}

class _FindingRoomScreenState extends State<FindingRoomScreen>
    with SingleTickerProviderStateMixin {
  int _frameIndex = 0;
  int _elapsedSeconds = 0;

  late final AnimationController _progressCtrl;
  late final Animation<double> _progressAnim;
  late final Timer _frameTimer;
  late final Timer _clockTimer;
  late final Timer _matchTimer;

  // Args passed from select_background_screen
  Map<String, dynamic>? _args;

  @override
  void initState() {
    super.initState();

    // Tuk-tuk frame animation — cycle every 180 ms
    _frameTimer = Timer.periodic(const Duration(milliseconds: 180), (_) {
      if (mounted) {
        setState(() => _frameIndex = (_frameIndex + 1) % _frames.length);
      }
    });

    // Elapsed time — tick every second
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });

    // Progress bar — fills to 100% over 4 s then navigates
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..forward();

    _progressAnim = CurvedAnimation(
      parent: _progressCtrl,
      curve: Curves.easeInOut,
    );

    // Navigate to chat when progress completes
    _matchTimer = Timer(const Duration(seconds: 4), _goToChat);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _args ??=
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
  }

  @override
  void dispose() {
    _frameTimer.cancel();
    _clockTimer.cancel();
    _matchTimer.cancel();
    _progressCtrl.dispose();
    super.dispose();
  }

  void _goToChat() {
    if (!mounted) return;
    final args = _args ?? {};
    final isGroup = args['isGroup'] as bool? ?? false;
    Navigator.pushReplacementNamed(
      context,
      isGroup ? AppRoutes.groupChatScreen : AppRoutes.chatScreen,
      arguments: {
        'roomName': args['roomName'] ?? 'Red Lotus Lake',
        'bgImage':
            args['bgImage'] ?? 'assets/images/backgrounds/red_lotus_lake.png',
        'roomType': args['roomType'],
      },
    );
  }

  // ── Elapsed time string ────────────────────────────────────────────────────
  String get _timeLabel {
    if (_elapsedSeconds < 60) return '$_elapsedSeconds sec';
    final m = _elapsedSeconds ~/ 60;
    final s = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '${m}m ${s}s';
  }

  // ── Dots animation for subtitle ────────────────────────────────────────────
  String get _dots => '.' * ((_elapsedSeconds % 3) + 1);

  // ── Room type badge config ────────────────────────────────────────────────
  ({String label, IconData icon}) get _roomTypeBadge {
    final roomType = _args?['roomType'] as String? ?? '1v1';
    return switch (roomType) {
      'group' => (label: 'Group Chat', icon: Icons.groups),
      'create' => (label: 'Private Group', icon: Icons.group_add),
      _ => (label: '1 on 1 Chat', icon: Icons.person),
    };
  }

  @override
  Widget build(BuildContext context) {
    final badge = _roomTypeBadge;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 3),

              // ── Title block ──────────────────────────────────────────────
              const Text(
                'Find a room',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'off to the$_dots',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Colors.black38,
                ),
              ),

              const SizedBox(height: 20),

              // ── Room type badge + room name ────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badge.icon, size: 18, color: Colors.black87),
                    const SizedBox(width: 8),
                    Text(
                      badge.label,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _args?['roomName'] as String? ?? '',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 24),

              // ── Tuk-tuk card ─────────────────────────────────────────────
              Container(
                width: double.infinity,
                height: 230,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.07),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                clipBehavior: Clip.hardEdge,
                child: Image.asset(
                  _frames[_frameIndex],
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Center(
                    child: Icon(
                      Icons.directions_car_rounded,
                      size: 80,
                      color: Colors.black12,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── Progress bar ──────────────────────────────────────────────
              AnimatedBuilder(
                animation: _progressAnim,
                builder: (context, _) {
                  final pct = (_progressAnim.value * 100).round();
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final fillW = constraints.maxWidth * _progressAnim.value;
                      return Stack(
                        children: [
                          // Background track
                          Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE4E4E4),
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                          // Green fill
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 80),
                            height: 44,
                            width: fillW.clamp(44.0, constraints.maxWidth),
                            decoration: BoxDecoration(
                              color: const Color(0xFFB5D4A5),
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                          // Percentage text
                          SizedBox(
                            height: 44,
                            width: constraints.maxWidth,
                            child: Center(
                              child: Text(
                                '$pct%',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 14),

              // ── Elapsed time ──────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    size: 16,
                    color: Colors.black38,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Searching for $_timeLabel',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: Colors.black38,
                    ),
                  ),
                ],
              ),

              const Spacer(flex: 3),

              // ── Cancel button ─────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.popUntil(
                    context,
                    ModalRoute.withName(AppRoutes.chooseRoomType),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black54,
                    side: const BorderSide(color: Colors.black26),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
