import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:admin_desktop/src/core/constants/hive_boxes.dart';
import 'package:admin_desktop/src/core/handlers/http_service.dart';
import 'package:admin_desktop/src/core/sync/payment_sync_handler.dart';
import 'package:admin_desktop/src/core/sync/sync_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
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
  late PaymentSyncHandler handler;
  late StreamController<SyncProgress> progressController;

  setUp(() async {
    await HiveService.init();
    await (await HiveService.openBox(HiveBoxes.payments)).clear();

    mockDio = Dio();
    progressController = StreamController<SyncProgress>.broadcast();
    handler = PaymentSyncHandler(
      httpService: MockHttpService(mockDio),
      progressSink: progressController.sink,
    );
  });

  tearDown(() async {
    await progressController.close();
    await Hive.close();
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

  group('PaymentSyncHandler', () {
    test('pullPayments success stores data in Hive', () async {
      final mockData = {
        'data': [
          {'id': 1, 'tag': 'cash', 'active': true},
          {'id': 2, 'tag': 'card', 'active': true},
        ]
      };

      mockDio.httpClientAdapter = MockAdapter((options) {
        if (options.path == '/api/v1/rest/payments') {
          return ResponseBody.fromString(
            jsonEncode(mockData),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }
        return ResponseBody.fromString('', 404);
      });

      final progressFuture = progressController.stream.first;

      final result = await handler.pullPayments();

      expect(result, true);

      // Verify Hive storage
      final box = await HiveService.openBox(HiveBoxes.payments);
      expect(box.length, 2);
      expect(box.get(1)['tag'], 'cash');
      expect(box.get(2)['tag'], 'card');

      // Verify progress report
      final progress = await progressFuture;
      expect(progress.entity, 'payments');
      expect(progress.processed, 2);
      expect(progress.total, 2);
    });

    test('pullPayments failure handles API error', () async {
      mockDio.httpClientAdapter = MockAdapter((options) {
        return ResponseBody.fromString('Error', 500);
      });

      final progressFuture = progressController.stream.first;

      final result = await handler.pullPayments();

      expect(result, false);

      // Verify Hive is still empty (or at least not updated with new data)
      final box = await HiveService.openBox(HiveBoxes.payments);
      expect(box.isEmpty, true);

      // Verify progress report with error
      final progress = await progressFuture;
      expect(progress.entity, 'payments');
      expect(progress.errors, isNotEmpty);
    });

    test('pullPayments handles empty response', () async {
      final mockData = {'data': []};

      mockDio.httpClientAdapter = MockAdapter((options) {
        return ResponseBody.fromString(
          jsonEncode(mockData),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final result = await handler.pullPayments();

      expect(result, true);

      final box = await HiveService.openBox(HiveBoxes.payments);
      expect(box.isEmpty, true);
    });
  });
}
