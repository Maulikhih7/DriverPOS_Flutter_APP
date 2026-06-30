import 'package:flutter/material.dart';

/// Parses the backend page-config JSON for the login screen.
///
/// Backend shape (GET /api/v1/page/:pageId):
/// {
///   "success": true,
///   "data": {
///     "screenKey": "login-screen",
///     "pageId": "...",
///     "isVisible": true,
///     "data": { <-- all UI keys live here
///       "background":    { "color", "blobColor", "blobOpacity" },
///       "card":          { "background", "borderRadius", "paddingTop/Bottom/Left/Right" },
///       "logo":          { "asset", "height" },
///       "subtitleText":  { "text", "fontSize", "fontWeight", "color" },
///       "headingText":   { "text", "fontSize", "fontWeight", "color" },
///       "usernameField": { "label", "labelColor", "placeholder", "borderColor", "focusBorderColor" },
///       "passwordField": { "label", "labelColor", "placeholder", "borderColor", "focusBorderColor" },
///       "loginButton":   { "text", "background", "textColor", "fontSize", "height", "borderRadius" },
///       "errorText":     { "color", "fontSize" }
///     }
///   }
/// }

class LoginPageConfig {
  // Background
  final Color backgroundColor;
  final Color blobColor;
  final double blobOpacity;

  // Card
  final Color cardBackground;
  final double cardBorderRadius;
  final double cardPaddingTop;
  final double cardPaddingBottom;
  final double cardPaddingLeft;
  final double cardPaddingRight;

  // Logo
  final String logoAsset;
  final double logoHeight;

  // Subtitle ("Login into your account")
  final String subtitleText;
  final Color subtitleColor;
  final double subtitleFontSize;
  final FontWeight subtitleFontWeight;

  // Heading ("Welcome to driver.io")
  final String headingText;
  final Color headingColor;
  final double headingFontSize;
  final FontWeight headingFontWeight;

  // Username field
  final String usernameLabel;
  final Color usernameLabelColor;
  final String usernamePlaceholder;
  final Color fieldBorderColor;
  final Color fieldFocusBorderColor;

  // Password field
  final String passwordLabel;
  final Color passwordLabelColor;
  final String passwordPlaceholder;

  // Login button
  final String loginButtonText;
  final Color loginButtonBackground;
  final Color loginButtonTextColor;
  final double loginButtonFontSize;
  final double loginButtonHeight;
  final double loginButtonBorderRadius;

  // Error text
  final Color errorTextColor;
  final double errorTextFontSize;

  const LoginPageConfig({
    required this.backgroundColor,
    required this.blobColor,
    required this.blobOpacity,
    required this.cardBackground,
    required this.cardBorderRadius,
    required this.cardPaddingTop,
    required this.cardPaddingBottom,
    required this.cardPaddingLeft,
    required this.cardPaddingRight,
    required this.logoAsset,
    required this.logoHeight,
    required this.subtitleText,
    required this.subtitleColor,
    required this.subtitleFontSize,
    required this.subtitleFontWeight,
    required this.headingText,
    required this.headingColor,
    required this.headingFontSize,
    required this.headingFontWeight,
    required this.usernameLabel,
    required this.usernameLabelColor,
    required this.usernamePlaceholder,
    required this.fieldBorderColor,
    required this.fieldFocusBorderColor,
    required this.passwordLabel,
    required this.passwordLabelColor,
    required this.passwordPlaceholder,
    required this.loginButtonText,
    required this.loginButtonBackground,
    required this.loginButtonTextColor,
    required this.loginButtonFontSize,
    required this.loginButtonHeight,
    required this.loginButtonBorderRadius,
    required this.errorTextColor,
    required this.errorTextFontSize,
  });

  /// Hard-coded defaults — used on first paint before the API responds.
  static const LoginPageConfig defaults = LoginPageConfig(
    backgroundColor: Color(0xFFEBF3E9),
    blobColor: Color(0xFFB5D4AF),
    blobOpacity: 0.45,
    cardBackground: Color(0xFFFFFFFF),
    cardBorderRadius: 20,
    cardPaddingTop: 40,
    cardPaddingBottom: 40,
    cardPaddingLeft: 36,
    cardPaddingRight: 36,
    logoAsset: 'assets/images/login_logo.png',
    logoHeight: 80,
    subtitleText: 'Login into your account',
    subtitleColor: Color(0xFF141414),
    subtitleFontSize: 14,
    subtitleFontWeight: FontWeight.w500,
    headingText: 'Welcome to driver.io',
    headingColor: Color(0xFF244065),
    headingFontSize: 26,
    headingFontWeight: FontWeight.w800,
    usernameLabel: 'User Name / Email',
    usernameLabelColor: Color(0xFF7FB069),
    usernamePlaceholder: 'Enter your user name or email id',
    fieldBorderColor: Color(0xFFE5E7EB),
    fieldFocusBorderColor: Color(0xFF7FB069),
    passwordLabel: 'Password',
    passwordLabelColor: Color(0xFF7FB069),
    passwordPlaceholder: 'Enter Password',
    loginButtonText: 'Login',
    loginButtonBackground: Color(0xFF7FB069),
    loginButtonTextColor: Color(0xFFFFFFFF),
    loginButtonFontSize: 16,
    loginButtonHeight: 52,
    loginButtonBorderRadius: 10,
    errorTextColor: Color(0xFFC01C2D),
    errorTextFontSize: 13,
  );

