import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kColorKey = 'theme_seed_color';
const _kDefaultColor = 0xFF6750A4;

class ThemeColorNotifier extends StateNotifier<Color> {
  ThemeColorNotifier(super.initial);

  Future<void> setColor(Color color) async {
    state = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kColorKey, color.toARGB32());
  }
}

final themeColorProvider =
    StateNotifierProvider<ThemeColorNotifier, Color>((ref) {
  return ThemeColorNotifier(const Color(_kDefaultColor));
});

/// Charge la couleur persistée. À appeler avant runApp.
Future<Color> loadPersistedColor() async {
  final prefs = await SharedPreferences.getInstance();
  final value = prefs.getInt(_kColorKey) ?? _kDefaultColor;
  return Color(value);
}
