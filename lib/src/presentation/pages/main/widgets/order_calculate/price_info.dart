import 'package:admin_desktop/src/core/constants/constants.dart';
import 'package:admin_desktop/src/core/constants/hive_boxes.dart';
import 'package:admin_desktop/src/core/db/hive_service.dart';
import 'package:admin_desktop/src/core/hooks/order_hooks.dart';
import 'package:admin_desktop/src/core/utils/utils.dart';
import 'package:admin_desktop/src/models/data/bag_data.dart';
import 'package:admin_desktop/src/models/data/order_body_data.dart';
import 'package:admin_desktop/src/presentation/pages/main/riverpod/notifier/main_notifier.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/order_calculate/generate_check.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/orders_table/orders/accepted/accepted_orders_provider.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/orders_table/orders/new/new_orders_provider.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/right_side/riverpod/right_side_notifier.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/right_side/riverpod/right_side_state.dart';
import 'package:admin_desktop/src/presentation/theme/app_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import 'package:admin_desktop/src/presentation/pages/main/widgets/open_drawer_dialog.dart';
import 'package:admin_desktop/src/core/di/dependency_manager.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/tables/riverpod/tables_provider.dart';

// ...existing imports...

import '../../../../components/components.dart';
// ...existing imports...

class PriceInfo extends StatelessWidget {
  final BagData bag;
  final RightSideState state;
  final RightSideNotifier notifier;
  final MainNotifier mainNotifier;
  final num calculatedTotal;
  final List<Map<String, dynamic>>? calculationData;
  final Map<String, dynamic>? groupedByCategory;

  const PriceInfo({
    super.key,
    required this.state,
    required this.notifier,
    required this.bag,
    required this.mainNotifier,
    required this.calculatedTotal,
    this.calculationData,
    this.groupedByCategory,
  });

// ADD: Method to create enhanced products from calculation data
  List<EnhancedProductOrder> createEnhancedProducts() {
    final stocks = state.paginateResponse?.stocks ?? [];

    // ── Hooks path ───────────────────────────────────────────────────────────
    if (LocalStorage.getUseOrderHooks()) {
      return OrderHooks().enhancedProduct.build(
        stocks: stocks,
        calculationData: calculationData ?? [],
        orderType: state.orderType,
      );
    }
    // ── Original path (unchanged) ────────────────────────────────────────────
    final List<EnhancedProductOrder> enhancedProducts = [];

    for (int i = 0; i < stocks.length; i++) {
      final stock = stocks[i];
      final num productPrice =
          (stock.stock?.price ?? 0) * (stock.quantity ?? 1);
      final num addonsTotal =
          (stock.addons ?? []).fold(0, (sum, e) => sum + (e.price ?? 0));
      final num originalPrice = productPrice + addonsTotal;

      // Get calculation data for this product if available
      Map<String, dynamic>? prodCalcData;
      if (calculationData != null && i < calculationData!.length) {
        prodCalcData = calculationData![i];
      }

      final String rawItemDiscountStr =
          (prodCalcData?['itemDiscountAmount'] ?? 0).toString();
      final num itemDiscountAmount = (num.tryParse(rawItemDiscountStr) ?? 0) < 0
          ? 0
          : (num.tryParse(rawItemDiscountStr) ?? 0);
      final String? itemDiscountType = prodCalcData?['itemDiscountType'];
      final num? itemDiscountPercent = prodCalcData?['itemDiscountPercent'];
      final num serviceChargeAmount = prodCalcData?['serviceChargeAmount'] ?? 0;
      final String? serviceChargeType = prodCalcData?['serviceChargeType'];
      final num serviceChargePercent = num.tryParse(
              prodCalcData?['serviceChargePercent']?.toString() ?? '0') ??
          0;
      final num taxAmount = prodCalcData?['taxAmount'] ?? 0;
      final num taxPercent =
          num.tryParse(prodCalcData?['taxPercent']?.toString() ?? '0') ?? 0;

      // Prevent discount exceeding originalPrice and ensure finalPrice >= 0
      final num clampedItemDiscount = itemDiscountAmount > originalPrice
          ? originalPrice
          : itemDiscountAmount;
      final num finalPriceRaw =
          originalPrice - clampedItemDiscount + serviceChargeAmount + taxAmount;
      final num finalPrice = finalPriceRaw < 0 ? 0 : finalPriceRaw;

      enhancedProducts.add(EnhancedProductOrder(
        stockId: stock.stock?.id ?? 0,
        countableId: stock.stock?.countableId,
        quantity: stock.quantity ?? 1,
        originalPrice: originalPrice,
        finalPrice: finalPrice,
        itemDiscountAmount: itemDiscountAmount,
        itemDiscountType: itemDiscountType,
        itemDiscountPercent: itemDiscountPercent,
        serviceChargeAmount: serviceChargeAmount,
        serviceChargeType: serviceChargeType ?? state.orderType.toLowerCase(),
        serviceChargePercent: serviceChargePercent,
        taxAmount: taxAmount,
        taxPercent: taxPercent,
        categoryName: stock.stock?.product?.category?.translation?.title,
        categoryId: stock.stock?.product?.category?.id,
        addons: (stock.addons ?? [])
            .map((addon) => EnhancedAddonOrder(
                  stockId: addon.id ?? 0,
                  countableId: addon.stockId,
                  quantity: addon.quantity ?? 1,
                  price: addon.price ?? 0,
                ))
            .toList(),
      ));
    }

    return enhancedProducts;
  }

