import 'package:admin_desktop/src/core/constants/hive_boxes.dart';
import 'package:admin_desktop/src/core/handlers/handlers.dart';
import 'package:admin_desktop/src/models/models.dart';
import 'package:hive/hive.dart';

import '../../core/db/hive_service.dart';
import '../shops_repository.dart';

class ShopsHiveRepository extends ShopsRepository {
  Future<Box> _box() => HiveService.openBox(HiveBoxes.shops);

  @override
  Future<ApiResult<ShopsPaginateResponse>> searchShops(String? query) async {
    try {
      final box = await _box();
      final items = box.values.whereType<Map>().toList();
      final filtered = items.where((e) {
        final title = (((e['translation'] ?? {}) as Map)['title'] ?? '')
            .toString()
            .toLowerCase();
        return query == null || title.contains(query.toLowerCase());
      }).toList();
      final list = filtered
          .map((e) => ShopData.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return ApiResult.success(data: ShopsPaginateResponse(data: list));
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<ShopsPaginateResponse>> getShopsByIds(
      List<int> shopIds) async {
    try {
      final box = await _box();
      final items = box.values
          .whereType<Map>()
          .where((e) => shopIds.contains(e['id']))
          .toList();
      final list = items
          .map((e) => ShopData.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return ApiResult.success(data: ShopsPaginateResponse(data: list));
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<ShopDeliveriesResponse>> getOnlyDeliveries() async {
    try {
      final box = await _box();
      final deliveries = box.values
          .whereType<Map>()
          .where((e) => (e['type'] ?? '') == 'delivery')
          .toList();
      final list = deliveries
          .map((e) => ShopDelivery.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return ApiResult.success(data: ShopDeliveriesResponse(data: list));
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }
}
