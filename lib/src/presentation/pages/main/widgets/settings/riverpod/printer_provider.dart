import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:admin_desktop/src/core/di/injection.dart';
import 'package:admin_desktop/src/repository/printer_repository.dart';
import 'printer_notifier.dart';
import 'printer_state.dart';

final printerProvider =
    StateNotifierProvider<PrinterNotifier, PrinterState>((ref) {
  final repository = inject<PrinterRepository>();
  return PrinterNotifier(repository);
});
