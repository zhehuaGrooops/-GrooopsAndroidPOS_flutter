import 'package:admin_desktop/src/core/constants/hive_boxes.dart';
import 'package:admin_desktop/src/core/db/hive_service.dart';
import 'package:admin_desktop/src/models/data/kitchen_printer_config.dart';
import 'package:hive/hive.dart';

import '../kitchen_printers_repository.dart';

class KitchenPrintersRepositoryImpl implements KitchenPrintersRepository {
  Future<Box> _box() => HiveService.openBox(HiveBoxes.kitchenPrintersConfig);

  @override
  Future<List<KitchenPrinterConfig>> getKitchenPrinters() async {
    final box = await _box();
    final configs = <KitchenPrinterConfig>[];
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw is Map) {
        final map = Map<String, dynamic>.from(raw);
        configs.add(KitchenPrinterConfig.fromJson(map));
      }
    }
    configs.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return configs;
  }

  @override
  Future<void> upsertKitchenPrinter(KitchenPrinterConfig config) async {
    final box = await _box();
    await box.put(config.id, config.toJson());
  }

  @override
  Future<void> deleteKitchenPrinter(String id) async {
    final box = await _box();
    await box.delete(id);
  }
}
