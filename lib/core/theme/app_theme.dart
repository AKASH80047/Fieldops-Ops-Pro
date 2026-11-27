import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum AppPalette {
  violet('Violet', Color(0xFF6738E8)),
  ocean('Ocean blue', Color(0xFF1859B2)),
  forest('Forest green', Color(0xFF167054));

  const AppPalette(this.label, this.color);
  final String label;
  final Color color;
}

final appPalette = ValueNotifier(AppPalette.violet);
const _themeStorage = FlutterSecureStorage();

Future<void> restoreAppPalette() async {
  try {
    final name = await _themeStorage.read(key: 'app_palette');
    appPalette.value = AppPalette.values.byName(name ?? 'violet');
  } catch (error) {
    debugPrint('Could not restore appearance: ${error.runtimeType}');
  }
}

Future<void> selectAppPalette(AppPalette palette) async {
  appPalette.value = palette;
  try {
    await _themeStorage.write(key: 'app_palette', value: palette.name);
  } catch (error) {
    debugPrint('Could not save appearance: ${error.runtimeType}');
  }
}

abstract final class AppColors {
  static const primary = Color(0xFF6738E8),
      secondary = Color(0xFF8B5CF6),
      background = Color(0xFFF7F7FB),
      ink = Color(0xFF17152A),
      muted = Color(0xFF66647A),
      border = Color(0xFFE7E5EE),
      softPrimary = Color(0xFFF0EBFF),
      success = Color(0xFF16A34A),
      warning = Color(0xFFF59E0B),
      error = Color(0xFFDC2626);
}

ThemeData appTheme([AppPalette palette = AppPalette.violet]) => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: AppColors.background,
  colorScheme: ColorScheme.light(
    primary: palette.color,
    secondary: palette.color,
    primaryContainer: Color.alphaBlend(
      palette.color.withValues(alpha: .09),
      Colors.white,
    ),
    surface: Colors.white,
    error: AppColors.error,
    onPrimary: Colors.white,
    onSurface: AppColors.ink,
  ),
  textTheme: const TextTheme(
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w800,
      color: AppColors.ink,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
    ),
    bodyMedium: TextStyle(fontSize: 14, color: AppColors.muted, height: 1.4),
    bodySmall: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.35),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
  ),
  appBarTheme: const AppBarTheme(
    elevation: 0,
    centerTitle: false,
    backgroundColor: AppColors.background,
    foregroundColor: AppColors.ink,
    surfaceTintColor: Colors.transparent,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: palette.color, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.error, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
  ),
  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 0,
    margin: EdgeInsets.zero,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: AppColors.border),
    ),
  ),
  navigationBarTheme: NavigationBarThemeData(
    height: 72,
    elevation: 0,
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    indicatorColor: palette.color.withValues(alpha: .12),
    iconTheme: WidgetStateProperty.resolveWith(
      (states) => IconThemeData(
        color: states.contains(WidgetState.selected)
            ? palette.color
            : AppColors.muted,
      ),
    ),
    labelTextStyle: WidgetStateProperty.resolveWith(
      (states) => TextStyle(
        fontWeight: states.contains(WidgetState.selected)
            ? FontWeight.w800
            : FontWeight.w600,
        color: states.contains(WidgetState.selected)
            ? palette.color
            : AppColors.muted,
      ),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 50),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(48, 48),
      foregroundColor: palette.color,
      side: const BorderSide(color: AppColors.border),
      textStyle: const TextStyle(fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: Colors.white,
    side: const BorderSide(color: Color(0xFFEAE8F2)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    labelStyle: const TextStyle(
      color: AppColors.ink,
      fontWeight: FontWeight.w600,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: AppColors.ink,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    showDragHandle: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
  ),
  dividerTheme: const DividerThemeData(color: AppColors.border, space: 1),
);
