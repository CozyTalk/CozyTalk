import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/matchmaking/domain/entities/matchmaking_status.dart';
import '../features/matchmaking/presentation/providers/matchmaking_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_routes.dart';

const _frames = [
  'assets/images/tuktuk/tuk_tuk_0.png',
  'assets/images/tuktuk/tuk_tuk_1.png',
  'assets/images/tuktuk/tuk_tuk_2.png',
  'assets/images/tuktuk/tuk_tuk_3.png',
  'assets/images/tuktuk/tuk_tuk_4.png',
  'assets/images/tuktuk/tuk_tuk_5.png',
  'assets/images/tuktuk/tuk_tuk_6.png',
];

class FindingRoomScreen extends ConsumerStatefulWidget {
  const FindingRoomScreen({super.key});

  @override
  ConsumerState<FindingRoomScreen> createState() => _FindingRoomScreenState();
}

class _FindingRoomScreenState extends ConsumerState<FindingRoomScreen> {
  int _frameIndex = 0;
  int _elapsedSeconds = 0;
  bool _didMatch = false;

  Map<String, dynamic>? _args;
  MatchmakingNotifier? _notifier;

  late final Timer _frameTimer;
  late final Timer _clockTimer;

  @override
  void initState() {
    super.initState();

    _frameTimer = Timer.periodic(const Duration(milliseconds: 180), (_) {
      if (mounted) {
        setState(() => _frameIndex = (_frameIndex + 1) % _frames.length);
      }
    });

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifier = ref.read(matchmakingNotifierProvider.notifier);
      _startMatchmaking();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _args ??=
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
  }

  // 0→90% over 60 s while searching; jumps to 100% on match.
  double get _progress =>
      _didMatch ? 1.0 : (_elapsedSeconds / 60.0).clamp(0.0, 0.9);

  @override
  void dispose() {
    _frameTimer.cancel();
    _clockTimer.cancel();
    if (!_didMatch) {
      _notifier?.cancelSearch();
    }
    super.dispose();
  }

  void _startMatchmaking() {
    final roomType = _args?['roomType'] as String? ?? '1v1';
    switch (roomType) {
      case 'group':
        _notifier?.joinGroupRoom();
      case 'create':
        _notifier?.createCustomRoom();
      default:
        _notifier?.join1v1Pool();
    }
  }

  String get _timeLabel {
    if (_elapsedSeconds < 60) return '$_elapsedSeconds sec';
    final m = _elapsedSeconds ~/ 60;
    final s = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '${m}m ${s}s';
  }

  String get _dots => '.' * ((_elapsedSeconds % 3) + 1);

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
    ref.listen<MatchmakingState>(matchmakingNotifierProvider, (_, next) {
      if (_didMatch) return;
      if (next.status == MatchmakingStatus.matched) {
        _didMatch = true;
        final args = _args ?? {};
        final isGroup = args['isGroup'] as bool? ?? false;
        Navigator.pushReplacementNamed(
          context,
          isGroup ? AppRoutes.groupChatScreen : AppRoutes.chatScreen,
          arguments: {
            'roomId': next.roomId,
            'roomName': args['roomName'],
            'bgImage': args['bgImage'],
          },
        );
      } else if (next.status == MatchmakingStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error ?? 'Something went wrong')),
        );
        _notifier?.cancelSearch();
        Navigator.popUntil(
          context,
          ModalRoute.withName(AppRoutes.chooseRoomType),
        );
      }
    });

    final badge = _roomTypeBadge;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 3),

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

              LayoutBuilder(
                builder: (context, constraints) {
                  final pct = (_progress * 100).round();
                  final fillW = constraints.maxWidth * _progress;
                  return Stack(
                    children: [
                      Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE4E4E4),
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOut,
                        height: 44,
                        width: fillW.clamp(44.0, constraints.maxWidth),
                        decoration: BoxDecoration(
                          color: const Color(0xFFB5D4A5),
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
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
              ),

              const SizedBox(height: 14),

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

              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () {
                    _notifier?.cancelSearch();
                    Navigator.popUntil(
                      context,
                      ModalRoute.withName(AppRoutes.chooseRoomType),
                    );
                  },
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
