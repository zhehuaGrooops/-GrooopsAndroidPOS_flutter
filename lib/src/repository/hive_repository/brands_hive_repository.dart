import 'package:admin_desktop/src/core/constants/hive_boxes.dart';
import 'package:admin_desktop/src/core/handlers/handlers.dart';
import 'package:admin_desktop/src/models/models.dart';
import 'package:hive/hive.dart';

import '../../core/db/hive_service.dart';
import '../brands_repository.dart';

class BrandsHiveRepository extends BrandsRepository {
  Future<Box> _box() => HiveService.openBox(HiveBoxes.brands);

  @override
  Future<ApiResult<BrandsPaginateResponse>> searchBrands(String? query) async {
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
          .map((e) => BrandData.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return ApiResult.success(data: BrandsPaginateResponse(data: list));
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }
}
