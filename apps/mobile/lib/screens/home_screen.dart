import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_routes.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _hasNotification = true;
  String _moodText = 'I love Tiktok very much!';

  // ── Edit mood bubble ──
  void _editMood() async {
    final controller = TextEditingController(text: _moodText);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Edit your thought',
          style: TextStyle(
            color: Color.fromRGBO(92, 61, 46, 1),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Type here...',
            hintStyle: TextStyle(color: AppColors.gray),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Cancel', style: TextStyle(color: AppColors.gray)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      setState(() => _moodText = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          _TopBar(
            hasNotification: _hasNotification,
            onBellTap: () {
              setState(() => _hasNotification = false);
              Navigator.pushNamed(context, AppRoutes.notification);
            },
            onUserTap: () => Navigator.pushNamed(context, AppRoutes.profile),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 35),

                    const Text(
                      'Hello, Somtum!',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF000000),
                      ),
                    ),
                    const SizedBox(height: 8),

                    _AvatarCard(
                      moodText: _moodText,
                      onMoodTap: _editMood,
                    ),
                    const SizedBox(height: 22),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _QuickAction(
                          imagePath: 'assets/images/DressUp.png',
                          label: 'Dress Up!',
                          imageWidth: 35,
                          imageHeight: 35,
                          onTap: () =>
                              Navigator.pushNamed(context, AppRoutes.dressUp),
                        ),
                        _QuickAction(
                          imagePath: 'assets/images/Mood.png',
                          label: 'Mood',
                          imageWidth: 42,
                          imageHeight: 42,
                          onTap: () =>
                              Navigator.pushNamed(context, AppRoutes.mood),
                        ),
                        _QuickAction(
                          imagePath: 'assets/images/Friends.png',
                          label: 'Friends',
                          imageWidth: 38,
                          imageHeight: 38,
                          onTap: () =>
                              Navigator.pushNamed(context, AppRoutes.friends),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    // Let's chat
                    Center(
                        child: _LetsChatButton(
                      onTap: () => Navigator.pushNamed(
                          context, AppRoutes.chooseRoomType),
                    )),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── TOP BAR ───────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final bool hasNotification;
  final VoidCallback onBellTap;
  final VoidCallback onUserTap;

  const _TopBar({
    required this.hasNotification,
    required this.onBellTap,
    required this.onUserTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF695959),
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
              Image.asset(
                'assets/images/Logo.png',
                height: 70,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Text(
                    'CozyTalk',
                    style: TextStyle(
                      color: AppColors.cream,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  );
                },
              ),
              const Spacer(),
              
              Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onTap: onBellTap,
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16), 
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
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
                        'assets/images/Notification.png',
                        width: 30, 
                        height: 30,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.notifications_outlined,
                            color: Colors.black87,
                            size: 30),
                      ),
                    ),
                  ),
                  if (hasNotification)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        width: 16, 
                        height: 16,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCF5733),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFA33615),
                            width: 2.0, 
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              
              const SizedBox(width: 14), 
              
              GestureDetector(
                onTap: onUserTap,
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
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
                    'assets/images/User.png',
                    width: 30, 
                    height: 30,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.account_circle,
                      color: Colors.black87,
                      size: 30,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── AVATAR CARD (เพิ่มเงาอย่างเดียว) ───────────────────────────────────
class _AvatarCard extends StatefulWidget {
  final String moodText;
  final VoidCallback onMoodTap;

  const _AvatarCard({required this.moodText, required this.onMoodTap});

  @override
  State<_AvatarCard> createState() => _AvatarCardState();
}

class _AvatarCardState extends State<_AvatarCard> {
  Offset _bubblePosition = const Offset(210, 80);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 270,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        // ลบ border ออก และใส่เฉพาะเงา
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12), // ปรับเงาให้ชัดขึ้นเล็กน้อยเพื่อความสวยงาม
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            double safeX =
                _bubblePosition.dx.clamp(0.0, constraints.maxWidth - 90.0);
            double safeY =
                _bubblePosition.dy.clamp(0.0, constraints.maxHeight - 100.0);

            return Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: Transform.scale(
                    scale: 1.15,
                    child: Image.asset(
                      'assets/images/HomeBg.png',
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.tanGreen,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 62,
                  child: Image.asset(
                    'assets/images/UserAvatar.png',
                    height: 90,
                    errorBuilder: (_, __, ___) => Container(
                      width: 70,
                      height: 85,
                      decoration: BoxDecoration(
                        color: AppColors.white.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: const Icon(Icons.person,
                          size: 50, color: AppColors.brownDeep),
                    ),
                  ),
                ),
                Positioned(
                  left: safeX,
                  top: safeY,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        double newX = _bubblePosition.dx + details.delta.dx;
                        double newY = _bubblePosition.dy + details.delta.dy;
                        newX = newX.clamp(0.0, constraints.maxWidth - 90.0);
                        newY = newY.clamp(0.0, constraints.maxHeight - 100.0);
                        _bubblePosition = Offset(newX, newY);
                      });
                    },
                    child: _ThoughtBubble(
                      text: widget.moodText,
                      onTap: widget.onMoodTap,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── THOUGHT BUBBLE WIDGET ─────────────────────────────────────
class _ThoughtBubble extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _ThoughtBubble({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        height: 100,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/ThinkBubble.png'),
            fit: BoxFit.contain,
          ),
        ),
        padding: const EdgeInsets.only(bottom: 12, left: 15, right: 10),
        alignment: Alignment.center,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

// ─── QUICK ACTION BUTTON ────────────────────────────────────────
class _QuickAction extends StatelessWidget {
  final String imagePath;
  final String label;
  final VoidCallback onTap;

  final double imageWidth;
  final double imageHeight;

  const _QuickAction({
    required this.imagePath,
    required this.label,
    required this.onTap,
    this.imageWidth = 35,
    this.imageHeight = 35,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 75,
            height: 75,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
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
              imagePath,
              width: imageWidth,
              height: imageHeight,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.image_not_supported, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── LET'S CHAT BUTTON ─────────────────────────────────────────
class _LetsChatButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LetsChatButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
          border: Border.all(
            color: Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/LetsChat.png',
              width: 45, 
              height: 45,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.chat,
                color: Colors.black,
                size: 35,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              "Let's chat!",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}