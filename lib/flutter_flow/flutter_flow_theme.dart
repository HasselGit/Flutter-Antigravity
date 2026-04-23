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
    primary = const Color(0xFF4A5D23);
    secondary = const Color(0xFFC68E17);
    tertiary = const Color(0xFF1E352F);
    alternate = const Color(0xFFE0E3E7);
    primaryText = const Color(0xFF14181B);
    secondaryText = const Color(0xFF57636C);
    primaryBackground = const Color(0xFFF1F4F8);
    secondaryBackground = const Color(0xFFFFFFFF);
    accent1 = const Color(0xFF4B39EF);
    accent2 = const Color(0xFF39D2C0);
    accent3 = const Color(0xFFEE8B60);
    accent4 = const Color(0xFF616161);
    success = const Color(0xFF249689);
    warning = const Color(0xFFF9CF58);
    error = const Color(0xFFFF5963);
    info = const Color(0xFFFFFFFF);
  }
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
