import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/pref_keys.dart';

/// ============================================================================
/// 外观主题状态
///
/// 支持「跟随系统 / 浅色 / 深色」三档，选择结果持久化到本地，
/// 下次启动直接生效。切换时由 MaterialApp 的 themeAnimationDuration
/// 配合 AppColors.lerp 做平滑过渡，不会突兀闪屏。
/// ============================================================================
class ThemeProvider extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  /// 当前是否处于深色（用于设置页开关回显）
  bool isDark(BuildContext context) {
    switch (_mode) {
      case ThemeMode.light:
        return false;
      case ThemeMode.dark:
        return true;
      case ThemeMode.system:
        return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
  }

  /// 启动时读取已保存的偏好
  Future<void> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _mode = _decode(prefs.getString(PrefKeys.themeMode));
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefKeys.themeMode, _encode(mode));
  }

  /// 在「浅色 ⇄ 深色」之间快速切换（顶部栏的月亮/太阳按钮）
  Future<void> toggle(BuildContext context) async {
    final bool dark = isDark(context);
    await setMode(dark ? ThemeMode.light : ThemeMode.dark);
  }

  static String _encode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  static ThemeMode _decode(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  /// 三档模式的中文标签
  static String labelOf(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return '跟随系统';
      case ThemeMode.light:
        return '浅色';
      case ThemeMode.dark:
        return '深色';
    }
  }
}
