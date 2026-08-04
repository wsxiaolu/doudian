import 'package:flutter/material.dart';

import '../theme/app_dimens.dart';

/// ============================================================================
/// 响应式布局工具
///
/// 三档形态：
///   mobile  (< 720)   手机：单列紧凑 + 底部导航
///   tablet  (720~1080) 平板/小窗：图标侧栏 + 双列
///   desktop (>= 1080) 桌面：永久展开侧栏 + 宽屏多列
/// ============================================================================

enum ScreenType { mobile, tablet, desktop }

extension ResponsiveX on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  double get screenHeight => MediaQuery.sizeOf(this).height;

  ScreenType get screenType {
    final double w = screenWidth;
    if (w < AppBreakpoints.mobile) return ScreenType.mobile;
    if (w < AppBreakpoints.tablet) return ScreenType.tablet;
    return ScreenType.desktop;
  }

  bool get isMobile => screenType == ScreenType.mobile;

  bool get isTablet => screenType == ScreenType.tablet;

  bool get isDesktop => screenType == ScreenType.desktop;

  /// 是否使用侧边导航（平板与桌面都用）
  bool get useSideNavigation => !isMobile;

  /// 页面左右内边距
  double get pagePadding =>
      isMobile ? AppSpacing.pageMobile : AppSpacing.pageDesktop;

  /// 统计卡片一行放几个
  int get statColumns {
    switch (screenType) {
      case ScreenType.mobile:
        return 2;
      case ScreenType.tablet:
        return 3;
      case ScreenType.desktop:
        return 4;
    }
  }

  /// 列表一行放几个（订单卡片）
  int get listColumns {
    final double w = screenWidth;
    if (w < AppBreakpoints.mobile) return 1;
    if (w < 1500) return 2;
    return 3;
  }

  /// 根据屏幕形态取值的语法糖
  T responsive<T>({required T mobile, T? tablet, T? desktop}) {
    switch (screenType) {
      case ScreenType.mobile:
        return mobile;
      case ScreenType.tablet:
        return tablet ?? mobile;
      case ScreenType.desktop:
        return desktop ?? tablet ?? mobile;
    }
  }
}

/// 内容居中并限制最大宽度，避免超宽屏上内容被拉得过长
class ContentConstraint extends StatelessWidget {
  const ContentConstraint({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoints.contentMaxWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
