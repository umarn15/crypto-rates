import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

TextStyle style = TextStyle(
  color: Colors.white,
);

final scaffoldColor = Color(0xFF151B1E);

ThemeData themeData = ThemeData(
  scaffoldBackgroundColor: scaffoldColor,
  appBarTheme: AppBarTheme(
    systemOverlayStyle: SystemUiOverlayStyle(
      statusBarColor: scaffoldColor,
      systemNavigationBarColor: scaffoldColor
    ),
    backgroundColor: Colors.transparent,
    iconTheme: IconThemeData(color: Colors.white),
    titleTextStyle: TextStyle(
      fontSize: 18,
      color: Colors.white,
      fontWeight: FontWeight.bold
    ),
    actionsIconTheme: IconThemeData(color: Colors.white),
  ),
  textTheme: TextTheme(
    bodyMedium: style,
    bodyLarge: style,
    bodySmall: style,
    titleMedium: style,
  ),
  cardColor: Colors.indigo,
  inputDecorationTheme: InputDecorationTheme(
      hintStyle: TextStyle(color: Colors.grey[400]),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(12)
      ),
      fillColor: Color(0xFF262A34),
      filled: true
  )
);