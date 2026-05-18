import 'package:flutter/material.dart';

import '../../core/di/injection.dart';
import '../../core/handlers/handlers.dart';
import '../../core/utils/utils.dart';
import '../../models/models.dart';
import '../repository.dart';

class ShopsRepositoryImpl extends ShopsRepository {
  @override
  Future<ApiResult<ShopsPaginateResponse>> searchShops(String? query) async {
    final data = {
      if (query != null) 'search': query,
      'lang': LocalStorage.getLanguage()?.locale ?? 'en',
      'status': 'approved',
    };
    try {
      final client = inject<HttpService>().client(requireAuth: true);
      final response = await client.get(
        '/api/v1/dashboard/${LocalStorage.getUser()?.role}/shops/search',
        queryParameters: data,
      );
      return ApiResult.success(
        data: ShopsPaginateResponse.fromJson(response.data),
      );
    } catch (e, stackTrace) {
      debugPrint('==> search shops failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'ShopsRepositoryImpl.searchShops',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<ShopsPaginateResponse>> getShopsByIds(
    List<int> shopIds,
  ) async {
    final data = <String, dynamic>{
      'lang': LocalStorage.getLanguage()?.locale ?? 'en',
    };
    for (int i = 0; i < shopIds.length; i++) {
      data['shops[$i]'] = shopIds[i];
    }
    try {
      final client = inject<HttpService>().client(requireAuth: true);
      final response = await client.get(
        '/api/v1/rest/shops',
        queryParameters: data,
      );
      return ApiResult.success(
        data: ShopsPaginateResponse.fromJson(response.data),
      );
    } catch (e, stackTrace) {
      debugPrint('==> get shops by ids failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'ShopsRepositoryImpl.getShopsByIds',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<ShopDeliveriesResponse>> getOnlyDeliveries() async {
    final data = {
      'currency_id': LocalStorage.getSelectedCurrency().id,
    };
    try {
      final client = inject<HttpService>().client(requireAuth: true);
      final response = await client.get(
        '/api/v1/rest/shops/deliveries',
        queryParameters: data,
      );
      return ApiResult.success(
        data: ShopDeliveriesResponse.fromJson(response.data),
      );
    } catch (e, stackTrace) {
      debugPrint('==> get shops deliveries failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'ShopsRepositoryImpl.getOnlyDeliveries',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }
}
