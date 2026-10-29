import 'package:flutter/material.dart';

class AppColors {
  static const accent = Color(0xFF00ACC3);
  static const accentDark = Color(0xFF009DB3);
  static const success = Color(0xFF00ACC2);
  static const failure = Color(0xFFFF005A);
  static const warning = Color(0xFFFF9600);
  static const text = Color(0xFF585858);
  static const textStrong = Color(0xFF212121);
  static const grey = Color(0xFFEBEBEB);
  static const background = Color(0xFFF7F7F7);
  static const purple = Color(0xFF4A148C);
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'DMSans',
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      primary: AppColors.accent,
      error: AppColors.failure,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: Colors.white,
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.textStrong,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'DMSans',
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: AppColors.textStrong,
      ),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.textStrong,
      displayColor: AppColors.textStrong,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        textStyle: const TextStyle(fontFamily: 'DMSans', fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textStrong,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: AppColors.grey, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        textStyle: const TextStyle(fontFamily: 'DMSans', fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      selectedColor: AppColors.accent,
      side: const BorderSide(color: AppColors.grey),
      shape: const StadiumBorder(),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    ),
  );
}
