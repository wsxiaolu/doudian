import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/widgets/app_card.dart';
import '../../state/auth_provider.dart';
import '../auth/auth_page.dart';
import '../shell/app_shell.dart';
import '../common/brand_logo.dart';

/// ============================================================================
/// 启动门
///
/// 根据 [AuthProvider] 的当前状态决定首屏：
///   · booting   → 启动图（短暂）
///   · 已登录/本地模式 → 主界面 AppShell
///   · 未登录     → 登录/注册页
/// ============================================================================
class BootGate extends StatelessWidget {
  const BootGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (BuildContext context, AuthProvider auth, _) {
        switch (auth.status) {
          case AuthStatus.booting:
            return const SplashScreen();
          case AuthStatus.signedIn:
          case AuthStatus.localOnly:
            return const AppShell();
          case AuthStatus.signedOut:
            return const AuthPage();
        }
      },
    );
  }
}

/// 启动图
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: c.background,
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (BuildContext ctx, double v, Widget? child) => Opacity(
            opacity: v,
            child: Transform.translate(
              offset: Offset(0, (1 - v) * 16),
              child: child,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const BrandLogo(size: 84, radius: 26),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '抖店订单管家',
                style: t.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '订单自动同步 · 发货一键搞定',
                style: t.bodySmall?.copyWith(color: c.textTertiary),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(c.accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 轻量卡片占位（登录页/设置页共用的提示条）
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.icon,
    required this.text,
    this.color,
  });

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final Color main = color ?? c.primary;
    return AppCard(
      useGradient: false,
      padding: const EdgeInsets.all(AppSpacing.md),
      background: main.withValues(alpha: 0.08),
      borderColor: main.withValues(alpha: 0.18),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: main),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: c.textSecondary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
