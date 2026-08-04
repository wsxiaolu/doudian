import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/widgets/status_chip.dart';
import '../../core/widgets/app_text_field.dart';
import '../../data/export/excel_exporter.dart';
import '../../data/remote/douyin_api_service.dart';
import '../../data/remote/supabase_service.dart';
import '../../data/sync/douyin_sync_service.dart';
import '../../data/sync/sync_service.dart';
import '../../state/auth_provider.dart';
import '../../state/data_provider.dart';
import '../../state/theme_provider.dart';

/// ============================================================================
/// 设置页
///
/// 账号资料、外观主题、Supabase 云端配置、抖店开放平台接入、
/// 云端双向同步策略，以及关于信息，全部集中在此管理。
/// 与「服装订单管家」一致的单页分组（AppSectionCard）布局。
/// ============================================================================
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _supabaseUrlController = TextEditingController();
  final TextEditingController _supabaseKeyController = TextEditingController();
  final TextEditingController _douyinAppKeyController = TextEditingController();
  final TextEditingController _douyinAppSecretController =
      TextEditingController();
  final TextEditingController _douyinShopIdController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _shopNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _savingCloud = false;
  bool _testingCloud = false;
  bool _savingDouyin = false;
  bool _savingProfile = false;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    final DouyinCredentials cred = DouyinApiService.instance.credentials;
    _douyinAppKeyController.text = cred.appKey;
    _douyinAppSecretController.text = cred.appSecret;
    _douyinShopIdController.text = cred.shopId;
    _loadCloudConfig();
  }

  Future<void> _loadCloudConfig() async {
    final (String url, String key) = await SupabaseService.loadConfig();
    if (!mounted) return;
    _supabaseUrlController.text = url;
    _supabaseKeyController.text = key;
  }

  @override
  void dispose() {
    _supabaseUrlController.dispose();
    _supabaseKeyController.dispose();
    _douyinAppKeyController.dispose();
    _douyinAppSecretController.dispose();
    _douyinShopIdController.dispose();
    _displayNameController.dispose();
    _shopNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // 账号资料
  // ---------------------------------------------------------------------------
  Future<void> _saveProfile(BuildContext context, AuthProvider auth) async {
    final String name = _displayNameController.text.trim();
    if (name.isEmpty) {
      AppFeedback.toast(context, '昵称不能为空', type: ToastType.warning);
      return;
    }
    setState(() => _savingProfile = true);
    try {
      final bool ok = await auth.updateProfile(
        displayName: name,
        shopName: _shopNameController.text,
        phone: _phoneController.text,
      );
      if (mounted) {
        Navigator.of(context).pop();
        AppFeedback.toast(
          context,
          ok ? '资料已保存' : '资料已保存（云端同步失败）',
          type: ok ? ToastType.success : ToastType.warning,
        );
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.toast(context, '保存失败：$e', type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  void _openProfileSheet(BuildContext context, AuthProvider auth) {
    _displayNameController.text = auth.profile?.displayName ?? '';
    _shopNameController.text = auth.profile?.shopName ?? '';
    _phoneController.text = auth.profile?.phone ?? '';
    AppFeedback.showSheet(
      context: context,
      title: '编辑账号资料',
      child: Column(
        children: <Widget>[
          AppTextField(
            label: '昵称',
            controller: _displayNameController,
            required: true,
            prefixIcon: Icons.badge_rounded,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: '店铺名称',
            controller: _shopNameController,
            prefixIcon: Icons.store_rounded,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: '联系电话',
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: AppInputFormatters.phone,
            prefixIcon: Icons.call_rounded,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            expanded: true,
            label: '保存',
            loading: _savingProfile,
            onPressed: () => _saveProfile(context, auth),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, AuthProvider auth) async {
    final bool ok = await AppFeedback.confirm(
      context: context,
      title: '退出登录',
      message: '退出后将回到登录页，本地已缓存的数据仍然保留。',
      confirmText: '退出',
      danger: true,
      icon: Icons.logout_rounded,
    );
    if (ok) await auth.signOut();
  }

  // ---------------------------------------------------------------------------
  // 云端（Supabase）配置
  // ---------------------------------------------------------------------------
  Future<void> _saveCloud() async {
    setState(() => _savingCloud = true);
    try {
      await SupabaseService.saveConfig(
        url: _supabaseUrlController.text,
        anonKey: _supabaseKeyController.text,
      );
      if (mounted) {
        AppFeedback.toast(context, '已保存，重启应用后生效',
            type: ToastType.success);
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.toast(context, '保存失败：$e', type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _savingCloud = false);
    }
  }

  Future<void> _testCloud() async {
    setState(() => _testingCloud = true);
    try {
      final bool ok = await SupabaseService.instance.ping();
      if (mounted) {
        AppFeedback.toast(
          context,
          ok ? '云端连接成功' : '连接失败，请检查 URL 与密钥',
          type: ok ? ToastType.success : ToastType.error,
        );
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.toast(context, SupabaseService.describeError(e),
            type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _testingCloud = false);
    }
  }

  // ---------------------------------------------------------------------------
  // 抖店接入
  // ---------------------------------------------------------------------------
  Future<void> _saveDouyin() async {
    setState(() => _savingDouyin = true);
    try {
      await DouyinApiService.instance.saveAppConfig(
        appKey: _douyinAppKeyController.text,
        appSecret: _douyinAppSecretController.text,
        shopId: _douyinShopIdController.text,
      );
      final String msg = await DouyinApiService.instance.testConnection();
      if (mounted) {
        AppFeedback.toast(context, msg, type: ToastType.success);
        setState(() {}); // 刷新「已配置」状态展示
      }
    } on DouyinApiException catch (e) {
      if (mounted) {
        AppFeedback.toast(context, e.toString(), type: ToastType.error);
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.toast(context, '连接失败：$e', type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _savingDouyin = false);
    }
  }

  Future<void> _syncNow() async {
    final DouyinSyncResult r =
        await DouyinSyncService.instance.syncNow(silent: false);
    if (mounted) {
      AppFeedback.toast(
        context,
        r.success ? r.summary : r.message,
        type: r.success ? ToastType.success : ToastType.error,
      );
    }
  }

  Future<void> _resetWatermark() async {
    await DouyinSyncService.instance.resetWatermark();
    if (mounted) {
      AppFeedback.toast(context, '已重置，下次同步将全量回溯',
          type: ToastType.success);
    }
  }

  Future<void> _clearDouyin() async {
    final bool ok = await AppFeedback.confirm(
      context: context,
      title: '解除抖店授权',
      message: '将清空本地保存的访问令牌，下次同步需重新授权。店铺配置仍保留。',
      confirmText: '解除',
      danger: true,
      icon: Icons.link_off_rounded,
    );
    if (!ok) return;
    await DouyinApiService.instance.clearToken();
    if (mounted) {
      AppFeedback.toast(context, '已解除授权', type: ToastType.success);
      setState(() {});
    }
  }

  static String _intervalLabel(int s) {
    if (s >= 3600) return '${s ~/ 3600} 小时';
    if (s >= 60) return '${s ~/ 60} 分钟';
    return '$s 秒';
  }

  // ---------------------------------------------------------------------------
  // 数据导出（Excel）
  // ---------------------------------------------------------------------------
  Future<void> _exportExcel(BuildContext context) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final DataProvider data =
          Provider.of<DataProvider>(context, listen: false);
      final Excel excel = ExcelExporter.buildWorkbook(
        orders: data.orders,
        products: data.products,
        customers: data.customers,
        afterSales: data.afterSales,
      );
      final List<int>? bytes = excel.save();
      if (bytes == null) throw Exception('生成表格失败');

      final String stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final String fileName = '抖店订单导出_$stamp.xlsx';

      // 优先让用户选目录（桌面 / 安卓支持，iOS 不支持则回退到分享面板）
      String? dir;
      try {
        dir = await FilePicker.platform.getDirectoryPath(
          dialogTitle: '选择导出文件保存位置',
        );
      } catch (_) {
        dir = null;
      }

      final String outPath;
      if (dir != null && dir.isNotEmpty) {
        outPath = p.join(dir, fileName);
      } else {
        final Directory docs = await getApplicationDocumentsDirectory();
        outPath = p.join(docs.path, fileName);
      }

      final File file = File(outPath);
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      if (dir != null && dir.isNotEmpty) {
        AppFeedback.toast(context, '已导出到：$outPath', type: ToastType.success);
      } else {
        // iOS 等不支持目录选择的平台：通过系统分享面板让用户决定保存位置
        await Share.shareXFiles(
          <XFile>[XFile(outPath)],
          subject: '抖店订单导出',
          text: '抖店订单管家数据导出',
        );
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.toast(context, '导出失败：$e', type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Widget _exportSection(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme t = Theme.of(context).textTheme;
    return AppSectionCard(
      title: '数据导出',
      icon: Icons.file_download_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '把当前账号的订单、订单明细、商品、客户、售后导出为 Excel，方便对账与盘点。',
            style: t.bodySmall?.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: '导出 Excel',
            icon: Icons.table_chart_rounded,
            loading: _exporting,
            onPressed: () => _exportExcel(context),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 构建
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme t = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: c.background,
      body: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: context.pagePadding,
          vertical: AppSpacing.md,
        ),
        children: <Widget>[
          Text('设置', style: t.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '账号、外观、云端同步与抖店接入都在这里管理',
            style: t.bodySmall?.copyWith(color: c.textTertiary),
          ),
          const SizedBox(height: AppSpacing.lg),

          Consumer<AuthProvider>(
            builder: (_, AuthProvider auth, __) => _accountSection(context, auth),
          ),
          const SizedBox(height: AppSpacing.lg),

          Consumer<ThemeProvider>(
            builder: (_, ThemeProvider theme, __) =>
                _appearanceSection(context, theme),
          ),
          const SizedBox(height: AppSpacing.lg),

          _cloudSection(context),
          const SizedBox(height: AppSpacing.lg),

          Consumer<DouyinSyncService>(
            builder: (_, DouyinSyncService d, __) =>
                _douyinSection(context, d),
          ),
          const SizedBox(height: AppSpacing.lg),

          Consumer<SyncService>(
            builder: (_, SyncService s, __) => _dataSyncSection(context, s),
          ),
          const SizedBox(height: AppSpacing.lg),

          _exportSection(context),
          const SizedBox(height: AppSpacing.lg),

          _aboutSection(context),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _accountSection(BuildContext context, AuthProvider auth) {
    final AppColors c = context.colors;
    final TextTheme t = Theme.of(context).textTheme;
    final bool signedIn = auth.status == AuthStatus.signedIn;
    return AppSectionCard(
      title: '账号',
      icon: Icons.account_circle_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person_rounded, color: c.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(auth.profile?.displayName ?? '本地用户',
                        style: t.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      signedIn
                          ? (auth.profile?.email ?? '')
                          : '本地模式 · 数据仅存本机',
                      style: t.labelSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              AppButton(
                label: '编辑资料',
                icon: Icons.edit_rounded,
                variant: AppButtonVariant.outline,
                size: AppButtonSize.small,
                onPressed: () => _openProfileSheet(context, auth),
              ),
              if (signedIn)
                AppButton(
                  label: '退出登录',
                  icon: Icons.logout_rounded,
                  variant: AppButtonVariant.danger,
                  size: AppButtonSize.small,
                  onPressed: () => _confirmSignOut(context, auth),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _appearanceSection(BuildContext context, ThemeProvider theme) {
    final TextTheme t = Theme.of(context).textTheme;
    return AppSectionCard(
      title: '外观',
      icon: Icons.palette_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('主题模式', style: t.bodyMedium),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              for (final ThemeMode m in const <ThemeMode>[
                ThemeMode.system,
                ThemeMode.light,
                ThemeMode.dark,
              ])
                FilterChipButton(
                  label: ThemeProvider.labelOf(m),
                  selected: theme.mode == m,
                  onTap: () => theme.setMode(m),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cloudSection(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme t = Theme.of(context).textTheme;
    final bool configured = SupabaseService.instance.isConfigured;
    return AppSectionCard(
      title: '云端账号（Supabase）',
      icon: Icons.cloud_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (configured)
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: c.successSoft,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.check_circle_rounded, color: c.success, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('已连接云端，多端数据自动同步',
                        style: t.bodySmall?.copyWith(color: c.success)),
                  ),
                ],
              ),
            ),
          AppTextField(
            label: 'Supabase URL',
            controller: _supabaseUrlController,
            hint: 'https://xxxx.supabase.co',
            prefixIcon: Icons.link_rounded,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Anon Key',
            controller: _supabaseKeyController,
            hint: '公开匿名密钥',
            obscureText: true,
            prefixIcon: Icons.key_rounded,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              AppButton(
                label: '保存配置',
                icon: Icons.save_rounded,
                loading: _savingCloud,
                onPressed: _saveCloud,
              ),
              AppButton(
                label: '测试连接',
                variant: AppButtonVariant.outline,
                loading: _testingCloud,
                onPressed: _testCloud,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '修改后需重启应用生效；留空则进入本地模式，数据只存本机。',
            style: t.labelSmall,
          ),
        ],
      ),
    );
  }

  Widget _douyinSection(BuildContext context, DouyinSyncService douyin) {
    final AppColors c = context.colors;
    final TextTheme t = Theme.of(context).textTheme;
    final bool configured = douyin.isConfigured;
    final String statusLine = douyin.lastSyncAt != null
        ? '${douyin.statusText} · 上次 ${Fmt.smartTime(douyin.lastSyncAt)}'
        : douyin.statusText;
    return AppSectionCard(
      title: '抖店开放平台',
      icon: Icons.store_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: configured ? c.successSoft : c.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  configured
                      ? Icons.check_circle_rounded
                      : Icons.info_outline_rounded,
                  color: configured ? c.success : c.textTertiary,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(statusLine,
                      style: t.bodySmall?.copyWith(
                          color: configured ? c.success : c.textSecondary)),
                ),
              ],
            ),
          ),
          AppTextField(
            label: 'App Key',
            controller: _douyinAppKeyController,
            prefixIcon: Icons.vpn_key_rounded,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'App Secret',
            controller: _douyinAppSecretController,
            obscureText: true,
            prefixIcon: Icons.lock_rounded,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: '店铺 ID',
            controller: _douyinShopIdController,
            prefixIcon: Icons.storefront_rounded,
            helper: '自用型应用必填，用于换取访问令牌',
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              AppButton(
                label: '保存并测试',
                icon: Icons.save_rounded,
                loading: _savingDouyin,
                onPressed: _saveDouyin,
              ),
              if (configured)
                AppButton(
                  label: '立即同步',
                  variant: AppButtonVariant.outline,
                  icon: Icons.sync_rounded,
                  onPressed: _syncNow,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _SwitchRow(
            label: '自动同步订单',
            subtitle: '按设定周期自动拉取抖店新增与变更订单',
            value: douyin.autoSync,
            onChanged: (bool v) => douyin.setAutoSync(v),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(child: Text('同步周期', style: t.bodyMedium)),
              DropdownButton<int>(
                value: douyin.intervalSeconds,
                underline: const SizedBox.shrink(),
                items: AppConfig.douyinSyncIntervalOptions
                    .map((int s) => DropdownMenuItem<int>(
                          value: s,
                          child: Text(_intervalLabel(s)),
                        ))
                    .toList(),
                onChanged: (int? v) {
                  if (v != null) douyin.setInterval(v);
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              AppButton(
                label: '重置同步进度',
                variant: AppButtonVariant.ghost,
                icon: Icons.restart_alt_rounded,
                size: AppButtonSize.small,
                onPressed: _resetWatermark,
              ),
              if (configured)
                AppButton(
                  label: '解除授权',
                  variant: AppButtonVariant.danger,
                  icon: Icons.link_off_rounded,
                  size: AppButtonSize.small,
                  onPressed: _clearDouyin,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dataSyncSection(BuildContext context, SyncService sync) {
    final AppColors c = context.colors;
    final TextTheme t = Theme.of(context).textTheme;
    final String statusLine = sync.lastSuccessAt != null
        ? '${sync.statusText} · 上次 ${Fmt.smartTime(sync.lastSuccessAt)}'
        : sync.statusText;
    return AppSectionCard(
      title: '数据同步（本地 ⇄ 云端）',
      icon: Icons.sync_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.info_outline_rounded,
                    color: c.textSecondary, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(statusLine,
                      style: t.bodySmall?.copyWith(color: c.textSecondary)),
                ),
              ],
            ),
          ),
          if (sync.pendingCount > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text('待上传 ${sync.pendingCount} 条改动',
                  style: t.labelMedium?.copyWith(color: c.warning)),
            ),
          _SwitchRow(
            label: '自动同步',
            subtitle: '联网时自动把本机改动推送到云端',
            value: sync.autoSyncEnabled,
            onChanged: (bool v) => sync.setAutoSync(v),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: '立即同步',
            icon: Icons.sync_rounded,
            variant: AppButtonVariant.outline,
            onPressed: () => sync.syncAll(manual: true),
          ),
        ],
      ),
    );
  }

  Widget _aboutSection(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme t = Theme.of(context).textTheme;
    return AppSectionCard(
      title: '关于',
      icon: Icons.info_outline_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(Icons.store_rounded, color: c.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(AppConfig.appName, style: t.titleMedium),
                    const SizedBox(height: 2),
                    Text('${AppConfig.appVersion} · ${AppConfig.appSlogan}',
                        style: t.labelSmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '抖店订单自动同步 · 三端一套代码（Windows / Android / iOS）',
            style: t.bodySmall?.copyWith(color: c.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// 设置页通用的「标题 + 开关」行
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme t = Theme.of(context).textTheme;
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: t.bodyMedium),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 2),
                Text(subtitle!, style: t.labelSmall),
              ],
            ],
          ),
        ),
        Switch(
          value: value,
          activeColor: c.accent,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
