import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/app_card.dart';
import '../common/empty_state.dart';
import '../../core/widgets/app_search_field.dart';
import '../../core/widgets/status_chip.dart';
import '../../state/data_provider.dart';
import '../../data/models/customer.dart';
import '../../data/models/order_status.dart';
import 'customer_edit_page.dart';

/// ============================================================================
/// 客户（买家）档案列表
///
/// 顶部搜索（昵称 / 收件人 / 电话 / 地址）；卡片网格展示客户概览与历史订单数，
/// 点击卡片进入编辑页。抖店同步下来的买家会自动归档为独立客户。
/// ============================================================================
class CustomersPage extends StatelessWidget {
  const CustomersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final DataProvider data = context.watch<DataProvider>();
    final List<Customer> customers = data.visibleCustomers;

    return Scaffold(
      backgroundColor: c.background,
      body: RefreshIndicator(
        onRefresh: () => data.refresh(),
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: context.pagePadding,
            vertical: AppSpacing.md,
          ),
          children: <Widget>[
            AppSearchField(
              hint: '搜索昵称 / 收件人 / 电话 / 地址',
              onChanged: data.setCustomerKeyword,
            ),
            const SizedBox(height: AppSpacing.md),
            if (customers.isEmpty)
              EmptyState(
                icon: Icons.people_alt_outlined,
                title: '没有匹配的客户',
                message: data.customerKeyword.isNotEmpty
                    ? '试试调整搜索条件'
                    : '抖店订单会自动归档买家，也可以手动新建客户',
                actionLabel:
                    data.customerKeyword.isEmpty ? '新建客户' : null,
                onAction: data.customerKeyword.isEmpty
                    ? () => Navigator.of(context).push(
                          MaterialPageRoute<dynamic>(
                            builder: (_) => const CustomerEditPage(),
                          ),
                        )
                    : null,
              )
            else
              _CustomerGrid(customers: customers),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

/// 客户卡片网格（响应式列数）
class _CustomerGrid extends StatelessWidget {
  const _CustomerGrid({required this.customers});

  final List<Customer> customers;

  @override
  Widget build(BuildContext context) {
    final int cols = context.listColumns;
    final double spacing = AppSpacing.sm;
    return LayoutBuilder(
      builder: (BuildContext ctx, BoxConstraints constraints) {
        final double w =
            (constraints.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: <Widget>[
            for (final Customer cu in customers)
              SizedBox(width: w, child: _CustomerCard(customer: cu)),
          ],
        );
      },
    );
  }
}

/// 客户卡片
class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme t = Theme.of(context).textTheme;
    final Customer cu = customer;
    final int orderCount =
        context.read<DataProvider>().ordersOfCustomer(cu.id).length;

    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<dynamic>(
          builder: (_) => CustomerEditPage(customer: cu),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: 18,
                backgroundColor: c.primarySoft,
                child: Text(
                  Fmt.initial(cu.displayName),
                  style: TextStyle(
                    color: c.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  cu.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              cu.source == OrderSource.douyin
                  ? const SoftTag(text: '抖店', icon: Icons.cloud_rounded)
                  : const SoftTag(text: '手动', icon: Icons.edit_rounded),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (cu.phone != null && cu.phone!.isNotEmpty) ...<Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.phone_rounded, size: 14, color: c.textTertiary),
                const SizedBox(width: 6),
                Text(Fmt.maskPhone(cu.phone), style: t.bodySmall),
              ],
            ),
            const SizedBox(height: 4),
          ],
          if (cu.address != null && cu.address!.trim().isNotEmpty) ...<Widget>[
            Text(
              cu.address!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.bodySmall?.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: 4),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            '$orderCount 笔订单',
            style: t.labelSmall?.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}
