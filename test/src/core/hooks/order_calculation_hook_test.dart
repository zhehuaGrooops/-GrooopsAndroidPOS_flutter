import 'package:admin_desktop/src/core/handlers/api_result.dart';
import 'package:admin_desktop/src/core/hooks/calculation/order_calculation_hook.dart';
import 'package:admin_desktop/src/models/models.dart';
import 'package:admin_desktop/src/models/response/product_calculate_response.dart';
import 'package:admin_desktop/src/models/response/products_paginate_response.dart';
import 'package:admin_desktop/src/repository/products_repository.dart';
import 'package:flutter_test/flutter_test.dart';

// ── Mock repository ──────────────────────────────────────────────────────────

class _MockProductsRepository implements ProductsRepository {
  final Map<String, Map<String, dynamic>> _byUuid;

  _MockProductsRepository(this._byUuid);

  @override
  Future<ApiResult<Map<String, dynamic>>> getProductByUuid(String uuid) async {
    final data = _byUuid[uuid];
    if (data == null) return const ApiResult.failure(error: 'not_found');
    return ApiResult.success(data: data);
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> getProductByStockId(
      int stockId) async {
    return const ApiResult.failure(error: 'not_implemented');
  }

  @override
  Future<ApiResult<ProductsPaginateResponse>> getProductsPaginate({
    String? query,
    int? categoryId,
    int? brandId,
    int? shopId,
    required int page,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<ApiResult<ProductCalculateResponse>> getAllCalculations(
    List<BagProductData> bagProducts,
    String type,
    String? coupon,
    int? discountSettingId,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<ApiResult<List<DiscountSetting>>> getDiscountSettingsSelectPaginate({
    int? page,
    String? query,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<ApiResult<List<ProductPricingTier>>> getProductPricingTiers() async {
    throw UnimplementedError();
  }

  @override
  Future<ApiResult<List<ProductData>>> getTierProducts(String tierName) async {
    throw UnimplementedError();
  }

  @override
  Future<ApiResult<void>> deductProductStock(int stockId, int quantity) async {
    throw UnimplementedError();
  }

  @override
  Future<ApiResult<void>> addProductStock(int stockId, int quantity) async {
    throw UnimplementedError();
  }

  @override
  Future<ApiResult<void>> deductAddonStock(
      int countableId, int quantity) async {
    throw UnimplementedError();
  }

  @override
  Future<ApiResult<void>> addAddonStock(int countableId, int quantity) async {
    throw UnimplementedError();
  }
}

// ── Helper builders ──────────────────────────────────────────────────────────

/// Build a minimal ProductData with a UUID and stock price.
ProductData _makeProduct({
  required String uuid,
  required int stockId,
  required num price,
  int quantity = 1,
}) {
  return ProductData.fromJson({
    'id': stockId,
    'uuid': uuid,
    'quantity': quantity,
    'stock': {
      'id': stockId,
      'price': price,
      'quantity': 99,
      'product': {'uuid': uuid},
    },
  });
}

/// Build a minimal product-detail map returned by the mock repo.
Map<String, dynamic> _makeProductDetail({
  required String categoryName,
  List<Map<String, dynamic>> serviceTypes = const [],
  Map<String, dynamic>? discountSetting,
}) {
  return {
    'category': {
      'translation': {'title': categoryName},
      'service_types': serviceTypes,
      if (discountSetting != null) 'discount_setting': discountSetting,
    },
  };
}

Map<String, dynamic> _dineServiceType({
  num serviceCharge = 0,
  num sstTax = 0,
}) =>
    {
      'name': 'Dine In',
      'service_charge': serviceCharge.toString(),
      'sst_tax': sstTax.toString(),
    };

BagProductData _bagProduct(int stockId, {bool withDiscount = false}) =>
    BagProductData(
      stockId: stockId,
      quantity: 1,
      selectedDiscount: withDiscount ? 'with' : 'without',
    );

OrderCalculationHook _hook(Map<String, Map<String, dynamic>> productsByUuid) {
  final repo = _MockProductsRepository(productsByUuid);
  return OrderCalculationHook(apiRepo: repo, hiveRepo: repo);
}

// ─────────────────────────────────────────────────────────────────────────────
void main() {
  // ── Scenario 1 ──────────────────────────────────────────────────────────────
  test('1: single item, no discount, no SC, no tax → finalTotal == subtotal',
      () async {
    const stockId = 1;
    const uuid = 'uuid-1';
    const price = 100.0;

    final hook = _hook({
      uuid: _makeProductDetail(
        categoryName: 'Food',
        serviceTypes: [_dineServiceType()],
      ),
    });

    final r = await hook.calculate(
      stocks: [_makeProduct(uuid: uuid, stockId: stockId, price: price)],
      orderType: 'dine_in',
      bagProducts: [_bagProduct(stockId)],
    );

    expect(r.originalSubtotal, price);
    expect(r.totalItemLevelDiscount, 0);
    expect(r.totalServiceCharge, 0);
    expect(r.totalTax, 0);
    expect(r.billDiscountValue, 0);
    expect(r.finalTotal, price);
  });

  // ── Scenario 2 ──────────────────────────────────────────────────────────────
  test('2: single item + 10% SC → totalServiceCharge == price * 0.10',
      () async {
    const stockId = 2;
    const uuid = 'uuid-2';
    const price = 100.0;

    final r = await _hook({
      uuid: _makeProductDetail(
        categoryName: 'Food',
        serviceTypes: [_dineServiceType(serviceCharge: 10)],
      ),
    }).calculate(
      stocks: [_makeProduct(uuid: uuid, stockId: stockId, price: price)],
      orderType: 'dine_in',
      bagProducts: [_bagProduct(stockId)],
    );

    expect(r.totalServiceCharge, closeTo(price * 0.10, 0.001));
    expect(r.finalTotal, closeTo(price * 1.10, 0.001));
  });

  // ── Scenario 3 ──────────────────────────────────────────────────────────────
  test('3: single item + 6% SST → totalTax == price * 0.06', () async {
    const stockId = 3;
    const uuid = 'uuid-3';
    const price = 100.0;

    final r = await _hook({
      uuid: _makeProductDetail(
        categoryName: 'Food',
        serviceTypes: [_dineServiceType(sstTax: 6)],
      ),
    }).calculate(
      stocks: [_makeProduct(uuid: uuid, stockId: stockId, price: price)],
      orderType: 'dine_in',
      bagProducts: [_bagProduct(stockId)],
    );

    expect(r.totalTax, closeTo(price * 0.06, 0.001));
    expect(r.finalTotal, closeTo(price * 1.06, 0.001));
  });

  // ── Scenario 4 ──────────────────────────────────────────────────────────────
  test('4: item discount percent 10% → totalItemLevelDiscount == price * 0.10',
      () async {
    const stockId = 4;
    const uuid = 'uuid-4';
    const price = 100.0;

    final r = await _hook({
      uuid: _makeProductDetail(
        categoryName: 'Food',
        serviceTypes: [_dineServiceType()],
        discountSetting: {'method': 'percent', 'value': 10},
      ),
    }).calculate(
      stocks: [_makeProduct(uuid: uuid, stockId: stockId, price: price)],
      orderType: 'dine_in',
      bagProducts: [_bagProduct(stockId, withDiscount: true)],
    );

    expect(r.totalItemLevelDiscount, closeTo(price * 0.10, 0.001));
    expect(r.finalTotal, closeTo(price * 0.90, 0.001));
  });

  // ── Scenario 5 ──────────────────────────────────────────────────────────────
  test('5: item discount fixed RM5 → totalItemLevelDiscount == 5', () async {
    const stockId = 5;
    const uuid = 'uuid-5';
    const price = 50.0;

    final r = await _hook({
      uuid: _makeProductDetail(
        categoryName: 'Food',
        serviceTypes: [_dineServiceType()],
        discountSetting: {'method': 'amount', 'value': 5},
      ),
    }).calculate(
      stocks: [_makeProduct(uuid: uuid, stockId: stockId, price: price)],
      orderType: 'dine_in',
      bagProducts: [_bagProduct(stockId, withDiscount: true)],
    );

    expect(r.totalItemLevelDiscount, 5.0);
    expect(r.finalTotal, closeTo(price - 5.0, 0.001));
  });

  // ── Scenario 6 ──────────────────────────────────────────────────────────────
  test('6: bill discount preset 15% → billDiscountValue == subtotal * 0.15',
      () async {
    const stockId = 6;
    const uuid = 'uuid-6';
    const price = 100.0;

    final r = await _hook({
      uuid: _makeProductDetail(
        categoryName: 'Food',
        serviceTypes: [_dineServiceType()],
      ),
    }).calculate(
      stocks: [_makeProduct(uuid: uuid, stockId: stockId, price: price)],
      orderType: 'dine_in',
      bagProducts: [_bagProduct(stockId)],
      selectedBillDiscount:
          DiscountSetting.fromJson({'method': 'percent', 'value': 15}),
    );

    expect(r.billDiscountValue, closeTo(price * 0.15, 0.001));
    expect(r.finalTotal, closeTo(price * 0.85, 0.001));
  });

  // ── Scenario 7 ──────────────────────────────────────────────────────────────
  test('7: bill discount manual RM10 → billDiscountValue == 10', () async {
    const stockId = 7;
    const uuid = 'uuid-7';
    const price = 100.0;

    final r = await _hook({
      uuid: _makeProductDetail(
        categoryName: 'Food',
        serviceTypes: [_dineServiceType()],
      ),
    }).calculate(
      stocks: [_makeProduct(uuid: uuid, stockId: stockId, price: price)],
      orderType: 'dine_in',
      bagProducts: [_bagProduct(stockId)],
      manualBillDiscountText: '10',
    );

    expect(r.billDiscountValue, 10.0);
    expect(r.finalTotal, closeTo(price - 10.0, 0.001));
  });

  // ── Scenario 8 ──────────────────────────────────────────────────────────────
  test('8: coupon RM20 → finalTotal == subtotal - 20', () async {
    const stockId = 8;
    const uuid = 'uuid-8';
    const price = 100.0;

    final r = await _hook({
      uuid: _makeProductDetail(
        categoryName: 'Food',
        serviceTypes: [_dineServiceType()],
      ),
    }).calculate(
      stocks: [_makeProduct(uuid: uuid, stockId: stockId, price: price)],
      orderType: 'dine_in',
      bagProducts: [_bagProduct(stockId)],
      couponPrice: 20,
    );

    expect(r.finalTotal, closeTo(price - 20.0, 0.001));
  });

  // ── Scenario 9 ──────────────────────────────────────────────────────────────
  test('9: two categories with different SC/tax rates', () async {
    const uuidA = 'uuid-9a';
    const uuidB = 'uuid-9b';
    const stockIdA = 91;
    const stockIdB = 92;
    const priceA = 100.0;
    const priceB = 80.0;

    final r = await _hook({
      uuidA: _makeProductDetail(
        categoryName: 'CategoryA',
        serviceTypes: [_dineServiceType(serviceCharge: 10, sstTax: 6)],
      ),
      uuidB: _makeProductDetail(
        categoryName: 'CategoryB',
        serviceTypes: [_dineServiceType(serviceCharge: 5)],
      ),
    }).calculate(
      stocks: [
        _makeProduct(uuid: uuidA, stockId: stockIdA, price: priceA),
        _makeProduct(uuid: uuidB, stockId: stockIdB, price: priceB),
      ],
      orderType: 'dine_in',
      bagProducts: [_bagProduct(stockIdA), _bagProduct(stockIdB)],
    );

    final expectedSCA = priceA * 0.10;
    final expectedTaxA = priceA * 0.06;
    final expectedSCB = priceB * 0.05;

    expect(r.totalServiceCharge, closeTo(expectedSCA + expectedSCB, 0.001));
    expect(r.totalTax, closeTo(expectedTaxA, 0.001));
    expect(
      r.finalTotal,
      closeTo(priceA + priceB + expectedSCA + expectedTaxA + expectedSCB,
          0.001),
    );
  });

  // ── Scenario 10 ─────────────────────────────────────────────────────────────
  test('10: delivery fee RM15 included in subtotalWithFees', () async {
    const stockId = 10;
    const uuid = 'uuid-10';
    const price = 100.0;

    final r = await _hook({
      uuid: _makeProductDetail(
        categoryName: 'Food',
        serviceTypes: [_dineServiceType()],
      ),
    }).calculate(
      stocks: [_makeProduct(uuid: uuid, stockId: stockId, price: price)],
      orderType: 'dine_in',
      bagProducts: [_bagProduct(stockId)],
      deliveryFee: 15,
    );

    expect(r.finalTotal, closeTo(price + 15.0, 0.001));
  });

  // ── Scenario 11 ─────────────────────────────────────────────────────────────
  test('11: no matching UUID → originalSubtotal 0, empty groupedByCategory',
      () async {
    final r = await _hook({}).calculate(
      stocks: [_makeProduct(uuid: 'unknown', stockId: 11, price: 50)],
      orderType: 'dine_in',
      bagProducts: [_bagProduct(11)],
    );

    expect(r.originalSubtotal, 0);
    expect(r.finalTotal, 0);
    expect(r.groupedByCategory, isEmpty);
  });

  // ── Scenario 12 ─────────────────────────────────────────────────────────────
  test(
      '12: all combined — SC 10% + SST 6% + item discount 10% + bill 15% + coupon 5',
      () async {
    const stockId = 12;
    const uuid = 'uuid-12';
    const price = 200.0;
    const coupon = 5.0;

    final r = await _hook({
      uuid: _makeProductDetail(
        categoryName: 'Food',
        serviceTypes: [_dineServiceType(serviceCharge: 10, sstTax: 6)],
        discountSetting: {'method': 'percent', 'value': 10},
      ),
    }).calculate(
      stocks: [_makeProduct(uuid: uuid, stockId: stockId, price: price)],
      orderType: 'dine_in',
      bagProducts: [_bagProduct(stockId, withDiscount: true)],
      selectedBillDiscount:
          DiscountSetting.fromJson({'method': 'percent', 'value': 15}),
      couponPrice: coupon,
    );

    final itemDiscount = price * 0.10; // 20
    final afterItem = price - itemDiscount; // 180
    final sc = afterItem * 0.10; // 18
    final tax = afterItem * 0.06; // 10.8
    final withFees = afterItem + sc + tax; // 208.8
    final billDiscount = withFees * 0.15; // 31.32
    final expected = withFees - billDiscount - coupon; // 172.48

    expect(r.totalItemLevelDiscount, closeTo(itemDiscount, 0.001));
    expect(r.totalServiceCharge, closeTo(sc, 0.001));
    expect(r.totalTax, closeTo(tax, 0.001));
    expect(r.billDiscountValue, closeTo(billDiscount, 0.001));
    expect(r.finalTotal, closeTo(expected, 0.001));
  });
}
