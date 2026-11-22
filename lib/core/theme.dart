import 'package:flutter/material.dart';

import 'app_settings.dart';

const kBlue = Color(0xFF1565C0);
const kBlueLight = Color(0xFFE3F0FF);

ThemeData buildTheme(AppearanceState state, {Brightness brightness = Brightness.light}) {
  final isDark = brightness == Brightness.dark;
  final seed = state.primaryColor;
  final baseScheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
  );
  final scheme = state.highContrast
      ? baseScheme.copyWith(
          primary: isDark ? baseScheme.primary : seed,
          surface: isDark ? const Color(0xFF0B0F17) : Colors.white,
          onSurface: isDark ? Colors.white : Colors.black,
          outline: isDark ? Colors.white70 : Colors.black87,
        )
      : baseScheme.copyWith(
          primary: isDark ? baseScheme.primary : seed,
        );

  final scaffoldBg = isDark
      ? (state.highContrast ? const Color(0xFF000000) : const Color(0xFF0F172A))
      : (state.highContrast ? const Color(0xFFF1F5F9) : const Color(0xFFF5F8FC));

  final cardColor = isDark
      ? (state.highContrast ? const Color(0xFF111827) : const Color(0xFF1E293B))
      : Colors.white;

  final borderColor = state.highContrast
      ? (isDark ? Colors.white60 : Colors.black54)
      : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));

  final btnMinHeight = state.largeButtons ? 54.0 : 46.0;
  final baseText =
      (isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme).apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );
  final textTheme = state.boldText
      ? baseText.copyWith(
          bodyLarge: baseText.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          bodyMedium: baseText.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          bodySmall: baseText.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          titleMedium:
              baseText.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          labelLarge: baseText.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        )
      : baseText;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: scaffoldBg,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? const Color(0xFF1E293B) : seed,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: state.boldText ? FontWeight.w800 : FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: cardColor,
      surfaceTintColor: Colors.transparent,
      elevation: isDark ? 0 : (state.highContrast ? 2 : 1.5),
      shadowColor: Colors.black.withValues(alpha: 0.08),
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: state.highContrast
              ? borderColor
              : borderColor.withValues(alpha: isDark ? 0.9 : 0.7),
          width: state.highContrast ? 1.6 : 1,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: borderColor,
          width: state.highContrast ? 1.5 : 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: state.largeButtons ? 16 : 12,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        minimumSize: Size(0, btnMinHeight),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: state.largeButtons ? 16 : 14.5,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: Size(0, btnMinHeight),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        side: BorderSide(
          color: state.highContrast ? scheme.primary : borderColor,
          width: state.highContrast ? 1.6 : 1.2,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: state.largeButtons ? 15.5 : 14,
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: cardColor,
      indicatorColor: scheme.primary.withValues(alpha: isDark ? 0.28 : 0.14),
      labelTextStyle: WidgetStateProperty.all(
        TextStyle(
          fontSize: 12,
          fontWeight: state.boldText ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: cardColor,
      indicatorColor: scheme.primary.withValues(alpha: isDark ? 0.28 : 0.14),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    listTileTheme: ListTileThemeData(
      titleTextStyle: TextStyle(
        fontSize: 15,
        fontWeight: state.boldText ? FontWeight.w700 : FontWeight.w600,
        color: scheme.onSurface,
      ),
      subtitleTextStyle: TextStyle(
        fontSize: 13,
        fontWeight: state.boldText ? FontWeight.w600 : FontWeight.w400,
        color: scheme.onSurfaceVariant,
      ),
      leadingAndTrailingTextStyle: TextStyle(
        fontSize: 15.5,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
    ),
  );
}

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const StatusBadge(this.label, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Color.lerp(color, Colors.white, 0.35)! : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
