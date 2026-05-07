import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class BlockedScreen extends StatefulWidget {
  const BlockedScreen({super.key});

  @override
  State<BlockedScreen> createState() => _BlockedScreenState();
}

class _BlockedScreenState extends State<BlockedScreen> {
  static const int _maxBlocked = 5;
  final List<String> _blocked = ['Somchai', 'Somying'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg, // พื้นหลังสีครีม
      body: Column(
        children: [
          _buildCustomAppBar(context),
          // แสดงจำนวนผู้ที่ถูกบล็อกชิดขวา
          Padding(
            padding: const EdgeInsets.only(top: 20, right: 30, bottom: 10),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${_blocked.length}/$_maxBlocked',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          Expanded(
            child: _blocked.isEmpty
                ? const Center(
                    child: Text(
                      'No blocked users',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _blocked.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (_, i) => _buildBlockedCard(_blocked[i], i),
                  ),
          ),
        ],
      ),
    );
  }

  // ─── Custom App Bar (สไตล์เดียวกับหน้า Profile/Notification) ───
  Widget _buildCustomAppBar(BuildContext context) {
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
                'Blocked',
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

  // ─── Blocked User Card ───
  Widget _buildBlockedCard(String name, int index) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
      child: Row(
        children: [
          // Avatar Box (สี่เหลี่ยมขอบมนสไตล์เดียวกับหน้า Profile)
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                )
              ],
              border: Border.all(
                color: Colors.grey.shade200,
                width: 1.5,
              ),
            ),
            child: const Icon(Icons.person, color: Colors.grey, size: 35),
          ),
          const SizedBox(width: 16),
          // Username
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: Colors.black,
              ),
            ),
          ),
          // Unblock Button (สีเทาตามรูป)
          GestureDetector(
            onTap: () => setState(() => _blocked.removeAt(index)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFDEDEDE), // สีเทาอ่อน
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: const Text(
                'Unblock',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}