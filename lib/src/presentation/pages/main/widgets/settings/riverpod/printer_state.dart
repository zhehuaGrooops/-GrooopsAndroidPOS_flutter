import 'package:admin_desktop/src/models/data/bluetooth_printer.dart';
import 'package:admin_desktop/src/models/data/printer_config.dart';

class PrinterState {
  final bool isScanning;
  final bool isConnecting;
  final List<BluetoothPrinter> devices;
  final BluetoothPrinter? selectedDevice;
  final PrinterConfig? savedConfig;
  final String? error;
  final bool isConnected;

  PrinterState({
    this.isScanning = false,
    this.isConnecting = false,
    this.devices = const [],
    this.selectedDevice,
    this.savedConfig,
    this.error,
    this.isConnected = false,
  });

  PrinterState copyWith({
    bool? isScanning,
    bool? isConnecting,
    List<BluetoothPrinter>? devices,
    BluetoothPrinter? selectedDevice,
    PrinterConfig? savedConfig,
    String? error,
    bool? isConnected,
  }) {
    return PrinterState(
      isScanning: isScanning ?? this.isScanning,
      isConnecting: isConnecting ?? this.isConnecting,
      devices: devices ?? this.devices,
      selectedDevice: selectedDevice ?? this.selectedDevice,
      savedConfig: savedConfig ?? this.savedConfig,
      error: error,
      isConnected: isConnected ?? this.isConnected,
    );
  }
}
