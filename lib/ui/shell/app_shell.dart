import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/app_icon_button.dart';
import '../../core/widgets/app_feedback.dart';
import '../../state/auth_provider.dart';
import '../../state/data_provider.dart';
import '../../state/theme_provider.dart';
import '../../data/sync/douyin_sync_service.dart';
import '../../data/sync/sync_service.dart';
import '../aftersales/after_sale_edit_page.dart';
import '../common/brand_logo.dart';
import '../customers/customer_edit_page.dart';
import '../dashboard/workbench_page.dart';
import '../orders/order_edit_page.dart';
import '../orders/orders_page.dart';
import '../products/product_edit_page.dart';
import '../products/products_page.dart';
import '../customers/customers_page.dart';
import '../aftersales/after_sales_page.dart';
import '../stats/stats_page.dart';
import '../settings/settings_page.dart';

/// ============================================================================
/// 主界面外壳
///
/// 三端统一的响应式导航：
///   · 桌面 / 平板 → 左侧 NavigationRail（桌面展开文字，平板仅图标）
///   · 手机       → 底部 NavigationBar
/// 顶部栏含模块标题、云端同步状态、手动同步、主题切换与账号菜单。
/// 进入后触发 [DataProvider.load] 把本账号数据读进内存。
/// ============================================================================
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  final List<Widget> _pages = const <Widget>[
    WorkbenchPage(),
    OrdersPage(),
    ProductsPage(),
    CustomersPage(),
    AfterSalesPage(),
    StatsPage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    final AuthProvider auth = context.read<AuthProvider>();
    final String? uid = auth.userId;
    if (uid != null) context.read<DataProvider>().load(uid);
  }

  void _manualSync() {
    SyncService.instance.syncAll(manual: true);
    if (DouyinSyncService.instance.isConfigured) {
      DouyinSyncService.instance.syncNow(silent: false);
    }
    AppFeedback.toast(context, '已开始同步', type: ToastType.info);
  }

  void _signOut() async {
    final bool ok = await AppFeedback.confirm(
      context: context,
      title: '退出登录',
      message: '退出后将回到登录页，本地已缓存的数据仍然保留。',
      confirmText: '退出',
      danger: true,
      icon: Icons.logout_rounded,
    );
    if (ok) await context.read<AuthProvider>().signOut();
  }

  Widget? get _fab {
    switch (_index) {
      case 1:
        return FloatingActionButton.extended(
          icon: const Icon(Icons.add_rounded),
          label: const Text('新建订单'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<dynamic>(builder: (_) => const OrderEditPage()),
          ),
        );
      case 2:
        return FloatingActionButton.extended(
          icon: const Icon(Icons.add_rounded),
          label: const Text('新建商品'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<dynamic>(builder: (_) => const ProductEditPage()),
          ),
        );
      case 3:
        return FloatingActionButton.extended(
          icon: const Icon(Icons.add_rounded),
          label: const Text('新建客户'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<dynamic>(builder: (_) => const CustomerEditPage()),
          ),
        );
      case 4:
        return FloatingActionButton.extended(
          icon: const Icon(Icons.add_rounded),
          label: const Text('登记售后'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<dynamic>(builder: (_) => const AfterSaleEditPage()),
          ),
        );
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme t = Theme.of(context).textTheme;

    final List<_NavItem> items = <_NavItem>[
      const _NavItem(
        icon: Icons.dashboard_outlined,
        active: Icons.dashboard_rounded,
        label: '工作台',
      ),
      _NavItem(
        icon: Icons.receipt_long_outlined,
        active: Icons.receipt_long_rounded,
        label: '订单',
        badge: context.watch<DataProvider>().pendingShipCount,
      ),
      const _NavItem(
        icon: Icons.inventory_2_outlined,
        active: Icons.inventory_2_rounded,
        label: '商品',
      ),
      const _NavItem(
        icon: Icons.people_alt_outlined,
        active: Icons.people_alt_rounded,
        label: '客户',
      ),
      _NavItem(
        icon: Icons.assignment_return_outlined,
        active: Icons.assignment_return_rounded,
        label: '售后',
        badge: context.watch<DataProvider>().openAfterSaleCount,
      ),
      const _NavItem(
        icon: Icons.insights_outlined,
        active: Icons.insights_rounded,
        label: '统计',
      ),
      const _NavItem(
        icon: Icons.settings_outlined,
        active: Icons.settings_rounded,
        label: '设置',
      ),
    ];

    final Widget content = AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: KeyedSubtree(
        key: ValueKey<int>(_index),
        child: _pages[_index],
      ),
    );

    final PreferredSizeWidget appBar = AppBar(
      title: Text(items[_index].label, style: t.titleLarge),
      elevation: 0,
      scrolledUnderElevation: 0,
      actions: <Widget>[
        const _SyncIndicator(),
        AppIconButton(
          icon: context.watch<ThemeProvider>().isDark(context)
              ? Icons.light_mode_rounded
              : Icons.dark_mode_rounded,
          tooltip: '切换主题',
          onPressed: () =>
              context.read<ThemeProvider>().toggle(context),
        ),
        AppIconButton(
          icon: Icons.sync_rounded,
          tooltip: '立即同步',
          onPressed: _manualSync,
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.account_circle_rounded, size: 22),
          onSelected: (String v) {
            if (v == 'settings') setState(() => _index = 6);
            if (v == 'logout') _signOut();
          },
          itemBuilder: (BuildContext ctx) => <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              value: 'profile',
              enabled: false,
              child: Consumer<AuthProvider>(
                builder: (_, AuthProvider a, __) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(a.profile?.displayName ?? '本地用户',
                        style: t.titleSmall),
                    Text(
                      a.status == AuthStatus.signedIn
                          ? (a.profile?.email ?? '')
                          : '本地模式',
                      style: t.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: 'settings',
              child: Row(children: <Widget>[
                Icon(Icons.settings_outlined, size: 18),
                SizedBox(width: AppSpacing.sm),
                Text('设置'),
              ]),
            ),
            const PopupMenuItem<String>(
              value: 'logout',
              child: Row(children: <Widget>[
                Icon(Icons.logout_rounded, size: 18),
                SizedBox(width: AppSpacing.sm),
                Text('退出登录'),
              ]),
            ),
          ],
        ),
        const SizedBox(width: AppSpacing.sm),
      ],
    );

    final Widget body = Scaffold(
      backgroundColor: c.background,
      appBar: appBar,
      body: content,
      floatingActionButton: _fab,
    );

    // 桌面 / 平板：左侧导航栏
    if (context.useSideNavigation) {
      return Row(
        children: <Widget>[
          NavigationRail(
            extended: context.isDesktop,
            selectedIndex: _index,
            onDestinationSelected: (int i) => setState(() => _index = i),
            leading: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: BrandLogo(size: context.isDesktop ? 40 : 36, radius: 12),
            ),
            destinations: items
                .map((_NavItem e) => NavigationRailDestination(
                      icon: Icon(e.icon),
                      selectedIcon: Icon(e.active),
                      label: _navLabel(e.label, e.badge),
                    ))
                .toList(),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: body),
        ],
      );
    }

    // 手机：底部导航
    return Scaffold(
      appBar: appBar,
      body: content,
      floatingActionButton: _fab,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int i) => setState(() => _index = i),
        destinations: items
            .map((_NavItem e) => NavigationDestination(
                  icon: e.badge > 0
                      ? Badge.count(count: e.badge, child: Icon(e.icon))
                      : Icon(e.icon),
                  selectedIcon: e.badge > 0
                      ? Badge.count(count: e.badge, child: Icon(e.active))
                      : Icon(e.active),
                  label: e.label,
                ))
            .toList(),
      ),
    );
  }

  Widget _navLabel(String label, int badge) {
    if (badge <= 0) return Text(label);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: context.colors.accent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            '$badge',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.active,
    required this.label,
    this.badge = 0,
  });

  final IconData icon;
  final IconData active;
  final String label;
  final int badge;
}

/// 顶部栏的同步状态小控件
class _SyncIndicator extends StatelessWidget {
  const _SyncIndicator();

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return Consumer<SyncService>(
      builder: (BuildContext ctx, SyncService sync, _) {
        final bool running = sync.phase == SyncPhase.running;
        final Color color = sync.phase == SyncPhase.failed
            ? c.danger
            : (sync.phase == SyncPhase.offlineOnly ? c.textTertiary : c.success);
        return Container(
          margin: const EdgeInsets.only(right: AppSpacing.xs),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: c.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: c.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (running)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(c.accent),
                  ),
                )
              else
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              const SizedBox(width: 6),
              Text(
                sync.statusText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: c.textSecondary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
