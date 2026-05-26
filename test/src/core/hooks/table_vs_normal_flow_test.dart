// ignore_for_file: avoid_dynamic_calls
//
// Compares table-order flow and normal-order flow across four areas:
//   Group A – OrderCalculationHook parity (same hook, same output for both flows)
//   Group B – EnhancedProductHook stockId-key regression (non-contiguous stocks)
//   Group C – displayItems SC/tax field equivalence
//   Group D – finalizeOrderPayment Hive patching
//
// Run: flutter test test/src/core/hooks/table_vs_normal_flow_test.dart
import 'dart:io';

import 'package:admin_desktop/src/core/constants/hive_boxes.dart';
import 'package:admin_desktop/src/core/db/hive_service.dart';
import 'package:admin_desktop/src/core/handlers/api_result.dart';
import 'package:admin_desktop/src/core/hooks/calculation/order_calculation_hook.dart';
import 'package:admin_desktop/src/core/hooks/product/enhanced_product_hook.dart';
import 'package:admin_desktop/src/models/data/bag_data.dart';
import 'package:admin_desktop/src/models/data/order_body_data.dart';
import 'package:admin_desktop/src/models/data/order_hive_model.dart';
import 'package:admin_desktop/src/models/data/product_data.dart';
import 'package:admin_desktop/src/models/models.dart';
import 'package:admin_desktop/src/models/response/product_calculate_response.dart';
import 'package:admin_desktop/src/models/response/products_paginate_response.dart';
import 'package:admin_desktop/src/repository/hive_repository/orders_hive_repository.dart';
import 'package:admin_desktop/src/repository/products_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Path-provider mock (allows Hive.initFlutter() to succeed in tests)
// ──────────────────────────────────────────────────────────────────────────────

class _MockPathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final String _dir;
  _MockPathProvider(this._dir);

  @override
  Future<String?> getApplicationDocumentsPath() async => _dir;
  @override
  Future<String?> getApplicationSupportPath() async => _dir;
  @override
  Future<String?> getTemporaryPath() async => _dir;
  @override
  Future<String?> getLibraryPath() async => _dir;
  @override
  Future<String?> getExternalStoragePath() async => _dir;
  @override
  Future<List<String>?> getExternalCachePaths() async => [_dir];
  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async =>
      [_dir];
  @override
  Future<String?> getDownloadsPath() async => _dir;
}

// ──────────────────────────────────────────────────────────────────────────────
// Mock products repository (pure-Dart; no I/O)
// ──────────────────────────────────────────────────────────────────────────────

class _MockProductsRepo implements ProductsRepository {
  final Map<String, Map<String, dynamic>> _byUuid;
  _MockProductsRepo(this._byUuid);

  @override
  Future<ApiResult<Map<String, dynamic>>> getProductByUuid(String uuid) async {
    final d = _byUuid[uuid];
    if (d == null) return const ApiResult.failure(error: 'not_found');
    return ApiResult.success(data: d);
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> getProductByStockId(
          int stockId) async =>
      const ApiResult.failure(error: 'not_implemented');

  @override
  Future<ApiResult<ProductsPaginateResponse>> getProductsPaginate({
    String? query,
    int? categoryId,
    int? brandId,
    int? shopId,
    required int page,
  }) async =>
      throw UnimplementedError();

  @override
  Future<ApiResult<ProductCalculateResponse>> getAllCalculations(
    List<BagProductData> bagProducts,
    String type,
    String? coupon,
    int? discountSettingId,
  ) async =>
      throw UnimplementedError();

  @override
  Future<ApiResult<List<DiscountSetting>>> getDiscountSettingsSelectPaginate({
    int? page,
    String? query,
  }) async =>
      throw UnimplementedError();

  @override
  Future<ApiResult<List<ProductPricingTier>>> getProductPricingTiers() async =>
      throw UnimplementedError();

  @override
  Future<ApiResult<List<ProductData>>> getTierProducts(String tierName) async =>
      throw UnimplementedError();

  @override
  Future<ApiResult<void>> deductProductStock(
          int stockId, int quantity) async =>
      throw UnimplementedError();

  @override
  Future<ApiResult<void>> addProductStock(int stockId, int quantity) async =>
      throw UnimplementedError();

  @override
  Future<ApiResult<void>> deductAddonStock(
          int countableId, int quantity) async =>
      throw UnimplementedError();

  @override
  Future<ApiResult<void>> addAddonStock(
          int countableId, int quantity) async =>
      throw UnimplementedError();
}

// ──────────────────────────────────────────────────────────────────────────────
// Shared test helpers
// ──────────────────────────────────────────────────────────────────────────────

/// Build a minimal [ProductData] with stock id, uuid and price.
/// Matches the shape that both flows produce for `paginateResponse.stocks`.
ProductData _makeStock({
  required int stockId,
  required String uuid,
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
      'product': {
        'uuid': uuid,
        'translation': {'title': 'Item-$stockId'},
      },
    },
  });
}

