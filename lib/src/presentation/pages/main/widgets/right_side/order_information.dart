import 'package:admin_desktop/src/core/constants/constants.dart';
import 'package:admin_desktop/src/core/hooks/order_hooks.dart';
import 'package:admin_desktop/src/models/response/product_calculate_response.dart';
import 'package:admin_desktop/src/core/utils/app_helpers.dart';
import 'package:admin_desktop/src/core/utils/app_validators.dart';
import 'package:admin_desktop/src/core/utils/local_storage.dart';
import 'package:admin_desktop/src/models/models.dart';
import 'package:admin_desktop/src/presentation/components/buttons/animation_button_effect.dart';
import 'package:admin_desktop/src/presentation/components/components.dart';
import 'package:admin_desktop/src/presentation/components/text_fields/custom_textformfield.dart';
import 'package:admin_desktop/src/presentation/pages/main/riverpod/provider/main_provider.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/tables/riverpod/tables_provider.dart';
import 'package:admin_desktop/src/presentation/theme/theme.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_remix/flutter_remix.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'riverpod/right_side_provider.dart';
import 'riverpod/right_side_state.dart';

class OrderInformation extends ConsumerStatefulWidget {
  final num subtotal;
  final num totalDiscount;
  final num finalTotal;

  const OrderInformation({
    super.key,
    required this.subtotal,
    required this.totalDiscount,
    required this.finalTotal,
  });

  @override
  ConsumerState<OrderInformation> createState() => _OrderInformationState();
}

class _OrderInformationState extends ConsumerState<OrderInformation> {
  List listOfType = [];
  List listDine = [TrKeys.dine];
  final formKey = GlobalKey<FormState>();
  bool _isProcessingConflict = false;

  List _buildShippingOptionsFromState(RightSideState state) {
    List<String> names = [];
    try {
      final stocks = state.paginateResponse?.stocks;
      if (stocks != null && stocks.isNotEmpty) {
        final category = stocks.first.category;
        final serviceTypes = (category == null)
            ? null
            : ((category as dynamic).serviceTypes ??
                (category as dynamic).service_types);

        if (serviceTypes is List && serviceTypes.isNotEmpty) {
          for (final st in serviceTypes) {
            if (st == null) continue;
            if (st is String) {
              names.add(st);
            } else if (st is Map) {
              names.add((st['name'] ?? '').toString());
            } else {
              try {
                names.add(((st as dynamic).name ?? '').toString());
              } catch (_) {}
            }
          }
        }
      }
    } catch (_) {}

    if (names.isEmpty) {
      names = [
        TrKeys.delivery,
        TrKeys.pickup,
        TrKeys.dine,
        TrKeys.grab,
        TrKeys.food,
      ].map((e) => e.toString()).toList();
    }

    return names.map((name) {
      final lower = name.toLowerCase();
      if (lower.contains('dine')) return TrKeys.dine;
      if (lower.contains('delivery')) return TrKeys.delivery;
      if (lower.contains('take') ||
          lower.contains('takeaway') ||
          lower.contains('take away')) {
        return TrKeys.pickup;
      }
      if (lower.contains('grab')) return TrKeys.grab;
      if (lower.contains('panda')) return TrKeys.food;
      return name;
    }).toList();
  }

