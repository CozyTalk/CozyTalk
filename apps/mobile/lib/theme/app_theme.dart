import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.scaffoldBg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.headerBg,
          surface: AppColors.scaffoldBg,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.headerBg,
          foregroundColor: AppColors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: AppColors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Nunito',
          ),
          iconTheme: IconThemeData(color: AppColors.white),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(
            color: AppColors.headerBg,
            fontFamily: 'Nunito',
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.saveBtn,
            foregroundColor: AppColors.headerBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              fontFamily: 'Nunito',
            ),
          ),
        ),
      );
}
