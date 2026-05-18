import 'package:admin_desktop/src/models/data/kitchen_printer_config.dart';

abstract class KitchenPrintersRepository {
  Future<List<KitchenPrinterConfig>> getKitchenPrinters();
  Future<void> upsertKitchenPrinter(KitchenPrinterConfig config);
  Future<void> deleteKitchenPrinter(String id);
}
