import 'package:admin_desktop/src/models/data/bag_data.dart';
import 'package:admin_desktop/src/models/data/product_data.dart';
import 'package:admin_desktop/src/repository/products_repository.dart';

/// Result returned by [OrderCalculationHook.calculate].
class OrderCalculationResult {
  /// Per-product rows: {stockId, itemDiscountAmount, itemDiscountType,
  /// itemDiscountPercent, serviceChargeAmount, serviceChargeType,
  /// serviceChargePercent, taxAmount, taxPercent}.
  /// Last entry is the bill-discount row: {billDiscountAmount,
  /// billDiscountType, billDiscountPercent}.
  final List<Map<String, dynamic>> calculationData;

  /// Products grouped by category name; value = {products, category_data}.
  final Map<String, dynamic> groupedByCategory;

  final num originalSubtotal;
  final num totalItemLevelDiscount;
  final num totalServiceCharge;
  final num totalTax;

  /// SC amounts keyed by rate string (e.g. "10").
  final Map<String, num> serviceChargeByPercent;

  /// SST tax amounts keyed by rate string (e.g. "6").
  final Map<String, num> taxByPercent;

  final num billDiscountValue;

  /// Final total after all discounts, taxes, delivery fee and coupon.
  final num finalTotal;

  const OrderCalculationResult({
    required this.calculationData,
    required this.groupedByCategory,
    required this.originalSubtotal,
    required this.totalItemLevelDiscount,
    required this.totalServiceCharge,
    required this.totalTax,
    required this.serviceChargeByPercent,
    required this.taxByPercent,
    required this.billDiscountValue,
    required this.finalTotal,
  });
}

/// Extracts the ~300-line FutureBuilder calculation logic from order_calculate.dart.
///
/// Algorithm:
///   1. Fetch product details from [apiRepo] for each stock item (async).
///   2. Group stocks by category.
///   3. Per-category: compute item discounts, service charge, SST tax.
///   4. Apply bill discount (preset or manual).
///   5. Apply coupon and delivery fee → final total.
class OrderCalculationHook {
  final ProductsRepository apiRepo;

  /// Kept for future direct-Hive extensions; not used in current calculation.
  final ProductsRepository hiveRepo;

  OrderCalculationHook({
    required this.apiRepo,
    required this.hiveRepo,
  });

