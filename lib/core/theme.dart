import 'package:flutter/material.dart';

const _seed = Color(0xFF0E7C86); // koyu turkuaz — güven/istikrar

/// Rakam sütunlarının hizalı durması için eşit genişlikli rakamlar.
const tabular = TextStyle(fontFeatures: [FontFeature.tabularFigures()]);

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    appBarTheme: const AppBarTheme(centerTitle: false),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
  );
}
