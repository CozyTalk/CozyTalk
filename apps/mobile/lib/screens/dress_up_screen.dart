import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class _DressItem {
  final String name;
  final String imagePath;
  final String label;
  final double equipBottom; // ตำแหน่งความสูงเวลาใส่บน Avatar
  final double equipHeight; // ขนาดของไอเทมเวลาใส่บน Avatar

  const _DressItem(
    this.name, 
    this.imagePath, 
    this.label, 
    this.equipBottom, 
    this.equipHeight
  );
}

class DressUpScreen extends StatefulWidget {
  const DressUpScreen({super.key});

  @override
  State<DressUpScreen> createState() => _DressUpScreenState();
}

class _DressUpScreenState extends State<DressUpScreen> {
  String? _selected;

  // ── รายการไอเทม พร้อมตั้งค่าตำแหน่งและขนาดเฉพาะตัว ──
  // คุณสามารถปรับเลข equipBottom (ความสูงจากขอบล่าง) และ equipHeight (ขนาด) ตรงนี้ได้เลย
  static const List<_DressItem> _items = [
    // หมวกต่างๆ ให้อยู่สูงหน่อย (bottom ประมาณ 85-95) และขนาดพอดีหัว
    _DressItem('Cap', 'assets/images/Cap.png', 'Cap', 80, 55),
    _DressItem('Beanie', 'assets/images/Pinkbeanie.png', 'Beanie', 85, 55),
    _DressItem('Witch', 'assets/images/WitchHat.png', 'Witch Hat', 90, 70), // หมวกแม่มดอาจจะทรงสูงหน่อย
    // แว่นตาให้อยู่ต่ำลงมาตรงหน้า (bottom ประมาณ 55) และขนาดเล็กกว่าหมวก
    _DressItem('Glasses', 'assets/images/Sunglasses.png', 'Sunglasses', 55, 30),
    // ที่คาดผมหูแมวและมงกุฎ
    _DressItem('Cat Headband', 'assets/images/CatHeadband.png', 'Cat Headband', 65, 70),
    _DressItem('Crown', 'assets/images/Crown.png', 'Crown', 100, 35),
  ];

  @override
  Widget build(BuildContext context) {
    // หาไอเทมที่กำลังถูกเลือก เพื่อดึงข้อมูลรูป ตำแหน่ง และขนาดมาใช้
    final selectedItem = _selected != null 
        ? _items.firstWhere((item) => item.name == _selected) 
        : null;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Stack(
        children: [
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
                              color: Colors.black.withOpacity(0.12),
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
                                  'assets/images/DressUpBg.png',
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
                              // ── แปะไอเทมที่เลือก (ดึงค่าตำแหน่งจากคลาสมาใช้) ──
                              if (selectedItem != null)
                                Positioned(
                                  bottom: selectedItem.equipBottom, // ใช้ค่าเฉพาะของไอเทมนั้นๆ
                                  child: Image.asset(
                                    selectedItem.imagePath,
                                    height: selectedItem.equipHeight, // ใช้ขนาดเฉพาะของไอเทมนั้นๆ
                                    fit: BoxFit.contain,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 12),

                      // ── Items Grid ──
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 15,
                          childAspectRatio: 0.85, 
                        ),
                        itemCount: _items.length,
                        itemBuilder: (_, i) {
                          final item = _items[i];
                          final sel = _selected == item.name;
                          return GestureDetector(
                            onTap: () => setState(() => _selected = item.name),
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
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    item.imagePath,
                                    height: 45,
                                    width: 45,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.style, size: 40),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    item.label,
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
                        color: Colors.black.withOpacity(0.15),
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
                        color: Colors.black.withOpacity(0.08),
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
                'Dress up',
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