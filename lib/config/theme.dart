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
  static const background = Color(0xFFF4F4F4);
  static const purple = Color(0xFF4A148C);
  static const ai = Color(0xFFAA58AD);

  // Karanlık mod (Popsa'nın koyu arayüzü)
  static const darkBackground = Color(0xFF1B1B1B);
  static const darkCard = Color(0xFF2B2B2B);
  static const darkPill = Color(0xFF3A3A3A);
}

/// Açık/koyu moda göre değişen arayüz renkleri.
extension AppThemeX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Kart / bölüm arka planı.
  Color get cardColor => isDark ? AppColors.darkCard : AppColors.background;

  /// Gri hap düğmeler (Paylaş, İleri, sayfa düğmeleri).
  Color get pillColor => isDark ? AppColors.darkPill : const Color(0xFFE6E6E6);

  Color get strongText => isDark ? Colors.white : AppColors.textStrong;

  Color get mutedText => isDark ? const Color(0xFFB5B5B5) : AppColors.text;

  Color get divider => isDark ? const Color(0xFF3A3A3A) : AppColors.grey;

  Color get sheetColor => isDark ? const Color(0xFF242424) : Colors.white;
}

ThemeData buildAppTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final bg = dark ? AppColors.darkBackground : Colors.white;
  final fg = dark ? Colors.white : AppColors.textStrong;
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: 'DMSans',
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: brightness,
      primary: AppColors.accent,
      error: AppColors.failure,
      surface: bg,
    ),
    scaffoldBackgroundColor: bg,
  );
  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: fg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: 'DMSans', fontSize: 20, fontWeight: FontWeight.w500, color: fg),
    ),
    textTheme: base.textTheme.apply(bodyColor: fg, displayColor: fg),
    dividerColor: dark ? const Color(0xFF3A3A3A) : AppColors.grey,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        disabledBackgroundColor: dark ? AppColors.darkPill : const Color(0xFFE0E0E0),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontFamily: 'DMSans', fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: fg,
        minimumSize: const Size.fromHeight(52),
        side: BorderSide(color: dark ? const Color(0xFF5A5A5A) : const Color(0xFFD0D0D0), width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontFamily: 'DMSans', fontSize: 15, fontWeight: FontWeight.w500),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.accent : Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColors.accent.withValues(alpha: 0.4) : (dark ? AppColors.darkPill : const Color(0xFFD6D6D6)),
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: dark ? const Color(0xFF242424) : Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: bg,
      indicatorColor: dark ? AppColors.darkPill : const Color(0xFFE6E6E6),
      labelTextStyle: WidgetStatePropertyAll(TextStyle(fontFamily: 'DMSans', fontSize: 12, color: fg)),
      iconTheme: WidgetStatePropertyAll(IconThemeData(color: fg)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
