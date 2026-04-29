import 'package:flutter/material.dart';

/// HSL helper — Flutter needs Color, CSS gives us HSL.
Color _hsl(double h, double s, double l, [double a = 1.0]) {
  return HSLColor.fromAHSL(a, h, s / 100, l / 100).toColor();
}

// ─── Dark palette ───────────────────────────────────────────────────────────

final _darkBackground = _hsl(222, 20, 7);
final _darkForeground = _hsl(210, 20, 96);
final _darkCard = _hsl(222, 20, 9);
final _darkBorder = _hsl(215, 20, 17);
final _darkMuted = _hsl(215, 20, 13);
final _darkMutedFg = _hsl(215, 15, 55);
final _darkPrimary = _hsl(213, 94, 55);
final _darkPrimaryFg = _hsl(0, 0, 100);
final _darkSecondary = _hsl(215, 20, 13);
final _darkSecondaryFg = _hsl(210, 20, 96);
final _darkDestructive = _hsl(0, 72, 51);
final _darkSuccess = _hsl(142, 71, 45);
final _darkWarning = _hsl(38, 92, 50);
const _statusDroppedOff = Color(0xFF34D399);

// ─── Light palette ──────────────────────────────────────────────────────────

final _lightBackground = _hsl(210, 20, 97);
final _lightForeground = _hsl(222, 25, 12);
final _lightCard = _hsl(0, 0, 100);
final _lightBorder = _hsl(214, 20, 88);
final _lightMutedFg = _hsl(215, 15, 45);
final _lightPrimary = _hsl(213, 94, 48);
final _lightPrimaryFg = _hsl(0, 0, 100);
final _lightSecondary = _hsl(214, 20, 93);
final _lightSecondaryFg = _hsl(222, 25, 12);
final _lightDestructive = _hsl(0, 72, 46);
final _lightSuccess = _hsl(142, 71, 35);
final _lightWarning = _hsl(38, 92, 42);

// ─── Semantic color extension ───────────────────────────────────────────────

