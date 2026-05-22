import 'package:admin_desktop/src/core/constants/constants.dart';
import 'package:admin_desktop/src/core/di/injection.dart';
import 'package:admin_desktop/src/core/handlers/api_result.dart';
import 'package:admin_desktop/src/core/utils/utils.dart';
import 'package:admin_desktop/src/models/data/addons_data.dart';
import 'package:admin_desktop/src/models/data/bag_data.dart';
import 'package:admin_desktop/src/models/data/product_data.dart';
import 'package:admin_desktop/src/presentation/components/buttons/animation_button_effect.dart';
import 'package:admin_desktop/src/presentation/components/common_image.dart';
import 'package:admin_desktop/src/presentation/pages/main/riverpod/notifier/main_notifier.dart';
import 'package:admin_desktop/src/presentation/pages/main/riverpod/provider/main_provider.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/right_side/riverpod/right_side_notifier.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/right_side/riverpod/right_side_state.dart';
import 'package:admin_desktop/src/presentation/theme/app_style.dart';
import 'package:admin_desktop/src/repository/products_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_remix/flutter_remix.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/order_calculate/price_info.dart';

import '../../../../../models/models.dart';
import '../right_side/riverpod/right_side_provider.dart';

final productsRepositoryProvider = Provider<ProductsRepository>((ref) {
  return inject<ProductsRepository>();
});

class OrderCalculate extends ConsumerStatefulWidget {
  const OrderCalculate({super.key});

  @override
  ConsumerState<OrderCalculate> createState() => _OrderCalculateState();
}

class _OrderCalculateState extends ConsumerState<OrderCalculate> {
  Future<List<ApiResult<Map<String, dynamic>>>>? _cachedFuture;
  String _lastStocksCacheKey = '';

