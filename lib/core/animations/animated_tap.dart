import 'package:flutter/material.dart';

import '../theme/app_dimens.dart';

/// ============================================================================
/// 柔和点按反馈包装器
///
/// 任何可点击元素套一层 AnimatedTap，即可获得：
///   · 按下时轻微缩小（0.97）+ 亮度微降，松手弹回 —— 反馈柔和不生硬
///   · 桌面端鼠标移入时轻微上浮（可选），并自动切换成手型光标
/// ============================================================================
class AnimatedTap extends StatefulWidget {
  const AnimatedTap({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleDown = 0.97,
    this.enableHoverLift = true,
    this.hoverLift = 2.0,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// 按下时缩放到的比例
  final double scaleDown;

  /// 桌面端鼠标移入是否上浮
  final bool enableHoverLift;
  final double hoverLift;

  final BorderRadius? borderRadius;

  @override
  State<AnimatedTap> createState() => _AnimatedTapState();
}

class _AnimatedTapState extends State<AnimatedTap> {
  bool _pressed = false;
  bool _hovered = false;

  void _setPressed(bool value) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final bool interactive =
        widget.onTap != null || widget.onLongPress != null;

    final double scale = _pressed ? widget.scaleDown : 1.0;
    final double lift =
        (widget.enableHoverLift && _hovered && !_pressed) ? -widget.hoverLift : 0.0;

    return MouseRegion(
      cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: AnimatedSlide(
          duration: AppDuration.fast,
          curve: AppCurves.enter,
          offset: Offset(0, lift / 100),
          child: AnimatedScale(
            duration: AppDuration.micro,
            curve: AppCurves.enter,
            scale: scale,
            child: AnimatedOpacity(
              duration: AppDuration.micro,
              opacity: _pressed ? 0.86 : 1.0,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// 列表项逐个入场动画（不依赖第三方库的轻量实现）
/// 用法：包住 ListView 的每个 item，传入 index 即可产生错落入场效果
/// ----------------------------------------------------------------------------
class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
    this.offsetY = 18,
    this.maxDelayItems = 12,
  });

  final int index;
  final Widget child;
  final double offsetY;

  /// 超过这个序号的项不再叠加延迟，避免长列表末尾迟迟不出现
  final int maxDelayItems;

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDuration.listItem,
  );

  @override
  void initState() {
    super.initState();
    final int effectiveIndex =
        widget.index.clamp(0, widget.maxDelayItems);
    final Duration delay = AppDuration.listStagger * effectiveIndex;
    Future<void>.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CurvedAnimation curved =
        CurvedAnimation(parent: _controller, curve: AppCurves.enter);
    return AnimatedBuilder(
      animation: curved,
      builder: (BuildContext context, Widget? child) {
        return Opacity(
          opacity: curved.value,
          child: Transform.translate(
            offset: Offset(0, (1 - curved.value) * widget.offsetY),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