/// Build a product-detail map returned by the mock repo for a given uuid.
Map<String, dynamic> _makeProductDetail({
  required String categoryName,
  List<Map<String, dynamic>> serviceTypes = const [],
  Map<String, dynamic>? discountSetting,
}) {
  return {
    'category': {
      'id': categoryName.hashCode,
      'translation': {'title': categoryName},
      'service_types': serviceTypes,
      if (discountSetting != null) 'discount_setting': discountSetting,
    },
  };
}

Map<String, dynamic> _dineServiceType({num sc = 0, num sst = 0}) => {
      'name': 'Dine In',
      'service_charge': sc.toString(),
      'sst_tax': sst.toString(),
    };

BagProductData _bagProduct(int stockId, {bool withDiscount = false}) =>
    BagProductData(
      stockId: stockId,
      quantity: 1,
      selectedDiscount: withDiscount ? 'with' : 'without',
    );

OrderCalculationHook _hook(_MockProductsRepo repo) => OrderCalculationHook(
      apiRepo: repo,
      hiveRepo: repo,
    );

// ── Helper: mirrors page_view_item.dart displayItems builder ─────────────────

/// Pure function that mirrors the displayItems construction in page_view_item.dart.
/// Maps calculationData entries to stocks by stockId (not array index).
List<Map<String, dynamic>> _buildDisplayItems({
  required List<ProductData> stocks,
  required OrderCalculationResult calcResult,
}) {
  // Build stockId → calcData map, skip the trailing bill-discount entry.
  final calcByStockId = <int, Map<String, dynamic>>{};
  for (final entry in calcResult.calculationData) {
    if (entry.containsKey('billDiscountAmount')) continue;
    final sid = entry['stockId'];
    if (sid == null) continue;
    final key = sid is int ? sid : (sid as num).toInt();
    calcByStockId[key] = entry;
  }

  return stocks.map((stock) {
    final stockId = stock.stock?.id;
    final qty = (stock.quantity ?? 1).toInt();
    final num total = (stock.stock?.price ?? 0) * qty;
    final cd =
        stockId != null ? (calcByStockId[stockId] ?? <String, dynamic>{}) : <String, dynamic>{};
    return <String, dynamic>{
      'stockId': stockId ?? 0,
      'uuid': stock.stock?.product?.uuid, // required for cashout FutureBuilder
      'productName': stock.stock?.product?.translation?.title ?? '',
      'quantity': qty,
      'totalPrice': total,
      'taxAmount': (cd['taxAmount'] as num?) ?? 0,
      'serviceChargeAmount': (cd['serviceChargeAmount'] as num?) ?? 0,
    };
  }).toList();
}

// ──────────────────────────────────────────────────────────────────────────────
// GROUP A  –  OrderCalculationHook parity
// ──────────────────────────────────────────────────────────────────────────────

