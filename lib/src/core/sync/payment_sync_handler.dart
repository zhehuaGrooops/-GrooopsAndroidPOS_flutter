import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../models/models.dart';
import '../handlers/handlers.dart';
import '../db/hive_service.dart';
import '../constants/hive_boxes.dart';
import '../utils/utils.dart';
import 'sync_models.dart';

/// Handler for payment synchronization tasks.
class PaymentSyncHandler {
  final HttpService _httpService;
  final StreamSink<SyncProgress> _progressSink;

  PaymentSyncHandler({
    required HttpService httpService,
    required StreamSink<SyncProgress> progressSink,
  })  : _httpService = httpService,
        _progressSink = progressSink;

  /// Gets a Dio client with appropriate authentication.
  Dio _getClient({required bool requireAuth}) {
    return _httpService.client(requireAuth: requireAuth);
  }

  /// Pulls payment data from the server and stores it in Hive.
  Future<bool> pullPayments() async {
    try {
      debugPrint("Pulling payment data from server...");
      final result = await fetchPayments();

      return await result.when(
        success: (response) async {
          final payments = response.data ?? [];
          final box = await HiveService.openBox(HiveBoxes.payments);
          await box.clear();

          for (final payment in payments) {
            if (payment.id != null) {
              await box.put(payment.id, payment.toJson());
            }
          }

          reportProgress(processed: payments.length, total: payments.length);
          debugPrint(
              "Finished pulling payment data. Processed ${payments.length} items.");
          return true;
        },
        failure: (error, statusCode) {
          debugPrint("Failed to pull payments: $error (Status: $statusCode)");
          reportProgress(processed: 0, total: 0, errors: [error]);
          return false;
        },
      );
    } catch (e, stackTrace) {
      debugPrint("Unexpected error during payment sync: $e");
      AppHelpers.recordSyncErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'PaymentSyncHandler.pullPayments',
      );
      reportProgress(processed: 0, total: 0, errors: [e.toString()]);
      return false;
    }
  }

  /// Fetches payment data from the API.
  Future<ApiResult<PaymentsResponse>> fetchPayments() async {
    try {
      final client = _getClient(requireAuth: true);
      final response = await client.get('/api/v1/rest/payments');

      if (response.statusCode == 200) {
        final parsed = PaymentsResponse.fromJson(response.data);
        return ApiResult.success(data: parsed);
      } else {
        return ApiResult.failure(
          error: "Failed to fetch payments: ${response.statusCode}",
          statusCode: response.statusCode,
        );
      }
    } catch (e, stackTrace) {
      AppHelpers.recordSyncErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'PaymentSyncHandler.fetchPayments',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  /// Reports progress to the sync stream.
  void reportProgress({
    required int processed,
    required int total,
    List<String> errors = const [],
  }) {
    _progressSink.add(SyncProgress(
      phase: 'pull',
      entity: 'payments',
      processed: processed,
      total: total,
      errors: errors,
    ));
  }
}
