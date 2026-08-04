import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';

/// ============================================================================
/// 带标题的表单输入框
///
/// 统一了「标题 + 必填星号 + 输入框 + 辅助说明」的排版，
/// 让所有表单页面的节奏保持一致。
/// ============================================================================
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.helper,
    this.required = false,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.prefixIcon,
    this.suffix,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.onChanged,
    this.onTap,
    this.validator,
    this.textInputAction,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;
  final bool required;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final int? minLines;
  final int? maxLength;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final FormFieldValidator<String>? validator;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme t = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 7),
          child: RichText(
            text: TextSpan(
              text: label,
              style: t.labelMedium?.copyWith(
                color: c.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              children: <InlineSpan>[
                if (required)
                  TextSpan(
                    text: ' *',
                    style: t.labelMedium?.copyWith(color: c.accent),
                  ),
              ],
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLines: obscureText ? 1 : maxLines,
          minLines: minLines,
          maxLength: maxLength,
          obscureText: obscureText,
          enabled: enabled,
          readOnly: readOnly,
          autofocus: autofocus,
          onChanged: onChanged,
          onTap: onTap,
          validator: validator,
          textInputAction: textInputAction,
          onFieldSubmitted: onSubmitted,
          style: t.bodyLarge,
          cursorRadius: const Radius.circular(2),
          decoration: InputDecoration(
            hintText: hint,
            counterText: '',
            prefixIcon: prefixIcon == null
                ? null
                : Icon(prefixIcon, size: 18, color: c.textTertiary),
            suffixIcon: suffix,
            filled: true,
            fillColor: enabled ? c.surfaceAlt : c.surfaceAlt.withValues(alpha: 0.5),
          ),
        ),
        if (helper != null)
          Padding(
            padding: const EdgeInsets.only(left: 2, top: 6),
            child: Text(helper!, style: t.labelSmall),
          ),
      ],
    );
  }
}

/// ----------------------------------------------------------------------------
/// 只读的「点击选择」字段：日期选择、客户选择等
/// ----------------------------------------------------------------------------
class AppPickerField extends StatelessWidget {
  const AppPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.hint = '点击选择',
    this.icon,
    this.required = false,
    this.onClear,
    this.helper,
  });

  final String label;

  /// 已选中的展示文本，为空时显示 hint
  final String? value;
  final VoidCallback onTap;
  final String hint;
  final IconData? icon;
  final bool required;

  /// 提供后会在右侧显示清除按钮
  final VoidCallback? onClear;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme t = Theme.of(context).textTheme;
    final bool hasValue = (value ?? '').trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 7),
          child: RichText(
            text: TextSpan(
              text: label,
              style: t.labelMedium?.copyWith(
                color: c.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              children: <InlineSpan>[
                if (required)
                  TextSpan(
                    text: ' *',
                    style: t.labelMedium?.copyWith(color: c.accent),
                  ),
              ],
            ),
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.fieldRadius,
            child: AnimatedContainer(
              duration: AppDuration.fast,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 15,
              ),
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                borderRadius: AppRadius.fieldRadius,
                border: Border.all(color: c.border),
              ),
              child: Row(
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    Icon(icon, size: 18, color: c.textTertiary),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: AppDuration.fast,
                      child: Text(
                        hasValue ? value! : hint,
                        key: ValueKey<String>(value ?? ''),
                        style: hasValue
                            ? t.bodyLarge
                            : t.bodyLarge?.copyWith(color: c.textTertiary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (hasValue && onClear != null)
                    GestureDetector(
                      onTap: onClear,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Icon(Icons.close_rounded,
                            size: 17, color: c.textTertiary),
                      ),
                    )
                  else
                    Icon(Icons.keyboard_arrow_down_rounded,
                        size: 20, color: c.textTertiary),
                ],
              ),
            ),
          ),
        ),
        if (helper != null)
          Padding(
            padding: const EdgeInsets.only(left: 2, top: 6),
            child: Text(helper!, style: t.labelSmall),
          ),
      ],
    );
  }
}

/// ----------------------------------------------------------------------------
/// 顶部搜索栏
/// ----------------------------------------------------------------------------
class AppSearchField extends StatefulWidget {
  const AppSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.controller,
    this.autofocus = false,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final bool autofocus;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _hasText = _controller.text.isNotEmpty;
    _focusNode.addListener(() {
      if (mounted) setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return AnimatedContainer(
      duration: AppDuration.fast,
      curve: AppCurves.enter,
      height: 44,
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: _focused ? c.primary : c.border,
          width: _focused ? 1.6 : 1,
        ),
      ),
      child: Row(
        children: <Widget>[
          const SizedBox(width: AppSpacing.sm),
          Icon(Icons.search_rounded,
              size: 19, color: _focused ? c.primary : c.textTertiary),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: widget.autofocus,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: c.textPrimary,
                  ),
              decoration: InputDecoration(
                hintText: widget.hint,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintStyle: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: c.textTertiary),
              ),
              onChanged: (String v) {
                widget.onChanged(v);
                final bool has = v.isNotEmpty;
                if (has != _hasText) setState(() => _hasText = has);
              },
            ),
          ),
          AnimatedSwitcher(
            duration: AppDuration.fast,
            child: _hasText
                ? IconButton(
                    key: const ValueKey<String>('clear'),
                    icon: Icon(Icons.cancel_rounded,
                        size: 17, color: c.textTertiary),
                    splashRadius: 16,
                    onPressed: () {
                      _controller.clear();
                      widget.onChanged('');
                      setState(() => _hasText = false);
                    },
                  )
                : const SizedBox(
                    key: ValueKey<String>('empty'), width: AppSpacing.sm),
          ),
        ],
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// 常用输入格式限制器
/// ----------------------------------------------------------------------------
class AppInputFormatters {
  AppInputFormatters._();

  /// 金额：最多两位小数
  static final List<TextInputFormatter> money = <TextInputFormatter>[
    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
  ];

  /// 正整数
  static final List<TextInputFormatter> integer = <TextInputFormatter>[
    FilteringTextInputFormatter.digitsOnly,
  ];

  /// 手机号
  static final List<TextInputFormatter> phone = <TextInputFormatter>[
    FilteringTextInputFormatter.allow(RegExp(r'[0-9\-+ ]')),
    LengthLimitingTextInputFormatter(20),
  ];
}