void _groupA() {
  group('Group A – OrderCalculationHook parity', () {
    test('A1: No SC/tax – subtotal equals price × qty', () async {
      final repo = _MockProductsRepo({
        'p1': _makeProductDetail(categoryName: 'Food'),
      });
      final stocks = [_makeStock(stockId: 1, uuid: 'p1', price: 50, quantity: 2)];
      final bags = [_bagProduct(1)];

      final result = await _hook(repo).calculate(
        stocks: stocks,
        orderType: 'dine_in',
        bagProducts: bags,
      );

      // Both flows would pass same inputs; assert deterministic output.
      expect(result.originalSubtotal, equals(100));
      expect(result.totalServiceCharge, equals(0));
      expect(result.totalTax, equals(0));
      expect(result.finalTotal, equals(100));
    });

    test('A2: Dine-In SC=10 sst=6 – finalTotal matches normal flow', () async {
      final repo = _MockProductsRepo({
        'p1': _makeProductDetail(
          categoryName: 'Food',
          serviceTypes: [_dineServiceType(sc: 10, sst: 6)],
        ),
      });
      final stocks = [_makeStock(stockId: 1, uuid: 'p1', price: 100)];
      final bags = [_bagProduct(1)];

      final result = await _hook(repo).calculate(
        stocks: stocks,
        orderType: 'dine_in',
        bagProducts: bags,
      );

      // subtotal=100, SC=10, tax=6, final=116
      expect(result.originalSubtotal, equals(100));
      expect(result.totalServiceCharge, equals(10));
      expect(result.totalTax, equals(6));
      expect(result.finalTotal, equals(116));
    });

    test('A3: Item discount 20% reduces base before SC/tax', () async {
      final repo = _MockProductsRepo({
        'p1': _makeProductDetail(
          categoryName: 'Food',
          serviceTypes: [_dineServiceType(sc: 10, sst: 6)],
          discountSetting: {'method': 'percent', 'value': 20},
        ),
      });
      final stocks = [_makeStock(stockId: 1, uuid: 'p1', price: 100)];
      final bags = [_bagProduct(1, withDiscount: true)];

      final result = await _hook(repo).calculate(
        stocks: stocks,
        orderType: 'dine_in',
        bagProducts: bags,
      );

      // After 20% discount: base = 80, SC = 8, tax = 4.8, total = 92.8
      expect(result.totalItemLevelDiscount, equals(20));
      expect(result.totalServiceCharge, closeTo(8.0, 0.01));
      expect(result.totalTax, closeTo(4.8, 0.01));
      expect(result.finalTotal, closeTo(92.8, 0.01));
    });

    test('A4: Two products same category – both get correct SC/tax amounts',
        () async {
      final repo = _MockProductsRepo({
        'p1': _makeProductDetail(
          categoryName: 'Drinks',
          serviceTypes: [_dineServiceType(sc: 5, sst: 8)],
        ),
        'p2': _makeProductDetail(
          categoryName: 'Drinks',
          serviceTypes: [_dineServiceType(sc: 5, sst: 8)],
        ),
      });
      final stocks = [
        _makeStock(stockId: 10, uuid: 'p1', price: 40),
        _makeStock(stockId: 20, uuid: 'p2', price: 60),
      ];
      final bags = [_bagProduct(10), _bagProduct(20)];

      final result = await _hook(repo).calculate(
        stocks: stocks,
        orderType: 'dine_in',
        bagProducts: bags,
      );

      // subtotal=100, SC=5, tax=8, final=113
      expect(result.originalSubtotal, equals(100));
      expect(result.totalServiceCharge, equals(5));
      expect(result.totalTax, equals(8));
      expect(result.finalTotal, equals(113));
    });
  });
}

// ──────────────────────────────────────────────────────────────────────────────
// GROUP B  –  EnhancedProductHook stockId-key regression
// ──────────────────────────────────────────────────────────────────────────────

