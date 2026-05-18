import 'dart:convert';
import 'package:admin_desktop/src/core/constants/hive_boxes.dart';
import 'package:admin_desktop/src/core/db/hive_service.dart';
import 'package:admin_desktop/src/core/utils/app_helpers.dart';
import 'package:admin_desktop/src/models/data/printer_config.dart';
import '../printer_repository.dart';

class PrinterRepositoryImpl implements PrinterRepository {
  @override
  Future<PrinterConfig?> getPrinterConfig() async {
    try {
      final box = await HiveService.openBox(HiveBoxes.printerConfig);
      final data = box.get('config');
      if (data == null) return null;

      if (data is PrinterConfig) return data;

      if (data is Map) {
        return PrinterConfig.fromJson(Map<String, dynamic>.from(data));
      }

      if (data is String) {
        final decoded = jsonDecode(data);
        if (decoded is Map) {
          return PrinterConfig.fromJson(Map<String, dynamic>.from(decoded));
        }
      }

      return null;
    } catch (e, stackTrace) {
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'PrinterRepositoryImpl.getPrinterConfig',
      );
      return null;
    }
  }

  @override
  Future<void> savePrinterConfig(PrinterConfig config) async {
    final box = await HiveService.openBox(HiveBoxes.printerConfig);
    await box.put('config', config.toJson());
  }

  @override
  Future<void> clearPrinterConfig() async {
    final box = await HiveService.openBox(HiveBoxes.printerConfig);
    await box.delete('config');
  }
}