  Future<bool?> _showConflictDialog(BuildContext ctx, int existingOrderId) {
    return showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text(
          AppHelpers.getTranslation('Active Order Detected'),
          style:
              GoogleFonts.inter(fontSize: 18.sp, fontWeight: FontWeight.w600),
        ),
        content: Text(
          AppHelpers.getTranslation(
              'This table already has an active order (#$existingOrderId). '
              'Do you want to add your items to it and proceed to checkout?'),
          style: GoogleFonts.inter(fontSize: 14.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(
              AppHelpers.getTranslation(TrKeys.cancel),
              style: GoogleFonts.inter(color: AppStyle.red),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppStyle.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r)),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(
              AppHelpers.getTranslation(TrKeys.confirm),
              style: GoogleFonts.inter(color: AppStyle.white),
            ),
          ),
        ],
      ),
    );
  }

  /// Reorders [state]'s cart items into [existingOrderId] on [tableId],
  /// appends them to LocalStorage, then navigates to the payment screen
  /// showing all items (previous + new).
  Future<void> _handleTableConflict({
    required BuildContext context,
    required int tableId,
    required int existingOrderId,
    required RightSideState state,
  }) async {
    if (mounted) setState(() => _isProcessingConflict = true);
    try {
      final hooks = OrderHooks();
      final stocks = state.paginateResponse?.stocks ?? [];
      final bagProds = state.bags[state.selectedBagIndex].bagProducts;

      final calcResult = await hooks.calculation.calculate(
        stocks: stocks,
        orderType: state.orderType,
        bagProducts: bagProds,
      );
      final enhancedProducts = hooks.enhancedProduct.build(
        stocks: stocks,
        calculationData: calcResult.calculationData,
        orderType: state.orderType,
      );

      if (enhancedProducts.isEmpty || !mounted) return;

      // Build display items using stockId-keyed lookup (matches page_view_item pattern).
      final calcByStockId = <int, Map<String, dynamic>>{};
      for (final entry in calcResult.calculationData) {
        if (entry.containsKey('billDiscountAmount')) continue;
        final sid = entry['stockId'];
        if (sid == null) continue;
        calcByStockId[sid is int ? sid : (sid as num).toInt()] = entry;
      }
      final displayItems = stocks.map((stock) {
        final qty = stock.quantity ?? 1;
        final unitPrice = stock.stock?.price ?? 0;
        final addonsTotal =
            (stock.addons ?? []).fold<num>(0, (s, a) => s + (a.price ?? 0));
        final total = (unitPrice * qty) + addonsTotal;
        final stockId = stock.stock?.id;
        final cd = stockId != null
            ? (calcByStockId[stockId] ?? <String, dynamic>{})
            : <String, dynamic>{};
        return <String, dynamic>{
          'stockId': stockId ?? 0,
          'countableId': stock.stock?.countableId,
          'uuid': stock.stock?.product?.uuid,
          'productName': stock.stock?.product?.translation?.title ?? '',
          'quantity': qty,
          'totalPrice': total,
          'taxAmount': cd['taxAmount'] ?? 0,
          'serviceChargeAmount': cd['serviceChargeAmount'] ?? 0,
          'taxPercent': cd['taxPercent'] ?? 0,
          'serviceChargePercent': cd['serviceChargePercent'] ?? 0,
          'serviceChargeType': cd['serviceChargeType'] ?? '',
          'categoryId': stock.stock?.product?.category?.id,
          'categoryName': stock.stock?.product?.category?.translation?.title,
          'addonNames': (stock.addons ?? [])
              .map((a) => a.product?.translation?.title ?? '')
              .where((s) => s.isNotEmpty)
              .toList(),
          'addons': (stock.addons ?? [])
              .map((a) => <String, dynamic>{
                    'stockId': a.id ?? 0,
                    'countableId': a.stockId,
                    'quantity': a.quantity ?? 1,
                    'price': a.price ?? 0,
                  })
              .toList(),
        };
      }).toList();

      // Add new items to existing server order.
      final rightNotifier = ref.read(rightSideProvider.notifier);
      final ok = await rightNotifier.reorderDineInOrder(
        orderId: existingOrderId,
        enhancedProducts: enhancedProducts,
        context: context,
      );
      if (ok == null || !mounted) return;

      // Persist combined display items (old + new).
      final existing = LocalStorage.getTableItems(tableId);
      await LocalStorage.setTableItems(tableId, [...existing, ...displayItems]);

      // Register cashout state so price_info.dart takes the table-cashout path.
      ref.read(tablesProvider.notifier).setTableOrderOnly(tableId, existingOrderId);
      await LocalStorage.setCashoutTableId(tableId);

      // Build PriceDate from ALL items for the payment screen.
      final allItems = LocalStorage.getTableItems(tableId);
      final num allTotal = allItems.fold<num>(
          0, (sum, item) => sum + ((item['totalPrice'] as num?) ?? 0));
      final builtStocks = allItems.map((item) {
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
              uuid: item['uuid'] as String?,
              translation: Translation(title: item['productName'] as String?),
            ),
          ),
          totalPrice: itemTotal,
          quantity: qty.toInt(),
        );
      }).toList();
      final allPriceDate = PriceDate(stocks: builtStocks, totalPrice: allTotal);

      if (!mounted) return;

      // Navigate to payment screen showing all order items.
      rightNotifier.updatePaginateResponse(allPriceDate);
      ref.read(mainProvider.notifier).setPriceDate(allPriceDate);

      if (mounted) context.maybePop();
    } finally {
      if (mounted) setState(() => _isProcessingConflict = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(rightSideProvider.notifier);
    final state = ref.watch(rightSideProvider);
    final BagData bag = state.bags[state.selectedBagIndex];
    final shippingOptions = _buildShippingOptionsFromState(state);
    final globalSettings = LocalStorage.getSettingsList();
    final bool hideTable = globalSettings
            .firstWhere((element) => element.key == 'hide_table',
                orElse: () => SettingsData(value: '0'))
            .value ==
        '1';

    return KeyboardDismisser(
      child: Container(
        width: MediaQuery.of(context).size.width / 2,
        padding: REdgeInsets.symmetric(horizontal: 24.r),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10.r),
          color: AppStyle.white,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    AppHelpers.getTranslation(TrKeys.order),
                    style: GoogleFonts.inter(
                        fontSize: 22.r, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(
                      onPressed: context.maybePop,
                      icon: const Icon(FlutterRemix.close_line))
                ],
              ),
              16.verticalSpace,
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (state.orderType == TrKeys.dine && !hideTable)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(
                                    color: AppStyle.unselectedBottomBarBack,
                                    width: 1.r,
                                  ),
                                ),
                                alignment: Alignment.center,
                                height: 56.r,
                                padding: EdgeInsets.only(left: 16.r),
                                child: CustomDropdown(
                                  hintText: AppHelpers.getTranslation(
                                      TrKeys.selectSection),
                                  searchHintText:
                                      AppHelpers.getTranslation(TrKeys.search),
                                  dropDownType: DropDownType.section,
                                  onChanged: (value) =>
                                      notifier.setSectionQuery(context, value),
                                  initialValue:
                                      bag.selectedSection?.translation?.title ??
                                          (state.sections.isNotEmpty
                                              ? state.sections.first.translation
                                                  ?.title
                                              : ''),
                                ),
                              ),
                              Visibility(
                                visible: state.selectSectionError != null,
                                child: Padding(
                                  padding: EdgeInsets.only(top: 6.r, left: 4.r),
                                  child: Text(
                                    AppHelpers.getTranslation(
                                        state.selectSectionError ?? ""),
                                    style: GoogleFonts.inter(
                                        color: AppStyle.red, fontSize: 14.sp),
                                  ),
                                ),
                              ),
                              24.verticalSpace,
                            ],
                          ),
                      ],
                    ),
                  ),
                  16.horizontalSpace,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (state.orderType == TrKeys.dine && !hideTable)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(
                                    color: AppStyle.unselectedBottomBarBack,
                                    width: 1.r,
                                  ),
                                ),
                                alignment: Alignment.center,
                                height: 56.r,
                                padding: EdgeInsets.only(left: 16.r),
                                child: CustomDropdown(
                                  hintText: AppHelpers.getTranslation(
                                      TrKeys.selectTable),
                                  searchHintText:
                                      AppHelpers.getTranslation(TrKeys.search),
                                  dropDownType: DropDownType.table,
                                  onChanged: (value) =>
                                      notifier.setTableQuery(context, value),
                                  initialValue: bag.selectedTable?.name ?? '',
                                ),
                              ),
                              Visibility(
                                visible: state.selectTableError != null,
                                child: Padding(
                                  padding: EdgeInsets.only(top: 6.r, left: 4.r),
                                  child: Text(
                                    AppHelpers.getTranslation(
                                        state.selectTableError ?? ""),
                                    style: GoogleFonts.inter(
                                        color: AppStyle.red, fontSize: 14.sp),
                                  ),
                                ),
                              ),
                              24.verticalSpace,
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              16.verticalSpace,
              if (AppHelpers.isNumberRequiredToOrder() &&
                  state.selectedUser != null &&
                  (state.selectedUser?.phone?.isEmpty ?? true))
                Form(
                  key: formKey,
                  child: Row(
                    children: [
                      Expanded(
                        child: CustomTextField(
                          inputType: TextInputType.phone,
                          validator: (value) {
                            return AppValidators.emptyCheck(value);
                          },
                          onChanged: (p0) {
                            notifier.setPhone(p0);
                          },
                          label: AppHelpers.getTranslation(TrKeys.phoneNumber),
                        ),
                      ),
                    ],
                  ),
                ),
              12.verticalSpace,
              const Divider(),
              12.verticalSpace,
              Text(
                AppHelpers.getTranslation(TrKeys.shippingInformation),
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600, fontSize: 22.r),
              ),
              16.verticalSpace,
              Row(
                children: [
                  ...(LocalStorage.getUser()?.role == TrKeys.waiter ||
                              LocalStorage.getUser()?.role == TrKeys.seller
                          ? shippingOptions
                          : listDine)
                      .map((e) => Expanded(
                            child: InkWell(
                              onTap: () {
                                notifier.setSelectedOrderType(e);
                                if (state.orderType.toLowerCase() !=
                                    e.toString().toLowerCase()) {
                                  ref
                                      .read(rightSideProvider.notifier)
                                      .fetchCarts(
                                          checkYourNetwork: () {
                                            AppHelpers.showSnackBar(
                                              context,
                                              AppHelpers.getTranslation(TrKeys
                                                  .checkYourNetworkConnection),
                                            );
                                          },
                                          isNotLoading: true);
                                }
                              },
                              child: AnimationButtonEffect(
                                child: Container(
                                  margin: EdgeInsets.symmetric(horizontal: 4.r),
                                  decoration: BoxDecoration(
                                    color: state.orderType.toLowerCase() ==
                                            e.toString().toLowerCase()
                                        ? AppStyle.primary
                                        : AppStyle.editProfileCircle,
                                    borderRadius: BorderRadius.circular(6.r),
                                  ),
                                  padding: EdgeInsets.symmetric(vertical: 8.r),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            color: AppStyle.transparent,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: AppStyle.black),
                                          ),
                                          padding: EdgeInsets.all(6.r),
                                          child: e == TrKeys.delivery
                                              ? Icon(
                                                  FlutterRemix.takeaway_fill,
                                                  size: 18.sp,
                                                )
                                              : e == TrKeys.pickup
                                                  ? SvgPicture.asset(
                                                      "assets/svg/pickup.svg")
                                                  : e == TrKeys.dine
                                                      ? SvgPicture.asset(
                                                          "assets/svg/dine.svg")
                                                      : (e == TrKeys.grab ||
                                                              e == TrKeys.food)
                                                          ? Icon(
                                                              FlutterRemix
                                                                  .e_bike_2_fill,
                                                              size: 18.sp)
                                                          : const SizedBox
                                                              .shrink(),
                                        ),
                                        4.verticalSpace,
                                        Text(
                                          AppHelpers.getTranslation(e),
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.inter(
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.w600),
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )),
                ],
              ),
              12.verticalSpace,
              const Divider(),
              24.verticalSpace,
              _priceInformation(
                state: state,
                bag: bag,
                context: context,
                subtotal: widget.subtotal,
                totalDiscount: widget.totalDiscount,
              ),
              20.verticalSpace,
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 186.w,
                    child: LoginButton(
                        isLoading: _isProcessingConflict,
                        isActive: !_isProcessingConflict,
                        title: AppHelpers.getTranslation(TrKeys.placeOrder),
                        onPressed: _isProcessingConflict
                            ? null
                            : () async {
                                if (AppHelpers.isNumberRequiredToOrder() &&
                                    state.selectedUser?.phone == null &&
                                    state.selectedUser != null) {
                                  if (!(formKey.currentState?.validate() ??
                                      false)) {
                                    return;
                                  }
                                }

                                // Proactive frontend conflict check: detect active order
                                // on selected table before calling createOrder, so the
                                // cashier is warned at "Place Order" time rather than
                                // after entering payment details and hitting a 409.
                                if (state.orderType == TrKeys.dine) {
                                  final tableId = bag.selectedTable?.id;
                                  if (tableId != null) {
                                    // Hydrate tableOrders from Hive — the in-memory
                                    // map may be empty if the tables page hasn't been
                                    // visited yet in this session.
                                    await ref
                                        .read(tablesProvider.notifier)
                                        .loadTableStatuses();
                                    if (!mounted) return;
                                    final existingOrderId = ref
                                        .read(tablesProvider)
                                        .tableOrders[tableId];
                                    if (existingOrderId != null) {
                                      if (!context.mounted) return;
                                      final confirmed =
                                          await _showConflictDialog(
                                              context, existingOrderId);
                                      if (confirmed != true || !mounted) return;
                                      // ignore: use_build_context_synchronously
                                      await _handleTableConflict(
                                        context: context,
                                        tableId: tableId,
                                        existingOrderId: existingOrderId,
                                        state: state,
                                      );
                                      return;
                                    }
                                  }
                                }

                                // No conflict — proceed with normal order flow.
                                notifier.placeOrder(
                                  checkYourNetwork: () {
                                    AppHelpers.showSnackBar(
                                      context,
                                      AppHelpers.getTranslation(
                                          TrKeys.checkYourNetworkConnection),
                                    );
                                  },
                                  openSelectDeliveriesDrawer: () {
                                    final updatedResponse =
                                        state.paginateResponse?.copyWith(
                                      totalPrice: widget.finalTotal,
                                      totalDiscount: widget.totalDiscount,
                                    );
                                    notifier.updatePaginateResponse(
                                        updatedResponse);
                                    ref
                                        .read(mainProvider.notifier)
                                        .setPriceDate(updatedResponse);
                                    context.maybePop();
                                  },
                                );
                              }),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppHelpers.getTranslation(TrKeys.totalPrice),
                        style: GoogleFonts.inter(
                          color: AppStyle.black,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.4,
                        ),
                      ),
                      Text(
                        AppHelpers.numberFormat(
                          widget.finalTotal,
                          symbol: bag.selectedCurrency?.symbol,
                        ),
                        style: GoogleFonts.inter(
                          color: AppStyle.black,
                          fontSize: 30.sp,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _priceInformation({
    required RightSideState state,
    required BagData bag,
    required BuildContext context,
    required num subtotal,
    required num totalDiscount,
  }) {
    return Column(
      children: [
        _priceItem(
          title: TrKeys.subtotal,
          price: subtotal,
          symbol: bag.selectedCurrency?.symbol,
        ),
        _priceItem(
          title: TrKeys.tax,
          price: state.paginateResponse?.totalTax,
          symbol: bag.selectedCurrency?.symbol,
        ),
        _priceItem(
          title: TrKeys.serviceFee,
          price: state.paginateResponse?.serviceFee,
          symbol: bag.selectedCurrency?.symbol,
        ),
        _priceItem(
          title: TrKeys.deliveryFee,
          price: state.paginateResponse?.deliveryFee,
          symbol: bag.selectedCurrency?.symbol,
        ),
        _priceItem(
          title: TrKeys.discount,
          price: totalDiscount,
          symbol: bag.selectedCurrency?.symbol,
          isDiscount: true,
        ),
        _priceItem(
          title: TrKeys.promoCode,
          price: state.paginateResponse?.couponPrice,
          symbol: bag.selectedCurrency?.symbol,
          isDiscount: true,
        ),
        const Divider(),
      ],
    );
  }

  Widget _priceItem({
    required String title,
    required num? price,
    required String? symbol,
    bool isDiscount = false,
  }) {
    return (price ?? 0) != 0
        ? Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppHelpers.getTranslation(title),
                    style: GoogleFonts.inter(
                      color: isDiscount ? AppStyle.red : AppStyle.black,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.4,
                    ),
                  ),
                  Text(
                    (isDiscount ? "-" : '') +
                        AppHelpers.numberFormat(price, symbol: symbol),
                    style: GoogleFonts.inter(
                      color: isDiscount ? AppStyle.red : AppStyle.black,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
              12.verticalSpace,
            ],
          )
        : const SizedBox.shrink();
  }
}
