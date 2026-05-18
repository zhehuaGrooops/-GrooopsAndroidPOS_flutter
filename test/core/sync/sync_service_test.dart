import 'dart:convert';
import 'dart:io';

import 'package:admin_desktop/src/core/constants/hive_boxes.dart';
import 'package:admin_desktop/src/core/handlers/http_service.dart';
import 'package:admin_desktop/src/core/sync/sync_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:admin_desktop/src/core/db/hive_service.dart';

class MockHttpService implements HttpService {
  final Dio _dio;
  MockHttpService(this._dio);

  @override
  Dio client({bool requireAuth = false}) {
    return _dio;
  }
}

class MockAdapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions options) handler;

  MockAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<List<int>>? requestStream, Future? cancelFuture) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Dio mockDio;
  late SyncService syncService;

  setUp(() async {
    // Initialize Hive via HiveService to match app behavior (uses current dir '.' on failure)
    await HiveService.init();

    // Clear boxes to ensure clean state
    await (await HiveService.openBox(HiveBoxes.orders)).clear();

    // Initialize SharedPreferences
    SharedPreferences.setMockInitialValues({});

    // Setup Mock Dio
    mockDio = Dio();
    syncService = SyncService();
    syncService.mockHttpService = MockHttpService(mockDio);
  });

  tearDown(() async {
    // Clean up Hive boxes
    await Hive.close();
    // Clean up files in current directory
    final dir = Directory.current;
    final files = dir.listSync();
    for (final file in files) {
      if (file is File &&
          (file.path.endsWith('.hive') || file.path.endsWith('.lock'))) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }
  });

  group('SyncService Transaction Submission', () {
    test('submitPaymentTransaction success', () async {
      // Setup Hive data
      final box = await HiveService.openBox(HiveBoxes.orders);
      final orderId = 123;
      final paymentId = 456;
      final hiveKey = 'order_123';

      await box.put(hiveKey, {
        'id': 'uuid_123',
        'payment_id': paymentId,
        'status': 'new',
        '_meta': {
          'serverId': orderId,
          'syncStatus': 'synced',
          'transactionStatus': 'pending'
        }
      });

      // Mock API success
      mockDio.httpClientAdapter = MockAdapter((options) {
        if (options.path
            .contains('/api/v1/payments/order/$orderId/transactions')) {
          return ResponseBody.fromString(
            jsonEncode({'success': true}),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }
        return ResponseBody.fromString('', 404);
      });

      final result =
          await syncService.submitPaymentTransaction(orderId, hiveKey: hiveKey);

      expect(result, true);

      // Verify Hive update
      final updatedEntry = box.get(hiveKey);
      final meta = updatedEntry['_meta'] as Map;
      expect(meta['transactionStatus'], 'synced');
      expect(meta['transactionUpdatedAt'], isNotNull);
    });

    test('submitPaymentTransaction fails when order not found', () async {
      final result = await syncService.submitPaymentTransaction(999);
      expect(result, false);
    });

    test('submitPaymentTransaction fails when payment_id missing', () async {
      final box = await HiveService.openBox(HiveBoxes.orders);
      final orderId = 124;
      final hiveKey = 'order_124';

      await box.put(hiveKey, {
        'id': 'uuid_124',
        'payment_id': null, // Missing payment ID
        '_meta': {
          'serverId': orderId,
        }
      });

      final result =
          await syncService.submitPaymentTransaction(orderId, hiveKey: hiveKey);
      expect(result, false);
    });

    test('submitPaymentTransaction handles API error', () async {
      final box = await HiveService.openBox(HiveBoxes.orders);
      final orderId = 125;
      final paymentId = 457;
      final hiveKey = 'order_125';

      await box.put(hiveKey, {
        'id': 'uuid_125',
        'payment_id': paymentId,
        '_meta': {
          'serverId': orderId,
        }
      });

      // Mock API error
      mockDio.httpClientAdapter = MockAdapter((options) {
        return ResponseBody.fromString('', 500);
      });

      final result =
          await syncService.submitPaymentTransaction(orderId, hiveKey: hiveKey);
      expect(result, false);

      // Verify Hive NOT updated
      final updatedEntry = box.get(hiveKey);
      final meta = updatedEntry['_meta'] as Map;
      expect(meta['transactionStatus'],
          isNull); // Should remain as it was (or null/pending)
    });
  });
}
