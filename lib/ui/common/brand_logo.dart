import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';

/// ============================================================================
/// 品牌标识
///
/// 用渐变圆角方块 + 线迹图标表达「衣线」，不依赖任何图片资源，
/// 任何平台、任何分辨率都清晰，也方便随主题变色。
/// ============================================================================
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.size = 44,
    this.radius,
  });

  final double size;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: c.heroGradient,
        ),
        borderRadius: BorderRadius.circular(radius ?? size * 0.3),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: c.primary.withValues(alpha: 0.28),
            blurRadius: size * 0.45,
            spreadRadius: -size * 0.12,
            offset: Offset(0, size * 0.16),
          ),
        ],
      ),
      child: Icon(
        Icons.content_cut_rounded,
        size: size * 0.5,
        color: Colors.white.withValues(alpha: 0.94),
      ),
    );
  }
}

/// 横排的「图标 + 应用名 + 副标题」组合
class BrandTitle extends StatelessWidget {
  const BrandTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.logoSize = 40,
  });

  final String title;
  final String? subtitle;
  final double logoSize;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme t = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        BrandLogo(size: logoSize),
        const SizedBox(width: AppSpacing.sm),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: t.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: t.labelSmall?.copyWith(color: c.textTertiary),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
