import 'package:flutter/material.dart';

/// ============================================================================
/// 尺寸 / 间距 / 圆角 / 动效 令牌
///
/// 统一在这里定义，保证全局视觉节奏一致，也方便一处修改全局生效。
/// ============================================================================

class AppSpacing {
  AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 44;

  /// 页面左右安全内边距（移动端）
  static const double pageMobile = 16;

  /// 页面左右安全内边距（桌面端，留白更充足）
  static const double pageDesktop = 32;
}

class AppRadius {
  AppRadius._();

  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16; // 卡片默认圆角：适中，不夸张
  static const double lg = 22;
  static const double xl = 28;
  static const double pill = 999;

  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(md));
  static const BorderRadius fieldRadius = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius sheetRadius = BorderRadius.vertical(
    top: Radius.circular(xl),
  );
}

/// 动效时长 —— 「适中流畅」：不快到突兀，也不慢到拖沓
class AppDuration {
  AppDuration._();

  /// 微交互：按钮按下反馈、图标切换
  static const Duration micro = Duration(milliseconds: 140);

  /// 快速：涟漪、选中态
  static const Duration fast = Duration(milliseconds: 220);

  /// 标准：卡片展开、内容切换
  static const Duration normal = Duration(milliseconds: 320);

  /// 页面转场
  static const Duration page = Duration(milliseconds: 380);

  /// 弹窗、底部面板
  static const Duration dialog = Duration(milliseconds: 300);

  /// 列表逐项入场的单项时长
  static const Duration listItem = Duration(milliseconds: 380);

  /// 列表逐项入场的相邻延迟（做出「流水般」的错落感）
  static const Duration listStagger = Duration(milliseconds: 45);
}

/// 缓动曲线 —— 统一使用「快出慢入」，观感高级顺滑
class AppCurves {
  AppCurves._();

  /// 主用：进入动画
  static const Curve enter = Curves.easeOutCubic;

  /// 主用：退出动画
  static const Curve exit = Curves.easeInCubic;

  /// 强调：带一点点回弹但不夸张
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);

  /// 弹窗缩放
  static const Curve dialogScale = Curves.easeOutBack;

  /// 平滑双向
  static const Curve smooth = Curves.easeInOutCubic;
}

/// 响应式断点
class AppBreakpoints {
  AppBreakpoints._();

  /// 小于该值视为手机（底部导航 + 单列）
  static const double mobile = 720;

  /// 小于该值视为平板 / 小窗（收起的侧边导航）
  static const double tablet = 1080;

  /// 内容区最大宽度，避免超宽屏文字拉得太长
  static const double contentMaxWidth = 1400;
}

/// 阴影预设：轻薄柔和渐变阴影
class AppShadows {
  AppShadows._();

  /// 卡片默认阴影
  static List<BoxShadow> card(Color soft) => [
        BoxShadow(
          color: soft,
          blurRadius: 18,
          spreadRadius: -4,
          offset: const Offset(0, 6),
        ),
      ];

  /// 悬浮态（鼠标移入 / 按下）
  static List<BoxShadow> hover(Color medium) => [
        BoxShadow(
          color: medium,
          blurRadius: 28,
          spreadRadius: -6,
          offset: const Offset(0, 12),
        ),
      ];

  /// 浮层：弹窗、下拉菜单
  static List<BoxShadow> overlay(Color medium) => [
        BoxShadow(
          color: medium,
          blurRadius: 40,
          spreadRadius: -8,
          offset: const Offset(0, 16),
        ),
      ];
}
