import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tokens.dart';

ThemeData buildTheme(Brightness b) {
  final t = b == Brightness.dark ? JeyaboTokens.dark : JeyaboTokens.light;
  final scheme = ColorScheme(
    brightness: b, primary: t.brand, onPrimary: t.onBrand, primaryContainer: t.brandSoft, onPrimaryContainer: t.ink,
    secondary: t.accent, onSecondary: t.onAccent, secondaryContainer: t.brandSoft, onSecondaryContainer: t.ink, tertiary: t.gold, onTertiary: t.onGold,
    error: t.danger, onError: t.onDanger, surface: t.surface, onSurface: t.ink, onSurfaceVariant: t.inkMuted,
    surfaceContainerHighest: t.surfaceRaised, outline: t.borderStrong, outlineVariant: t.border,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: b);
  final body = GoogleFonts.figtreeTextTheme(base.textTheme).apply(bodyColor: t.ink, displayColor: t.ink);
  final display = GoogleFonts.bricolageGrotesque;
  return base.copyWith(
    extensions: [t],
    scaffoldBackgroundColor: t.bg,
    textTheme: body.copyWith(
      headlineMedium: display(fontSize: 32, height: 38 / 32, fontWeight: FontWeight.w700, color: t.ink),
      titleLarge: display(fontSize: 20, height: 28 / 20, fontWeight: FontWeight.w600, color: t.ink),
    ),
    appBarTheme: AppBarTheme(backgroundColor: t.bg, foregroundColor: t.ink, elevation: 0, scrolledUnderElevation: 0, centerTitle: false),
    cardTheme: CardThemeData(color: t.surface, elevation: 0, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rd.lg), side: BorderSide(color: t.border))),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: t.surfaceRaised,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(Rd.md), borderSide: BorderSide(color: t.borderStrong)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Rd.md), borderSide: BorderSide(color: t.borderStrong)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Rd.md), borderSide: BorderSide(color: t.brand, width: 2)),
    ),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(backgroundColor: t.brand, foregroundColor: t.onBrand, minimumSize: const Size(64, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rd.md)), textStyle: const TextStyle(fontWeight: FontWeight.w700))),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(foregroundColor: t.ink, minimumSize: const Size(64, 48), side: BorderSide(color: t.borderStrong, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rd.md)))),
    dividerTheme: DividerThemeData(color: t.border, space: 1, thickness: 1),
    navigationBarTheme: NavigationBarThemeData(backgroundColor: Colors.transparent, indicatorColor: t.brandSoft, labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.ink))),
    snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: t.ink, contentTextStyle: TextStyle(color: t.bg)),
  );
}
