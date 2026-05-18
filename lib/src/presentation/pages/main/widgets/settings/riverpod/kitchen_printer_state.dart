import 'package:admin_desktop/src/models/data/bluetooth_printer.dart';
import 'package:admin_desktop/src/models/data/kitchen_printer_config.dart';

class KitchenPrinterState {
  final bool isLoading;
  final List<KitchenPrinterConfig> printers;
  final String? selectedPrinterId;

  final bool isScanning;
  final bool isConnecting;
  final List<BluetoothPrinter> devices;
  final BluetoothPrinter? selectedDevice;
  final String? error;
  final bool isConnected;

  KitchenPrinterState({
    this.isLoading = false,
    this.printers = const [],
    this.selectedPrinterId,
    this.isScanning = false,
    this.isConnecting = false,
    this.devices = const [],
    this.selectedDevice,
    this.error,
    this.isConnected = false,
  });

  KitchenPrinterConfig? get selectedPrinter {
    final id = selectedPrinterId;
    if (id == null) return null;
    try {
      return printers.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  KitchenPrinterState copyWith({
    bool? isLoading,
    List<KitchenPrinterConfig>? printers,
    String? selectedPrinterId,
    bool? isScanning,
    bool? isConnecting,
    List<BluetoothPrinter>? devices,
    BluetoothPrinter? selectedDevice,
    String? error,
    bool? isConnected,
  }) {
    return KitchenPrinterState(
      isLoading: isLoading ?? this.isLoading,
      printers: printers ?? this.printers,
      selectedPrinterId: selectedPrinterId ?? this.selectedPrinterId,
      isScanning: isScanning ?? this.isScanning,
      isConnecting: isConnecting ?? this.isConnecting,
      devices: devices ?? this.devices,
      selectedDevice: selectedDevice ?? this.selectedDevice,
      error: error,
      isConnected: isConnected ?? this.isConnected,
    );
  }
}
