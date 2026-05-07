import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class _MoodOption {
  final String name;
  final String imagePath;
  const _MoodOption(this.name, this.imagePath);
}

class MoodScreen extends StatefulWidget {
  const MoodScreen({super.key});

  @override
  State<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends State<MoodScreen> {
  String? _selected;

  // รายการ Mood
  static const List<_MoodOption> _moods = [
    _MoodOption('Happy', 'assets/images/Happy.png'),
    _MoodOption('Thrilled', 'assets/images/Thrilled.png'),
    _MoodOption('Sad', 'assets/images/Sad.png'),
    _MoodOption('Lonely', 'assets/images/Lonely.png'),
    _MoodOption('Silly', 'assets/images/Silly.png'),
    _MoodOption('Grumpy', 'assets/images/Grumpy.png'),
  ];

  @override
  Widget build(BuildContext context) {
    // หา path ของรูปอารมณ์ที่ถูกเลือก เพื่อเอาไปแปะบนหน้า Avatar
    final selectedMoodImage = _selected != null 
        ? _moods.firstWhere((m) => m.name == _selected).imagePath 
        : null;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Stack(
        children: [
          // ── เลเยอร์เนื้อหาหลัก ──
          Column(
            children: [
              _buildCustomAppBar(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 120),
                  child: Column(
                    children: [
                      // ── Avatar Preview ──
                      Container(
                        width: double.infinity,
                        height: 250,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha:0.12),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(25),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned.fill(
                                child: Image.asset(
                                  'assets/images/MoodBg.png',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      Container(color: AppColors.tanGreen),
                                ),
                              ),
                              // ตัวละครเปล่า
                              Positioned(
                                bottom: -15,
                                child: Image.asset(
                                  'assets/images/UserAvatar.png',
                                  height: 130,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              // แปะหน้าอารมณ์ที่เลือก
                              if (selectedMoodImage != null)
                                Positioned(
                                  bottom: 48,
                                  child: Image.asset(
                                    selectedMoodImage,
                                    height: 45,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      
                      // ลดระยะห่างตรงนี้ให้รูปด้านบนกับตัวเลือกด้านล่างชิดกันมากขึ้น
                      const SizedBox(height: 30),

                      // ── Mood Grid ──
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero, // ── ลบ Padding แฝงของ GridView ทิ้ง ──
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 15,
                          childAspectRatio: 0.85, 
                        ),
                        itemCount: _moods.length,
                        itemBuilder: (_, i) {
                          final mood = _moods[i];
                          final sel = _selected == mood.name;
                          return GestureDetector(
                            onTap: () => setState(() => _selected = mood.name),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                              transform: Matrix4.translationValues(0, sel ? -10.0 : 0, 0),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: sel ? const Color(0xFFCE5E42) : Colors.grey.shade300,
                                  width: sel ? 2.5 : 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha:0.08),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    mood.imagePath,
                                    height: 45,
                                    width: 45,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.sentiment_satisfied, size: 40),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    mood.name,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── เลเยอร์ปุ่มลอย Save ──
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDEF1C2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFC7D2B5),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha:0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Custom App Bar ──────────────────────────────────────────
  Widget _buildCustomAppBar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF695959),
        borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
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
                    border: Border.all(color: Colors.grey.shade300, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha:0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/Back.png',
                    width: 26,
                    height: 26,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'Mood',
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
}