void _groupB() {
  group('Group B – EnhancedProductHook stockId-key regression', () {
    // Setup:  3 stocks (A=101 cat1, B=102 cat2, C=103 cat1).
    // calculationData emitted in category-group order: [A, C, B, billDiscount].
    // Old index-based code: stocks[1]=B got calcData[1]=C's SC/tax (BUG).
    // New stockId-keyed code: stocks[1]=B gets B's entry correctly.

    late List<ProductData> stocks;
    late List<Map<String, dynamic>> calcData;

    setUp(() {
      stocks = [
        _makeStock(stockId: 101, uuid: 'cat1-A', price: 100), // cat1
        _makeStock(stockId: 102, uuid: 'cat2-B', price: 50),  // cat2 – no SC
        _makeStock(stockId: 103, uuid: 'cat1-C', price: 80),  // cat1
      ];

      // Simulate what OrderCalculationHook would emit in category-group order:
      // cat1 processed first → A (101), C (103); then cat2 → B (102).
      calcData = [
        {
          'stockId': 101,
          'itemDiscountAmount': 0,
          'serviceChargeAmount': 10.0, // 10% of 100
          'serviceChargeType': 'dine_in',
          'serviceChargePercent': '10',
          'taxAmount': 6.0, // 6% of 100
          'taxPercent': '6',
        },
        {
          'stockId': 103,
          'itemDiscountAmount': 0,
          'serviceChargeAmount': 8.0, // 10% of 80
          'serviceChargeType': 'dine_in',
          'serviceChargePercent': '10',
          'taxAmount': 4.8, // 6% of 80
          'taxPercent': '6',
        },
        {
          'stockId': 102,
          'itemDiscountAmount': 0,
          'serviceChargeAmount': 0.0,
          'serviceChargeType': 'dine_in',
          'serviceChargePercent': '0',
          'taxAmount': 0.0,
          'taxPercent': '0',
        },
        {'billDiscountAmount': 0.0}, // trailing bill-discount row
      ];
    });

    test('B1: B (cat2, no SC/tax) correctly gets 0 SC and 0 tax', () {
      final hook = const EnhancedProductHook();
      final enhanced = hook.build(
        stocks: stocks,
        calculationData: calcData,
        orderType: 'dine_in',
      );

      // stocks[1] = B (stockId=102)
      final bProduct = enhanced.firstWhere((e) => e.stockId == 102);
      expect(bProduct.serviceChargeAmount, equals(0.0),
          reason: 'B is cat2 with no SC — must not get cat1\'s SC');
      expect(bProduct.taxAmount, equals(0.0),
          reason: 'B is cat2 with no SST — must not get cat1\'s SST');
    });

    test('B2: C (cat1) correctly gets cat1 SC and tax, not B\'s zeros', () {
      final hook = const EnhancedProductHook();
      final enhanced = hook.build(
        stocks: stocks,
        calculationData: calcData,
        orderType: 'dine_in',
      );

      final cProduct = enhanced.firstWhere((e) => e.stockId == 103);
      expect(cProduct.serviceChargeAmount, closeTo(8.0, 0.01),
          reason: 'C (price=80, SC=10%) must have SC=8');
      expect(cProduct.taxAmount, closeTo(4.8, 0.01),
          reason: 'C (price=80, SST=6%) must have tax=4.8');
    });

    test('B3: finalPrice for each stock uses its own SC/tax', () {
      final hook = const EnhancedProductHook();
      final enhanced = hook.build(
        stocks: stocks,
        calculationData: calcData,
        orderType: 'dine_in',
      );

      // A: 100 + 10 + 6 = 116
      final a = enhanced.firstWhere((e) => e.stockId == 101);
      expect(a.finalPrice, closeTo(116.0, 0.01));

      // B: 50 + 0 + 0 = 50
      final b = enhanced.firstWhere((e) => e.stockId == 102);
      expect(b.finalPrice, closeTo(50.0, 0.01));

      // C: 80 + 8 + 4.8 = 92.8
      final c = enhanced.firstWhere((e) => e.stockId == 103);
      expect(c.finalPrice, closeTo(92.8, 0.01));
    });
  });
}

// ──────────────────────────────────────────────────────────────────────────────
// GROUP C  –  displayItems SC/tax equivalence
// ──────────────────────────────────────────────────────────────────────────────

