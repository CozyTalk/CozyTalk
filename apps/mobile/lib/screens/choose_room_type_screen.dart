import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_routes.dart';

class ChooseRoomTypeScreen extends StatefulWidget {
  const ChooseRoomTypeScreen({super.key});

  @override
  State<ChooseRoomTypeScreen> createState() => _ChooseRoomTypeScreenState();
}

class _ChooseRoomTypeScreenState extends State<ChooseRoomTypeScreen> {
  String? selectedType;

  void handleJoin() {
    if (selectedType == null) return;

    if (selectedType == "1v1") {
      Navigator.pushNamed(context, AppRoutes.selectBackground,
          arguments: "1v1");
    } else if (selectedType == "group") {
      _showJoinGroupDialog();
    } else if (selectedType == "create") {
      Navigator.pushNamed(context, AppRoutes.selectBackground,
          arguments: "create");
    }
  }

  void _showJoinGroupDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 40),
                    const Text(
                      'Join a room',
                      style:
                          TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 30),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(
                              context, AppRoutes.selectBackground,
                              arguments: "group");
                        },
                        child: _dialogOptionCard(
                            'Random Match', 'Meet\nsomeone\nnew!'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, AppRoutes.joinRoomId);
                        },
                        child: _dialogOptionCard('Room ID',
                            'Enter a Room\nID to join your\nfriend.'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _dialogOptionCard(String title, String subtitle) {
    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
                height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _roomTypeCard({
    required String type,
    required String title,
    required String description,
    required String imagePath,
    bool wide = false,
  }) {
    final isSelected = selectedType == type;

    return GestureDetector(
      onTap: () => setState(() => selectedType = type),
      child: Container(
        height: wide ? 180 : 260,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            width: isSelected ? 3 : 1.5,
            color: isSelected ? Colors.black : const Color(0xFFD9D9D9),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.black)),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                  height: 1.3),
            ),
            const Spacer(),
            Image.asset(
              imagePath,
              height: wide ? 70 : 90,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.broken_image, size: 40, color: Colors.red),
                  Text(
                    'Missing:\n$imagePath',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10, color: Colors.red),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isSelectedAny = selectedType != null;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          Container(
            width: double.infinity,
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
                            ),
                          ],
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(Icons.chevron_left,
                            color: Colors.black, size: 30),
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'Choose your room type',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                              color: Color(0xFF85BA72),
                              shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      const Text('User online ~ 234',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _roomTypeCard(
                            type: '1v1',
                            title: '1 on 1',
                            description:
                                'A private chat with\none stranger.\nCozy and personal.',
                            imagePath: 'assets/images/1on1_doodle.png'),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _roomTypeCard(
                            type: 'group',
                            title: 'Group',
                            description:
                                'Meet multiple\nstrangers at once.\nMore fun, more\nchaos!',
                            imagePath: 'assets/images/group_doodle.png'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _roomTypeCard(
                      type: 'create',
                      title: 'Create Group Room',
                      description: 'Chat privately with your crew.',
                      imagePath: 'assets/images/create_group_doodle.png',
                      wide: true),
                  const SizedBox(height: 40),
                  GestureDetector(
                    onTap: handleJoin,
                    child: Container(
                      width: double.infinity,
                      height: 65,
                      decoration: BoxDecoration(
                        color: isSelectedAny
                            ? const Color(0xFF85BA72)
                            : const Color(0xFFE0E0E0),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.black12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4))
                        ],
                      ),
                      child: Center(
                        child: Text(
                          'Join Room',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: isSelectedAny
                                  ? Colors.white
                                  : Colors.black54),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
