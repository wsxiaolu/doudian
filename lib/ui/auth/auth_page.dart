import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/widgets/app_text_field.dart';
import '../../data/remote/supabase_service.dart';
import '../../state/auth_provider.dart';
import '../../state/data_provider.dart';
import '../common/brand_logo.dart';

/// ============================================================================
/// 登录 / 注册 / 本地模式 入口
///
/// 三种进入方式：
///   ① 邮箱密码登录（云端账号，多端同步）
///   ② 注册新账号
///   ③ 先本地用着（不配置云端，数据只存本机，以后可补配云端）
///
/// 云端地址/密钥可在本页「高级」里填，但修改后需重启 App 才生效
/// （Supabase SDK 仅初始化一次）。更细的配置见设置页。
/// ============================================================================
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool _isRegister = false;
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _url = TextEditingController();
  final TextEditingController _key = TextEditingController();
  bool _showAdvanced = false;
  bool _advancedLoaded = false;

  @override
  void initState() {
    super.initState();
    // 回到登录页时清空内存数据，避免上一个账号的数据残留
    final DataProvider? data =
        context.findAncestorStateOfType<State>() == null
            ? null
            : Provider.of<DataProvider>(context, listen: false);
    data?.clear();
    final AuthProvider auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.lastEmail.isNotEmpty) _email.text = auth.lastEmail;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _url.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _ensureAdvanced() async {
    if (_advancedLoaded) return;
    final (String u, String k) = await SupabaseService.loadConfig();
    _url.text = u;
    _key.text = k;
    _advancedLoaded = true;
  }

  Future<void> _submit() async {
    final AuthProvider auth = context.read<AuthProvider>();
    final String email = _email.text.trim();
    final String pwd = _password.text;
    if (email.isEmpty || pwd.isEmpty) {
      AppFeedback.toast(context, '请输入邮箱与密码', type: ToastType.warning);
      return;
    }
    if (_isRegister && pwd.length < 6) {
      AppFeedback.toast(context, '密码至少 6 位', type: ToastType.warning);
      return;
    }
    bool ok;
    if (_isRegister) {
      ok = await auth.signUp(email: email, password: pwd, displayName: _name.text);
    } else {
      ok = await auth.signIn(email: email, password: pwd);
    }
    if (!ok && auth.errorText != null && mounted) {
      AppFeedback.toast(context, auth.errorText!, type: ToastType.error);
    }
  }

  Future<void> _forgot() async {
    final String email = _email.text.trim();
    if (email.isEmpty) {
      AppFeedback.toast(context, '请先填写邮箱', type: ToastType.warning);
      return;
    }
    final AuthProvider auth = context.read<AuthProvider>();
    await auth.sendResetMail(email);
    if (auth.errorText != null && mounted) {
      AppFeedback.toast(context, auth.errorText!, type: ToastType.success);
    }
  }

  Future<void> _saveCloud() async {
    final String u = _url.text.trim();
    final String k = _key.text.trim();
    if (u.isEmpty || k.isEmpty) {
      AppFeedback.toast(context, '请填写完整的 URL 与密钥', type: ToastType.warning);
      return;
    }
    await SupabaseService.saveConfig(url: u, anonKey: k);
    if (mounted) {
      AppFeedback.toast(
        context,
        '已保存，重启应用后生效',
        type: ToastType.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme t = Theme.of(context).textTheme;
    final AuthProvider auth = context.watch<AuthProvider>();
    final bool busy = auth.busy;

    return Scaffold(
      backgroundColor: c.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const BrandLogo(size: 64, radius: 20),
                const SizedBox(height: AppSpacing.md),
                Text(
                  AppConfig.appName,
                  style: t.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  AppConfig.appSlogan,
                  style: t.bodySmall?.copyWith(color: c.textTertiary),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // 登录 / 注册 切换
                      Container(
                        decoration: BoxDecoration(
                          color: c.surfaceAlt,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: _SegmentTab(
                                label: '登录',
                                selected: !_isRegister,
                                onTap: () => setState(() => _isRegister = false),
                              ),
                            ),
                            Expanded(
                              child: _SegmentTab(
                                label: '注册',
                                selected: _isRegister,
                                onTap: () => setState(() => _isRegister = true),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppTextField(
                        label: '邮箱',
                        controller: _email,
                        hint: 'you@example.com',
                        prefixIcon: Icons.alternate_email_rounded,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (_isRegister) ...<Widget>[
                        AppTextField(
                          label: '昵称',
                          controller: _name,
                          hint: '店铺或你的称呼',
                          prefixIcon: Icons.person_outline_rounded,
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      AppTextField(
                        label: '密码',
                        controller: _password,
                        hint: '至少 6 位',
                        prefixIcon: Icons.lock_outline_rounded,
                        obscureText: true,
                        onSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (!_isRegister)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _forgot,
                            child: const Text('忘记密码？'),
                          ),
                        ),
                      const SizedBox(height: AppSpacing.sm),
                      AppButton(
                        label: _isRegister ? '注册并进入' : '登录',
                        icon: Icons.login_rounded,
                        loading: busy,
                        expanded: true,
                        onPressed: busy ? null : _submit,
                      ),
                      // 高级：云端配置
                      const SizedBox(height: AppSpacing.md),
                      _AdvancedToggle(
                        expanded: _showAdvanced,
                        onToggle: () {
                          setState(() => _showAdvanced = !_showAdvanced);
                          if (_showAdvanced) _ensureAdvanced();
                        },
                      ),
                      if (_showAdvanced) ...<Widget>[
                        const SizedBox(height: AppSpacing.md),
                        AppTextField(
                          label: 'Supabase URL',
                          controller: _url,
                          hint: 'https://xxxx.supabase.co',
                          prefixIcon: Icons.cloud_outlined,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppTextField(
                          label: 'Anon Key',
                          controller: _key,
                          hint: '公钥，可明文分发',
                          prefixIcon: Icons.key_rounded,
                          obscureText: true,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppButton(
                          label: '保存云端配置',
                          variant: AppButtonVariant.outline,
                          icon: Icons.save_outlined,
                          expanded: true,
                          onPressed: _saveCloud,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: '先本地用着（数据只存本机）',
                  variant: AppButtonVariant.ghost,
                  icon: Icons.devices_rounded,
                  onPressed: busy
                      ? null
                      : () async {
                          await auth.useLocalMode();
                        },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 登录 / 注册 分段控件
class _SegmentTab extends StatelessWidget {
  const _SegmentTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? c.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.xs),
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: c.shadowSoft,
                      blurRadius: 10,
                      spreadRadius: -4,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? c.textPrimary : c.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 高级配置折叠标题
class _AdvancedToggle extends StatelessWidget {
  const _AdvancedToggle({required this.expanded, required this.onToggle});

  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.tune_rounded,
                size: 16,
                color: c.textTertiary,
              ),
              const SizedBox(width: 6),
              Text(
                '高级：配置云端账号',
                style: TextStyle(
                  fontSize: 13,
                  color: c.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                expanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 16,
                color: c.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
