import 'package:admin_desktop/src/models/data/printer_config.dart';

abstract class PrinterRepository {
  Future<PrinterConfig?> getPrinterConfig();
  Future<void> savePrinterConfig(PrinterConfig config);
  Future<void> clearPrinterConfig();
}
