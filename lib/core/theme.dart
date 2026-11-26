import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// AgroBid admin palette: forest green for the brand, grain gold as the accent.
class AppColors {
  static const primary = Color(0xFF1F6B3A);
  static const primaryDark = Color(0xFF14492A);
  static const primarySoft = Color(0xFFE6F1EA);
  static const sidebar = Color(0xFF0F2619);
  static const sidebarHover = Color(0xFF1A3826);
  static const sidebarText = Color(0xFFA9BDB0);
  static const accent = Color(0xFFD9A21B);
  static const background = Color(0xFFF4F6F4);
  static const surface = Colors.white;
  static const border = Color(0xFFE2E8E4);
  static const text = Color(0xFF16261C);
  static const muted = Color(0xFF6A786F);
  static const tableHeader = Color(0xFFF7F9F8);

  static const success = Color(0xFF1E8A4C);
  static const warning = Color(0xFFC77C0A);
  static const danger = Color(0xFFC6392F);
  static const info = Color(0xFF2F6DB5);
  static const neutral = Color(0xFF6B7C8C);

  /// Categorical series colours for charts, in a fixed order so a category keeps its colour.
  static const chart = [Color(0xFF1F7A45), Color(0xFFD9A21B), Color(0xFF2F6DB5), Color(0xFFC8553D), Color(0xFF2A9D8F), Color(0xFF8A6BBE)];
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary, surface: AppColors.surface).copyWith(
    primary: AppColors.primary,
    onSurface: AppColors.text,
    onSurfaceVariant: AppColors.muted,
    outline: AppColors.border,
    outlineVariant: AppColors.border,
    surfaceContainerLow: AppColors.background,
    primaryContainer: AppColors.primarySoft,
    onPrimaryContainer: AppColors.primaryDark,
    error: AppColors.danger,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true, scaffoldBackgroundColor: AppColors.background);
  final text = GoogleFonts.interTextTheme(base.textTheme).apply(bodyColor: AppColors.text, displayColor: AppColors.text);
  final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
  const buttonPadding = EdgeInsets.symmetric(horizontal: 18, vertical: 14);

  OutlineInputBorder outline(Color color, [double width = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: color, width: width));

  return base.copyWith(
    textTheme: text,
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: outline(AppColors.border),
      enabledBorder: outline(AppColors.border),
      focusedBorder: outline(AppColors.primary, 1.6),
      errorBorder: outline(AppColors.danger),
      labelStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
      prefixIconColor: AppColors.muted,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(shape: rounded, padding: buttonPadding, textStyle: const TextStyle(fontWeight: FontWeight.w600)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: rounded,
        padding: buttonPadding,
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.border),
        backgroundColor: AppColors.surface,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(shape: rounded, textStyle: const TextStyle(fontWeight: FontWeight.w600))),
    chipTheme: base.chipTheme.copyWith(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), side: const BorderSide(color: AppColors.border)),
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStateProperty.all(AppColors.tableHeader),
      headingTextStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted, letterSpacing: 0.3),
      dataTextStyle: GoogleFonts.inter(fontSize: 13.5, color: AppColors.text),
      dataRowMinHeight: 52,
      dataRowMaxHeight: 64,
      headingRowHeight: 44,
      horizontalMargin: 20,
      columnSpacing: 28,
      dividerThickness: 1,
    ),
    dialogTheme: DialogThemeData(backgroundColor: AppColors.surface, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, shape: rounded, backgroundColor: AppColors.text),
    tooltipTheme: TooltipThemeData(decoration: BoxDecoration(color: AppColors.text, borderRadius: BorderRadius.circular(6)), textStyle: const TextStyle(color: Colors.white, fontSize: 12)),
    popupMenuTheme: PopupMenuThemeData(color: AppColors.surface, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: AppColors.border))),
  );
}
