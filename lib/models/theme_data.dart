import 'package:flutter/material.dart';

TextStyle style = TextStyle(
  color: Colors.white,
);

ThemeData themeData = ThemeData(
  scaffoldBackgroundColor: Colors.black,
  appBarTheme: AppBarTheme(
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
);