import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract class FlutterFlowTheme {
  static FlutterFlowTheme of(BuildContext context) => LightModeTheme();

  late Color primary;
  late Color secondary;
  late Color tertiary;
  late Color alternate;
  late Color primaryText;
  late Color secondaryText;
  late Color primaryBackground;
  late Color secondaryBackground;
  late Color accent1;
  late Color accent2;
  late Color accent3;
  late Color accent4;
  late Color success;
  late Color warning;
  late Color error;
  late Color info;

  TextStyle get displayLarge => GoogleFonts.interTight(fontSize: 64, fontWeight: FontWeight.normal);
  TextStyle get displayMedium => GoogleFonts.interTight(fontSize: 44, fontWeight: FontWeight.normal);
  TextStyle get displaySmall => GoogleFonts.interTight(fontSize: 36, fontWeight: FontWeight.normal);
  TextStyle get headlineLarge => GoogleFonts.interTight(fontSize: 32, fontWeight: FontWeight.normal);
  TextStyle get headlineMedium => GoogleFonts.interTight(fontSize: 24, fontWeight: FontWeight.normal);
  TextStyle get headlineSmall => GoogleFonts.interTight(fontSize: 20, fontWeight: FontWeight.normal);
  TextStyle get titleLarge => GoogleFonts.interTight(fontSize: 22, fontWeight: FontWeight.normal);
  TextStyle get titleMedium => GoogleFonts.interTight(fontSize: 18, fontWeight: FontWeight.normal);
  TextStyle get titleSmall => GoogleFonts.interTight(fontSize: 16, fontWeight: FontWeight.normal);
  TextStyle get bodyLarge => GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.normal);
  TextStyle get bodyMedium => GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.normal);
  TextStyle get bodySmall => GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.normal);
  TextStyle get labelLarge => GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.normal);
  TextStyle get labelMedium => GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.normal);
  TextStyle get labelSmall => GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.normal);
}

class LightModeTheme extends FlutterFlowTheme {
  LightModeTheme() {
    primary = const Color(0xFF1E352F); // Forest Green (Primary en imagen)
    secondary = const Color(0xFFC68E17); // Honey Gold (Secondary en imagen)
    tertiary = const Color(0xFFFAF9F6); // Cream (Tertiary en imagen)
    alternate = const Color(0xFFE4E2E2);
    primaryText = const Color(0xFF1B1C1C);
    secondaryText = const Color(0xFF4A4A4A); // Neutral en imagen
    primaryBackground = const Color(0xFFFAF9F6); // Fondo Cream
    secondaryBackground = const Color(0xFFFFFFFF);
    accent1 = const Color(0xFF4B635C);
    accent2 = const Color(0xFFC68E17); // Oro para acentos
    accent3 = const Color(0xFFEE8B60);
    accent4 = const Color(0xFFE4E2E2);
    success = const Color(0xFF249689);
    warning = const Color(0xFFF9CF58);
    error = const Color(0xFFBA1A1A);
    info = const Color(0xFFFFFFFF);
  }

  @override
  TextStyle get displayLarge => GoogleFonts.manrope(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.02,
        color: primaryText,
      );

  @override
  TextStyle get headlineMedium => GoogleFonts.manrope(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: primaryText,
      );

  @override
  TextStyle get titleSmall => GoogleFonts.manrope(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: primaryText,
      );

  @override
  TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: primaryText,
      );

  @override
  TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: primaryText,
      );

  @override
  TextStyle get labelSmall => GoogleFonts.workSans(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.05,
        color: secondaryText,
      );
}

extension TextStyleHelper on TextStyle {
  TextStyle override({
    TextStyle? font,
    String? fontFamily,
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    TextDecoration? decoration,
    double? lineHeight,
  }) =>
      copyWith(
        fontFamily: font?.fontFamily ?? fontFamily,
        color: color ?? font?.color,
        fontSize: fontSize ?? font?.fontSize,
        fontWeight: fontWeight ?? font?.fontWeight,
        fontStyle: fontStyle ?? font?.fontStyle,
        letterSpacing: letterSpacing ?? font?.letterSpacing,
        decoration: decoration ?? font?.decoration,
        height: lineHeight ?? font?.height,
      );
}