void _groupC() {
  group('Group C – displayItems SC/tax field equivalence', () {
    test('C1: uuid field populated in each displayItem (needed for cashout)',
        () async {
      final repo = _MockProductsRepo({
        'p1': _makeProductDetail(
          categoryName: 'Food',
          serviceTypes: [_dineServiceType(sc: 10, sst: 6)],
        ),
      });
      final stocks = [_makeStock(stockId: 301, uuid: 'p1', price: 100)];
      final calcResult = await _hook(repo).calculate(
        stocks: stocks,
        orderType: 'dine_in',
        bagProducts: [_bagProduct(301)],
      );

      final items = _buildDisplayItems(stocks: stocks, calcResult: calcResult);
      expect(items, hasLength(1));
      expect(items[0]['uuid'], equals('p1'),
          reason: 'uuid must be stored so cashout FutureBuilder can call getProductByUuid');
    });

    test('C2: Non-contiguous stocks – each item carries correct SC/tax', () async {
      // A (cat1, SC=10% SST=6%), B (cat2, no SC), C (cat1)
      final repo = _MockProductsRepo({
        'cat1-A': _makeProductDetail(
          categoryName: 'Cat1',
          serviceTypes: [_dineServiceType(sc: 10, sst: 6)],
        ),
        'cat2-B': _makeProductDetail(categoryName: 'Cat2'),
        'cat1-C': _makeProductDetail(
          categoryName: 'Cat1',
          serviceTypes: [_dineServiceType(sc: 10, sst: 6)],
        ),
      });
      final stocks = [
        _makeStock(stockId: 101, uuid: 'cat1-A', price: 100),
        _makeStock(stockId: 102, uuid: 'cat2-B', price: 50),
        _makeStock(stockId: 103, uuid: 'cat1-C', price: 80),
      ];
      final bags = stocks.map((s) => _bagProduct(s.stock!.id!)).toList();

      final calcResult = await _hook(repo).calculate(
        stocks: stocks,
        orderType: 'dine_in',
        bagProducts: bags,
      );

      final items = _buildDisplayItems(stocks: stocks, calcResult: calcResult);

      final itemA = items.firstWhere((i) => i['stockId'] == 101);
      final itemB = items.firstWhere((i) => i['stockId'] == 102);
      final itemC = items.firstWhere((i) => i['stockId'] == 103);

      // A: 10% SC = 10, 6% tax = 6
      expect((itemA['serviceChargeAmount'] as num), closeTo(10.0, 0.01));
      expect((itemA['taxAmount'] as num), closeTo(6.0, 0.01));

      // B: no SC/tax
      expect((itemB['serviceChargeAmount'] as num), equals(0));
      expect((itemB['taxAmount'] as num), equals(0));

      // C: 10% SC = 8, 6% tax = 4.8
      expect((itemC['serviceChargeAmount'] as num), closeTo(8.0, 0.01));
      expect((itemC['taxAmount'] as num), closeTo(4.8, 0.01));
    });

    test('C3: _total (sum of totalPrice+tax+SC) equals hook finalTotal', () async {
      final repo = _MockProductsRepo({
        'p1': _makeProductDetail(
          categoryName: 'Food',
          serviceTypes: [_dineServiceType(sc: 10, sst: 6)],
        ),
        'p2': _makeProductDetail(
          categoryName: 'Food',
          serviceTypes: [_dineServiceType(sc: 10, sst: 6)],
        ),
      });
      final stocks = [
        _makeStock(stockId: 401, uuid: 'p1', price: 100),
        _makeStock(stockId: 402, uuid: 'p2', price: 60),
      ];
      final bags = [_bagProduct(401), _bagProduct(402)];

      final calcResult = await _hook(repo).calculate(
        stocks: stocks,
        orderType: 'dine_in',
        bagProducts: bags,
      );

      final items = _buildDisplayItems(stocks: stocks, calcResult: calcResult);

      // Mirrors TableActiveDialog._total: sum(totalPrice + taxAmount + SC)
      final total = items.fold<num>(
        0,
        (s, item) =>
            s +
            ((item['totalPrice'] as num?) ?? 0) +
            ((item['taxAmount'] as num?) ?? 0) +
            ((item['serviceChargeAmount'] as num?) ?? 0),
      );

      // Hook finalTotal = (100+60) + (100+60)*10% SC + (100+60)*6% tax = 160+16+9.6 = 185.6
      expect(total, closeTo(calcResult.finalTotal as double, 0.01));
    });
  });
}

// ──────────────────────────────────────────────────────────────────────────────
// GROUP D  –  finalizeOrderPayment Hive patching
// ──────────────────────────────────────────────────────────────────────────────

