import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'widgets.dart';

class ChooseRoomTypeScreen extends StatelessWidget {
  const ChooseRoomTypeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: buildAppBar(context, 'Choose Room Type'),
      body: const Center(
        child: Text(
          'Choose Room Type — coming soon!',
          style: TextStyle(color: AppColors.grayDark, fontSize: 16),
        ),
      ),
    );
  }
}
