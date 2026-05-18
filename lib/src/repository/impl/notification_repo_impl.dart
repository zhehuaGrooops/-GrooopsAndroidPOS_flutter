import 'package:admin_desktop/src/core/utils/utils.dart';
import 'package:admin_desktop/src/models/data/count_of_notifications_data.dart';
import 'package:admin_desktop/src/models/data/notification_data.dart';
import 'package:admin_desktop/src/models/data/notification_transactions_data.dart';
import 'package:admin_desktop/src/models/data/read_one_notification_data.dart';
import 'package:admin_desktop/src/repository/notification_repository.dart';
import 'package:flutter/material.dart';
import '../../core/di/injection.dart';
import '../../core/handlers/handlers.dart';

class NotificationRepositoryImpl extends NotificationRepository {
  @override
  Future<ApiResult<TransactionListResponse>> getTransactions(
      {int? page}) async {
    final data = {
      if (page != null) 'page': page,
      'perPage': 4,
      'lang': LocalStorage.getLanguage()?.locale ?? 'en',
      'model': 'orders'
    };
    try {
      final client = inject<HttpService>().client(requireAuth: true);
      final response = await client.get(
        '/api/v1/dashboard/${LocalStorage.getUser()?.role}/transactions/paginate',
        queryParameters: data,
      );
      return ApiResult.success(
        data: TransactionListResponse.fromJson(response.data),
      );
    } catch (e, stackTrace) {
      debugPrint('==> get getTransactions failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'NotificationRepositoryImpl.getTransactions',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<NotificationResponse>> getNotifications({
    int? page,
  }) async {
    final data = {
      if (page != null) 'page': page,
      'column': 'created_at',
      'sort': 'desc',
      'perPage': 5,
      'lang': LocalStorage.getLanguage()?.locale ?? 'en',
    };
    try {
      final client = inject<HttpService>().client(requireAuth: true);
      final response = await client.get(
        '/api/v1/dashboard/notifications',
        queryParameters: data,
      );
      return ApiResult.success(
        data: NotificationResponse.fromJson(response.data),
      );
    } catch (e, stackTrace) {
      debugPrint('==> get notification failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'NotificationRepositoryImpl.getNotifications',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<NotificationResponse>> readAll() async {
    try {
      final client = inject<HttpService>().client(requireAuth: true);
      final response = await client.post(
        '/api/v1/dashboard/notifications/read-all',
      );
      return ApiResult.success(
        data: NotificationResponse.fromJson(response.data),
      );
    } catch (e, stackTrace) {
      debugPrint('==> get notification failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'NotificationRepositoryImpl.readAll',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<ReadOneNotificationResponse>> readOne({int? id}) async {
    final data = {
      if (id != null) '$id': id,
      // 'lang': LocalStorage.getLanguage()?.locale ?? 'en',
    };
    try {
      final client = inject<HttpService>().client(requireAuth: true);
      final response = await client.post(
        '/api/v1/dashboard/notifications/$id/read-at',
        queryParameters: data,
      );
      return ApiResult.success(
        data: ReadOneNotificationResponse.fromJson(response.data),
      );
    } catch (e, stackTrace) {
      debugPrint('==> get notification failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'NotificationRepositoryImpl.readOne',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<NotificationResponse>> showSingleUser({int? id}) async {
    final data = {
      if (id != null) '$id': id,
      'lang': LocalStorage.getLanguage()?.locale ?? 'en',
    };
    try {
      final client = inject<HttpService>().client(requireAuth: true);
      final response = await client.post(
        '/api/v1/dashboard/notifications/$id',
        queryParameters: data,
      );
      return ApiResult.success(
        data: NotificationResponse.fromJson(response.data),
      );
    } catch (e, stackTrace) {
      debugPrint('==> get notification failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'NotificationRepositoryImpl.showSingleUser',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<NotificationResponse>> getAllNotifications() async {
    final data = {
      'lang': LocalStorage.getLanguage()?.locale ?? 'en',
    };
    try {
      final client = inject<HttpService>().client(requireAuth: true);
      final response = await client.get(
        '/api/v1/dashboard/notifications',
        queryParameters: data,
      );
      return ApiResult.success(
        data: NotificationResponse.fromJson(response.data),
      );
    } catch (e, stackTrace) {
      debugPrint('==> get notification failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'NotificationRepositoryImpl.getAllNotifications',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<CountNotificationModel>> getCount() async {
    try {
      final client = inject<HttpService>().client(requireAuth: true);
      final response = await client.get(
        '/api/v1/dashboard/user/profile/notifications-statistic',
      );
      return ApiResult.success(
        data: CountNotificationModel.fromJson(response.data),
      );
    } catch (e, stackTrace) {
      debugPrint('==> get notification failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'NotificationRepositoryImpl.getCount',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }
}
