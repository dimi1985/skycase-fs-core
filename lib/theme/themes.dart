import 'package:flutter/material.dart';

// Navigraph Color Palette
const naviNavy      = Color(0xFF0B0E11);
const naviCharcoal  = Color(0xFF14181D);
const naviBlue      = Color(0xFF0099FF);
const naviGray      = Color(0xFFA0A8B3);
const naviGold      = Color(0xFFFFCC33);
const naviSurface   = Color(0xFF1A1E24);

// LIGHT THEME (you can style it later)
// SKYCASE LIGHT THEME (Custom)
final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  useMaterial3: true,

  scaffoldBackgroundColor: const Color(0xFFF6F7F9),

  colorScheme: const ColorScheme.light(
    background: Color(0xFFF6F7F9),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFF0F1F3),
    primary: naviBlue,
    secondary: Color(0xFF4A4F57),
    onBackground: Color(0xFF1A1D21),
    onSurface: Color(0xFF1A1D21),
    onSurfaceVariant: Color(0xFF5A5F68),
    outline: Color(0xFFE0E3E7),
  ),

  cardColor: Colors.white,

  textTheme: const TextTheme(
    headlineMedium: TextStyle(
      color: Color(0xFF1A1D21),
      fontWeight: FontWeight.w800,
    ),
    titleMedium: TextStyle(
      color: Color(0xFF1A1D21),
      fontWeight: FontWeight.w600,
    ),
    bodyMedium: TextStyle(
      color: Color(0xFF44484E),
    ),
    bodySmall: TextStyle(
      color: Color(0xFF44484E),
    ),
  ),

  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    iconTheme: IconThemeData(color: Color(0xFF1A1D21)),
  ),
);


// NAVIGRAPH DARK THEME
final ThemeData navigraphDarkTheme = ThemeData(
  brightness: Brightness.dark,
  useMaterial3: true,

  scaffoldBackgroundColor: naviNavy,
  cardColor: naviCharcoal,

  colorScheme: const ColorScheme.dark(
    background: naviNavy,
    surface: naviCharcoal,
    surfaceVariant: naviSurface,
    primary: naviBlue,
    secondary: naviGold,
    onBackground: Colors.white,
    onSurface: naviGray,
    onSurfaceVariant: naviGray,
    outline: Color(0xFF2C323A),
  ),

  textTheme: const TextTheme(
    headlineMedium: TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w700,
    ),
    titleMedium: TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w600,
    ),
    bodyMedium: TextStyle(
      color: naviGray,
    ),
    bodySmall: TextStyle(
      color: naviGray,
    ),
  ),
);
