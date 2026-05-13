import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_routes.dart';

class SelectBackgroundScreen extends StatefulWidget {
  final String? roomType;

  const SelectBackgroundScreen({super.key, this.roomType});

  @override
  State<SelectBackgroundScreen> createState() => _SelectBackgroundScreenState();
}

class _SelectBackgroundScreenState extends State<SelectBackgroundScreen> {
  String? selectedLocation;

  final List<Map<String, String>> locations = [
    {
      'id': 'kao_tapu',
      'title': 'Kao Tapu',
      'image': 'assets/images/backgrounds/kao_tapu.png',
    },
    {
      'id': 'red_lotus_lake',
      'title': 'Red Lotus Lake',
      'image': 'assets/images/backgrounds/red_lotus_lake.png',
    },
    {
      'id': 'sea_of_cloud',
      'title': 'The Sea of Cloud',
      'image': 'assets/images/backgrounds/sea_of_cloud.png',
    },
    {
      'id': 'lumphini_park',
      'title': 'Lumphini Park',
      'image': 'assets/images/backgrounds/lumphini_park.png',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final roomType = widget.roomType ?? (args is String ? args : null);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppColors.brownDeep,
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
                        child: const Icon(
                          Icons.chevron_left,
                          color: Colors.black,
                          size: 30,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'Select background',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85,
              ),
              itemCount: locations.length,
              itemBuilder: (context, index) {
                final loc = locations[index];
                final isSelected = selectedLocation == loc['id'];

                return GestureDetector(
                  onTap: () => setState(() => selectedLocation = loc['id']),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        width: isSelected ? 3 : 0,
                        color: isSelected
                            ? const Color(0xFF85BA72)
                            : Colors.transparent,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 3,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                            child: Image.asset(
                              loc['image']!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    color: Colors.grey.shade300,
                                    child: const Icon(Icons.image),
                                  ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Center(
                            child: Text(
                              loc['title']!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  ElevatedButton(
                    onPressed: selectedLocation != null
                        ? () {
                            final selectedLocData = locations.firstWhere(
                              (loc) => loc['id'] == selectedLocation,
                            );

                            if (roomType == 'group' || roomType == 'create') {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.groupChatScreen,
                                arguments: {
                                  'roomName': selectedLocData['title'],
                                  'bgImage': selectedLocData['image'],
                                },
                              );
                            } else {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.chatScreen,
                                arguments: {
                                  'roomName': selectedLocData['title'],
                                  'bgImage': selectedLocData['image'],
                                  'roomType': roomType,
                                },
                              );
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD9EACF),
                      foregroundColor: Colors.black,
                      elevation: 4,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      "Let's go!",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 45,
                    height: 45,
                    decoration: const BoxDecoration(
                      color: Color(0xFF6B5E5B),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white,
                      size: 30,
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
