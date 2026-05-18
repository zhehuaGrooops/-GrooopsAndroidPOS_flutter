import 'package:admin_desktop/src/core/constants/hive_boxes.dart';
import 'package:admin_desktop/src/core/handlers/handlers.dart';
import 'package:admin_desktop/src/models/models.dart';
import 'package:hive/hive.dart';

import '../../core/db/hive_service.dart';
import '../currencies_repository.dart';

class CurrenciesHiveRepository extends CurrenciesRepository {
  Future<Box> _box() => HiveService.openBox(HiveBoxes.currencies);

  @override
  Future<ApiResult<CurrenciesResponse>> getCurrencies() async {
    try {
      final box = await _box();
      final list = box.values
          .whereType<Map>()
          .map((e) => CurrencyData.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return ApiResult.success(data: CurrenciesResponse(data: list));
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }
}
