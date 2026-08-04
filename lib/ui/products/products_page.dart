import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/app_card.dart';
import '../common/empty_state.dart';
import '../../core/widgets/app_search_field.dart';
import '../../core/widgets/app_icon_button.dart';
import '../../core/widgets/status_chip.dart';
import '../../state/data_provider.dart';
import '../../data/models/product.dart';
import 'product_edit_page.dart';

/// ============================================================================
/// 商品档案列表
///
/// 顶部搜索 + 分类筛选 + 「仅看上架」开关；卡片网格展示售价、成本、毛利、
/// 库存与上下架状态，点开关即可上下架，点编辑图标进入编辑页。
/// ============================================================================
class ProductsPage extends StatelessWidget {
  const ProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme t = Theme.of(context).textTheme;
    final DataProvider data = context.watch<DataProvider>();
    final List<Product> products = data.visibleProducts;

    // 从全部商品派生分类，保证筛选项完整
    final Set<String> categories = <String>{};
    for (final Product p in data.products) {
      final String cat = (p.category ?? '').trim();
      if (cat.isNotEmpty) categories.add(cat);
    }

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
              hint: '搜索商品名 / 规格 / 编码 / 分类',
              onChanged: data.setProductKeyword,
            ),
            const SizedBox(height: AppSpacing.md),

            // 分类筛选
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  FilterChipButton(
                    label: '全部',
                    selected: data.productCategory == null,
                    onTap: () => data.setProductCategory(null),
                  ),
                  for (final String cat in categories)
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.xs),
                      child: FilterChipButton(
                        label: cat,
                        selected: data.productCategory == cat,
                        onTap: () => data.setProductCategory(cat),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // 仅看上架
            Row(
              children: <Widget>[
                Text('仅看上架', style: t.bodyMedium),
                const Spacer(),
                Switch(
                  value: data.productOnlyActive,
                  activeColor: c.success,
                  onChanged: (bool v) => data.setProductOnlyActive(v),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${products.length} 件',
                  style: t.labelMedium?.copyWith(color: c.textTertiary),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            if (products.isEmpty)
              EmptyState(
                icon: Icons.inventory_2_outlined,
                title: '没有匹配的商品',
                message: data.productKeyword.isNotEmpty ||
                        data.productCategory != null
                    ? '试试调整搜索或筛选条件'
                    : '去添加一个商品，建单时可以直接带出价格',
                actionLabel: data.productKeyword.isEmpty &&
                        data.productCategory == null
                    ? '添加商品'
                    : null,
                onAction: data.productKeyword.isEmpty &&
                        data.productCategory == null
                    ? () => Navigator.of(context).push(
                          MaterialPageRoute<dynamic>(
                            builder: (_) => const ProductEditPage(),
                          ),
                        )
                    : null,
              )
            else
              _ProductGrid(products: products),

            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

/// 商品卡片网格（响应式列数）
class _ProductGrid extends StatelessWidget {
  const _ProductGrid({required this.products});

  final List<Product> products;

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
            for (final Product p in products)
              SizedBox(width: w, child: _ProductCard(product: p)),
          ],
        );
      },
    );
  }
}

/// 商品卡片
class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final TextTheme t = Theme.of(context).textTheme;
    final Product p = product;
    final double? rate = p.profitRate;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              AppIconButton(
                icon: Icons.edit_outlined,
                size: 32,
                iconSize: 16,
                tooltip: '编辑',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<dynamic>(
                    builder: (_) => ProductEditPage(product: p),
                  ),
                ),
              ),
            ],
          ),
          if ((p.spec ?? '').trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 2),
            Text(p.spec!, style: t.labelSmall?.copyWith(color: c.textSecondary)),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('售价', style: t.labelSmall?.copyWith(color: c.textTertiary)),
                    const SizedBox(height: 2),
                    Text(
                      Fmt.money(p.salePrice),
                      style: t.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: c.accent,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('成本', style: t.labelSmall?.copyWith(color: c.textTertiary)),
                    const SizedBox(height: 2),
                    Text(Fmt.money(p.costPrice), style: t.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: <Widget>[
              if (rate != null)
                SoftTag(
                  text: '毛利率 ${(rate * 100).toStringAsFixed(0)}%',
                  color: rate >= 0 ? c.success : c.danger,
                )
              else
                const SoftTag(text: '未设成本', color: null),
              const SizedBox(width: AppSpacing.xs),
              SoftTag(text: '库存 ${p.stock}'),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  p.isActive ? '已上架' : '已下架',
                  style: t.bodySmall?.copyWith(
                    color: p.isActive ? c.success : c.textTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Switch(
                value: p.isActive,
                activeColor: c.success,
                onChanged: (_) =>
                    context.read<DataProvider>().toggleProductActive(p),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
