import 'package:flutter_test/flutter_test.dart';
import 'package:admin_desktop/src/repository/hive_repository/cash_sessions_hive_repository.dart';
import 'package:admin_desktop/src/core/handlers/handlers.dart';
import 'package:admin_desktop/src/repository/repository.dart';
import 'package:admin_desktop/src/models/models.dart';
import 'package:admin_desktop/src/core/constants/hive_boxes.dart';
import 'package:admin_desktop/src/core/utils/local_storage.dart';
import 'package:hive/hive.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:get_it/get_it.dart';

class MockPathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async => Directory.systemTemp.path;
  @override
  Future<String?> getApplicationSupportPath() async =>
      Directory.systemTemp.path;
  @override
  Future<String?> getApplicationDocumentsPath() async =>
      Directory.systemTemp.path;
  @override
  Future<String?> getExternalStoragePath() async => Directory.systemTemp.path;
  @override
  Future<List<String>?> getExternalCachePaths() async =>
      [Directory.systemTemp.path];
  @override
  Future<List<String>?> getExternalStoragePaths(
          {StorageDirectory? type}) async =>
      [Directory.systemTemp.path];
  @override
  Future<String?> getDownloadsPath() async => Directory.systemTemp.path;
}

class MockOrdersRepo extends Fake implements OrdersRepository {
  Map<int, double> prices = {};
  double defaultPrice = 100.0;

  @override
  Future<ApiResult<OrderHiveModel>> fetchOrderById(int orderId) async {
    return ApiResult.success(
      data: OrderHiveModel(
        id: orderId,
        totalPrice: prices[orderId] ?? defaultPrice,
        body: OrderBodyData(
          deliveryType: 'dine_in',
          phone: '',
          address: AddressModel(),
          deliveryDate: '',
          deliveryTime: '',
          bagData: BagData(),
          enhancedProducts: [],
        ),
      ),
    );
  }
}

class MockPaymentsRepo extends Fake implements PaymentsRepository {
  List<Map<String, dynamic>> transactions = [];

  @override
  Future<ApiResult<PaymentsResponse>> getPayments() async {
    return ApiResult.success(data: PaymentsResponse(data: []));
  }

  @override
  Future<ApiResult<List<Map<String, dynamic>>>> getTransactionsBySessionId(
      int sessionId) async {
    final filtered =
        transactions.where((t) => t['cash_session_id'] == sessionId).toList();
    return ApiResult.success(data: filtered);
  }
}

void main() {
  late CashSessionsHiveRepository repo;
  late MockOrdersRepo mockOrders;
  late MockPaymentsRepo mockPayments;

  setUpAll(() async {
    PathProviderPlatform.instance = MockPathProvider();
    final tempDir = await Directory.systemTemp.createTemp();
    Hive.init(tempDir.path);
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  setUp(() async {
    // Clear Hive boxes
    final box = await Hive.openBox(HiveBoxes.cashSessions);
    await box.clear();

    mockOrders = MockOrdersRepo();
    mockPayments = MockPaymentsRepo();

    // Register mocks in GetIt
    final getIt = GetIt.instance;
    getIt.allowReassignment = true;
    getIt.registerSingleton<OrdersRepository>(mockOrders);
    getIt.registerSingleton<PaymentsRepository>(mockPayments);

    repo = CashSessionsHiveRepository(ordersRepo: mockOrders);
  });

  group('CashSessionsHiveRepository Offline Tests', () {
    test('openCashSession should create a local session with pending status',
        () async {
      // When
      final result = await repo.openCashSession(body: {'amount': 50.0});

      // Then
      result.when(
        success: (data) {
          expect(data['data']['opening_balance'], 50.0);
          expect(data['data']['state'], 'open');
          expect(data['data']['_meta']['syncStatus'], 'pending');
        },
        failure: (e, _) => fail('Should succeed locally'),
      );

      final box = await Hive.openBox(HiveBoxes.cashSessions);
      expect(box.length, 1);
      final stored = box.values.first;
      expect(stored['_meta']['syncStatus'], 'pending');
    });

    test('activeCashSession should return the current local active session',
        () async {
      // Given
      final box = await Hive.openBox(HiveBoxes.cashSessions);
      await box.put(123, {
        'id': 123,
        'opened_at': '2025-01-01',
        'closed_at': null,
        'state': 'open',
      });

      // When
      final result = await repo.activeCashSession();

      // Then
      result.when(
        success: (data) => expect(data['data']['id'], 123),
        failure: (e, _) => fail('Should succeed'),
      );
    });

    test(
        'closeCashSession should calculate summary and set close_pending status',
        () async {
      // Given
      final sessionId = 500;
      final box = await Hive.openBox(HiveBoxes.cashSessions);
      await box.put(sessionId, {
        'id': sessionId,
        'state': 'open',
        'closed_at': null,
        'opening_balance': 0.0,
      });

      mockPayments.transactions = [
        {
          'cash_session_id': sessionId,
          'order_id': 1,
          'price': 100.0,
          'payment_tag': 'cash'
        }
      ];

      // When
      final result = await repo.closeCashSession(id: sessionId);

      // Then
      result.when(
        success: (data) {
          expect(data['data']['state'], 'closed');
          expect(data['data']['_meta']['syncStatus'], 'close_pending');
          expect(data['data']['transactions_summary'], isNotNull);
          expect(data['data']['revenue_amount'], 100.0);
        },
        failure: (e, _) => fail('Should succeed locally: $e'),
      );

      final stored = box.get(sessionId);
      expect(stored['_meta']['syncStatus'], 'close_pending');
    });

    test(
        'calculateSessionSummaryForTest should correctly group MOP collections',
        () async {
      // Given
      final sessionId = 800;
      final box = await Hive.openBox(HiveBoxes.cashSessions);
      await box.put(sessionId, {
        'id': sessionId,
        'opening_balance': 0,
        'closed_at': DateTime.now().toIso8601String(),
      });

      // Different prices for different orders
      mockOrders.prices = {1: 100.0, 2: 50.0};

      // Two transactions with different MOPs
      mockPayments.transactions = [
        {
          'cash_session_id': sessionId,
          'order_id': 1,
          'price': 100.0,
          'payment_tag': 'cash'
        },
        {
          'cash_session_id': sessionId,
          'order_id': 2,
          'price': 50.0,
          'payment_tag': 'card'
        },
      ];

      // When
      final summary = await repo.calculateSessionSummaryForTest(sessionId);

      // Then
      expect(summary['mop_collections']['items'], hasLength(2));

      final cashItem = summary['mop_collections']['items']
          .firstWhere((i) => i['method'].toString().toLowerCase() == 'cash');
      final cardItem = summary['mop_collections']['items']
          .firstWhere((i) => i['method'].toString().toLowerCase() == 'card');

      expect(cashItem['amount'], 100.0);
      expect(cardItem['amount'], 50.0);
    });

    test('closeCashSession should return error if session not found', () async {
      // When
      final result = await repo.closeCashSession(id: 9999);

      // Then
      result.when(
        success: (_) => fail('Should have failed'),
        failure: (error, _) => expect(error, 'Session not found'),
      );
    });
  });
}
