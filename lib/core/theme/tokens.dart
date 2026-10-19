import 'package:flutter/material.dart';

/// Design tokens RepTrack (ADR 0012). Wartości są jedynym źródłem kolorów,
/// odstępów i rozmiarów w UI.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Boczny margines ekranu.
  static const double gutter = l;
}

abstract final class AppRadius {
  static const double s = 12;
  static const double m = 16;
  static const double l = 24;
}

abstract final class AppSizes {
  /// Minimalny cel dotyku (WCAG, Material).
  static const double minTouch = 48;

  /// Steppery ciężaru i powtórzeń w aktywnym treningu.
  static const double stepper = 56;

  /// Główna akcja treningu („Zatwierdź serię”).
  static const double primaryAction = 64;

  static const double iconM = 24;
  static const double iconL = 32;
  static const double iconXl = 48;
}

/// Paleta jednego motywu. Kontrast tekstu do tła co najmniej WCAG AA.
@immutable
final class AppPalette {
  const AppPalette({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.outline,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.accentFill,
    required this.onAccentFill,
    required this.accentText,
    required this.danger,
    required this.onDanger,
    required this.success,
  });

  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color outline;
  final Color textPrimary;
  final Color textSecondary;

  /// Podpowiedzi (np. wartości z poprzedniego treningu): wyraźnie słabsze
  /// od wpisanych, ale nadal ≥ 4,5:1 na [surface].
  final Color textHint;

  /// Akcent „volt” jako wypełnienie (przyciski, wskaźniki).
  final Color accentFill;
  final Color onAccentFill;

  /// Akcent jako kolor tekstu i ikon na tle [background]/[surface].
  final Color accentText;
  final Color danger;
  final Color onDanger;
  final Color success;

  static const volt = Color(0xFFC8F25A);
  static const ink = Color(0xFF0E0F11);

  static const dark = AppPalette(
    brightness: Brightness.dark,
    background: ink,
    surface: Color(0xFF17181C),
    surfaceRaised: Color(0xFF1F2126),
    outline: Color(0xFF2E3138),
    textPrimary: Color(0xFFF2F3F5),
    textSecondary: Color(0xFFA8ADB7),
    textHint: Color(0xFF8A909B),
    accentFill: volt,
    onAccentFill: ink,
    accentText: volt,
    danger: Color(0xFFFF7A7A),
    onDanger: ink,
    success: Color(0xFF7EE0A1),
  );

  static const light = AppPalette(
    brightness: Brightness.light,
    background: Color(0xFFF5F6F8),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFF0F1F4),
    outline: Color(0xFFD9DCE2),
    textPrimary: Color(0xFF111318),
    textSecondary: Color(0xFF4A505C),
    textHint: Color(0xFF6B7280),
    accentFill: volt,
    onAccentFill: ink,
    accentText: Color(0xFF3F5A00),
    danger: Color(0xFFB3261E),
    onDanger: Color(0xFFFFFFFF),
    success: Color(0xFF1E7A43),
  );
}
