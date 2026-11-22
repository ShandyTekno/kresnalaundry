import 'package:flutter/material.dart';

import '../data/database.dart';

class ThemePalette {
  final String id;
  final String name;
  final Color color;
  const ThemePalette(this.id, this.name, this.color);
}

const kThemePalettes = [
  ThemePalette('blue', 'Biru Kresna', Color(0xFF1565C0)),
  ThemePalette('teal', 'Hijau Zamrud', Color(0xFF0F766E)),
  ThemePalette('indigo', 'Ungu Indigo', Color(0xFF4338CA)),
  ThemePalette('amber', 'Cokelat Hangat', Color(0xFF9A3412)),
  ThemePalette('slate', 'Abu Kontras', Color(0xFF1E293B)),
];

class AppearanceState {
  final double fontScale;
  final String paletteId;
  final ThemeMode themeMode;
  final bool highContrast;
  final bool boldText;
  final bool largeButtons;

  const AppearanceState({
    this.fontScale = 1.0,
    this.paletteId = 'blue',
    this.themeMode = ThemeMode.light,
    this.highContrast = false,
    this.boldText = false,
    this.largeButtons = false,
  });

  ThemePalette get palette => kThemePalettes.firstWhere(
        (p) => p.id == paletteId,
        orElse: () => kThemePalettes.first,
      );

  Color get primaryColor => palette.color;

  bool get isSeniorFriendly =>
      fontScale >= 1.25 && highContrast && boldText && largeButtons;

  AppearanceState copyWith({
    double? fontScale,
    String? paletteId,
    ThemeMode? themeMode,
    bool? highContrast,
    bool? boldText,
    bool? largeButtons,
  }) =>
      AppearanceState(
        fontScale: fontScale ?? this.fontScale,
        paletteId: paletteId ?? this.paletteId,
        themeMode: themeMode ?? this.themeMode,
        highContrast: highContrast ?? this.highContrast,
        boldText: boldText ?? this.boldText,
        largeButtons: largeButtons ?? this.largeButtons,
      );
}

class AppAppearance extends ValueNotifier<AppearanceState> {
  AppAppearance._() : super(const AppearanceState());
  static final AppAppearance instance = AppAppearance._();

  Future<void> load() async {
    final db = AppDb.instance;
    final scaleStr = await db.getSetting('ui_font_scale', '1.0');
    final paletteId = await db.getSetting('ui_palette', 'blue');
    final modeStr = await db.getSetting('ui_theme_mode', 'light');
    final hc = await db.getSetting('ui_high_contrast', '0') == '1';
    final bold = await db.getSetting('ui_bold_text', '0') == '1';
    final bigBtn = await db.getSetting('ui_large_buttons', '0') == '1';

    final scale = (double.tryParse(scaleStr) ?? 1.0).clamp(0.9, 1.5);
    final mode = switch (modeStr) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };

    value = AppearanceState(
      fontScale: scale,
      paletteId: paletteId,
      themeMode: mode,
      highContrast: hc,
      boldText: bold,
      largeButtons: bigBtn,
    );
  }

  Future<void> update(AppearanceState next) async {
    value = next;
    final db = AppDb.instance;
    final modeStr = switch (next.themeMode) {
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
      ThemeMode.light => 'light',
    };
    await db.setSetting('ui_font_scale', next.fontScale.toStringAsFixed(2));
    await db.setSetting('ui_palette', next.paletteId);
    await db.setSetting('ui_theme_mode', modeStr);
    await db.setSetting('ui_high_contrast', next.highContrast ? '1' : '0');
    await db.setSetting('ui_bold_text', next.boldText ? '1' : '0');
    await db.setSetting('ui_large_buttons', next.largeButtons ? '1' : '0');
  }

  Future<void> toggleSeniorMode(bool enable) {
    if (enable) {
      return update(value.copyWith(
        fontScale: 1.30,
        highContrast: true,
        boldText: true,
        largeButtons: true,
      ));
    }
    return update(value.copyWith(
      fontScale: 1.0,
      highContrast: false,
      boldText: false,
      largeButtons: false,
    ));
  }

  Future<void> reset() => update(const AppearanceState());
}
