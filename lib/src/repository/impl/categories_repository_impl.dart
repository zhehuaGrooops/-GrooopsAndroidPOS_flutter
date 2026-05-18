import 'package:admin_desktop/src/core/constants/constants.dart';
import 'package:flutter/material.dart';

import '../../core/di/injection.dart';
import '../../core/handlers/handlers.dart';
import '../../core/utils/utils.dart';
import '../../models/models.dart';
import '../repository.dart';

class CategoriesRepositoryImpl extends CategoriesRepository {
  @override
  Future<ApiResult<CategoriesPaginateResponse>> searchCategories(
    String? query,
  ) async {
    final data = {
      'lang': LocalStorage.getLanguage()?.locale ?? 'en',
      'perPage': 100,
      'type': 'main',
      "has_products": 1,
      "p_shop_id": LocalStorage.getUser()?.role == TrKeys.waiter
          ? LocalStorage.getUser()?.invite?.shopId ?? 0
          : LocalStorage.getUser()?.shop?.id ?? 0
    };
    try {
      final client = inject<HttpService>().client(requireAuth: true);
      final response = await client.get(
        '/api/v1/rest/categories/paginate',
        // LocalStorage.getUser()?.role == TrKeys.seller
        //     ? '/api/v1/dashboard/${LocalStorage.getUser()?.role}/categories/paginate'
        //     : '/api/v1/rest/categories/paginate',
        queryParameters: data,
      );
      return ApiResult.success(
        data: CategoriesPaginateResponse.fromJson(response.data),
      );
    } catch (e, stackTrace) {
      debugPrint('==> get categories failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'CategoriesRepositoryImpl.searchCategories',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }
}
