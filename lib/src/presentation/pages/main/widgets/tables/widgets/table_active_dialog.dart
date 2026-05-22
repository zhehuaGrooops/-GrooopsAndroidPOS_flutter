import 'package:admin_desktop/src/core/di/dependency_manager.dart';
import 'package:admin_desktop/src/core/utils/local_storage.dart';
import 'package:admin_desktop/src/models/response/product_calculate_response.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../../core/constants/constants.dart';
import '../../../../../../core/utils/app_helpers.dart';
import '../../../../../../models/models.dart';
import '../../../../../theme/theme.dart';
import '../../../riverpod/provider/main_provider.dart';
import '../../right_side/riverpod/right_side_provider.dart';
import '../riverpod/tables_provider.dart';
import 'manager_pin_dialog.dart';
import 'table_timer_display.dart';

class TableActiveDialog extends ConsumerStatefulWidget {
  final int tableId;
  final String tableName;

  const TableActiveDialog({
    super.key,
    required this.tableId,
    required this.tableName,
  });

  @override
  ConsumerState<TableActiveDialog> createState() => _TableActiveDialogState();
}

class _TableActiveDialogState extends ConsumerState<TableActiveDialog> {
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  void _loadItems() {
    setState(() {
      _items = LocalStorage.getTableItems(widget.tableId);
    });
  }

  num get _total => _items.fold<num>(
      0, (sum, item) => sum + ((item['totalPrice'] as num?) ?? 0));

  void _cancelItem(int index) {
    final tablesNotifier = ref.read(tablesProvider.notifier);
    final tablesState = ref.read(tablesProvider);
    Navigator.pop(context);
    AppHelpers.showAlertDialog(
      context: context,
      child: ManagerPinDialog(
        onVerified: () async {
          final updated = List<Map<String, dynamic>>.from(_items)
            ..removeAt(index);
          await LocalStorage.setTableItems(widget.tableId, updated);
          if (updated.isEmpty) {
            final orderId = tablesState.tableOrders[widget.tableId];
            if (orderId != null) {
              await ordersRepository.setOrderVoided(orderId: orderId);
            }
            tablesNotifier.clearTableTimer(widget.tableId);
            tablesNotifier.clearTableOrder(widget.tableId);
            await LocalStorage.clearTableItems(widget.tableId);
            return;
          }
          if (!mounted) return;
          // ignore: use_build_context_synchronously
          AppHelpers.showAlertDialog(
            context: context,
            child: TableActiveDialog(
              tableId: widget.tableId,
              tableName: widget.tableName,
            ),
          );
        },
      ),
    );
  }

