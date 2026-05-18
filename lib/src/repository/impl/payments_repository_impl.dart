import 'dart:convert';

import 'package:admin_desktop/src/core/utils/utils.dart';
import 'package:flutter/material.dart';

import '../../core/di/injection.dart';
import '../../core/handlers/handlers.dart';
import '../../models/models.dart';
import '../repository.dart';

class PaymentsRepositoryImpl extends PaymentsRepository {
  @override
  Future<ApiResult<PaymentsResponse>> getPayments() async {
    try {
      final client = inject<HttpService>().client(requireAuth: true);
      final response = await client.get('/api/v1/rest/payments');

      return ApiResult.success(
        data: PaymentsResponse.fromJson(response.data),
      );
    } catch (e, stackTrace) {
      debugPrint('==> get payments failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'PaymentsRepositoryImpl.getPayments',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<TransactionsResponse>> createTransaction({
    required int orderId,
    required int paymentId,
  }) async {
    final data = {'payment_sys_id': paymentId};
    debugPrint('===> create transaction body: ${jsonEncode(data)}');
    debugPrint('===> create transaction order id: $orderId');
    try {
      final client = inject<HttpService>().client(requireAuth: true);
      final response = await client.post(
        '/api/v1/payments/order/$orderId/transactions',
        data: data,
      );
      return ApiResult.success(
        data: TransactionsResponse.fromJson(response.data),
      );
    } catch (e, stackTrace) {
      debugPrint('==> create transaction failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'PaymentsRepositoryImpl.createTransaction',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<List<Map<String, dynamic>>>> getTransactionsBySessionId(
    int sessionId,
  ) async {
    // This is primarily for local Hive storage, but could be implemented for API if needed.
    return const ApiResult.success(data: []);
  }
}