  Future<OrderCalculationResult> calculate({
    required List<ProductData> stocks,
    required String orderType,
    required List<BagProductData>? bagProducts,
    DiscountSetting? selectedBillDiscount,
    String manualBillDiscountText = '',
    num couponPrice = 0,
    num deliveryFee = 0,
    List<Map<String, dynamic>>? cashoutRecoveryItems,
  }) async {
    final Map<String, dynamic> groupedByCategory = {};
    final Map<String, num> serviceChargeByPercent = {};
    final Map<String, num> taxByPercent = {};
    final List<Map<String, dynamic>> calculationData = [];

    num originalSubtotal = 0;
    num totalItemLevelDiscount = 0;
    num totalServiceCharge = 0;
    num totalTax = 0;

    // ── Step 1: resolve product details and group by category ────────────────
    for (int i = 0; i < stocks.length; i++) {
      final stock = stocks[i];
      final uuid = stock.stock?.product?.uuid;

      Map<String, dynamic>? productDetails;
      if (uuid != null) {
        final res = await apiRepo.getProductByUuid(uuid);
        res.when(success: (d) => productDetails = d, failure: (_, __) {});
      }
      if (productDetails == null) continue;

      final category = productDetails!['category'];
      if (category == null || category['translation']?['title'] == null) {
        continue;
      }
      final categoryName = category['translation']!['title'] as String;
      if (!groupedByCategory.containsKey(categoryName)) {
        groupedByCategory[categoryName] = {
          'products': <dynamic>[],
          'category_data': category,
        };
      }
      (groupedByCategory[categoryName]['products'] as List).add(stock);
    }

    // ── Step 2: per-category item discount + SC + tax ────────────────────────
    groupedByCategory.forEach((categoryName, data) {
      final List productsInGroup = data['products'] as List;
      final dynamic categoryData = data['category_data'];

      num groupOriginalSubtotal = 0;
      num groupItemDiscount = 0;

      // Resolve discount setting for this category
      DiscountSetting? discountSetting;
      try {
        if (categoryData['discount_setting'] != null) {
          discountSetting =
              DiscountSetting.fromJson(categoryData['discount_setting']);
        }
      } catch (_) {
        discountSetting = null;
      }

      // First pass: accumulate group subtotal + item discounts
      for (final p in productsInGroup) {
        final prod = p as ProductData;
        final matchIdx = _findBagProductIndex(bagProducts, prod);
        final isDiscountSelected =
            matchIdx != -1 && bagProducts?[matchIdx].selectedDiscount == 'with';

        final num productPrice =
            (prod.stock?.price ?? 0) * (prod.quantity ?? 1);
        final num addonsTotal = (prod.addons ?? [])
            .fold<num>(0, (s, e) => s + (e.price ?? 0));
        final num totalProductPrice = productPrice + addonsTotal;

        groupOriginalSubtotal += totalProductPrice;

        num itemDiscountAmount = 0;
        if (isDiscountSelected && discountSetting != null) {
          if (discountSetting.method == 'percent') {
            itemDiscountAmount =
                totalProductPrice * ((discountSetting.value ?? 0) / 100);
          } else if (discountSetting.method == 'amount') {
            itemDiscountAmount = discountSetting.value ?? 0;
          }
          if (itemDiscountAmount < 0) itemDiscountAmount = 0;
          if (itemDiscountAmount > totalProductPrice) {
            itemDiscountAmount = totalProductPrice;
          }
        }
        groupItemDiscount += itemDiscountAmount;
      }

      final num groupSubtotalAfterDiscount =
          groupOriginalSubtotal - groupItemDiscount;

      // Resolve service type for this order type
      final List serviceTypes = categoryData['service_types'] ?? [];
      final orderTypeLower = orderType.toLowerCase();

      dynamic currentServiceType;
      for (final st in serviceTypes) {
        final name =
            st is Map ? ((st['name'] as String?) ?? '').toLowerCase() : '';
        if (orderTypeLower == 'dine_in' && name.contains('dine')) {
          currentServiceType = st;
          break;
        }
        if (orderTypeLower == 'pickup' &&
            (name.contains('take') || name.contains('away'))) {
          currentServiceType = st;
          break;
        }
        if (orderTypeLower == 'delivery' && name.contains('delivery')) {
          currentServiceType = st;
          break;
        }
        if (orderTypeLower == 'grab_food' && name.contains('grab')) {
          currentServiceType = st;
          break;
        }
        if (orderTypeLower == 'food_panda' && name.contains('panda')) {
          currentServiceType = st;
          break;
        }
      }

      if (currentServiceType != null) {
        final serviceChargeRate = num.tryParse(
                currentServiceType['service_charge']?.toString() ?? '0') ??
            0;
        final sstTaxRate =
            num.tryParse(currentServiceType['sst_tax']?.toString() ?? '0') ??
                0;

        final serviceChargeAmount =
            groupSubtotalAfterDiscount * (serviceChargeRate / 100);
        final sstTaxAmount =
            groupSubtotalAfterDiscount * (sstTaxRate / 100);

        // Accumulate by rate for display rows
        final scKey = serviceChargeRate.toString();
        serviceChargeByPercent[scKey] =
            (serviceChargeByPercent[scKey] ?? 0) + serviceChargeAmount;
        final taxKey = sstTaxRate.toString();
        taxByPercent[taxKey] =
            (taxByPercent[taxKey] ?? 0) + sstTaxAmount;

        totalServiceCharge += serviceChargeAmount;
        totalTax += sstTaxAmount;

        // Second pass: emit per-product calculationData entries
        for (final p in productsInGroup) {
          final prod = p as ProductData;
          final matchIdx = _findBagProductIndex(bagProducts, prod);
          final isDiscountSelected = matchIdx != -1 &&
              bagProducts?[matchIdx].selectedDiscount == 'with';

          final num productPrice =
              (prod.stock?.price ?? 0) * (prod.quantity ?? 1);
          final num addonsTotal = (prod.addons ?? [])
              .fold<num>(0, (s, e) => s + (e.price ?? 0));
          final num totalProductPrice = productPrice + addonsTotal;

          num itemDiscountAmount = 0;
          String? itemDiscountType;
          num? itemDiscountPercent;

          if (isDiscountSelected && discountSetting != null) {
            if (discountSetting.method == 'percent') {
              itemDiscountAmount =
                  totalProductPrice * ((discountSetting.value ?? 0) / 100);
              itemDiscountType = 'percent';
              itemDiscountPercent = discountSetting.value;
            } else if (discountSetting.method == 'amount') {
              itemDiscountAmount = discountSetting.value ?? 0;
              itemDiscountType = 'amount';
            }
            if (itemDiscountAmount < 0) itemDiscountAmount = 0;
            if (itemDiscountAmount > totalProductPrice) {
              itemDiscountAmount = totalProductPrice;
            }
          }

          final num productServiceCharge =
              (totalProductPrice - itemDiscountAmount) *
                  (serviceChargeRate / 100);
          final num productTax =
              (totalProductPrice - itemDiscountAmount) * (sstTaxRate / 100);

          calculationData.add({
            'stockId': prod.stock?.id,
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

    // ── Step 3: bill discount ────────────────────────────────────────────────
    final num subtotalAfterItemDiscount =
        originalSubtotal - totalItemLevelDiscount;
    final num subtotalWithTaxesAndFees =
        subtotalAfterItemDiscount + totalServiceCharge + totalTax + deliveryFee;

    num billDiscountValue = 0;
    if (selectedBillDiscount != null) {
      if (selectedBillDiscount.method == 'percent') {
        billDiscountValue = subtotalWithTaxesAndFees *
            ((selectedBillDiscount.value ?? 0) / 100);
      } else if (selectedBillDiscount.method == 'amount') {
        billDiscountValue = selectedBillDiscount.value ?? 0;
      }
    } else {
      final raw = manualBillDiscountText.replaceAll(',', '.').trim();
      final num parsed = num.tryParse(raw) ?? 0;
      billDiscountValue = parsed.clamp(0, subtotalWithTaxesAndFees);
    }

    // Append bill-discount entry (consumed by EnhancedProductHook to skip)
    calculationData.add({
      'billDiscountAmount': billDiscountValue,
      'billDiscountType': selectedBillDiscount?.method ?? 'amount',
      'billDiscountPercent': selectedBillDiscount?.value,
    });

    // ── Step 4: final total ──────────────────────────────────────────────────
    final num finalTotal =
        (subtotalWithTaxesAndFees - billDiscountValue - couponPrice)
            .clamp(0, double.infinity);

    return OrderCalculationResult(
      calculationData: calculationData,
      groupedByCategory: groupedByCategory,
      originalSubtotal: originalSubtotal,
      totalItemLevelDiscount: totalItemLevelDiscount,
      totalServiceCharge: totalServiceCharge,
      totalTax: totalTax,
      serviceChargeByPercent: serviceChargeByPercent,
      taxByPercent: taxByPercent,
      billDiscountValue: billDiscountValue,
      finalTotal: finalTotal,
    );
  }

  /// Mirrors _findBagProductIndex from order_calculate.dart.
  int _findBagProductIndex(
      List<BagProductData>? bagProducts, ProductData? prod) {
    if (bagProducts == null || prod == null) return -1;
    final rightIds = <dynamic>[
      prod.id,
      prod.stock?.id,
      prod.stock?.countableId,
      prod.uuid,
      prod.stock?.product?.uuid,
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
}