  Future<String?> _validateAddonStock() async {
    // ── Hooks path ─────────────────────────────────────────────────────────
    if (LocalStorage.getUseOrderHooks()) {
      return OrderHooks().addonValidator.validate(
        state.paginateResponse?.stocks ?? [],
      );
    }
    // ── Original path (unchanged) ──────────────────────────────────────────
    try {
      final box = await HiveService.openBox(HiveBoxes.products);

      // 1. Aggregate requested addon quantities and collect titles from state.stocks
      final Map<int, num> requestedAddons = {};
      final Map<int, String> addonNames = {};

      final stocks = state.paginateResponse?.stocks ?? [];
      for (final s in stocks) {
        for (final addon in (s.addons ?? [])) {
          // In the model, addon.stockId is what matches countable_id in Hive for addons
          final id = addon.stockId;
          if (id != null) {
            requestedAddons[id] =
                (requestedAddons[id] ?? 0) + (addon.quantity ?? 0);
            addonNames[id] = addon.product?.translation?.title ?? 'Addon ($id)';
          }
        }
      }

      if (requestedAddons.isEmpty) return null;

      // 2. Check available stock in Hive
      final Map<int, num> availableStock = {};
      final Set<int> processedStockIds = {};

      for (final value in box.values) {
        if (value is! Map) continue;
        final productMap = Map<String, dynamic>.from(value);

        void checkStock(Map? stock) {
          if (stock == null) return;

          // Prevent double-counting the same stock entry
          final sId = _num(stock['id'])?.toInt();
          if (sId != null && !processedStockIds.add(sId)) return;

          final cId = _num(stock['countable_id'])?.toInt();
          if (cId != null && requestedAddons.containsKey(cId)) {
            availableStock[cId] =
                (availableStock[cId] ?? 0) + (_num(stock['quantity']) ?? 0);
          }

          // Recursively check for nested addons
          if (stock['addons'] is List) {
            for (final a in stock['addons']) {
              if (a is Map) {
                checkStock(a['stock'] ??
                    (a['product'] is Map ? a['product']['stock'] : null));
              }
            }
          }
        }

        checkStock(productMap['stock']);
        if (productMap['addons'] is List) {
          for (final a in productMap['addons']) {
            if (a is Map) {
              checkStock(a['stock'] ??
                  (a['product'] is Map ? a['product']['stock'] : null));
            }
          }
        }
        if (productMap['stocks'] is List) {
          for (final s in productMap['stocks']) {
            if (s is Map) checkStock(s);
          }
        }
      }

      // 3. Compare and return error if any
      final List<String> errors = [];

      // Explicitly convert to list and iterate to ensure completion before proceeding
      final List<MapEntry<int, num>> requestedEntries =
          requestedAddons.entries.toList();

      for (int i = 0; i < requestedEntries.length; i++) {
        final entry = requestedEntries[i];
        final id = entry.key;
        final requested = entry.value;
        final available = availableStock[id] ?? 0;

        if (requested > available) {
          final name = addonNames[id] ?? 'Addon ($id)';
          errors.add("$name (Request: $requested, Available: $available)");
        }
      }

      if (errors.isNotEmpty) {
        final String errorMessage =
            "Insufficient addon stock:\n${errors.join('\n')}";
        return errorMessage;
      }

      return null;
    } catch (e) {
      debugPrint('Error validating addon stock: $e');
      return null;
    }
  }

