import 'package:admin_desktop/src/core/utils/utils.dart';
import 'package:flutter/material.dart';

import '../../core/di/injection.dart';
import '../../core/handlers/handlers.dart';
import '../../models/models.dart';
import '../repository.dart';

class BrandsRepositoryImpl extends BrandsRepository {
  @override
  Future<ApiResult<BrandsPaginateResponse>> searchBrands(String? query) async {
    final data = {'search': query};
    try {
      final client = inject<HttpService>().client(requireAuth: true);
      final response = await client.get(
        '/api/v1/rest/brands/paginate',
        queryParameters: data,
      );
      return ApiResult.success(
        data: BrandsPaginateResponse.fromJson(response.data),
      );
    } catch (e, stackTrace) {
      debugPrint('==> search brands failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'BrandsRepositoryImpl.searchBrands',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }
}
