import 'package:admin_desktop/src/models/response/product_calculate_response.dart';

import '../core/handlers/handlers.dart';
import '../models/models.dart';

abstract class ProductsRepository {
  Future<ApiResult<ProductsPaginateResponse>> getProductsPaginate({
    String? query,
    int? categoryId,
    int? brandId,
    int? shopId,
    required int page,
  });

  Future<ApiResult<ProductCalculateResponse>> getAllCalculations(
      List<BagProductData> bagProducts,
      String type,
      String? coupon,
      int? discountSettingId);

  Future<ApiResult<Map<String, dynamic>>> getProductByUuid(String uuid);

  Future<ApiResult<Map<String, dynamic>>> getProductByStockId(int stockId);

  Future<ApiResult<List<DiscountSetting>>> getDiscountSettingsSelectPaginate({
    int? page,
    String? query,
  });

  Future<ApiResult<List<ProductPricingTier>>> getProductPricingTiers();

  Future<ApiResult<List<ProductData>>> getTierProducts(String tierName);

  Future<ApiResult<void>> deductProductStock(int stockId, int quantity);

  Future<ApiResult<void>> addProductStock(int stockId, int quantity);

  Future<ApiResult<void>> deductAddonStock(int countableId, int quantity);

  Future<ApiResult<void>> addAddonStock(int countableId, int quantity);
}
