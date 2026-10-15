import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Identidad visual de Spado Rackets.
///
/// El azul sale del logo del club (#0D3E66). El amarillo pelota se usa sólo
/// sobre superficies azules —barra de navegación, cabeceras— y nunca como
/// texto sobre blanco, donde no se lee.
abstract final class AppColors {
  static const navy = Color(0xFF0D3E66); // logo
  static const navyDeep = Color(0xFF082A47); // cabeceras, barra inferior
  static const navySoft = Color(0xFF1C5A8C);
  static const ball = Color(0xFFD9E54A); // acento: pelota de tenis

  static const bg = Color(0xFFF3F5F8);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF0E1B2A);
  static const textSecondary = Color(0xFF5A6B7D);
  static const border = Color(0xFFDDE3EA);

  static const success = Color(0xFF1F7A55);
  static const warning = Color(0xFFB26A00);
  static const danger = Color(0xFFC0392B);
  static const info = navySoft;
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

abstract final class AppRadius {
  static const card = 14.0;
  static const field = 10.0;
  static const pill = 999.0;
}

abstract final class AppTheme {
  /// Barlow Semi Condensed en titulares —deportiva sin gritar— y Manrope en el
  /// cuerpo, la misma que Spado Soccer para que las dos apps sean familia.
  static TextTheme _textTheme() {
    final display = GoogleFonts.barlowSemiCondensedTextTheme();
    final body = GoogleFonts.manropeTextTheme();

    TextStyle? titular(TextStyle? base, {double? size}) => base?.copyWith(
          color: AppColors.navy,
          fontWeight: FontWeight.w600,
          fontSize: size,
          letterSpacing: 0.2,
        );

    return TextTheme(
      displaySmall: titular(display.displaySmall),
      headlineLarge: titular(display.headlineLarge),
      headlineMedium: titular(display.headlineMedium, size: 28),
      headlineSmall: titular(display.headlineSmall, size: 24),
      titleLarge: titular(display.titleLarge, size: 20),
      titleMedium: body.titleMedium?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      titleSmall: body.titleSmall?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: body.bodyLarge?.copyWith(color: AppColors.textPrimary),
      bodyMedium: body.bodyMedium?.copyWith(color: AppColors.textPrimary),
      bodySmall: body.bodySmall?.copyWith(color: AppColors.textSecondary),
      labelLarge: body.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      labelMedium: body.labelMedium?.copyWith(color: AppColors.textSecondary),
      labelSmall: body.labelSmall?.copyWith(
        color: AppColors.textSecondary,
        letterSpacing: 0.4,
      ),
    );
  }

  static ThemeData light() {
    // Las tipografías van incluidas en la app (assets/google_fonts): no se
    // descargan en ejecución, así que funcionan sin red y bajo la CSP.
    GoogleFonts.config.allowRuntimeFetching = false;
    final textTheme = _textTheme();
    final borde = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.field),
      borderSide: const BorderSide(color: AppColors.border),
    );

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.bg,
      textTheme: textTheme,
      colorScheme: const ColorScheme.light(
        primary: AppColors.navy,
        onPrimary: Colors.white,
        secondary: AppColors.navySoft,
        onSecondary: Colors.white,
        tertiary: AppColors.ball,
        onTertiary: AppColors.navyDeep,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.danger,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.navyDeep,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontSize: 21,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        border: borde,
        enabledBorder: borde,
        focusedBorder: borde.copyWith(
          borderSide: const BorderSide(color: AppColors.navy, width: 1.6),
        ),
        errorBorder: borde.copyWith(
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.field),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navy,
          minimumSize: const Size.fromHeight(50),
          side: const BorderSide(color: AppColors.border, width: 1.4),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.field),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.navy),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.navyDeep,
        indicatorColor: AppColors.ball.withValues(alpha: 0.18),
        height: 66,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            color: selected ? AppColors.ball : Colors.white70,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.ball : Colors.white70,
          );
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.navy,
        side: const BorderSide(color: AppColors.border),
        labelStyle: textTheme.labelMedium,
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: Colors.white,
        ),
        checkmarkColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.navyDeep,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.bg,
        showDragHandle: true,
      ),
    );
  }
}