  void _addMoreItems() {
    final tableData = ref
        .read(tablesProvider)
        .tableListData
        .firstWhere((t) => t?.id == widget.tableId, orElse: () => null);
    if (tableData == null) return;
    final tablesNotifier = ref.read(tablesProvider.notifier);
    final rightNotifier = ref.read(rightSideProvider.notifier);
    final mainNotifier = ref.read(mainProvider.notifier);

    Navigator.pop(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      rightNotifier.presetTableContext(tableData,
          section: tableData.shopSection);
      mainNotifier.setPriceDate(null);
      tablesNotifier.enterTableOrdering(tableData);
    });
  }

  void _checkout() {
    if (_items.isEmpty) return;

    final tableData = ref
        .read(tablesProvider)
        .tableListData
        .firstWhere((t) => t?.id == widget.tableId, orElse: () => null);
    if (tableData == null) return;

    final tablesNotifier = ref.read(tablesProvider.notifier);
    final rightNotifier = ref.read(rightSideProvider.notifier);
    final mainNotifier = ref.read(mainProvider.notifier);

    final builtStocks = _items.map((item) {
      final num qty = (item['quantity'] as num?) ?? 1;
      final num itemTotal = (item['totalPrice'] as num?) ?? 0;
      final num unitPrice = qty > 0 ? itemTotal / qty : itemTotal;
      return ProductData(
        stock: Stocks(
          id: item['stockId'] as int?,
          countableId: item['countableId'] as int?,
          price: unitPrice,
          totalPrice: itemTotal,
          quantity: qty.toInt(),
          product: ProductData(
            translation: Translation(title: item['productName'] as String?),
          ),
        ),
        totalPrice: itemTotal,
        quantity: qty.toInt(),
      );
    }).toList();
    final priceDate = PriceDate(
      stocks: builtStocks,
      totalPrice: _total,
    );

    LocalStorage.setCashoutTableId(widget.tableId);

    Navigator.pop(context);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      rightNotifier.presetTableContext(tableData,
          section: tableData.shopSection);
      rightNotifier.updatePaginateResponse(priceDate);
      mainNotifier.setPriceDate(priceDate);
      tablesNotifier.enterTableOrdering(tableData);
    });
  }

  @override
  Widget build(BuildContext context) {
    final startDate = ref.watch(tablesProvider).tableTimers[widget.tableId];
    final symbol = ref.watch(rightSideProvider).selectedCurrency?.symbol;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.tableName,
                  style: GoogleFonts.inter(
                    color: AppStyle.black,
                    fontWeight: FontWeight.w700,
                    fontSize: 18.sp,
                  ),
                ),
                4.verticalSpace,
                TableTimerDisplay(startDate: startDate),
              ],
            ),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Icon(Icons.close, color: AppStyle.black, size: 24.r),
            ),
          ],
        ),
        16.verticalSpace,
        if (_items.isEmpty)
          Padding(
            padding: REdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                AppHelpers.getTranslation(TrKeys.emptyOrders),
                style:
                    GoogleFonts.inter(color: AppStyle.hint, fontSize: 14.sp),
              ),
            ),
          )
        else
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _items.asMap().entries.map((entry) {
                  return _ItemCard(
                    item: entry.value,
                    symbol: symbol,
                    onCancel: () => _cancelItem(entry.key),
                  );
                }).toList(),
              ),
            ),
          ),
        if (_items.isNotEmpty) ...[
          12.verticalSpace,
          const Divider(color: AppStyle.hint, height: 1),
          12.verticalSpace,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppHelpers.getTranslation(TrKeys.totalPrice),
                style: GoogleFonts.inter(
                  color: AppStyle.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 15.sp,
                ),
              ),
              Text(
                AppHelpers.numberFormat(_total, symbol: symbol),
                style: GoogleFonts.inter(
                  color: AppStyle.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 16.sp,
                ),
              ),
            ],
          ),
        ],
        16.verticalSpace,
        const Divider(color: AppStyle.hint, height: 1),
        12.verticalSpace,
        Row(
          children: [
            Expanded(
              child: _BottomButton(
                label: 'Reorder',
                icon: Icons.add_circle_outline,
                color: AppStyle.primary,
                onTap: _addMoreItems,
              ),
            ),
            12.horizontalSpace,
            Expanded(
              child: _BottomButton(
                label: AppHelpers.getTranslation(TrKeys.checkout),
                icon: Icons.payment_outlined,
                color: AppStyle.textGrey,
                onTap: _items.isNotEmpty ? _checkout : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String? symbol;
  final VoidCallback onCancel;

  const _ItemCard({
    required this.item,
    required this.symbol,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final name = (item['productName'] as String?)?.isNotEmpty == true
        ? item['productName'] as String
        : (item['categoryName'] as String? ?? 'Item');
    final qty = (item['quantity'] as num?)?.toInt() ?? 1;
    final num price = (item['totalPrice'] as num?) ?? 0;
    final addonNames = List<String>.from(item['addonNames'] as List? ?? []);

    return Container(
      margin: REdgeInsets.only(bottom: 8),
      padding: REdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppStyle.white,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: AppStyle.hint.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30.r,
            height: 30.r,
            decoration: BoxDecoration(
              color: AppStyle.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Center(
              child: Text(
                'x$qty',
                style: GoogleFonts.inter(
                  color: AppStyle.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11.sp,
                ),
              ),
            ),
          ),
          10.horizontalSpace,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    color: AppStyle.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.sp,
                  ),
                ),
                if (addonNames.isNotEmpty) ...[
                  3.verticalSpace,
                  Text(
                    addonNames.join(', '),
                    style: GoogleFonts.inter(
                      color: AppStyle.reviewText,
                      fontSize: 11.sp,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            AppHelpers.numberFormat(price, symbol: symbol),
            style: GoogleFonts.inter(
              color: AppStyle.black,
              fontWeight: FontWeight.w600,
              fontSize: 13.sp,
            ),
          ),
          8.horizontalSpace,
          GestureDetector(
            onTap: onCancel,
            child:
                Icon(Icons.cancel_outlined, color: AppStyle.red, size: 20.r),
          ),
        ],
      ),
    );
  }
}

class _BottomButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _BottomButton({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: REdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: active
              ? color.withValues(alpha: 0.08)
              : AppStyle.hint.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: active ? color : AppStyle.hint,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: active ? color : AppStyle.hint, size: 18.r),
            6.horizontalSpace,
            Text(
              label,
              style: GoogleFonts.inter(
                color: active ? color : AppStyle.hint,
                fontWeight: FontWeight.w600,
                fontSize: 13.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
