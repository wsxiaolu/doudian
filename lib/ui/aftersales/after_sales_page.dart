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
import '../../data/models/after_sale.dart';
import 'after_sale_edit_page.dart';

/// ============================================================================
/// 售后单列表
///
/// 顶部搜索 + 进度筛选 + 类型筛选；卡片展示订单号、类型、进度、退款金额、
/// 商品与买家。点击进入登记 / 跟进页。抖店同步下来的售后单也在这里统一管理。
/// ============================================================================
class AfterSalesPage extends StatelessWidget {
  const AfterSalesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final DataProvider data = context.watch<DataProvider>();
    final List<AfterSale> list = data.visibleAfterSales;

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
              hint: '搜索订单号 / 售后单号 / 买家 / 商品 / 原因',
              onChanged: data.setAfterSaleKeyword,
            ),
            const SizedBox(height: AppSpacing.md),

            // 进度筛选
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  FilterChipButton(
                    label: '全部',
                    selected: data.afterSaleStageFilter.isEmpty,
                    onTap: () {
                      // 清空进度筛选：逐个移除
                      for (final AfterSaleStage s
                          in List<AfterSaleStage>.from(data.afterSaleStageFilter)) {
                        data.toggleAfterSaleStage(s);
                      }
                    },
                  ),
                  for (final AfterSaleStage s in AfterSaleStageX.values)
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.xs),
                      child: FilterChipButton(
                        label: s.label,
                        count: data.afterSaleStageCounts[s] ?? 0,
                        selected: data.afterSaleStageFilter.contains(s),
                        color: AfterSaleStageChip.colorOf(context, s),
                        onTap: () => data.toggleAfterSaleStage(s),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // 类型筛选
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  for (final AfterSaleType ty in AfterSaleTypeX.values)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: FilterChipButton(
                        label: ty.label,
                        selected: data.afterSaleTypeFilter.contains(ty),
                        onTap: () => data.toggleAfterSaleType(ty),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            if (list.isEmpty)
              EmptyState(
                icon: Icons.assignment_return_outlined,
                title: '没有匹配的售后单',
                message: data.afterSaleKeyword.isNotEmpty ||
                        data.afterSaleStageFilter.isNotEmpty
                    ? '试试调整搜索或筛选条件'
                    : '抖店售后会自动同步，也可以登记线下售后',
                actionLabel: data.afterSaleKeyword.isEmpty &&
                        data.afterSaleStageFilter.isEmpty
                    ? '登记售后'
                    : null,
                onAction: data.afterSaleKeyword.isEmpty &&
                        data.afterSaleStageFilter.isEmpty
                    ? () => Navigator.of(context).push(
                          MaterialPageRoute<dynamic>(
                            builder: (_) => const AfterSaleEditPage(),
                          ),
                        )
                    : null,
              )
            else
              _AfterSaleGrid(items: list),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

/// 售后卡片网格（响应式列数）
class _AfterSaleGrid extends StatelessWidget {
  const _AfterSaleGrid({required this.items});

  final List<AfterSale> items;

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
            for (final AfterSale a in items)
              SizedBox(width: w, child: _AfterSaleCard(item: a)),
          ],
        );
      },
    );
  }
}

/// 售后卡片
class _AfterSaleCard extends StatelessWidget {
  const _AfterSaleCard({required this.item});

  final AfterSale item;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme t = Theme.of(context).textTheme;
    final AfterSale a = item;

    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<dynamic>(builder: (_) => AfterSaleEditPage(afterSale: a)),
      ),
      accentBarColor: AfterSaleStageChip.colorOf(context, a.stage),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  a.orderNo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              AfterSaleStageChip(stage: a.stage, compact: true),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              SoftTag(text: a.type.label),
              if (a.refundAmount > 0) ...<Widget>[
                const SizedBox(width: AppSpacing.xs),
                SoftTag(
                  text: '退款 ${Fmt.money(a.refundAmount)}',
                  color: c.danger,
                ),
              ],
            ],
          ),
          if ((a.productSummary ?? '').trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              a.productSummary!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.bodySmall,
            ),
          ],
          if ((a.buyerNick ?? '').trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              a.buyerNick!,
              style: t.labelSmall?.copyWith(color: c.textSecondary),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            '申请 ${Fmt.date(a.applyTime)}',
            style: t.labelSmall?.copyWith(color: c.textTertiary),
          ),
        ],
      ),
    );
  }
}
