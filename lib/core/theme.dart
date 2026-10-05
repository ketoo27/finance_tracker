import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Ledger / bank-passbook design tokens.
class AppColors {
  static const ink = Color(0xFF152521);
  static const paper = Color(0xFFF5F3EC);
  static const paperLine = Color(0xFFDAD5C4);
  static const teal = Color(0xFF215B57);
  static const tealDeep = Color(0xFF123634);
  static const gold = Color(0xFFA9822C);
  static const green = Color(0xFF3E7A4E);
  static const red = Color(0xFFAB4438);
  static const card = Color(0xFFFFFFFF);
  static const muted = Color(0xFF8A8878);
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.teal,
        primary: AppColors.teal,
        surface: AppColors.paper,
      ),
      scaffoldBackgroundColor: AppColors.paper,
    );
    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.tealDeep,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.paperLine),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.paperLine),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.tealDeep,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.tealDeep,
        foregroundColor: Colors.white,
      ),
    );
  }

  static TextStyle serifDisplay(BuildContext context, {double size = 28, Color? color}) {
    return GoogleFonts.playfairDisplay(
      fontSize: size,
      fontWeight: FontWeight.w600,
      color: color ?? AppColors.ink,
    );
  }
}

String formatRupee(num amount) {
  final rounded = amount.abs().round();
  final s = rounded.toString();
  final buffer = StringBuffer();
  final chars = s.split('').reversed.toList();
  for (int i = 0; i < chars.length; i++) {
    if (i == 3) buffer.write(',');
    if (i > 3 && (i - 3) % 2 == 0) buffer.write(',');
    buffer.write(chars[i]);
  }
  return '₹${buffer.toString().split('').reversed.join()}';
}
