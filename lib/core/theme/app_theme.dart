import 'package:flutter/material.dart';

import 'tokens.dart';

/// Kolory spoza [ColorScheme], dostępne przez `context.appColors`.
@immutable
final class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.textHint,
    required this.surfaceRaised,
    required this.accentFill,
    required this.onAccentFill,
    required this.success,
  });

  factory AppColors.fromPalette(AppPalette p) => AppColors(
    textHint: p.textHint,
    surfaceRaised: p.surfaceRaised,
    accentFill: p.accentFill,
    onAccentFill: p.onAccentFill,
    success: p.success,
  );

  final Color textHint;
  final Color surfaceRaised;
  final Color accentFill;
  final Color onAccentFill;
  final Color success;

  @override
  AppColors copyWith({
    Color? textHint,
    Color? surfaceRaised,
    Color? accentFill,
    Color? onAccentFill,
    Color? success,
  }) => AppColors(
    textHint: textHint ?? this.textHint,
    surfaceRaised: surfaceRaised ?? this.surfaceRaised,
    accentFill: accentFill ?? this.accentFill,
    onAccentFill: onAccentFill ?? this.onAccentFill,
    success: success ?? this.success,
  );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      textHint: Color.lerp(textHint, other.textHint, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      accentFill: Color.lerp(accentFill, other.accentFill, t)!,
      onAccentFill: Color.lerp(onAccentFill, other.onAccentFill, t)!,
      success: Color.lerp(success, other.success, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}

abstract final class AppTheme {
  static const fontFamily = 'Inter';

  /// Cyfry o stałej szerokości: liczby i timer nie „skaczą” przy zmianie.
  static const tabularFigures = [FontFeature.tabularFigures()];

  static ThemeData dark() => _build(AppPalette.dark);

  static ThemeData light() => _build(AppPalette.light);

  static ThemeData _build(AppPalette p) {
    final scheme = ColorScheme(
      brightness: p.brightness,
      primary: p.accentText,
      onPrimary: p.brightness == Brightness.dark ? p.onAccentFill : p.surface,
      primaryContainer: p.accentFill,
      onPrimaryContainer: p.onAccentFill,
      secondary: p.textSecondary,
      onSecondary: p.background,
      secondaryContainer: p.accentFill,
      onSecondaryContainer: p.onAccentFill,
      error: p.danger,
      onError: p.onDanger,
      surface: p.surface,
      onSurface: p.textPrimary,
      onSurfaceVariant: p.textSecondary,
      surfaceContainerLowest: p.background,
      surfaceContainerLow: p.surface,
      surfaceContainer: p.surface,
      surfaceContainerHigh: p.surfaceRaised,
      surfaceContainerHighest: p.surfaceRaised,
      outline: p.outline,
      outlineVariant: p.outline,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: p.background,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
    );

    final textTheme = base.textTheme.apply(
      bodyColor: p.textPrimary,
      displayColor: p.textPrimary,
    );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.m),
    );
    const minButton = Size(AppSizes.minTouch, AppSizes.minTouch);

    return base.copyWith(
      textTheme: textTheme.copyWith(
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        labelLarge: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      extensions: [AppColors.fromPalette(p)],
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: shape,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accentFill,
          foregroundColor: p.onAccentFill,
          minimumSize: minButton,
          shape: shape,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          minimumSize: minButton,
          shape: shape,
          side: BorderSide(color: p.outline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.accentText,
          minimumSize: minButton,
          shape: shape,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: minButton),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: p.accentFill,
        elevation: 0,
        height: 72,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? p.onAccentFill
                : p.textSecondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? p.textPrimary
                : p.textSecondary,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(color: p.outline, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceRaised,
        hintStyle: TextStyle(color: p.textHint),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
          borderSide: BorderSide.none,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.surfaceRaised,
        contentTextStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.s),
        ),
      ),
    );
  }
}