  @override
  void initState() {
    super.initState();
    // Initialize calculator to "0" when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rightNotifier = ref.read(rightSideProvider.notifier);
      rightNotifier.clearTempCalculate(); // Clear any existing value
    });
  }

  void onTriggerDnqr() {
    final rightNotifier = ref.read(rightSideProvider.notifier);

  }

  void onMethodTap(PaymentData paymentMethod) {
    final rightNotifier = ref.read(rightSideProvider.notifier);
    rightNotifier.setSelectedPayment(paymentMethod.id);
    if (paymentMethod.tag == "rhb_dnqr") {
      AppHelpers.showSnackBar(context, "Using DuitNow QR");
      onTriggerDnqr();
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(mainProvider.notifier);
    final rightNotifier = ref.read(rightSideProvider.notifier);
    final stateRight = ref.watch(rightSideProvider);
    return Scaffold(
      backgroundColor: AppStyle.mainBack,
      body: Padding(
        padding: EdgeInsets.all(16.r),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _informationWidget(ref, notifier, rightNotifier, stateRight),
            16.horizontalSpace,
            _calculator(stateRight, rightNotifier)
          ],
        ),
      ),
    );
  }

  int _findBagProductIndex(
      List<BagProductData>? bagProducts, ProductData? prod) {
    if (bagProducts == null || prod == null) return -1;
    final rightIds = <dynamic>[
      prod.id,
      prod.stock?.id,
      prod.stock?.countableId,
      prod.uuid,
      prod.stock?.product?.uuid
    ];
    for (int i = 0; i < bagProducts.length; i++) {
      final bp = bagProducts[i];
      final leftIds = <dynamic>[bp.stockId, bp.parentId];
      for (final l in leftIds) {
        if (l == null) continue;
        for (final r in rightIds) {
          if (r == null) continue;
          if (l.toString() == r.toString()) return i;
        }
      }
    }
    return -1;
  }

  Widget _buildPriceRow(String title, String value, {bool isDiscount = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.r),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w500,
              fontSize: 14.sp,
              color: isDiscount ? AppStyle.red : AppStyle.black,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w500,
              fontSize: 14.sp,
              color: isDiscount ? AppStyle.red : AppStyle.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _informationWidget(WidgetRef ref, MainNotifier notifier,
      RightSideNotifier rightSideNotifier, RightSideState stateRight) {
    final stocks = stateRight.paginateResponse?.stocks ?? [];

    // Create cache key based on stocks (not tempCalculate)
    final stocksCacheKey =
        stocks.map((s) => '${s.stock?.id}_${s.quantity}').join('|');

    // Only recreate future if stocks actually changed
    if (_cachedFuture == null || _lastStocksCacheKey != stocksCacheKey) {
      final List<Future<ApiResult<Map<String, dynamic>>>> futures = [];
      if (stocks.isNotEmpty) {
        final productRepo = ref.read(productsRepositoryProvider);
        for (final stock in stocks) {
          final uuid = stock.stock?.product?.uuid;
          if (uuid != null) {
            futures.add(productRepo.getProductByUuid(uuid));
          } else {
            futures.add(Future.value(
                const ApiResult.failure(error: 'no_uuid')));
          }
        }
      }
      _cachedFuture = Future.wait(futures);
      _lastStocksCacheKey = stocksCacheKey;
    }

    return Expanded(
      child: SingleChildScrollView(
        child: Column(
          children: [
            Row(
              children: [
                InkWell(
                  onTap: () {
                    notifier.setPriceDate(null);
                    rightSideNotifier.clearCalculate();
                  },
                  child: Row(
                    children: [
                      Icon(
                        FlutterRemix.arrow_left_s_line,
                        size: 32.r,
                      ),
                      Text(
                        AppHelpers.getTranslation(TrKeys.back),
                        style: GoogleFonts.inter(
                          fontSize: 16.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            16.verticalSpace,
            Container(
              padding: EdgeInsets.symmetric(vertical: 20.r, horizontal: 16.r),
              decoration: BoxDecoration(
                  color: AppStyle.white,
                  borderRadius: BorderRadius.circular(10.r)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppHelpers.getTranslation(TrKeys.order),
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600, fontSize: 22.sp),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${stateRight.bags[stateRight.selectedBagIndex].selectedUser?.firstname ?? ""} ${stateRight.bags[stateRight.selectedBagIndex].selectedUser?.lastname ?? ""}",
                        style: GoogleFonts.inter(
                            fontSize: 16.sp, color: AppStyle.icon),
                      ),
                      Text(
                        AppHelpers.getTranslation(stateRight.orderType),
                        style: GoogleFonts.inter(
                            fontSize: 16.sp, color: AppStyle.icon),
                      ),
                    ],
                  ),
                  8.verticalSpace,
                  const Divider(),
                  8.verticalSpace,
                  Text(
                    AppHelpers.getTranslation(TrKeys.totalItem),
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600, fontSize: 18.sp),
                  ),
                  ListView.builder(
                      padding: EdgeInsets.only(top: 16.r),
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: stocks.length,
                      itemBuilder: (context, index) {
                        final stock = stocks[index];
                        return Padding(
                          padding: EdgeInsets.only(bottom: 16.r),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "${stock.stock?.product?.translation?.title ?? ""} x ${stock.quantity ?? 1}",
                                      style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16.sp,
                                          color: AppStyle.black),
                                    ),
                                    for (Addons e in (stock.addons ?? []))
                                      Text(
                                        "${e.product?.translation?.title ?? ""} ( ${AppHelpers.numberFormat((e.price ?? 0) / (e.quantity ?? 1))} x ${(e.quantity ?? 1)} )",
                                        style: GoogleFonts.inter(
                                          fontSize: 15.sp,
                                          color: AppStyle.unselectedTab,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (stock.bonus ?? false)
                                Text(
                                  AppHelpers.getTranslation(TrKeys.bonus),
                                  style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14.sp,
                                      color: AppStyle.black),
                                )
                              else
                                Text(
                                  AppHelpers.numberFormat(
                                      stock.totalPrice ?? 0),
                                  style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14.sp,
                                      color: AppStyle.black),
                                )
                            ],
                          ),
                        );
                      }),
                  const Divider(),
                  FutureBuilder<List<ApiResult<Map<String, dynamic>>>>(
                    future: _cachedFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError || !snapshot.hasData) {
                        return _buildPriceRow(
                            "Service Fees", "Error loading details");
                      }

                      final Map<String, dynamic> groupedByCategory = {};
                      final Map<String, num> serviceChargeByPercent = {};
                      final Map<String, num> taxByPercent = {};

                      final List<Map<String, dynamic>> calculationData = [];
                      num originalSubtotal = 0;
                      num totalItemLevelDiscount = 0;
                      num totalServiceCharge = 0;
                      num totalTax = 0;

                      final bagProducts = stateRight
                          .bags[stateRight.selectedBagIndex].bagProducts;

                      for (int i = 0; i < stocks.length; i++) {
                        final stock = stocks[i];
                        final result = snapshot.data![i];

                        result.when(
                          success: (productDetails) {
                            final category = productDetails['category'];
                            if (category != null &&
                                category['translation']?['title'] != null) {
                              final categoryName =
                                  category['translation']['title'];
                              if (!groupedByCategory
                                  .containsKey(categoryName)) {
                                groupedByCategory[categoryName] = {
                                  'products': [],
                                  'category_data': category,
                                };
                              }
                              groupedByCategory[categoryName]['products']
                                  .add(stock);
                            }
                          },
                          failure: (_, __) {},
                        );
                      }

                      groupedByCategory.forEach((categoryName, data) {
                        final List productsInGroup = data['products'];
                        final dynamic categoryData = data['category_data'];

                        num groupOriginalSubtotal = 0;
                        num groupItemDiscount = 0;

                        // ADD: Get discount setting for this category
                        DiscountSetting? discountSetting;
                        try {
                          if (categoryData['discount_setting'] != null) {
                            discountSetting = DiscountSetting.fromJson(
                                categoryData['discount_setting']);
                          }
                        } catch (e) {
                          discountSetting = null;
                        }

                        // Calculate for each product in the group
                        for (var p in productsInGroup) {
                          final matchIdx = _findBagProductIndex(bagProducts, p);
                          final isDiscountSelected = (matchIdx != -1) &&
                              (bagProducts?[matchIdx].selectedDiscount ==
                                  'with');

                          final num productPrice =
                              (p.stock?.price ?? 0) * (p.quantity ?? 1);
                          final num addonsTotal = (p.addons ?? [])
                              .fold(0, (sum, e) => sum + (e.price ?? 0));
                          final num totalProductPrice =
                              productPrice + addonsTotal;

                          groupOriginalSubtotal += totalProductPrice;

                          num itemDiscountAmount = 0;

                          if (isDiscountSelected && discountSetting != null) {
                            if (discountSetting.method == 'percent') {
                              itemDiscountAmount = totalProductPrice *
                                  ((discountSetting.value ?? 0) / 100);
                            } else if (discountSetting.method == 'amount') {
                              itemDiscountAmount = discountSetting.value ?? 0;
                            }
                            // Ensure discount doesn't exceed the total product price
                            if (itemDiscountAmount < 0) itemDiscountAmount = 0;
                            if (itemDiscountAmount > totalProductPrice) {
                              itemDiscountAmount = totalProductPrice;
                            }
                          }

                          groupItemDiscount += itemDiscountAmount;
                        }
                        // **FIX END**

                        final num groupSubtotalAfterDiscount =
                            groupOriginalSubtotal - groupItemDiscount;

                        // final List serviceTypes = categoryData['service_types'] ?? [];
                        // final orderType = stateRight.orderType.toLowerCase();

                        // final currentServiceType = serviceTypes.firstWhere(
                        //   (st) => (st['name'] as String? ?? '').toLowerCase().contains(orderType),
                        //   orElse: () => null,
                        // );

                        final List serviceTypes =
                            categoryData['service_types'] ?? [];
                        final orderType = stateRight.orderType.toLowerCase();

                        // FIX: Improve order type matching
                        final currentServiceType = serviceTypes.firstWhere(
                          (st) {
                            final serviceName =
                                (st['name'] as String? ?? '').toLowerCase();

                            // Match "dine" with "Dine In"
                            if (orderType == 'dine_in' &&
                                serviceName.contains('dine')) {
                              return true;
                            }

                            // Match "pickup" with "Take Away"
                            if (orderType == 'pickup' &&
                                (serviceName.contains('take') ||
                                    serviceName.contains('away'))) {
                              return true;
                            }

                            // Match "delivery" with "Delivery"
                            if (orderType == 'delivery' &&
                                serviceName.contains('delivery')) {
                              return true;
                            }

                            if (orderType == 'grab_food' &&
                                serviceName.contains('grab')) {
                              return true;
                            }

                            if (orderType == 'food_panda' &&
                                serviceName.contains('panda')) {
                              return true;
                            }

                            return false;
                          },
                          orElse: () => null,
                        );

                        if (currentServiceType != null) {
                          final serviceChargeRate = num.tryParse(
                                  currentServiceType['service_charge']
                                          ?.toString() ??
                                      '0') ??
                              0;
                          final sstTaxRate = num.tryParse(
                                  currentServiceType['sst_tax']?.toString() ??
                                      '0') ??
                              0;

                          final serviceChargeAmount =
                              groupSubtotalAfterDiscount *
                                  (serviceChargeRate / 100);
                          final sstTaxAmount =
                              groupSubtotalAfterDiscount * (sstTaxRate / 100);

                          // Aggregate amounts by percentage
                          final scKey = serviceChargeRate.toString();
                          serviceChargeByPercent[scKey] =
                              (serviceChargeByPercent[scKey] ?? 0) +
                                  serviceChargeAmount;

                          final taxKey = sstTaxRate.toString();
                          taxByPercent[taxKey] =
                              (taxByPercent[taxKey] ?? 0) + sstTaxAmount;

                          totalServiceCharge += serviceChargeAmount;
                          totalTax += sstTaxAmount;

                          // ADD: Store calculation data for each product in this category
                          for (var p in productsInGroup) {
                            final matchIdx =
                                _findBagProductIndex(bagProducts, p);
                            final isDiscountSelected = (matchIdx != -1) &&
                                (bagProducts?[matchIdx].selectedDiscount ==
                                    'with');

                            final num productPrice =
                                (p.stock?.price ?? 0) * (p.quantity ?? 1);
                            final num addonsTotal = (p.addons ?? [])
                                .fold(0, (sum, e) => sum + (e.price ?? 0));
                            final num totalProductPrice =
                                productPrice + addonsTotal;

                            num itemDiscountAmount = 0;
                            String? itemDiscountType;
                            num? itemDiscountPercent;

                            if (isDiscountSelected && discountSetting != null) {
                              if (discountSetting.method == 'percent') {
                                itemDiscountAmount = totalProductPrice *
                                    ((discountSetting.value ?? 0) / 100);
                                itemDiscountType = 'percent';
                                itemDiscountPercent = discountSetting.value;
                              } else if (discountSetting.method == 'amount') {
                                itemDiscountAmount = discountSetting.value ?? 0;
                                itemDiscountType = 'amount';
                              }
                              // clamp discount to item price
                              if (itemDiscountAmount < 0) {
                                itemDiscountAmount = 0;
                              }
                              if (itemDiscountAmount > totalProductPrice) {
                                itemDiscountAmount = totalProductPrice;
                              }
                            }

                            final num productServiceCharge =
                                (totalProductPrice - itemDiscountAmount) *
                                    (serviceChargeRate / 100);
                            final num productTax =
                                (totalProductPrice - itemDiscountAmount) *
                                    (sstTaxRate / 100);

                            calculationData.add({
                              'stockId': p.stock?.id,
                              'itemDiscountAmount': itemDiscountAmount,
                              'itemDiscountType': itemDiscountType,
                              'itemDiscountPercent': itemDiscountPercent,
                              'serviceChargeAmount': productServiceCharge,
                              'serviceChargeType': categoryName.toLowerCase(),
                              'serviceChargePercent': serviceChargeRate,
                              'taxAmount': productTax,
                              'taxPercent': sstTaxRate,
                            });
                          }
                        }

                        originalSubtotal += groupOriginalSubtotal;
                        totalItemLevelDiscount += groupItemDiscount;
                      });

                      final num deliveryFee =
                          stateRight.paginateResponse?.deliveryFee ?? 0;
                      final num couponPrice =
                          stateRight.paginateResponse?.couponPrice ?? 0;
                      final num subtotalAfterItemDiscount =
                          originalSubtotal - totalItemLevelDiscount;
                      final num subtotalWithTaxesAndFees =
                          subtotalAfterItemDiscount +
                              totalServiceCharge +
                              totalTax +
                              deliveryFee;

                      num billDiscountValue = 0;
                      final selectedBillDiscount = stateRight
                          .bags[stateRight.selectedBagIndex]
                          .selectedBillDiscount;
                      if (selectedBillDiscount != null) {
                        if (selectedBillDiscount.method == 'percent') {
                          billDiscountValue = subtotalWithTaxesAndFees *
                              ((selectedBillDiscount.value ?? 0) / 100);
                        } else if (selectedBillDiscount.method == 'amount') {
                          billDiscountValue = (selectedBillDiscount.value ?? 0);
                        }
                      } else {
                        // Use manual input when no preset bill discount selected.
                        final raw = (stateRight.manualBillDiscountText)
                            .replaceAll(',', '.')
                            .trim();
                        final num parsed = num.tryParse(raw) ?? 0;
                        // Treat manual input as an amount. Cap to subtotalWithTaxesAndFees.
                        billDiscountValue =
                            parsed.clamp(0, subtotalWithTaxesAndFees);
                      }

                      // Add bill discount data
                      calculationData.add({
                        'billDiscountAmount': billDiscountValue,
                        'billDiscountType':
                            selectedBillDiscount?.method ?? 'amount',
                        'billDiscountPercent': selectedBillDiscount?.value,
                      });

                      final num finalTotal = (subtotalWithTaxesAndFees -
                              billDiscountValue -
                              couponPrice)
                          .clamp(0, double.infinity);

                      // For table checkout items stored without UUID, category
                      // data is unavailable so originalSubtotal stays 0. Fall
                      // back to paginateResponse.totalPrice (the pre-computed
                      // total that already includes taxes/charges).
                      final num paginateTotal =
                          stateRight.paginateResponse?.totalPrice ?? 0;
                      final bool noCategory =
                          originalSubtotal == 0 && paginateTotal > 0;
                      final num effectiveSubtotal =
                          noCategory ? paginateTotal : originalSubtotal;
                      final num effectiveFinalTotal =
                          noCategory ? paginateTotal : finalTotal;

                      return Column(
                        children: [
                          _buildPriceRow(
                            AppHelpers.getTranslation(TrKeys.subtotal),
                            AppHelpers.numberFormat(effectiveSubtotal),
                          ),
                          if (totalItemLevelDiscount > 0)
                            _buildPriceRow(
                              "Item Discount",
                              "-${AppHelpers.numberFormat(totalItemLevelDiscount)}",
                              isDiscount: true,
                            ),
                          // Display aggregated Service Charge by percentage
                          for (final entry in serviceChargeByPercent.entries)
                            if (entry.value > 0)
                              _buildPriceRow(
                                "Service Charge (${double.tryParse(entry.key)?.toStringAsFixed(0)}%)",
                                AppHelpers.numberFormat(entry.value),
                              ),
                          // Display aggregated SST Tax by percentage
                          for (final entry in taxByPercent.entries)
                            if (entry.value > 0)
                              _buildPriceRow(
                                "SST Tax (${double.tryParse(entry.key)?.toStringAsFixed(0)}%)",
                                AppHelpers.numberFormat(entry.value),
                              ),
                          if (billDiscountValue > 0)
                            _buildPriceRow(
                              "Bill Discount",
                              "-${AppHelpers.numberFormat(billDiscountValue)}",
                              isDiscount: true,
                            ),
                          // ================= END OF NEW FUTUREBUILDER =================
                          PriceInfo(
                            bag: LocalStorage.getBags()[
                                stateRight.selectedBagIndex],
                            state: stateRight,
                            notifier: rightSideNotifier,
                            mainNotifier: notifier,
                            calculatedTotal: effectiveFinalTotal,
                            calculationData: calculationData,
                            groupedByCategory: groupedByCategory,
                          )
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _calculator(
      RightSideState stateRight, RightSideNotifier rightSideNotifier) {
    // ... Omitted for brevity ...
    return Expanded(
      child: Container(
        decoration: const BoxDecoration(color: AppStyle.white),
        padding: EdgeInsets.symmetric(vertical: 28.r, horizontal: 16.r),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppHelpers.getTranslation(TrKeys.payableAmount),
                          style: GoogleFonts.inter(
                              fontSize: 18.sp, fontWeight: FontWeight.w600),
                        ),
                        6.verticalSpace,
                        Text(
                          AppHelpers.numberFormat(
                            stateRight.selectedUser?.wallet?.price ?? 0,
                          ),
                          style: GoogleFonts.inter(
                              fontSize: 26.sp, fontWeight: FontWeight.w600),
                        ),
                      ],
                    )
                  ],
                ),
                24.horizontalSpace,
                if (stateRight.selectedUser != null)
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        CommonImage(
                          imageUrl: stateRight.selectedUser?.img ?? "",
                          width: 50,
                          height: 50,
                          radius: 25,
                        ),
                        12.horizontalSpace,
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${stateRight.selectedUser?.firstname ?? ""} ${stateRight.selectedUser?.lastname ?? ""}",
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 18.sp),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                "#${AppHelpers.getTranslation(TrKeys.id)}${stateRight.selectedUser?.id ?? ""}",
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14.sp,
                                    color: AppStyle.icon),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            16.verticalSpace,
            const Divider(),
            const Spacer(),
            // Payment methods rendered from stateRight.payments (horizontal)
            Column(
              children: [
                if (stateRight.isPaymentsLoading)
                  const Center(child: CircularProgressIndicator())
                else if ((stateRight.payments).isEmpty)
                  const SizedBox.shrink()
                else
                  Padding(
                    padding: EdgeInsets.only(bottom: 12.r),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: stateRight.payments.map((payment) {
                          final label =
                              AppHelpers.getTranslation(payment.tag ?? '');
                          final bool isSelected =
                              stateRight.selectedPayment?.id == payment.id;
                          return Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4.r),
                            child: InkWell(
                              onTap: () {
                                onMethodTap(payment);
                              },
                              child: AnimationButtonEffect(
                                child: Container(
                                  constraints: BoxConstraints(minWidth: 100.r),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppStyle.primary
                                        : AppStyle.editProfileCircle,
                                    borderRadius: BorderRadius.circular(6.r),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                      vertical: 12.r, horizontal: 12.r),
                                  child: Center(
                                    child: Text(
                                      label,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected
                                              ? AppStyle.white
                                              : AppStyle.black),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                16.verticalSpace,
              ],
            ),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20.r),
              decoration: BoxDecoration(
                  border: Border.all(color: AppStyle.differBorder),
                  borderRadius: BorderRadius.circular(8.r)),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  stateRight.tempCalculate.isEmpty
                      ? "0"
                      : stateRight.tempCalculate,
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600, fontSize: 24.sp),
                  maxLines: 1,
                ),
              ),
            ),
            12.verticalSpace,
            // Quick denomination buttons (clears and inserts amount)
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      rightSideNotifier.clearTempCalculate();
                      rightSideNotifier.setCalculate("5");
                    },
                    child: AnimationButtonEffect(
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: 4.r),
                        decoration: BoxDecoration(
                          color: AppStyle.editProfileCircle,
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12.r),
                        child: Center(
                          child: Text(
                            AppHelpers.numberFormat(
                              5,
                              symbol: stateRight
                                  .bags[stateRight.selectedBagIndex]
                                  .selectedCurrency
                                  ?.symbol,
                              decimalDigits: 0,
                            ),
                            style: GoogleFonts.inter(
                                fontSize: 14.sp, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                8.horizontalSpace,
                Expanded(
                  child: InkWell(
                    onTap: () {
                      rightSideNotifier.clearTempCalculate();
                      rightSideNotifier.setCalculate("10");
                    },
                    child: AnimationButtonEffect(
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: 4.r),
                        decoration: BoxDecoration(
                          color: AppStyle.editProfileCircle,
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12.r),
                        child: Center(
                          child: Text(
                            AppHelpers.numberFormat(
                              10,
                              symbol: stateRight
                                  .bags[stateRight.selectedBagIndex]
                                  .selectedCurrency
                                  ?.symbol,
                              decimalDigits: 0,
                            ),
                            style: GoogleFonts.inter(
                                fontSize: 14.sp, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                8.horizontalSpace,
                Expanded(
                  child: InkWell(
                    onTap: () {
                      rightSideNotifier.clearTempCalculate();
                      rightSideNotifier.setCalculate("50");
                    },
                    child: AnimationButtonEffect(
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: 4.r),
                        decoration: BoxDecoration(
                          color: AppStyle.editProfileCircle,
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12.r),
                        child: Center(
                          child: Text(
                            AppHelpers.numberFormat(
                              50,
                              symbol: stateRight
                                  .bags[stateRight.selectedBagIndex]
                                  .selectedCurrency
                                  ?.symbol,
                              decimalDigits: 0,
                            ),
                            style: GoogleFonts.inter(
                                fontSize: 14.sp, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                8.horizontalSpace,
                Expanded(
                  child: InkWell(
                    onTap: () {
                      rightSideNotifier.clearTempCalculate();
                      rightSideNotifier.setCalculate("100");
                    },
                    child: AnimationButtonEffect(
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: 4.r),
                        decoration: BoxDecoration(
                          color: AppStyle.editProfileCircle,
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12.r),
                        child: Center(
                          child: Text(
                            AppHelpers.numberFormat(
                              100,
                              symbol: stateRight
                                  .bags[stateRight.selectedBagIndex]
                                  .selectedCurrency
                                  ?.symbol,
                              decimalDigits: 0,
                            ),
                            style: GoogleFonts.inter(
                                fontSize: 14.sp, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 12,
                shrinkWrap: true,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 28.w,
                  mainAxisSpacing: 24.h,
                  mainAxisExtent: 48.r,
                ),
                itemBuilder: (context, index) {
                  return InkWell(
                    onTap: () {
                      rightSideNotifier.setCalculate(index == 9
                          ? "00"
                          : index == 10
                              ? "0"
                              : index == 11
                                  ? "-1"
                                  : (index + 1).toString());
                    },
                    child: AnimationButtonEffect(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppStyle.addButtonColor,
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Center(
                          child: index == 11
                              ? const Icon(FlutterRemix.delete_back_2_line)
                              : Text(
                                  index == 9
                                      ? "00"
                                      : index == 10
                                          ? "0"
                                          : (index + 1).toString(),
                                  style: GoogleFonts.inter(
                                      fontSize: 24.sp,
                                      fontWeight: FontWeight.w600),
                                ),
                        ),
                      ),
                    ),
                  );
                }),
            16.verticalSpace,
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: InkWell(
                    onTap: () {
                      rightSideNotifier.setCalculate(".");
                    },
                    child: AnimationButtonEffect(
                      child: Container(
                        height: 48.r,
                        decoration: BoxDecoration(
                          color: AppStyle.addButtonColor,
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Center(
                          child: Text(
                            ".",
                            style: GoogleFonts.inter(
                                fontSize: 24.sp, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                28.horizontalSpace,
                Expanded(
                  flex: 2,
                  child: InkWell(
                    onTap: () {
                      // Confirm the calculation when OK is pressed
                      rightSideNotifier.confirmCalculate();
                    },
                    child: AnimationButtonEffect(
                      child: Container(
                        height: 48.r,
                        decoration: BoxDecoration(
                          color: AppStyle.addButtonColor,
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Center(
                          child: Text(
                            AppHelpers.getTranslation(TrKeys.ok),
                            style: GoogleFonts.inter(
                                fontSize: 24.sp, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
