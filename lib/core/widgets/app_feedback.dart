import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import 'app_button.dart';

/// ============================================================================
/// 全局反馈：弹窗 / 底部面板 / 轻提示
///
/// 所有弹层统一使用「缩放 + 淡入 + 背景模糊变暗」的柔和入场动画，
/// 关闭时反向播放，绝不生硬闪现。
/// ============================================================================
class AppFeedback {
  AppFeedback._();

  // ---------------------------------------------------------------------------
  // 通用动画弹窗
  // ---------------------------------------------------------------------------
  static Future<T?> showDialogPanel<T>({
    required BuildContext context,
    required Widget child,
    bool barrierDismissible = true,
    double maxWidth = 460,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: '关闭',
      barrierColor: Colors.black.withValues(alpha: 0.32),
      transitionDuration: AppDuration.dialog,
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (
        BuildContext ctx,
        Animation<double> animation,
        Animation<double> secondary,
        Widget _,
      ) {
        final CurvedAnimation curved = CurvedAnimation(
          parent: animation,
          curve: AppCurves.enter,
          reverseCurve: AppCurves.exit,
        );
        return FadeTransition(
          opacity: curved,
          child: Transform.scale(
            scale: 0.94 + 0.06 * curved.value,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: maxWidth,
                    maxHeight: MediaQuery.sizeOf(ctx).height * 0.86,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 标准信息弹窗（标题 + 正文 + 按钮组）
  static Future<T?> showPanel<T>({
    required BuildContext context,
    required String title,
    String? message,
    Widget? content,
    List<Widget> actions = const <Widget>[],
    IconData? icon,
    Color? iconColor,
    bool barrierDismissible = true,
    double maxWidth = 460,
  }) {
    return showDialogPanel<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      maxWidth: maxWidth,
      child: Builder(
        builder: (BuildContext ctx) {
          final AppColors c = ctx.colors;
          final TextTheme t = Theme.of(ctx).textTheme;
          return Container(
            decoration: BoxDecoration(
              color: c.surfaceElevated,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: c.border),
              boxShadow: AppShadows.overlay(c.shadowMedium),
            ),
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    if (icon != null) ...<Widget>[
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: (iconColor ?? c.primary)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Icon(icon,
                            size: 20, color: iconColor ?? c.primary),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Expanded(
                      child: Text(title, style: t.headlineSmall),
                    ),
                  ],
                ),
                if (message != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Text(message, style: t.bodyMedium),
                ],
                if (content != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  Flexible(child: SingleChildScrollView(child: content)),
                ],
                if (actions.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      for (int i = 0; i < actions.length; i++) ...<Widget>[
                        if (i > 0) const SizedBox(width: AppSpacing.sm),
                        actions[i],
                      ],
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  /// 确认对话框，返回 true 表示用户点了确认
  static Future<bool> confirm({
    required BuildContext context,
    required String title,
    String? message,
    String confirmText = '确认',
    String cancelText = '取消',
    bool danger = false,
    IconData? icon,
  }) async {
    final bool? result = await showPanel<bool>(
      context: context,
      title: title,
      message: message,
      icon: icon ?? (danger ? Icons.warning_amber_rounded : Icons.help_outline_rounded),
      iconColor: danger ? context.colors.danger : context.colors.primary,
      maxWidth: 420,
      actions: <Widget>[
        Builder(
          builder: (BuildContext ctx) => AppButton(
            label: cancelText,
            variant: AppButtonVariant.outline,
            size: AppButtonSize.small,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
        ),
        Builder(
          builder: (BuildContext ctx) => AppButton(
            label: confirmText,
            variant:
                danger ? AppButtonVariant.danger : AppButtonVariant.primary,
            size: AppButtonSize.small,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ),
      ],
    );
    return result ?? false;
  }

  // ---------------------------------------------------------------------------
  // 底部面板（移动端）/ 居中面板（桌面端）
  // ---------------------------------------------------------------------------
  static Future<T?> showSheet<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    bool isScrollControlled = true,
    double desktopWidth = 520,
  }) {
    final bool wide = MediaQuery.sizeOf(context).width >= AppBreakpoints.mobile;

    final Widget body = Builder(
      builder: (BuildContext ctx) {
        final TextTheme t = Theme.of(ctx).textTheme;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (title != null)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  wide ? AppSpacing.xl : AppSpacing.xs,
                  AppSpacing.xl,
                  AppSpacing.md,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(child: Text(title, style: t.headlineSmall)),
                    AppIconButton(
                      icon: Icons.close_rounded,
                      size: 32,
                      iconSize: 17,
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  0,
                  AppSpacing.xl,
                  AppSpacing.xl + MediaQuery.viewInsetsOf(ctx).bottom,
                ),
                child: child,
              ),
            ),
          ],
        );
      },
    );

    // 桌面端用居中弹窗，移动端用底部抽屉，各自符合平台习惯
    if (wide) {
      return showDialogPanel<T>(
        context: context,
        maxWidth: desktopWidth,
        child: Builder(
          builder: (BuildContext ctx) {
            final AppColors c = ctx.colors;
            return Container(
              decoration: BoxDecoration(
                color: c.surfaceElevated,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: c.border),
                boxShadow: AppShadows.overlay(c.shadowMedium),
              ),
              child: body,
            );
          },
        ),
      );
    }

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      useSafeArea: true,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      backgroundColor: context.colors.surfaceElevated,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetRadius),
      builder: (BuildContext ctx) => body,
    );
  }

  // ---------------------------------------------------------------------------
  // 轻提示
  // ---------------------------------------------------------------------------
  static void toast(
    BuildContext context,
    String message, {
    ToastType type = ToastType.info,
    Duration duration = const Duration(milliseconds: 2600),
    SnackBarAction? action,
  }) {
    final AppColors c = context.colors;
    final (IconData icon, Color color) = switch (type) {
      ToastType.success => (Icons.check_circle_rounded, c.success),
      ToastType.error => (Icons.error_rounded, c.danger),
      ToastType.warning => (Icons.warning_rounded, c.warning),
      ToastType.info => (Icons.info_rounded, c.primary),
    };

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: duration,
          action: action,
          width: MediaQuery.sizeOf(context).width >= AppBreakpoints.mobile
              ? 460
              : null,
          margin: MediaQuery.sizeOf(context).width >= AppBreakpoints.mobile
              ? null
              : const EdgeInsets.all(AppSpacing.md),
          content: Row(
            children: <Widget>[
              Icon(icon, size: 18, color: color),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  /// 全屏加载遮罩，返回一个关闭函数
  static VoidCallback showLoading(BuildContext context, {String? text}) {
    final NavigatorState navigator = Navigator.of(context, rootNavigator: true);
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: '加载中',
      barrierColor: Colors.black.withValues(alpha: 0.28),
      transitionDuration: AppDuration.fast,
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (BuildContext ctx, Animation<double> anim, _, __) {
        final AppColors c = ctx.colors;
        return FadeTransition(
          opacity: anim,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.lg,
              ),
              decoration: BoxDecoration(
                color: c.surfaceElevated,
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: AppShadows.overlay(c.shadowMedium),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation<Color>(c.accent),
                    ),
                  ),
                  if (text != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    Text(text,
                        style: Theme.of(ctx).textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
    return () {
      if (navigator.canPop()) navigator.pop();
    };
  }
}

enum ToastType { info, success, warning, error }
