import 'package:admin_desktop/src/models/data/order_body_data.dart';
import 'package:admin_desktop/src/models/data/product_data.dart';

/// Builds [List<EnhancedProductOrder>] from stocks + pre-computed calculationData.
/// Extracted from price_info.dart createEnhancedProducts().
class EnhancedProductHook {
  const EnhancedProductHook();

  List<EnhancedProductOrder> build({
    required List<ProductData> stocks,
    required List<Map<String, dynamic>> calculationData,
    required String orderType,
  }) {
    final List<EnhancedProductOrder> enhancedProducts = [];

    // Build stockId → calcData lookup. Skip trailing bill-discount entry.
    // Keyed by stockId so emission order in calculationData doesn't matter.
    final calcByStockId = <int, Map<String, dynamic>>{};
    for (final entry in calculationData) {
      if (entry.containsKey('billDiscountAmount')) continue;
      final sid = entry['stockId'];
      if (sid == null) continue;
      final key = sid is int ? sid : (sid as num).toInt();
      calcByStockId[key] = entry;
    }

    for (int i = 0; i < stocks.length; i++) {
      final stock = stocks[i];
      final num productPrice =
          (stock.stock?.price ?? 0) * (stock.quantity ?? 1);
      final num addonsTotal =
          (stock.addons ?? []).fold(0, (sum, e) => sum + (e.price ?? 0));
      final num originalPrice = productPrice + addonsTotal;

      // Per-product calculation data matched by stockId (not array index).
      // This is correct even when stocks from the same category are non-contiguous
      // in the bag, because calculationData emits entries in category-group order.
      final sid = stock.stock?.id;
      final Map<String, dynamic>? prodCalcData =
          sid != null ? calcByStockId[sid] : null;

      final String rawItemDiscountStr =
          (prodCalcData?['itemDiscountAmount'] ?? 0).toString();
      final num rawItemDiscount = num.tryParse(rawItemDiscountStr) ?? 0;
      final num itemDiscountAmount =
          rawItemDiscount < 0 ? 0 : rawItemDiscount;
      final String? itemDiscountType = prodCalcData?['itemDiscountType'];
      final num? itemDiscountPercent = prodCalcData?['itemDiscountPercent'];
      final num serviceChargeAmount =
          prodCalcData?['serviceChargeAmount'] ?? 0;
      final String? serviceChargeType = prodCalcData?['serviceChargeType'];
      final num serviceChargePercent = num.tryParse(
              prodCalcData?['serviceChargePercent']?.toString() ?? '0') ??
          0;
      final num taxAmount = prodCalcData?['taxAmount'] ?? 0;
      final num taxPercent =
          num.tryParse(prodCalcData?['taxPercent']?.toString() ?? '0') ?? 0;

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
        serviceChargeType: serviceChargeType ?? orderType.toLowerCase(),
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
}
