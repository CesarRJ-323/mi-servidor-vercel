import 'package:flutter/material.dart';

/// ============================================================
///  DESIGN TOKENS — Rapidiya
///  Paleta "fresh market": verde como acento principal sobre
///  fondo clarísimo, comida protagonista. Inspiración: apps de
///  delivery premium (ver referencia HOME.jpg de Pinterest).
/// ============================================================

class AppColors {
  AppColors._();

  // Primario verde (identidad fresh-market)
  static const Color primary = Color(0xFF2E9E5B);
  static const Color primaryDark = Color(0xFF1E7A44);
  static const Color primaryDeep = Color(0xFF14662F); // chips de precio
  static const Color primarySoft = Color(0xFFE6F4EC); // fondos suaves

  // Gradiente del hero (verde profundo -> verde medio)
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E7A44), Color(0xFF3CB06B)],
  );

  // Acentos
  static const Color accent = Color(0xFFF5A524); // estrellas, destacados
  static const Color accentSoft = Color(0xFFFFF4DE);

  // Neutros
  static const Color background = Color(0xFFF7F9F4); // verdoso clarísimo
  static const Color card = Colors.white;
  static const Color imageBg = Color(0xFFF0F2EE);
  static const Color textPrimary = Color(0xFF182420);
  static const Color textSecondary = Color(0xFF5E6B64);
  static const Color textMuted = Color(0xFF98A39D);
  static const Color outline = Color(0xFFE2E7E3);

  // Estado
  static const Color success = Color(0xFF2EAA6E);
  static const Color danger = Color(0xFFE5484D);
  static const Color warning = Color(0xFFF5A524);

  // Compatibilidad con pantallas que aún usan "secondary".
  static const Color secondary = primary;
}

class AppRadii {
  AppRadii._();
  static const double card = 20;
  static const double button = 14;
  static const double chip = 10;
  static const double image = 16;
  static const double search = 30;
}

class AppShadows {
  AppShadows._();

  static List<BoxShadow> card = [
    BoxShadow(
      color: const Color(0xFF14662F).withValues(alpha: 0.07),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> floating = [
    BoxShadow(
      color: const Color(0xFF14662F).withValues(alpha: 0.3),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
}

class AppTheme {
  AppTheme._();

  static const String fontFamily = 'Sora';

  static ThemeData get light {
    const scheme = ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.card,
      error: AppColors.danger,
    );

    final base = ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
        fontFamily: fontFamily,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primarySoft,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: fontFamily,
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            color: selected ? AppColors.primaryDark : AppColors.textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.primaryDark : AppColors.textMuted,
          );
        }),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.chip),
        ),
      ),
    );
  }
}
