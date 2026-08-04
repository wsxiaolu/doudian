import 'package:flutter/material.dart';

import '../theme/app_dimens.dart';

/// ============================================================================
/// 页面转场动画
///
/// 全平台统一使用「淡入 + 轻微上移 + 极细微缩放」的组合转场：
///   · 观感高级，不像手机默认的整屏横推那样廉价
///   · 时长 380ms，缓动 easeOutCubic —— 适中流畅，不快不卡
/// ============================================================================

/// 供 ThemeData.pageTransitionsTheme 使用的转场构建器
class SmoothPageTransitionsBuilder extends PageTransitionsBuilder {
  const SmoothPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T>? route,
    BuildContext? context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _SmoothTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}

class _SmoothTransition extends StatelessWidget {
  const _SmoothTransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // 新页面进入：透明度 0→1，向上位移 24px→0，缩放 0.985→1
    final CurvedAnimation enter = CurvedAnimation(
      parent: animation,
      curve: AppCurves.enter,
      reverseCurve: AppCurves.exit,
    );

    // 旧页面退场：轻微缩小并淡出，形成层次纵深
    final CurvedAnimation leave = CurvedAnimation(
      parent: secondaryAnimation,
      curve: AppCurves.smooth,
    );

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[enter, leave]),
      builder: (BuildContext context, Widget? inner) {
        final double enterValue = enter.value;
        final double leaveValue = leave.value;
        return Opacity(
          opacity: (enterValue * (1 - leaveValue * 0.45)).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - enterValue) * 24 - leaveValue * 12),
            child: Transform.scale(
              scale: (0.985 + 0.015 * enterValue) * (1 - leaveValue * 0.02),
              child: inner,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

/// ----------------------------------------------------------------------------
/// 命令式导航使用的路由：`Navigator.push(context, SmoothPageRoute(child: XxxPage()))`
/// ----------------------------------------------------------------------------
class SmoothPageRoute<T> extends PageRouteBuilder<T> {
  SmoothPageRoute({
    required this.child,
    super.settings,
    super.fullscreenDialog,
  }) : super(
          transitionDuration: AppDuration.page,
          reverseTransitionDuration: AppDuration.page,
          opaque: true,
          pageBuilder: (_, __, ___) => child,
          transitionsBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget page,
          ) {
            return _SmoothTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              child: page,
            );
          },
        );

  final Widget child;
}

/// ----------------------------------------------------------------------------
/// 从右侧滑入的抽屉式路由（桌面端「新建/编辑」表单常用，体验更接近原生应用）
/// ----------------------------------------------------------------------------
class SlideInPageRoute<T> extends PageRouteBuilder<T> {
  SlideInPageRoute({
    required this.child,
    super.settings,
  }) : super(
          transitionDuration: AppDuration.page,
          reverseTransitionDuration: AppDuration.page,
          pageBuilder: (_, __, ___) => child,
          transitionsBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget page,
          ) {
            final Animation<Offset> slide = Tween<Offset>(
              begin: const Offset(0.06, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: AppCurves.enter,
              reverseCurve: AppCurves.exit,
            ));
            return SlideTransition(
              position: slide,
              child: FadeTransition(opacity: animation, child: page),
            );
          },
        );

  final Widget child;
}
