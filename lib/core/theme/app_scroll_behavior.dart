import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// ============================================================================
/// 全局滚动行为
///
/// 目标：
///   1. 全平台统一使用「惯性回弹」滚动物理，手感顺滑（含 Windows / macOS）；
///   2. 桌面端允许鼠标拖拽滚动列表，不必非得用滚轮；
///   3. 去掉 Android 默认的生硬蓝色水波纹溢出指示，改为通透的回弹。
/// ============================================================================
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  /// 允许触发滚动的输入设备：加入鼠标与触控板，桌面端可直接按住拖动
  @override
  Set<PointerDeviceKind> get dragDevices => <PointerDeviceKind>{
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.unknown,
      };

  /// 统一的惯性回弹物理效果
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }

  /// 不绘制安卓式的溢出发光，保持界面干净
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
