import 'package:flutter/material.dart';

/// Warm, friendly palette: cream background, orange accent, dark-brown ink.
class VeilColors {
  static const orange = Color(0xFFEF6C1A);
  static const orangeSoft = Color(0xFFFFE6D4);
  static const cream = Color(0xFFFFFAF5);
  static const peach = Color(0xFFFFF1E6);
  static const ink = Color(0xFF3B2A20);
  static const muted = Color(0xFF8C7B70);
  static const line = Color(0xFFF2E2D5);
  static const sky = Color(0xFF3B7DD8);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: VeilColors.orange,
    primary: VeilColors.orange,
    onPrimary: Colors.white,
    primaryContainer: VeilColors.orangeSoft,
    onPrimaryContainer: VeilColors.ink,
    surface: VeilColors.cream,
    onSurface: VeilColors.ink,
    surfaceContainerHighest: VeilColors.peach,
    onSurfaceVariant: VeilColors.muted,
    outline: VeilColors.line,
    error: const Color(0xFFD64545),
  );
  const ink = VeilColors.ink;
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(24));

  return ThemeData(
    fontFamily: 'Montserrat',
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: VeilColors.cream,
    splashFactory: InkSparkle.splashFactory,
    textTheme: const TextTheme(
      displaySmall: TextStyle(
          fontSize: 38, height: 1.1, fontWeight: FontWeight.w800, color: VeilColors.orange),
      headlineSmall: TextStyle(
          fontSize: 26, height: 1.2, fontWeight: FontWeight.w800, color: ink),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ink),
      titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ink),
      bodyLarge: TextStyle(fontSize: 16, height: 1.45, color: ink),
      bodyMedium: TextStyle(fontSize: 15, height: 1.45, color: ink),
      bodySmall: TextStyle(fontSize: 13, height: 1.4, color: VeilColors.muted),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: VeilColors.cream,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ink),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 10,
      shadowColor: VeilColors.orange.withValues(alpha: 0.12),
      shape: shape,
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: VeilColors.peach,
      hintStyle: const TextStyle(color: VeilColors.muted),
      labelStyle: const TextStyle(color: VeilColors.muted),
      floatingLabelStyle: const TextStyle(color: VeilColors.orange),
      prefixIconColor: VeilColors.orange,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: VeilColors.orange, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: VeilColors.orange,
        foregroundColor: Colors.white,
        disabledBackgroundColor: VeilColors.line,
        minimumSize: const Size.fromHeight(58),
        shape: const StadiumBorder(),
        elevation: 6,
        shadowColor: VeilColors.orange.withValues(alpha: 0.4),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: VeilColors.orange,
        minimumSize: const Size.fromHeight(58),
        shape: const StadiumBorder(),
        side: const BorderSide(color: VeilColors.orangeSoft, width: 1.5),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: VeilColors.orange,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: VeilColors.orangeSoft,
      elevation: 0,
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? VeilColors.orange : VeilColors.muted)),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? VeilColors.orange : VeilColors.muted,
          )),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: VeilColors.orange,
      unselectedLabelColor: VeilColors.muted,
      indicatorColor: VeilColors.orange,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: Colors.transparent,
      labelStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      unselectedLabelStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: Colors.white,
        selectedBackgroundColor: VeilColors.orange,
        selectedForegroundColor: Colors.white,
        foregroundColor: VeilColors.ink,
        side: const BorderSide(color: VeilColors.line),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? VeilColors.orange : Colors.transparent),
      side: const BorderSide(color: VeilColors.orange, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: VeilColors.orangeSoft,
      side: BorderSide.none,
      labelStyle: TextStyle(color: VeilColors.orange, fontWeight: FontWeight.w700),
      shape: StadiumBorder(),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: VeilColors.orange),
    popupMenuTheme: PopupMenuThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: VeilColors.cream,
      surfaceTintColor: Colors.transparent,
      shape: shape,
    ),
  );
}
