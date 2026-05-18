import 'package:flutter_test/flutter_test.dart';
import 'package:admin_desktop/src/core/db/hive_service.dart';
import 'package:admin_desktop/src/core/constants/hive_boxes.dart';
import 'package:admin_desktop/src/repository/hive_repository/cash_sessions_hive_repository.dart';
import 'package:admin_desktop/src/repository/hive_repository/payments_hive_repository.dart';
import 'package:admin_desktop/src/core/utils/local_storage.dart';
import 'package:admin_desktop/src/repository/repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'dart:io';
import 'package:hive/hive.dart';
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

void main() {
  setUp(() async {
    PathProviderPlatform.instance = MockPathProvider();
    final tempDir = await Directory.systemTemp.createTemp();
    Hive.init(tempDir.path);
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    final getIt = GetIt.I;
    if (getIt.isRegistered<PaymentsRepository>()) {
      getIt.unregister<PaymentsRepository>();
    }
    getIt.registerSingleton<PaymentsRepository>(PaymentsHiveRepository());
  });

  tearDown(() async {
    await Hive.close();
  });

  group('CashSessionsHiveRepository Calculation Logic', () {
    test(
        'calculateSessionSummary computes correct totals matching Laravel logic',
        () async {
      final repo = CashSessionsHiveRepository();

      final ordersBox = await HiveService.openBox(HiveBoxes.orders);
      final paymentsBox = await HiveService.openBox(HiveBoxes.payments);
      final transactionsBox = await HiveService.openBox(HiveBoxes.transactions);
      final cashSessionsBox = await HiveService.openBox(HiveBoxes.cashSessions);

      const sessionId = 123;
      const orderId = 456;
      const paymentId = 789;

      // 1. Mock Payment/Transaction
      await transactionsBox.put(1, {
        'id': 1,
        'cash_session_id': sessionId,
        'order_id': orderId,
        'payment_id': paymentId,
        'payment_tag': 'cash',
        'price': 115.0, // Total paid
      });

      // 2. Mock Payment Method
      await paymentsBox.put('payment_$paymentId', {
        'id': paymentId,
        'tag': 'cash',
      });

      // 3. Mock Order Data in OrderHiveModel format
      final orderData = {
        'id': orderId,
        'body': {
          'delivery_type': 'dine_in',
          'phone': '123456789',
          'delivery_date': '2025-12-23',
          'delivery_time': '12:00',
          'bag_data': {'bag_products': []},
          'enhanced_products': [
            {
              'original_price': 100.0,
              'tax_amount': 15.0,
              'service_charge_amount': 10.0,
              'quantity': 1,
              'item_discount_amount': 0.0,
              'stock_id': 1,
              'final_price': 125.0,
            }
          ],
          'bill_discount_amount': 10.0,
        },
        'status': 'delivered',
        'total_price': 115.0, // (100 + 15 + 10) - 10 discount = 115
      };
      await ordersBox.put(orderId, orderData);

      // 4. Mock Current Session
      await cashSessionsBox.put(sessionId, {
        'id': sessionId,
        'shop_id': 1,
        'user_id': 1,
        'status': 'opened',
      });

      // 5. Run calculation
      final summary = await repo.calculateSessionSummaryForTest(sessionId);

      // 6. Assertions matching Laravel's computeRevenueSummary & computeCategories
      // revenueBreakdown[method] = txAmount - billDiscount = (100 - 0) - 10 = 90
      expect(summary['revenue_summary']['cash_sales'], 90.0);
      expect(summary['revenue_summary']['tax'], 15.0);
      expect(summary['revenue_summary']['service_charge'], 10.0);
      expect(summary['revenue_summary']['total'], 115.0);

      // categories: baseAmount = 125, discountShare = (125/125)*10 = 10, amount = 125-10 = 115
      expect(summary['categories']['items'][0]['amount'], 115.0);
      expect(summary['categories']['items'][0]['qty'], 1);

      expect(summary['mop_collections']['total'], 115.0);
      expect(summary['mop_collections']['items'][0]['method'], 'Cash');

      // tax_summary: srGross = 10 (service_charge), srTax = 15 (tax), srNet = 25
      // nonGross = 90 (cash), nonTax = 0, nonNet = 90
      // totalGross = 10 + 90 = 100, totalTax = 15, totalNet = 115
      expect(summary['tax_summary']['gross'], 100.0);
      expect(summary['tax_summary']['tax'], 15.0);
      expect(summary['tax_summary']['net'], 115.0);
    });
  });
}
