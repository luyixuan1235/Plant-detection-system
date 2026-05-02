import 'package:flutter/material.dart';

class AppColors {
  static const forest = Color(0xFF2F8F46);
  static const forestDark = Color(0xFF173F2A);
  static const forestDeep = Color(0xFF0F2E1F);
  static const leaf = Color(0xFFEAF6EC);
  static const mint = Color(0xFFF4FAF5);
  static const canvas = Color(0xFFF7FBF6);
  static const card = Color(0xFFFFFFFF);
  static const line = Color(0xFFDDEBDD);
  static const mutedLine = Color(0xFFE8F0E7);
  static const text = Color(0xFF20352A);
  static const textMuted = Color(0xFF66776B);
  static const success = Color(0xFF2E7D32);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFD64545);
  static const info = Color(0xFF3B82A0);

  // Legacy status aliases used by the older seat-map model.
  static const green = forest;
  static const blue = info;
  static const grey = Color(0xFF94A39A);
  static const yellow = warning;
  static const red = danger;

  static const reportButton = Color(0xFFF4B8A7);
  static const confirmButton = Color(0xFFCDECCB);
  static const dialogBackground = mint;
}

class AppRadii {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 28.0;
}

class AppShadows {
  static List<BoxShadow> get soft => [
    BoxShadow(
      color: const Color(0xFF24452D).withValues(alpha: 0.08),
      offset: const Offset(0, 14),
      blurRadius: 34,
    ),
  ];

  static List<BoxShadow> get subtle => [
    BoxShadow(
      color: const Color(0xFF24452D).withValues(alpha: 0.05),
      offset: const Offset(0, 8),
      blurRadius: 22,
    ),
  ];
}

class AppDecorations {
  static BoxDecoration card({Color color = AppColors.card}) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      border: Border.all(color: AppColors.mutedLine),
      boxShadow: AppShadows.subtle,
    );
  }

  static BoxDecoration tintedCard() {
    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.card, AppColors.leaf],
      ),
      borderRadius: BorderRadius.circular(AppRadii.xl),
      border: Border.all(color: AppColors.line),
      boxShadow: AppShadows.soft,
    );
  }
}

class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.forest,
      brightness: Brightness.light,
      primary: AppColors.forest,
      secondary: AppColors.success,
      surface: AppColors.card,
      error: AppColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.canvas,
      fontFamily: 'Noto Sans SC',
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontWeight: FontWeight.w800,
          color: AppColors.forestDeep,
        ),
        headlineMedium: TextStyle(
          fontWeight: FontWeight.w800,
          color: AppColors.forestDeep,
        ),
        titleLarge: TextStyle(
          fontWeight: FontWeight.w800,
          color: AppColors.text,
        ),
        titleMedium: TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
        bodyLarge: TextStyle(color: AppColors.text),
        bodyMedium: TextStyle(color: AppColors.textMuted),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.forestDeep,
        titleTextStyle: TextStyle(
          color: AppColors.forestDeep,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.card,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: const BorderSide(color: AppColors.mutedLine),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted),
        labelStyle: const TextStyle(color: AppColors.textMuted),
        prefixIconColor: AppColors.textMuted,
        suffixIconColor: AppColors.textMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.mutedLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.mutedLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.forest, width: 1.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.forest,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.1,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.forest,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.forest,
          side: const BorderSide(color: AppColors.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.forest,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.forestDeep,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: const BorderSide(color: AppColors.mutedLine),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
      ),
    );
  }
}
