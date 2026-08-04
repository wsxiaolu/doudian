import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/formatters.dart';

/// ============================================================================
/// 迷你营收柱状图
///
/// 不引入任何图表库，用 CustomPainter 手绘：
///   · 体积小、启动快，全平台渲染一致
///   · 柱体自下而上「生长」入场，最高月份用强调色点亮
///   · 鼠标/手指点选某根柱子时高亮并回调（桌面端悬停亦可）
/// ============================================================================
class MiniRevenueChart extends StatefulWidget {
  const MiniRevenueChart({
    super.key,
    required this.data,
    this.height = 148,
  });

  /// 每项为 (月份标签, 金额)
  final List<({String label, double amount})> data;
  final double height;

  @override
  State<MiniRevenueChart> createState() => _MiniRevenueChartState();
}

class _MiniRevenueChartState extends State<MiniRevenueChart> {
  /// 当前高亮的柱子序号，-1 表示未选中
  int _active = -1;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme t = Theme.of(context).textTheme;
    final List<({String label, double amount})> data = widget.data;

    if (data.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Text('暂无营收数据', style: t.bodySmall),
        ),
      );
    }

    // 最大值用于归一化柱高；全为 0 时给一个兜底值，避免除零
    double maxValue = 0;
    int maxIndex = 0;
    for (int i = 0; i < data.length; i++) {
      if (data[i].amount > maxValue) {
        maxValue = data[i].amount;
        maxIndex = i;
      }
    }
    final bool allZero = maxValue <= 0;

    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double slot = constraints.maxWidth / data.length;

          return Stack(
            children: <Widget>[
              // —— 柱体绘制层 ——
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: AppDuration.page,
                  curve: AppCurves.enter,
                  builder: (BuildContext context, double progress, Widget? _) {
                    return CustomPaint(
                      painter: _BarChartPainter(
                        data: data,
                        maxValue: allZero ? 1 : maxValue,
                        progress: progress,
                        activeIndex: _active,
                        highlightIndex: allZero ? -1 : maxIndex,
                        barColor: c.primary,
                        accentColor: c.accent,
                        gridColor: c.border,
                        labelColor: c.textTertiary,
                        allZero: allZero,
                      ),
                    );
                  },
                ),
              ),

              // —— 交互热区：每根柱子一个 ——
              Positioned.fill(
                child: Row(
                  children: <Widget>[
                    for (int i = 0; i < data.length; i++)
                      SizedBox(
                        width: slot,
                        child: MouseRegion(
                          onEnter: (_) => setState(() => _active = i),
                          onExit: (_) => setState(() => _active = -1),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: (_) => setState(() => _active = i),
                            onTapCancel: () => setState(() => _active = -1),
                            onTap: () => setState(() => _active = -1),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // —— 数值气泡 ——
              if (_active >= 0 && _active < data.length)
                Positioned(
                  left: (slot * _active + slot / 2 - 52)
                      .clamp(0, constraints.maxWidth - 104),
                  top: 0,
                  child: IgnorePointer(
                    child: Container(
                      width: 104,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: c.surfaceElevated,
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                        border: Border.all(color: c.border),
                        boxShadow: AppShadows.card(c.shadowSoft),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(data[_active].label, style: t.labelSmall),
                          Text(
                            Fmt.moneyCompact(data[_active].amount),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.titleSmall?.copyWith(color: c.accent),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// 柱状图绘制器
class _BarChartPainter extends CustomPainter {
  _BarChartPainter({
    required this.data,
    required this.maxValue,
    required this.progress,
    required this.activeIndex,
    required this.highlightIndex,
    required this.barColor,
    required this.accentColor,
    required this.gridColor,
    required this.labelColor,
    required this.allZero,
  });

  final List<({String label, double amount})> data;
  final double maxValue;

  /// 入场进度 0~1
  final double progress;
  final int activeIndex;

  /// 金额最高的那根柱子（用强调色）
  final int highlightIndex;

  final Color barColor;
  final Color accentColor;
  final Color gridColor;
  final Color labelColor;
  final bool allZero;

  static const double _labelHeight = 20;
  static const double _topPadding = 14;

  @override
  void paint(Canvas canvas, Size size) {
    final double chartHeight = size.height - _labelHeight - _topPadding;
    if (chartHeight <= 0) return;

    final double slot = size.width / data.length;
    // 柱宽占槽位的 44%，两侧自然留白，观感通透
    final double barWidth = (slot * 0.44).clamp(6.0, 26.0);

    // —— 基准线 ——
    final Paint gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, _topPadding + chartHeight),
      Offset(size.width, _topPadding + chartHeight),
      gridPaint,
    );

    for (int i = 0; i < data.length; i++) {
      final double ratio = allZero ? 0 : (data[i].amount / maxValue);
      // 有金额时至少画出 4px，让「有数据但很小」也能被看见
      final double fullHeight =
          data[i].amount > 0 ? (ratio * chartHeight).clamp(4.0, chartHeight) : 0;
      final double barHeight = fullHeight * progress;

      final double cx = slot * i + slot / 2;
      final double left = cx - barWidth / 2;
      final double top = _topPadding + chartHeight - barHeight;

      final bool isActive = i == activeIndex;
      final bool isPeak = i == highlightIndex;
      final Color color = isActive || isPeak ? accentColor : barColor;

      if (barHeight > 0) {
        final Rect rect = Rect.fromLTWH(left, top, barWidth, barHeight);
        final Paint paint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              color.withValues(alpha: isActive ? 0.95 : 0.78),
              color.withValues(alpha: isActive ? 0.55 : 0.30),
            ],
          ).createShader(rect);
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            rect,
            topLeft: const Radius.circular(5),
            topRight: const Radius.circular(5),
          ),
          paint,
        );
      } else {
        // 该月没有收款：画一个浅浅的空槽，保持节奏感
        final Rect rect = Rect.fromLTWH(
          left,
          _topPadding + chartHeight - 3,
          barWidth,
          3,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          Paint()..color = gridColor,
        );
      }

      // —— 月份标签 ——
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: data[i].label,
          style: TextStyle(
            fontSize: 10.5,
            height: 1.2,
            color: isActive || isPeak ? accentColor : labelColor,
            fontWeight: isActive || isPeak ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: slot);
      tp.paint(
        canvas,
        Offset(cx - tp.width / 2, size.height - _labelHeight + 4),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter old) =>
      old.progress != progress ||
      old.activeIndex != activeIndex ||
      old.maxValue != maxValue ||
      old.data != data ||
      old.barColor != barColor;
}

/// ============================================================================
/// 收款进度条
///
/// 用于订单卡片与详情页展示「已收 / 总额」的完成度。
/// ============================================================================
class AmountProgressBar extends StatelessWidget {
  const AmountProgressBar({
    super.key,
    required this.ratio,
    this.height = 6,
    this.color,
    this.showLabel = false,
  });

  /// 0~1
  final double ratio;
  final double height;
  final Color? color;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final double safe = ratio.clamp(0.0, 1.0);
    // 已结清用成功绿，未结清用强调橘
    final Color main = color ?? (safe >= 1 ? c.success : c.accent);

    final Widget bar = ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Stack(
        children: <Widget>[
          Container(height: height, color: c.surfaceAlt),
          // 宽度变化走动画，收款登记后进度条平滑推进
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: safe),
            duration: AppDuration.page,
            curve: AppCurves.enter,
            builder: (BuildContext context, double v, Widget? _) {
              return FractionallySizedBox(
                widthFactor: v,
                child: Container(
                  height: height,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        main.withValues(alpha: 0.75),
                        main,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(height),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );

    if (!showLabel) return bar;

    return Row(
      children: <Widget>[
        Expanded(child: bar),
        const SizedBox(width: AppSpacing.xs),
        Text(
          '${(safe * 100).toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: main,
          ),
        ),
      ],
    );
  }
}