  num? _num(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v);
    return null;
  }

  /// Shows "Table has active order" confirmation dialog.
  /// Returns [true] if user chose to continue, [false]/null if cancelled.
  static Future<bool?> _showConflictDialog(
      BuildContext ctx, int conflictServerId) {
    return showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text(
          AppHelpers.getTranslation('Active Order Detected'),
          style: GoogleFonts.inter(
              fontWeight: FontWeight.w600, fontSize: 18.sp),
        ),
        content: Text(
          AppHelpers.getTranslation(
              'This table already has an active order (#$conflictServerId). '
              'Do you want to add your items to it?'),
          style: GoogleFonts.inter(fontSize: 14.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(TrKeys.cancel,
                style: GoogleFonts.inter(color: AppStyle.red)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppStyle.primary,
                foregroundColor: AppStyle.white),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(TrKeys.confirm,
                style: GoogleFonts.inter(color: AppStyle.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // subtotal/service/tax aggregation intentionally omitted here
    // (calculation is handled elsewhere; displayed total uses `calculatedTotal`)

    final num rounding = (calculatedTotal * 20).round() / 20 - calculatedTotal;
    // Apply rounding to the calculated total to get the displayed total
    final num displayedTotal = calculatedTotal + rounding;

    return Column(
      children: [
        // Row(
        //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
        //   children: [
        //     Text(
        //       AppHelpers.getTranslation(TrKeys.subtotal),
        //       style: GoogleFonts.inter(
        //         color: AppStyle.black,
        //         fontSize: 16.sp,
        //         fontWeight: FontWeight.w500,
        //         letterSpacing: -0.4,
        //       ),
        //     ),
        //     Text(
        //       AppHelpers.numberFormat(
        //         state.paginateResponse?.price ?? 0,
        //         symbol: bag.selectedCurrency?.symbol,
        //       ),
        //       style: GoogleFonts.inter(
        //         color: AppStyle.black,
        //         fontSize: 16.sp,
        //         fontWeight: FontWeight.w500,
        //         letterSpacing: -0.4,
        //       ),
        //     ),
        //   ],
        // ),
        // 12.verticalSpace,
        // Row(
        //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
        //   children: [
        //     Text(
        //       AppHelpers.getTranslation(TrKeys.tax),
        //       style: GoogleFonts.inter(
        //         color: AppStyle.black,
        //         fontSize: 16.sp,
        //         fontWeight: FontWeight.w500,
        //         letterSpacing: -0.4,
        //       ),
        //     ),
        //     Text(
        //       AppHelpers.numberFormat(
        //         state.paginateResponse?.totalTax ?? 0,
        //         symbol: bag.selectedCurrency?.symbol,
        //       ),
        //       style: GoogleFonts.inter(
        //         color: AppStyle.black,
        //         fontSize: 16.sp,
        //         fontWeight: FontWeight.w400,
        //         letterSpacing: -0.4,
        //       ),
        //     ),
        //   ],
        // ),
        // 12.verticalSpace,
        // Row(
        //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
        //   children: [
        //     Text(
        //       AppHelpers.getTranslation(TrKeys.deliveryFee),
        //       style: GoogleFonts.inter(
        //         color: AppStyle.black,
        //         fontSize: 16.sp,
        //         fontWeight: FontWeight.w500,
        //         letterSpacing: -0.4,
        //       ),
        //     ),
        //     Text(
        //       AppHelpers.numberFormat(
        //         state.paginateResponse?.deliveryFee ?? 0,
        //         symbol: bag.selectedCurrency?.symbol,
        //       ),
        //       style: GoogleFonts.inter(
        //         color: AppStyle.black,
        //         fontSize: 16.sp,
        //         fontWeight: FontWeight.w400,
        //         letterSpacing: -0.4,
        //       ),
        //     ),
        //   ],
        // ),
        // 12.verticalSpace,
        // if ((state.paginateResponse?.totalDiscount ?? 0) != 0)
        //   Column(
        //     children: [
        //       Row(
        //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
        //         children: [
        //           Text(
        //             AppHelpers.getTranslation(TrKeys.discount),
        //             style: GoogleFonts.inter(
        //               color: AppStyle.black,
        //               fontSize: 16.sp,
        //               fontWeight: FontWeight.w500,
        //               letterSpacing: -0.4,
        //             ),
        //           ),
        //           Text(
        //             "-${AppHelpers.numberFormat(state.paginateResponse?.totalDiscount ?? 0, symbol: bag.selectedCurrency?.symbol)}",
        //             style: GoogleFonts.inter(
        //               color: AppStyle.red,
        //               fontSize: 16.sp,
        //               fontWeight: FontWeight.w400,
        //               letterSpacing: -0.4,
        //             ),
        //           ),
        //         ],
        //       ),
        //       12.verticalSpace,
        //     ],
        //   ),
        state.paginateResponse?.couponPrice != 0
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppHelpers.getTranslation(TrKeys.promoCode),
                    style: GoogleFonts.inter(
                      color: AppStyle.black,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.4,
                    ),
                  ),
                  Text(
                    "-${AppHelpers.numberFormat(
                      state.paginateResponse?.couponPrice ?? 0,
                      symbol: bag.selectedCurrency?.symbol,
                    )}",
                    style: GoogleFonts.inter(
                      color: AppStyle.red,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              )
            : const SizedBox.shrink(),
        const Divider(),
        20.verticalSpace,
        // Show rounding adjustment calculated from (subtotalAfterItemDiscount + serviceCharge + tax)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Rounding Adjustment",
              style: GoogleFonts.inter(
                color: AppStyle.black,
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.4,
              ),
            ),
            Text(
              AppHelpers.numberFormat(
                rounding,
                symbol: bag.selectedCurrency?.symbol,
              ),
              style: GoogleFonts.inter(
                color: AppStyle.black,
                fontSize: 16.sp,
                fontWeight: FontWeight.w400,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
        12.verticalSpace,
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppHelpers.getTranslation(TrKeys.totalPrice),
              style: GoogleFonts.inter(
                color: AppStyle.black,
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4,
              ),
            ),
            Text(
              AppHelpers.numberFormat(
                displayedTotal,
                symbol: bag.selectedCurrency?.symbol,
              ),
              style: GoogleFonts.inter(
                color: AppStyle.black,
                fontSize: 22.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
        20.verticalSpace,
        state.calculate.isEmpty
            ? const SizedBox.shrink()
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppHelpers.getTranslation(TrKeys.refund),
                    style: GoogleFonts.inter(
                      color: AppStyle.black,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.4,
                    ),
                  ),
                  Text(
                    AppHelpers.numberFormat(
                      // refund should be based on the displayed total (with rounding)
                      displayedTotal - (double.tryParse(state.calculate) ?? 0),
                      symbol: bag.selectedCurrency?.symbol,
                    ),
                    style: GoogleFonts.inter(
                      color: AppStyle.black,
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
        32.verticalSpace,
        Consumer(
          builder: (BuildContext context, WidgetRef ref, Widget? child) {
            // Calculate bill discount from calculation data or bag-local selection
            num billDiscountAmount = 0;
            final selectedBillDiscount = bag.selectedBillDiscount;
            if (selectedBillDiscount != null && calculationData != null) {
              // Get bill discount from calculation data if available
              final billDiscountData = calculationData!.firstWhere(
                (data) => data.containsKey('billDiscountAmount'),
                orElse: () => <String, dynamic>{},
              );
              billDiscountAmount = billDiscountData['billDiscountAmount'] ?? 0;
            } else {
              // use manual input from bag/state when no dropdown selected
              final raw = (state.manualBillDiscountText).isNotEmpty
                  ? (state.manualBillDiscountText).replaceAll(',', '.').trim()
                  : '';
              // If notifier doesn't have manual text, try bag persisted value (none currently)
              final num parsed = num.tryParse(raw) ?? 0;
              billDiscountAmount = parsed;
            }

            // Check if calculation is confirmed and tempCalculate is not empty
            // determine paid amount (prefer confirmed calculate, fallback to temp input)
            final num paid = (state.calculate.isNotEmpty
                    ? double.tryParse(state.calculate)
                    : double.tryParse(state.tempCalculate)) ??
                0;
            // refund = displayedTotal - paid ; if > 0 => customer still owes money -> invalid
            final num refund = displayedTotal - paid;
            final bool isCalculationValid = state.isCalculateConfirmed &&
                state.tempCalculate.isNotEmpty &&
                !(refund > 0);

            // Show an inline warning when refund > 0 (insufficient payment)
            final Widget? insufficientNotice = (refund > 0)
                ? Padding(
                    padding: EdgeInsets.only(bottom: 12.r),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: AppStyle.red,
                          size: 18.r,
                        ),
                        8.horizontalSpace,
                        Expanded(
                          child: Text(
                            'Insufficient payable amount. Please check on the payment',
                            style: GoogleFonts.inter(
                              color: AppStyle.red,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : null;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (insufficientNotice != null) insufficientNotice,
                LoginButton(
                    isLoading: state.isOrderLoading,
                    title: AppHelpers.getTranslation(TrKeys.confirmOrder),
                    isActive: isCalculationValid && !state.isOrderLoading,
                    onPressed: (isCalculationValid && !state.isOrderLoading)
                        ? () async {
                            // Lock immediately to block double-taps during async setup.
                            notifier.setOrderLoading(true);
                            final addonStockError = await _validateAddonStock();
                            if (addonStockError != null) {
                              notifier.setOrderLoading(false);
                              if (context.mounted) {
                                AppHelpers.showSnackBar(
                                    context, addonStockError);
                              }
                              return;
                            }

                            // TABLE CASHOUT: resolve early to avoid wasting a
                            // running-number increment — doc no was already
                            // assigned at init order time.
                            final cashoutTableId = LocalStorage.getCashoutTableId();
                            String? formattedTransactionId;
                            int? cashoutExistingOrderId;

                            if (cashoutTableId != null) {
                              final tablesState = ref.read(tablesProvider);
                              cashoutExistingOrderId = tablesState.tableOrders[cashoutTableId];
                              if (cashoutExistingOrderId == null) {
                                notifier.setOrderLoading(false);
                                if (context.mounted) AppHelpers.showSnackBar(context, 'No active order for this table');
                                return;
                              }
                              // Reuse transactionId stored at init order time.
                              final orderResult = await ordersRepository.fetchOrderById(cashoutExistingOrderId);
                              orderResult.when(
                                success: (order) {
                                  final tid = order.body?.transactionId;
                                  if (tid != null && tid.isNotEmpty) formattedTransactionId = tid;
                                },
                                failure: (_, __) {},
                              );
                            } else {
                              // NORMAL ORDER: generate new doc no from running-number endpoint.
                              final int? numericShopId =
                                  LocalStorage.getUser()?.shop?.id ??
                                      LocalStorage.getUser()?.invite?.shopId;
                              final String shopid = (numericShopId ?? 0).toString();
                              String terminalId = '';
                              try {
                                final termRes = await settingsRepository.getTerminalID();
                                termRes.when(
                                  success: (id) { terminalId = id ?? ''; },
                                  failure: (err, status) { debugPrint('Failed to get terminal id: $err'); },
                                );
                              } catch (e) {
                                debugPrint('Error while getting terminal id: $e');
                              }
                              final prefix = 'POS-S$shopid-$terminalId-CSH';
                              final result = await settingsRepository.generateTransactionID(prefix);
                              result.when(
                                success: (docNo) {
                                  if (docNo != null && docNo.isNotEmpty) formattedTransactionId = docNo;
                                },
                                failure: (error, statusCode) {
                                  debugPrint('running-number request error: $error');
                                },
                              );
                              if (formattedTransactionId == null) {
                                notifier.setOrderLoading(false);
                                try {
                                  if (context.mounted) {
                                    AppHelpers.showSnackBar(context,
                                        'Failed to obtain doc no from server. Order not created.');
                                  }
                                } catch (_) {}
                                return;
                              }
                            }

                            // Attach queue number and createdAt timestamp at order creation time.
                            // Persist counter per-day in LocalStorage and reset when date changes.
                            final now = DateTime.now();
                            final today = now
                                .toIso8601String()
                                .substring(0, 10); // YYYY-MM-DD
                            final qs = LocalStorage.getQueueState();
                            int counter = (qs['counter'] as int?) ?? 0;
                            final savedDate = (qs['date'] as String?) ?? '';
                            if (savedDate != today) {
                              counter = 0; // reset for new day
                            }
                            counter++;
                            // persist new counter and date
                            await LocalStorage.setQueueState(counter, today);

                            if (!context.mounted) {
                              notifier.setOrderLoading(false);
                              return;
                            }

                            if (cashoutTableId != null) {
                              await notifier.cashoutTableOrder(
                                context: context,
                                orderId: cashoutExistingOrderId!,
                                paymentId: bag.selectedPayment?.id ?? 1,
                                paidAmount: paid,
                                billDiscountAmount: billDiscountAmount,
                                billDiscountType:
                                    bag.selectedBillDiscount?.method,
                                billDiscountPercent:
                                    bag.selectedBillDiscount?.value,
                                roundingAmount: rounding,
                                refundAmount: refund < 0 ? refund.abs() : 0,
                                transactionId: formattedTransactionId ?? '',
                                queueNo:
                                    counter.toString().padLeft(4, '0'),
                                onSuccess: (effectiveId) async {
                                  ref.read(newOrdersProvider.notifier).fetchNewOrders(isRefresh: true);
                                  ref.read(acceptedOrdersProvider.notifier).fetchAcceptedOrders(isRefresh: true);
                                  if (context.mounted && state.paginateResponse != null) {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => Dialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12.r),
                                        ),
                                        child: SizedBox(
                                          width: 380.w,
                                          child: GenerateReceiptPage(
                                            orderId: effectiveId.toString(),
                                            isKitchen: true,
                                          ),
                                        ),
                                      ),
                                    );
                                    await OpenDrawerDialog.openDrawer(context);
                                  }
                                  notifier.clearCalculate();
                                  mainNotifier.setPriceDate(null);
                                  notifier.removeSelectedTable();
                                  final tablesNotifier = ref.read(tablesProvider.notifier);
                                  // Exit ordering immediately so the table page (not
                                  // the POS/reorder view) is shown while async ops run.
                                  tablesNotifier.exitTableOrdering();
                                  await LocalStorage.setCashoutTableId(null);
                                  tablesNotifier.clearTableTimer(cashoutTableId);
                                  tablesNotifier.clearTableOrder(cashoutTableId);
                                  await LocalStorage.clearTableItems(cashoutTableId);
                                },
                              );
                              return;
                            }

                            notifier.createOrder(
                                context,
                                OrderBodyData(
                                  bagData: bag,
                                  coupon: state.coupon,
                                  note: bag.note ?? '',
                                  userId: LocalStorage.getUser()?.id,
                                  deliveryFee:
                                      state.paginateResponse?.deliveryFee,
                                  deliveryType: state.orderType,
                                  location: state.selectedAddress?.location,
                                  address: AddressModel(
                                      address: state.selectedAddress?.address),
                                  deliveryDate: intl.DateFormat("yyyy-MM-dd")
                                      .format(
                                          state.orderDate ?? DateTime.now()),
                                  deliveryTime: state.orderTime != null
                                      ? (state.orderTime?.hour
                                                  .toString()
                                                  .length ==
                                              2
                                          ? "${state.orderTime?.hour}:${state.orderTime?.minute.toString().padLeft(2, '0')}"
                                          : "0${state.orderTime?.hour}:${state.orderTime?.minute.toString().padLeft(2, '0')}")
                                      : (TimeOfDay.now()
                                                  .hour
                                                  .toString()
                                                  .length ==
                                              2
                                          ? "${TimeOfDay.now().hour}:${TimeOfDay.now().minute.toString().padLeft(2, '0')}"
                                          : "0${TimeOfDay.now().hour}:${TimeOfDay.now().minute.toString().padLeft(2, '0')}"),
                                  currencyId: state.selectedCurrency?.id,
                                  tableId: state.selectedTable?.id,
                                  phone: LocalStorage.getUser()?.phone,
                                  rate: state.selectedCurrency?.rate ?? 0,
                                  enhancedProducts: createEnhancedProducts(),
                                  billDiscountAmount: billDiscountAmount,
                                  billDiscountType:
                                      bag.selectedBillDiscount?.method,
                                  billDiscountPercent:
                                      bag.selectedBillDiscount?.value,
                                  transactionId: formattedTransactionId,
                                  roundingAmount: rounding,
                                  paidAmount: paid,
                                  refundAmount: refund,
                                  queueNo: counter.toString().padLeft(4, '0'),
                                  createdAt: now.toIso8601String(),
                                ), onSuccess: (orderId) async {
                              ref
                                  .read(newOrdersProvider.notifier)
                                  .fetchNewOrders(isRefresh: true);
                              ref
                                  .read(acceptedOrdersProvider.notifier)
                                  .fetchAcceptedOrders(isRefresh: true);

                              // Navigate directly to GenerateReceiptPage using available data
                              if (context.mounted &&
                                  state.paginateResponse != null) {
                                showDialog(
                                    context: context,
                                    builder: (context) {
                                      return Dialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12.r),
                                        ),
                                        child: SizedBox(
                                          width: 380.w,
                                          child: GenerateReceiptPage(
                                            orderId: orderId.toString(),
                                            isKitchen: true,
                                          ),
                                        ),
                                      );
                                    });
                                await OpenDrawerDialog.openDrawer(context);
                                // AppHelpers.showAlertDialog(
                                //     context: context,
                                //     child: Container(
                                //       width: 200.w,
                                //       height: 200.w,
                                //       padding: EdgeInsets.all(30.r),
                                //       decoration: BoxDecoration(
                                //           color: AppStyle.white,
                                //           borderRadius: BorderRadius.circular(10.r)),
                                //       child: Column(
                                //         children: [
                                //           Container(
                                //             decoration: const BoxDecoration(
                                //                 color: AppStyle.primary,
                                //                 shape: BoxShape.circle),
                                //             padding: EdgeInsets.all(12.r),
                                //             child: Icon(
                                //               Icons.check,
                                //               size: 56.r,
                                //               color: AppStyle.white,
                                //             ),
                                //           ),
                                //           const Spacer(),
                                //           Text(
                                //             AppHelpers.getTranslation(
                                //                 TrKeys.thankYouForOrder),
                                //             style: GoogleFonts.inter(
                                //                 fontWeight: FontWeight.w600,
                                //                 fontSize: 22.r),
                                //             textAlign: TextAlign.center,
                                //           )
                                //         ],
                                //       ),
                                //     ));

                                // clear calculation/refund after successful order
                                notifier.clearCalculate();
                                mainNotifier.setPriceDate(null);
                                notifier.removeSelectedTable();

                                // clear table timer/order if this was a table checkout
                                final int? cashoutTableId =
                                    LocalStorage.getCashoutTableId();
                                if (cashoutTableId != null) {
                                  final tablesNotifier =
                                      ref.read(tablesProvider.notifier);
                                  tablesNotifier
                                      .clearTableTimer(cashoutTableId);
                                  tablesNotifier
                                      .clearTableOrder(cashoutTableId);
                                  await LocalStorage
                                      .clearTableItems(cashoutTableId);
                                  await LocalStorage.setCashoutTableId(null);
                                  tablesNotifier.exitTableOrdering();
                                }
                              }
                            },
                            onConflict: (conflictServerId) async {
                              // 409 TABLE_HAS_ACTIVE_ORDER fired from normal
                              // order flow (dine_in with a table selected).
                              if (!context.mounted) return;
                              final tableData = state.selectedTable;
                              final tableId = tableData?.id;
                              if (tableData == null || tableId == null) return;

                              final confirmed = await _showConflictDialog(
                                  context, conflictServerId);
                              if (confirmed != true || !context.mounted) {
                                return;
                              }

                              // Add current cart items to the existing order.
                              // ignore: use_build_context_synchronously
                              await notifier.reorderDineInOrder(
                                orderId: conflictServerId,
                                enhancedProducts: createEnhancedProducts(),
                                context: context,
                              );

                              // Map table → existing server order (no timer so
                              // tables_page timerJustStarted listener stays quiet).
                              final conflictTablesNotifier =
                                  ref.read(tablesProvider.notifier);
                              conflictTablesNotifier.setTableOrderOnly(
                                  tableId, conflictServerId);

                              await LocalStorage.setCashoutTableId(tableId);

                              if (!context.mounted) return;

                              // Proceed directly to cashout with the payment
                              // values already entered by the cashier.
                              // ignore: use_build_context_synchronously
                              await notifier.cashoutTableOrder(
                                context: context,
                                orderId: conflictServerId,
                                paymentId: bag.selectedPayment?.id ?? 1,
                                paidAmount: paid,
                                billDiscountAmount: billDiscountAmount,
                                billDiscountType:
                                    bag.selectedBillDiscount?.method,
                                billDiscountPercent:
                                    bag.selectedBillDiscount?.value,
                                roundingAmount: rounding,
                                refundAmount: refund < 0 ? refund.abs() : 0,
                                transactionId: formattedTransactionId ?? '',
                                queueNo:
                                    counter.toString().padLeft(4, '0'),
                                onSuccess: (effectiveId) async {
                                  ref
                                      .read(newOrdersProvider.notifier)
                                      .fetchNewOrders(isRefresh: true);
                                  ref
                                      .read(acceptedOrdersProvider.notifier)
                                      .fetchAcceptedOrders(isRefresh: true);
                                  if (context.mounted &&
                                      state.paginateResponse != null) {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => Dialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12.r),
                                        ),
                                        child: SizedBox(
                                          width: 380.w,
                                          child: GenerateReceiptPage(
                                            orderId: effectiveId.toString(),
                                            isKitchen: true,
                                          ),
                                        ),
                                      ),
                                    );
                                    // ignore: use_build_context_synchronously
                                    await OpenDrawerDialog.openDrawer(context);
                                  }
                                  notifier.clearCalculate();
                                  mainNotifier.setPriceDate(null);
                                  notifier.removeSelectedTable();
                                  await LocalStorage.setCashoutTableId(null);
                                  conflictTablesNotifier
                                      .clearTableOrder(tableId);
                                },
                              );
                            });
                          }
                        : null),
              ],
            );
          },
        )
      ],
    );
  }
}
