import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:admin_desktop/src/models/data/printer_config.dart';
import 'package:admin_desktop/src/models/data/bluetooth_printer.dart';
import 'package:admin_desktop/src/core/utils/utils.dart';
import 'package:admin_desktop/src/repository/printer_repository.dart';
import 'printer_state.dart';

class PrinterNotifier extends StateNotifier<PrinterState> {
  final PrinterRepository _repository;
  final PrinterManager _printerManager = PrinterManager.instance;
  StreamSubscription<PrinterDevice>? _discoverySubscription;
  StreamSubscription<BTStatus>? _btStatusSubscription;
  StreamSubscription<USBStatus>? _usbStatusSubscription;
  Future<void>? _initFuture;

  PrinterNotifier(this._repository) : super(PrinterState()) {
    _initSubscriptions();
    unawaited(init());
  }

  void _initSubscriptions() {
    _btStatusSubscription = _printerManager.stateBluetooth.listen((status) {
      if (status == BTStatus.connected) {
        state = state.copyWith(isConnected: true, isConnecting: false);
      } else if (status == BTStatus.none) {
        state = state.copyWith(isConnected: false);
      }
    });

    _usbStatusSubscription = _printerManager.stateUSB.listen((status) {
      if (Platform.isAndroid) {
        if (status == USBStatus.connected) {
          state = state.copyWith(isConnected: true, isConnecting: false);
        } else if (status == USBStatus.none) {
          state = state.copyWith(isConnected: false);
        }
      }
    });
  }

  Future<void> init() {
    final existing = _initFuture;
    if (existing != null) return existing;
    final future = _initInternal();
    _initFuture = future;
    return future;
  }

  Future<void> _initInternal() async {
    try {
      final config = await _repository.getPrinterConfig();
      if (config != null) {
        state = state.copyWith(savedConfig: config);
        await connectToSavedPrinter();
      }
    } catch (_) {
      _initFuture = null;
      rethrow;
    }
  }

  Future<void> scan(PrinterType type, {bool isBle = false}) async {
    state = state.copyWith(isScanning: true, devices: []);
    _discoverySubscription?.cancel();

    _discoverySubscription =
        _printerManager.discovery(type: type, isBle: isBle).listen((device) {
      final newDevice = BluetoothPrinter(
        deviceName: device.name,
        address: device.address,
        isBle: isBle,
        vendorId: device.vendorId,
        productId: device.productId,
        typePrinter: type,
      );
      // Avoid duplicates
      if (!state.devices.any(
          (d) => d.address == device.address && d.deviceName == device.name)) {
        state = state.copyWith(devices: [...state.devices, newDevice]);
      }
    }, onDone: () {
      state = state.copyWith(isScanning: false);
    });
  }

  void clearDevices() {
    state = state.copyWith(devices: [], error: null);
  }

  Future<void> stopScan() async {
    await _discoverySubscription?.cancel();
    state = state.copyWith(isScanning: false);
  }

  Future<void> connect(BluetoothPrinter device) async {
    state = state.copyWith(isConnecting: true, error: null);
    try {
      await disconnect(clearConfig: false); // Disconnect current first

      bool connected = false;
      switch (device.typePrinter) {
        case PrinterType.usb:
          connected = await _printerManager.connect(
            type: device.typePrinter,
            model: UsbPrinterInput(
              name: device.deviceName,
              productId: device.productId,
              vendorId: device.vendorId,
            ),
          );
          break;
        case PrinterType.bluetooth:
          connected = await _printerManager.connect(
            type: device.typePrinter,
            model: BluetoothPrinterInput(
              name: device.deviceName,
              address: device.address!,
              isBle: device.isBle ?? false,
              autoConnect: true,
            ),
          );
          break;
        case PrinterType.network:
          connected = await _printerManager.connect(
            type: device.typePrinter,
            model: TcpPrinterInput(ipAddress: device.address!),
          );
          break;
      }

      // On Android Bluetooth, connection might not be immediate or return true immediately
      // But we will rely on listeners or just assume success if no exception for now.
      if (connected ||
          (device.typePrinter == PrinterType.bluetooth && Platform.isAndroid)) {
        state = state.copyWith(
            selectedDevice: device, isConnected: true, isConnecting: false);

        // Save config
        final existingCharsPerLine = state.savedConfig?.charsPerLine ?? 48;
        final config = PrinterConfig(
          name: device.deviceName,
          address: device.address,
          vendorId: device.vendorId,
          productId: device.productId,
          isBle: device.isBle ?? false,
          type: device.typePrinter.index,
          charsPerLine: existingCharsPerLine,
        );
        await _repository.savePrinterConfig(config);
        state = state.copyWith(savedConfig: config);
      } else {
        state = state.copyWith(isConnecting: false, error: "Connection failed");
      }
    } catch (e) {
      state = state.copyWith(isConnecting: false, error: e.toString());
    }
  }

  Future<void> connectToSavedPrinter() async {
    final config = state.savedConfig;
    if (config == null) return;

    // Convert int type back to PrinterType
    if (config.type < 0 || config.type >= PrinterType.values.length) return;
    PrinterType type = PrinterType.values[config.type];

    final device = BluetoothPrinter(
      deviceName: config.name,
      address: config.address,
      vendorId: config.vendorId,
      productId: config.productId,
      isBle: config.isBle,
      typePrinter: type,
    );

    await connect(device);
  }

  Future<void> disconnect({bool clearConfig = true}) async {
    String? disconnectError;
    if (state.selectedDevice != null) {
      try {
        await _printerManager.disconnect(
            type: state.selectedDevice!.typePrinter);
      } catch (e) {
        disconnectError = e.toString();
      }
    }
    if (clearConfig) {
      try {
        await _repository.clearPrinterConfig();
      } catch (e) {
        disconnectError ??= e.toString();
      }
    }
    state = PrinterState(
      isScanning: state.isScanning,
      isConnecting: false,
      devices: state.devices,
      selectedDevice: null,
      savedConfig: clearConfig ? null : state.savedConfig,
      error: disconnectError,
      isConnected: false,
    );
  }

  Future<void> updateCharsPerLine(int charsPerLine) async {
    final current = state.savedConfig;
    if (current == null) return;
    final updated = current.copyWith(
      charsPerLine: AppHelpers.clampCharsPerLine(charsPerLine),
    );
    try {
      await _repository.savePrinterConfig(updated);
      state = state.copyWith(savedConfig: updated, error: null);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  @override
  void dispose() {
    _discoverySubscription?.cancel();
    _btStatusSubscription?.cancel();
    _usbStatusSubscription?.cancel();
    super.dispose();
  }
}