/// Theme-aware semantic colors accessible via [AppColors.of].
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.background,
    required this.foreground,
    required this.card,
    required this.border,
    required this.muted,
    required this.mutedForeground,
    required this.primary,
    required this.primaryForeground,
    required this.secondary,
    required this.secondaryForeground,
    required this.destructive,
    required this.success,
    required this.warning,
    required this.statusDroppedOff,
  });

  final Color background;
  final Color foreground;
  final Color card;
  final Color border;
  final Color muted;
  final Color mutedForeground;
  final Color primary;
  final Color primaryForeground;
  final Color secondary;
  final Color secondaryForeground;
  final Color destructive;
  final Color success;
  final Color warning;
  final Color statusDroppedOff;

  @override
  AppSemanticColors copyWith({
    Color? background,
    Color? foreground,
    Color? card,
    Color? border,
    Color? muted,
    Color? mutedForeground,
    Color? primary,
    Color? primaryForeground,
    Color? secondary,
    Color? secondaryForeground,
    Color? destructive,
    Color? success,
    Color? warning,
    Color? statusDroppedOff,
  }) {
    return AppSemanticColors(
      background: background ?? this.background,
      foreground: foreground ?? this.foreground,
      card: card ?? this.card,
      border: border ?? this.border,
      muted: muted ?? this.muted,
      mutedForeground: mutedForeground ?? this.mutedForeground,
      primary: primary ?? this.primary,
      primaryForeground: primaryForeground ?? this.primaryForeground,
      secondary: secondary ?? this.secondary,
      secondaryForeground: secondaryForeground ?? this.secondaryForeground,
      destructive: destructive ?? this.destructive,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      statusDroppedOff: statusDroppedOff ?? this.statusDroppedOff,
    );
  }

  @override
  AppSemanticColors lerp(AppSemanticColors? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      background: Color.lerp(background, other.background, t)!,
      foreground: Color.lerp(foreground, other.foreground, t)!,
      card: Color.lerp(card, other.card, t)!,
      border: Color.lerp(border, other.border, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      mutedForeground: Color.lerp(mutedForeground, other.mutedForeground, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryForeground: Color.lerp(
        primaryForeground,
        other.primaryForeground,
        t,
      )!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      secondaryForeground: Color.lerp(
        secondaryForeground,
        other.secondaryForeground,
        t,
      )!,
      destructive: Color.lerp(destructive, other.destructive, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      statusDroppedOff: Color.lerp(
        statusDroppedOff,
        other.statusDroppedOff,
        t,
      )!,
    );
  }
}

// ─── Convenience accessor ───────────────────────────────────────────────────

/// Use `AppColors.of(context).primary` etc. to get theme-aware semantic colors.
class AppColors {
  AppColors._();

  static AppSemanticColors of(BuildContext context) =>
      Theme.of(context).extension<AppSemanticColors>()!;

  // Dark mode (fallback statics — prefer AppColors.of(context) for theme-aware access)
  static Color get background => _darkBackground;
  static Color get foreground => _darkForeground;
  static Color get card => _darkCard;
  static Color get border => _darkBorder;
  static Color get muted => _darkMuted;
  static Color get mutedForeground => _darkMutedFg;
  static Color get primary => _darkPrimary;
  static Color get primaryForeground => _darkPrimaryFg;
  static Color get secondary => _darkSecondary;
  static Color get secondaryForeground => _darkSecondaryFg;
  static Color get destructive => _darkDestructive;
  static Color get success => _darkSuccess;
  static Color get warning => _darkWarning;
  static Color get statusDroppedOff => _statusDroppedOff;
}

// ─── Theme data ─────────────────────────────────────────────────────────────

class AppTheme {
  AppTheme._();

  static ThemeData get dark => _buildTheme(
    brightness: Brightness.dark,
    background: _darkBackground,
    foreground: _darkForeground,
    card: _darkCard,
    border: _darkBorder,
    muted: _darkMuted,
    mutedFg: _darkMutedFg,
    primary: _darkPrimary,
    primaryFg: _darkPrimaryFg,
    secondary: _darkSecondary,
    secondaryFg: _darkSecondaryFg,
    destructive: _darkDestructive,
    success: _darkSuccess,
    warning: _darkWarning,
  );

  static ThemeData get light => _buildTheme(
    brightness: Brightness.light,
    background: _lightBackground,
    foreground: _lightForeground,
    card: _lightCard,
    border: _lightBorder,
    muted: _lightSecondary,
    mutedFg: _lightMutedFg,
    primary: _lightPrimary,
    primaryFg: _lightPrimaryFg,
    secondary: _lightSecondary,
    secondaryFg: _lightSecondaryFg,
    destructive: _lightDestructive,
    success: _lightSuccess,
    warning: _lightWarning,
  );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color background,
    required Color foreground,
    required Color card,
    required Color border,
    required Color muted,
    required Color mutedFg,
    required Color primary,
    required Color primaryFg,
    required Color secondary,
    required Color secondaryFg,
    required Color destructive,
    required Color success,
    required Color warning,
  }) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: primaryFg,
      secondary: secondary,
      onSecondary: secondaryFg,
      error: destructive,
      onError: primaryFg,
      surface: card,
      onSurface: foreground,
      surfaceContainerHighest: muted,
      outline: border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      fontFamily: 'Inter',
      extensions: [
        AppSemanticColors(
          background: background,
          foreground: foreground,
          card: card,
          border: border,
          muted: muted,
          mutedForeground: mutedFg,
          primary: primary,
          primaryForeground: primaryFg,
          secondary: secondary,
          secondaryForeground: secondaryFg,
          destructive: destructive,
          success: success,
          warning: warning,
          statusDroppedOff: _statusDroppedOff,
        ),
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: foreground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: muted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        labelStyle: TextStyle(color: mutedFg),
        hintStyle: TextStyle(color: mutedFg),
        prefixIconColor: mutedFg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: primaryFg,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: foreground,
          side: BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: card,
        selectedItemColor: primary,
        unselectedItemColor: mutedFg,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: mutedFg,
        indicatorColor: primary,
        dividerColor: border,
        labelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: card,
        contentTextStyle: TextStyle(color: foreground),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return muted;
        }),
        checkColor: WidgetStateProperty.all(primaryFg),
      ),
    );
  }
}
