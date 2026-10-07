import 'package:flutter/material.dart';

const _seed = Color(0xFF2B4C7E);

ThemeData buildTheme(Brightness brightness) {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: brightness),
    useMaterial3: true,
  );
}
