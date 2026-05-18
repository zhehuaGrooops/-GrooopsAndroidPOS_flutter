import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/di/injection.dart';
import '../../core/handlers/handlers.dart';
import '../../core/utils/app_helpers.dart';
import '../../core/utils/local_storage.dart';
import '../repository.dart';

class CashSessionsRepositoryImpl extends CashSessionsRepository {
  @override
  Future<ApiResult<dynamic>> openCashSession(
      {required Map<String, dynamic> body}) async {
    try {
      debugPrint('==> open cash session request: ${jsonEncode(body)}');
      final client = inject<HttpService>().client(requireAuth: true);
      final response = await client.post(
        '/api/v1/dashboard/${LocalStorage.getUser()?.role}/cash-sessions/open',
        data: body,
      );
      return ApiResult.success(data: response.data);
    } catch (e, stackTrace) {
      debugPrint('==> open cash session failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'CashSessionsRepositoryImpl.openCashSession',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<dynamic>> closeCashSession({
    required int id,
    Map<String, dynamic>? summary,
  }) async {
    try {
      final client = inject<HttpService>().client(requireAuth: true);
      final body = {
        if (summary != null) 'transactions_summary': summary,
        'closed_at': DateTime.now().toIso8601String(),
      };
      final response = await client.post(
        '/api/v1/dashboard/${LocalStorage.getUser()?.role}/cash-sessions/$id/close',
        data: body,
      );
      return ApiResult.success(data: response.data);
    } catch (e, stackTrace) {
      debugPrint('==> close cash session failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'CashSessionsRepositoryImpl.closeCashSession',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<dynamic>> activeCashSession() async {
    try {
      final client = inject<HttpService>().client(requireAuth: true);
      final response = await client.get(
        '/api/v1/dashboard/${LocalStorage.getUser()?.role}/cash-sessions/active',
      );
      return ApiResult.success(data: response.data);
    } catch (e, stackTrace) {
      debugPrint('==> get active cash session failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'CashSessionsRepositoryImpl.activeCashSession',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }
}
