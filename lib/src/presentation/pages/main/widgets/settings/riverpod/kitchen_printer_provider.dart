import 'package:admin_desktop/src/core/di/injection.dart';
import 'package:admin_desktop/src/repository/kitchen_printers_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'kitchen_printer_notifier.dart';
import 'kitchen_printer_state.dart';

final kitchenPrinterProvider =
    StateNotifierProvider<KitchenPrinterNotifier, KitchenPrinterState>((ref) {
  final repository = inject<KitchenPrintersRepository>();
  return KitchenPrinterNotifier(repository);
});
