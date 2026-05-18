import 'package:admin_desktop/src/core/constants/constants.dart';
import 'package:admin_desktop/src/models/response/product_calculate_response.dart';
import 'package:flutter/material.dart';

import '../../core/di/injection.dart';
import '../../core/handlers/handlers.dart';
import '../../core/utils/utils.dart';
import '../../models/models.dart';
import '../repository.dart';

class ProductsRepositoryImpl extends ProductsRepository {
  @override
  Future<ApiResult<ProductsPaginateResponse>> getProductsPaginate({
    String? query,
    int? categoryId,
    int? brandId,
    int? shopId,
    required int page,
  }) async {
    final data = {
      if (brandId != null) 'brand_id': brandId,
      if (categoryId != null) 'category_id': categoryId,
      if (shopId != null ||
          LocalStorage.getUser()?.role == TrKeys.waiter ||
          LocalStorage.getUser()?.role == TrKeys.admin)
        'shop_id': (LocalStorage.getUser()?.role == TrKeys.waiter)
            ? LocalStorage.getUser()?.invite?.shopId
            : LocalStorage.getUser()?.role == TrKeys.admin
                ? LocalStorage.getUser()?.shop?.id
                : shopId,
      if (query != null) 'search': query,
      'perPage': 12,
      'page': page,
      'lang': LocalStorage.getLanguage()?.locale ?? 'en',
      "status": "published",
      "addon_status": "published"
    };
    try {
      final client = inject<HttpService>().client(requireAuth: true);
      final response = await client.get(
        LocalStorage.getUser()?.role == TrKeys.waiter
            ? '/api/v1/rest/products/paginate'
            : '/api/v1/dashboard/${LocalStorage.getUser()?.role}/products/paginate',
        queryParameters: data,
      );
      return ApiResult.success(
        data: ProductsPaginateResponse.fromJson(response.data),
      );
    } catch (e, stackTrace) {
      debugPrint('==> get products failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'ProductsRepositoryImpl.getProductsPaginate',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<List<ProductPricingTier>>> getProductPricingTiers() async {
    try {
      final client = inject<HttpService>().client(requireAuth: true);
      final response = await client.get(
        '/api/v1/rest/product-pricing-tiers',
        queryParameters: {'lang': LocalStorage.getLanguage()?.locale ?? 'en'},
      );
      final List<ProductPricingTier> rawTiers = (response.data as List)
          .where((e) {
            final translations = e['translations'];
            return translations != null &&
                (translations as List).isNotEmpty &&
                (translations).first is Map &&
                (translations).first['title'] != null;
          })
          .map((e) => ProductPricingTier.fromJson(e))
          .toList();

      // Prevent duplicates with the same title (case-insensitive)
      final Map<String, ProductPricingTier> uniqueTiers = {};
      for (final tier in rawTiers) {
        final title = tier.title?.trim();
        if (title != null && title.isNotEmpty) {
          final lowerTitle = title.toLowerCase();
          if (!uniqueTiers.containsKey(lowerTitle)) {
            uniqueTiers[lowerTitle] = tier;
          }
        }
      }

      return ApiResult.success(data: uniqueTiers.values.toList());
    } catch (e, stackTrace) {
      debugPrint('==> get pricing tiers failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'ProductsRepositoryImpl.getProductPricingTiers',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<ProductCalculateResponse>> getAllCalculations(
      List<BagProductData> bagProducts,
      String type,
      String? coupon,
      int? discountSettingId) async {
    UserData? userData = LocalStorage.getUser();
    final data = {
      'currency_id': LocalStorage.getSelectedCurrency().id,
      'lang': LocalStorage.getLanguage()?.locale ?? 'en',
      'shop_id': userData?.role == TrKeys.waiter
          ? userData?.invite?.shopId ?? 0
          : userData?.shop?.id ?? 0,
      'type': type.isEmpty ? TrKeys.dine : type,
      if (coupon != null) "coupon": coupon,
      if (discountSettingId != null) 'discount_setting_id': discountSettingId,
      'address[latitude]':
          LocalStorage.getBags().first.selectedAddress?.location?.latitude ?? 0,
      'address[longitude]':
          LocalStorage.getBags().first.selectedAddress?.location?.longitude ?? 0
    };
    for (int i = 0; i < (bagProducts.length); i++) {
      data['products[$i][stock_id]'] = bagProducts[i].stockId;
      data['products[$i][quantity]'] = bagProducts[i].quantity;
      for (int j = 0; j < (bagProducts[i].carts?.length ?? 0); j++) {
        data['products[$i][addons][$j][stock_id]'] =
            bagProducts[i].carts?[j].stockId;
        data['products[$i][addons][$j][quantity]'] =
            bagProducts[i].carts?[j].quantity;
      }
    }

    try {
      final client = inject<HttpService>().client(requireAuth: true);
      final response = await client.get(
        '/api/v1/rest/order/products/calculate',
        queryParameters: data,
      );
      return ApiResult.success(
        data: ProductCalculateResponse.fromJson(response.data),
      );
    } catch (e, s) {
      debugPrint('==> get all calculations failure: $e');
      debugPrint('==> get all calculations failure: $s');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: s,
        context: 'ProductsRepositoryImpl.getAllCalculations',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> getProductByUuid(String uuid) async {
    try {
      final user = LocalStorage.getUser();
      final roleSegment =
          user?.role == TrKeys.waiter ? 'rest' : 'dashboard/${user?.role}';
      final client = inject<HttpService>().client(requireAuth: true);
      final response = await client.get(
        '/api/v1/$roleSegment/products/$uuid',
        queryParameters: {
          'lang': LocalStorage.getLanguage()?.locale ?? 'en',

          // ================== START OF FIX ==================
          // This line tells the server to include the nested data you need.
          'with': 'category.service_types,shop',
          // =================== END OF FIX ===================
        },
      );
      final Map<String, dynamic> data = (response.data
          as Map<String, dynamic>)['data'] as Map<String, dynamic>;
      return ApiResult.success(data: data);
    } catch (e, stackTrace) {
      debugPrint('==> get product detail failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'ProductsRepositoryImpl.getProductByUuid',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> getProductByStockId(
      int stockId) async {
    return ApiResult.success(data: {});
  }

  @override
  Future<ApiResult<List<DiscountSetting>>> getDiscountSettingsSelectPaginate({
    int? page,
    String? query,
  }) async {
    final data = {
      if (page != null) 'page': page,
      if (query != null) 'search': query,
      'perPage': 20,
      'lang': LocalStorage.getLanguage()?.locale ?? 'en',
    };
    try {
      final client = inject<HttpService>().client(requireAuth: true);
      final response = await client.get(
        '/api/v1/rest/discount-settings/select-paginate',
        queryParameters: data,
      );
      final raw = (response.data as Map<String, dynamic>)['data'];
      final List<DiscountSetting> items = [];
      List<dynamic> listPayload = [];
      if (raw is List) {
        listPayload = raw;
      } else if (raw is Map && raw['data'] is List) {
        listPayload = raw['data'];
      }
      for (final e in listPayload) {
        try {
          if (e is Map<String, dynamic>) {
            final method = e['method'] ?? e['type'] ?? e['discount_method'];

            dynamic rawValue = e['value'] ?? e['amount'] ?? e['discount'];
            num parsedValue = 0;
            if (rawValue is num) {
              parsedValue = rawValue;
            } else if (rawValue is String) {
              parsedValue = num.tryParse(rawValue) ?? 0;
            }
            final active = e['active'] == 1 || e['active'] == true;
            final scope = e['scope'] ?? e['scope_name'];
            final id = e['id'];
            final title = e['title']?.toString();
            items.add(DiscountSetting(
              id: id is int ? id : (id is String ? int.tryParse(id) : null),
              title: title,
              method: method?.toString(),
              value: parsedValue,
              active: active,
              scope: scope?.toString(),
            ));
          } else {
            items.add(DiscountSetting.fromJson(e));
          }
        } catch (err, stackTrace) {
          debugPrint('==> discount parse error: $err');
          AppHelpers.recordErrorToCrashlytics(
            error: err,
            stackTrace: stackTrace,
            context:
                'ProductsRepositoryImpl.getDiscountSettingsSelectPaginate.parse',
          );
        }
      }
      return ApiResult.success(data: items);
    } catch (e, s) {
      debugPrint('==> get discount-settings failure: $e');
      debugPrint('$s');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: s,
        context: 'ProductsRepositoryImpl.getDiscountSettingsSelectPaginate',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<List<ProductData>>> getTierProducts(String tierName) async {
    try {
      final client = inject<HttpService>().client(requireAuth: true);
      final response = await client.get(
        '/api/v1/rest/product-pricing-tiers/by-name/$tierName',
        queryParameters: {'lang': LocalStorage.getLanguage()?.locale ?? 'en'},
      );
      // The API returns a list under a 'products' key, we need to parse it.
      final List<dynamic> productList = response.data['products'];

      final List<ProductData> tiers = productList.map((e) {
        final json = e as Map<String, dynamic>;

        // Create a mutable copy to fix the data structure before parsing
        final correctedJson = Map<String, dynamic>.from(json);

        // FIX 1: Convert the price from String to a num.
        if (correctedJson['price'] is String) {
          correctedJson['price'] = num.tryParse(correctedJson['price']) ?? 0.0;
        }

        // FIX 2: Map 'product_id' to 'id', which ProductData.fromJson likely expects.
        if (correctedJson.containsKey('product_id')) {
          correctedJson['id'] = correctedJson['product_id'];
        }

        // FIX 3: Map 'product_name' to the nested translation object.
        if (correctedJson.containsKey('product_name')) {
          correctedJson['translation'] = {
            'title': correctedJson['product_name']
          };
        }

        // Now, parse the corrected JSON.
        return ProductData.fromJson(correctedJson);
      }).toList();

      return ApiResult.success(data: tiers);
    } catch (e, s) {
      debugPrint('==> get tier products failure: $e');
      debugPrint(s.toString()); // Also log the stack trace for better debugging
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: s,
        context: 'ProductsRepositoryImpl.getTierProducts',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<void>> deductProductStock(int stockId, int quantity) async {
    return ApiResult.success(data: null);
  }

  @override
  Future<ApiResult<void>> addProductStock(int stockId, int quantity) async {
    return ApiResult.success(data: null);
  }

  @override
  Future<ApiResult<void>> deductAddonStock(
      int countableId, int quantity) async {
    return ApiResult.success(data: null);
  }

  @override
  Future<ApiResult<void>> addAddonStock(int countableId, int quantity) async {
    return ApiResult.success(data: null);
  }
}
