import 'package:admin_desktop/src/core/constants/hive_boxes.dart';
import 'package:admin_desktop/src/core/handlers/handlers.dart';
import 'package:admin_desktop/src/models/models.dart';
import 'package:flutter/cupertino.dart';
import 'package:hive/hive.dart';

import '../../core/db/hive_service.dart';
import '../categories_repository.dart';

class CategoriesHiveRepository extends CategoriesRepository {
  Future<Box> _box() => HiveService.openBox(HiveBoxes.categories);

  @override
  Future<ApiResult<CategoriesPaginateResponse>> searchCategories(
      String? query) async {
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
          .map((e) => CategoryData.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      debugPrint("Categories Data : $filtered");
      return ApiResult.success(data: CategoriesPaginateResponse(data: list));
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }
}
