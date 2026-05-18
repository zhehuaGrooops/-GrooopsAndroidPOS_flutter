import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_desktop/src/repository/hive_repository/orders_hive_repository.dart';
import 'package:admin_desktop/src/core/constants/hive_boxes.dart';
import 'package:admin_desktop/src/core/db/hive_service.dart';
import 'package:admin_desktop/src/core/utils/local_storage.dart';
import 'package:admin_desktop/src/models/data/order_data.dart';
import 'package:admin_desktop/src/models/data/order_hive_model.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  late OrdersHiveRepository repo;

  setUpAll(() async {
    PathProviderPlatform.instance = MockPathProvider();
    await HiveService.init();
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  setUp(() async {
    final box = await HiveService.openBox(HiveBoxes.orders);
    await box.clear();
    repo = OrdersHiveRepository();
  });

  group('OrdersHiveRepository fetchOrderById Tests', () {
    test('fetchOrderById should successfully return order when it exists',
        () async {
      // Given
      final box = await HiveService.openBox(HiveBoxes.orders);
      final orderId = 123;
      final orderData = {
        'id': orderId,
        'status': 'new',
        'body': {'note': 'Test Order'}
      };
      await box.put(orderId, orderData);

      // When
      final result = await repo.fetchOrderById(orderId);

      // Then
      result.when(
        success: (data) {
          expect(data.id, orderId);
          expect(data.status, 'new');
          expect(data.body?.note, 'Test Order');
        },
        failure: (e, _) => fail('Should have succeeded but failed with: $e'),
      );
    });

    test(
        'fetchOrderById should successfully return order when searching by serverId',
        () async {
      // Given
      final box = await HiveService.openBox(HiveBoxes.orders);
      final localId = 123;
      final serverId = 456;
      final orderData = {
        'id': localId,
        'status': 'new',
        '_meta': {'serverId': serverId}
      };
      // Put with a different key to ensure we are searching by value
      await box.put(999, orderData);

      // When - searching by serverId
      final result = await repo.fetchOrderById(serverId);

      // Then
      result.when(
        success: (data) {
          expect(data.id, localId);
          expect(data.meta?.serverId, serverId);
        },
        failure: (e, _) => fail('Should have succeeded but failed with: $e'),
      );
    });

    test(
        'fetchOrderById should successfully return order when searching by id (different from key)',
        () async {
      // Given
      final box = await HiveService.openBox(HiveBoxes.orders);
      final localId = 123;
      final orderData = {
        'id': localId,
        'status': 'new',
      };
      // Put with a different key
      await box.put(999, orderData);

      // When - searching by localId
      final result = await repo.fetchOrderById(localId);

      // Then
      result.when(
        success: (data) {
          expect(data.id, localId);
        },
        failure: (e, _) => fail('Should have succeeded but failed with: $e'),
      );
    });

    test('fetchOrderById should return failure when order ID does not exist',
        () async {
      // Given
      final orderId = 999;

      // When
      final result = await repo.fetchOrderById(orderId);

      // Then
      result.when(
        success: (_) => fail('Should have failed for non-existent ID'),
        failure: (error, _) {
          expect(error, contains('not found in local database'));
        },
      );
    });

    test('fetchOrderById should return failure when data conversion fails',
        () async {
      // Given
      final box = await HiveService.openBox(HiveBoxes.orders);
      final orderId = 456;
      // Storing data where id matches so it's found, but other fields have invalid types
      // status expects a String, but we provide an int
      await box.put(orderId, {
        'id': orderId,
        'status': 123,
      });

      // When
      final result = await repo.fetchOrderById(orderId);

      // Then
      result.when(
        success: (_) => fail('Should have failed due to data conversion error'),
        failure: (error, _) {
          expect(error, contains('Failed to convert order data'));
        },
      );
    });

    test('OrderHiveModel should persist shop snapshot into JSON', () {
      final model = OrderHiveModel(
        id: 1,
        status: 'new',
        shopSnapshot: {
          'id': 7,
          'translation': {
            'title': 'Main Shop',
            'address': '221B Baker Street',
          }
        },
      );

      final json = model.toJson();

      expect(json['shop_snapshot'], isA<Map<String, dynamic>>());
      expect(json['shop_snapshot']['translation']['title'], 'Main Shop');
      expect(
        json['shop_snapshot']['translation']['address'],
        '221B Baker Street',
      );
    });

    test('OrderData should hydrate shop from shop_snapshot fallback', () {
      final order = OrderData.fromJson({
        'id': 1,
        'status': 'new',
        'shop_snapshot': {
          'id': 7,
          'translation': {
            'title': 'Main Shop',
            'address': '221B Baker Street',
          }
        }
      });

      expect(order.shop?.translation?.title, 'Main Shop');
      expect(order.shop?.translation?.address, '221B Baker Street');
    });
  });
}