  factory LoginPageConfig.fromJson(Map<String, dynamic> json) {
    // The backend wraps the UI keys under a nested "data" key
    final d = (json['data'] as Map<String, dynamic>?) ?? {};

    final bg = (d['background'] as Map<String, dynamic>?) ?? {};
    final card = (d['card'] as Map<String, dynamic>?) ?? {};
    final logo = (d['logo'] as Map<String, dynamic>?) ?? {};
    final subtitle = (d['subtitleText'] as Map<String, dynamic>?) ?? {};
    final heading = (d['headingText'] as Map<String, dynamic>?) ?? {};
    final username = (d['usernameField'] as Map<String, dynamic>?) ?? {};
    final password = (d['passwordField'] as Map<String, dynamic>?) ?? {};
    final button = (d['loginButton'] as Map<String, dynamic>?) ?? {};
    final error = (d['errorText'] as Map<String, dynamic>?) ?? {};

    final def = LoginPageConfig.defaults;

    return LoginPageConfig(
      backgroundColor: _color(bg['color'], def.backgroundColor),
      blobColor: _color(bg['blobColor'], def.blobColor),
      blobOpacity: _double(bg['blobOpacity'], def.blobOpacity),
      cardBackground: _color(card['background'], def.cardBackground),
      cardBorderRadius: _pxDouble(card['borderRadius'], def.cardBorderRadius),
      cardPaddingTop: _pxDouble(card['paddingTop'], def.cardPaddingTop),
      cardPaddingBottom: _pxDouble(card['paddingBottom'], def.cardPaddingBottom),
      cardPaddingLeft: _pxDouble(card['paddingLeft'], def.cardPaddingLeft),
      cardPaddingRight: _pxDouble(card['paddingRight'], def.cardPaddingRight),
      logoAsset: _str(logo['asset'], def.logoAsset),
      logoHeight: _pxDouble(logo['height'], def.logoHeight),
      subtitleText: _str(subtitle['text'], def.subtitleText),
      subtitleColor: _color(subtitle['color'], def.subtitleColor),
      subtitleFontSize: _pxDouble(subtitle['fontSize'], def.subtitleFontSize),
      subtitleFontWeight: _fontWeight(subtitle['fontWeight'], def.subtitleFontWeight),
      headingText: _str(heading['text'], def.headingText),
      headingColor: _color(heading['color'], def.headingColor),
      headingFontSize: _pxDouble(heading['fontSize'], def.headingFontSize),
      headingFontWeight: _fontWeight(heading['fontWeight'], def.headingFontWeight),
      usernameLabel: _str(username['label'], def.usernameLabel),
      usernameLabelColor: _color(username['labelColor'], def.usernameLabelColor),
      usernamePlaceholder: _str(username['placeholder'], def.usernamePlaceholder),
      fieldBorderColor: _color(username['borderColor'], def.fieldBorderColor),
      fieldFocusBorderColor: _color(username['focusBorderColor'], def.fieldFocusBorderColor),
      passwordLabel: _str(password['label'], def.passwordLabel),
      passwordLabelColor: _color(password['labelColor'], def.passwordLabelColor),
      passwordPlaceholder: _str(password['placeholder'], def.passwordPlaceholder),
      loginButtonText: _str(button['text'], def.loginButtonText),
      loginButtonBackground: _color(button['background'], def.loginButtonBackground),
      loginButtonTextColor: _color(button['textColor'], def.loginButtonTextColor),
      loginButtonFontSize: _pxDouble(button['fontSize'], def.loginButtonFontSize),
      loginButtonHeight: _pxDouble(button['height'], def.loginButtonHeight),
      loginButtonBorderRadius: _pxDouble(button['borderRadius'], def.loginButtonBorderRadius),
      errorTextColor: _color(error['color'], def.errorTextColor),
      errorTextFontSize: _pxDouble(error['fontSize'], def.errorTextFontSize),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static Color _color(dynamic raw, Color fallback) {
    if (raw is! String) return fallback;
    final hex = raw.trim().replaceFirst('#', '');
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    } else if (hex.length == 8) {
      return Color(int.parse(hex, radix: 16));
    }
    return fallback;
  }

  /// Parses both bare numbers and CSS px strings, e.g. "20px" or 20
  static double _pxDouble(dynamic raw, double fallback) {
    if (raw == null) return fallback;
    if (raw is num) return raw.toDouble();
    final s = raw.toString().replaceAll('px', '').trim();
    return double.tryParse(s) ?? fallback;
  }

  static double _double(dynamic raw, double fallback) {
    if (raw is num) return raw.toDouble();
    return fallback;
  }

  static String _str(dynamic raw, String fallback) =>
      raw is String && raw.isNotEmpty ? raw : fallback;

  static FontWeight _fontWeight(dynamic raw, FontWeight fallback) {
    if (raw == null) return fallback;
    final n = int.tryParse(raw.toString());
    if (n != null) {
      return FontWeight.values.firstWhere(
        (fw) => fw.value == n,
        orElse: () => fallback,
      );
    }
    switch (raw.toString().toLowerCase()) {
      case 'bold': return FontWeight.bold;
      case '100': return FontWeight.w100;
      case '200': return FontWeight.w200;
      case '300': return FontWeight.w300;
      case '400': return FontWeight.w400;
      case '500': return FontWeight.w500;
      case '600': return FontWeight.w600;
      case '700': return FontWeight.w700;
      case '800': return FontWeight.w800;
      case '900': return FontWeight.w900;
    }
    return fallback;
  }
}