void _groupD() {
  group('Group D – finalizeOrderPayment Hive patching', () {
    late Directory _tempDir;
    late Box _box;

    setUpAll(() async {
      // TestWidgetsFlutterBinding needed so Hive.initFlutter() finds a binding.
      TestWidgetsFlutterBinding.ensureInitialized();
      _tempDir = await Directory.systemTemp.createTemp('hive_flow_test_');
      PathProviderPlatform.instance = _MockPathProvider(_tempDir.path);
      // Force HiveService to initialise once using our mocked path provider.
      await HiveService.init();
    });

    setUp(() async {
      _box = await HiveService.openBox(HiveBoxes.orders);
      await _box.clear();
    });

    tearDownAll(() async {
      await Hive.close();
      await _tempDir.delete(recursive: true);
    });

    /// Helper: write an order to Hive and return the hive key (= orderId).
    Future<int> _seedOrder({
      required int orderId,
      String syncStatus = 'pending',
      int? serverId,
      List<EnhancedProductOrder>? products,
    }) async {
      final prods = products ??
          [
            EnhancedProductOrder(
              stockId: 501,
              countableId: null,
              quantity: 2,
              originalPrice: 100.0,
              finalPrice: 112.0, // 100 + 10(SC) + 2(tax)
              itemDiscountAmount: 0,
              serviceChargeAmount: 10.0,
              serviceChargeType: 'dine_in',
              serviceChargePercent: 10,
              taxAmount: 2.0,
              taxPercent: 2,
            ),
          ];

      final order = OrderHiveModel(
        id: orderId,
        body: OrderBodyData(
          deliveryType: 'dine_in',
          phone: null,
          address: AddressModel(),
          deliveryDate: '',
          deliveryTime: '',
          bagData: BagData(),
          enhancedProducts: prods,
        ),
        status: 'new',
        totalPrice: prods.fold<num>(0, (s, p) => s + p.finalPrice),
        meta: OrderMeta(
          syncStatus: syncStatus,
          updatedAt: DateTime.now().toIso8601String(),
          serverId: serverId,
        ),
      );
      await _box.put(orderId, order.toJson());
      return orderId;
    }

    test('D1: payment fields written to order body', () async {
      final orderId = await _seedOrder(orderId: 1000001);

      final repo = OrdersHiveRepository();
      final result = await repo.finalizeOrderPayment(
        orderId: orderId,
        paidAmount: 250.0,
        billDiscountAmount: 0.0,
        roundingAmount: 0.0,
        refundAmount: 26.0,
        transactionId: 'TXN-001',
        queueNo: '0001',
      );

      expect(result, isA<ApiResult<dynamic>>());
      result.when(
        success: (_) {},
        failure: (err, _) => fail('Expected success but got failure: $err'),
      );

      final raw = Map<String, dynamic>.from(_box.get(orderId) as Map);
      final updated = OrderHiveModel.fromJson(raw);

      expect(updated.body?.transactionId, equals('TXN-001'));
      expect(updated.body?.queueNo, equals('0001'));
      expect(updated.body?.paidAmount, equals(250.0));
      expect(updated.body?.refundAmount, equals(26.0));
    });

    test('D2: totalPrice recalculated as sum(finalPrice) - billDiscount + rounding',
        () async {
      // Two products: finalPrice 112 + 80 = 192; bill discount 10, rounding 0.05
      final products = [
        EnhancedProductOrder(
          stockId: 502,
          countableId: null,
          quantity: 1,
          originalPrice: 100.0,
          finalPrice: 112.0,
          itemDiscountAmount: 0,
          serviceChargeAmount: 10.0,
          serviceChargeType: 'dine_in',
          serviceChargePercent: 10,
          taxAmount: 2.0,
          taxPercent: 2,
        ),
        EnhancedProductOrder(
          stockId: 503,
          countableId: null,
          quantity: 1,
          originalPrice: 70.0,
          finalPrice: 80.0,
          itemDiscountAmount: 0,
          serviceChargeAmount: 7.0,
          serviceChargeType: 'dine_in',
          serviceChargePercent: 10,
          taxAmount: 3.0,
          taxPercent: 4.3,
        ),
      ];

      final orderId = await _seedOrder(orderId: 1000002, products: products);

      final repo = OrdersHiveRepository();
      await repo.finalizeOrderPayment(
        orderId: orderId,
        paidAmount: 200.0,
        billDiscountAmount: 10.0,
        billDiscountType: 'amount',
        roundingAmount: 0.05,
        refundAmount: 7.95,
        transactionId: 'TXN-002',
        queueNo: '0002',
      );

      final raw = Map<String, dynamic>.from(_box.get(orderId) as Map);
      final updated = OrderHiveModel.fromJson(raw);

      // 192 - 10 + 0.05 = 182.05
      expect(updated.totalPrice, closeTo(182.05, 0.001));
    });

    test('D3: order found by serverId (not just localId)', () async {
      const localId = 1000003;
      const serverId = 9999;
      await _seedOrder(orderId: localId, syncStatus: 'synced', serverId: serverId);

      final repo = OrdersHiveRepository();
      final result = await repo.finalizeOrderPayment(
        orderId: serverId, // look up by server id
        paidAmount: 100.0,
        billDiscountAmount: 0.0,
        roundingAmount: 0.0,
        refundAmount: 0.0,
        transactionId: 'TXN-S-003',
        queueNo: '0003',
      );

      result.when(
        success: (_) {},
        failure: (err, _) =>
            fail('Should find order by serverId; got: $err'),
      );

      final raw = Map<String, dynamic>.from(_box.get(localId) as Map);
      final updated = OrderHiveModel.fromJson(raw);
      expect(updated.body?.transactionId, equals('TXN-S-003'));
    });

    test('D4: syncStatus preserved after finalizeOrderPayment', () async {
      final orderId = await _seedOrder(orderId: 1000004, syncStatus: 'synced');

      final repo = OrdersHiveRepository();
      await repo.finalizeOrderPayment(
        orderId: orderId,
        paidAmount: 150.0,
        billDiscountAmount: 0.0,
        roundingAmount: 0.0,
        refundAmount: 0.0,
        transactionId: 'TXN-004',
        queueNo: '0004',
      );

      final raw = Map<String, dynamic>.from(_box.get(orderId) as Map);
      final updated = OrderHiveModel.fromJson(raw);
      expect(updated.meta?.syncStatus, equals('synced'),
          reason: 'finalizeOrderPayment must not reset syncStatus');
    });

    test('D5: order not found returns ApiResult.failure', () async {
      final repo = OrdersHiveRepository();
      final result = await repo.finalizeOrderPayment(
        orderId: 99999999, // does not exist in box
        paidAmount: 0.0,
        billDiscountAmount: 0.0,
        roundingAmount: 0.0,
        refundAmount: 0.0,
        transactionId: '',
        queueNo: '',
      );

      var sawFailure = false;
      result.when(
        success: (_) => fail('Expected failure for missing order'),
        failure: (err, _) {
          sawFailure = true;
          expect(err, isNotEmpty);
        },
      );
      expect(sawFailure, isTrue);
    });

    test('D6: billDiscountType and billDiscountPercent stored correctly',
        () async {
      final orderId = await _seedOrder(orderId: 1000006);

      final repo = OrdersHiveRepository();
      await repo.finalizeOrderPayment(
        orderId: orderId,
        paidAmount: 106.4,
        billDiscountAmount: 5.6,
        billDiscountType: 'percent',
        billDiscountPercent: 5.0,
        roundingAmount: 0.0,
        refundAmount: 0.0,
        transactionId: 'TXN-006',
        queueNo: '0006',
      );

      final raw = Map<String, dynamic>.from(_box.get(orderId) as Map);
      final updated = OrderHiveModel.fromJson(raw);

      expect(updated.body?.billDiscountAmount, equals(5.6));
      expect(updated.body?.billDiscountType, equals('percent'));
      expect(updated.body?.billDiscountPercent, equals(5.0));
    });
  });
}

// ──────────────────────────────────────────────────────────────────────────────
// Entry point
// ──────────────────────────────────────────────────────────────────────────────

void main() {
  _groupA();
  _groupB();
  _groupC();
  _groupD();
}
