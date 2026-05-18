import 'dart:async';
import 'dart:io';

import 'package:admin_desktop/src/models/data/bluetooth_printer.dart';
import 'package:admin_desktop/src/models/data/kitchen_printer_config.dart';
import 'package:admin_desktop/src/models/data/printer_config.dart';
import 'package:admin_desktop/src/core/utils/utils.dart';
import 'package:admin_desktop/src/repository/kitchen_printers_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';

import 'kitchen_printer_state.dart';

class KitchenPrinterNotifier extends StateNotifier<KitchenPrinterState> {
  final KitchenPrintersRepository _repository;
  final PrinterManager _printerManager = PrinterManager.instance;

  StreamSubscription<PrinterDevice>? _discoverySubscription;
  StreamSubscription<BTStatus>? _btStatusSubscription;
  StreamSubscription<USBStatus>? _usbStatusSubscription;

  KitchenPrinterNotifier(this._repository) : super(KitchenPrinterState()) {
    try {
      _initSubscriptions();
      unawaited(loadPrinters());
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void _initSubscriptions() {
    try {
      _btStatusSubscription = _printerManager.stateBluetooth.listen((status) {
        try {
          if (status == BTStatus.connected) {
            state = state.copyWith(isConnected: true, isConnecting: false);
          } else if (status == BTStatus.none) {
            state = state.copyWith(isConnected: false);
          }
        } catch (e) {
          state = state.copyWith(isConnecting: false, error: e.toString());
        }
      }, onError: (Object e, StackTrace _) {
        state = state.copyWith(isConnecting: false, error: e.toString());
      });

      _usbStatusSubscription = _printerManager.stateUSB.listen((status) {
        try {
          if (Platform.isAndroid) {
            if (status == USBStatus.connected) {
              state = state.copyWith(isConnected: true, isConnecting: false);
            } else if (status == USBStatus.none) {
              state = state.copyWith(isConnected: false);
            }
          }
        } catch (e) {
          state = state.copyWith(isConnecting: false, error: e.toString());
        }
      }, onError: (Object e, StackTrace _) {
        state = state.copyWith(isConnecting: false, error: e.toString());
      });
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> loadPrinters() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final printers = await _repository.getKitchenPrinters();
      final selectedId = state.selectedPrinterId ??
          (printers.isNotEmpty ? printers.first.id : null);
      state = state.copyWith(
        isLoading: false,
        printers: printers,
        selectedPrinterId: selectedId,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> addPrinter() async {
    try {
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final config = KitchenPrinterConfig(
        id: id,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        charsPerLine: 48,
      );
      await _repository.upsertKitchenPrinter(config);
      final updated = [...state.printers, config]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      state =
          state.copyWith(printers: updated, selectedPrinterId: id, error: null);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> removePrinter(String id) async {
    try {
      await _repository.deleteKitchenPrinter(id);
      final updated = state.printers.where((p) => p.id != id).toList();
      String? nextSelected = state.selectedPrinterId;
      if (nextSelected == id) {
        nextSelected = updated.isNotEmpty ? updated.first.id : null;
      }
      state = state.copyWith(
        printers: updated,
        selectedPrinterId: nextSelected,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void selectPrinter(String id) {
    if (state.selectedPrinterId == id) return;
    state = state.copyWith(selectedPrinterId: id, error: null);
  }

  Future<void> updateSelectedCategories(List<int> categoryIds) async {
    try {
      final current = state.selectedPrinter;
      if (current == null) return;
      final updatedConfig = current.copyWith(categoryIds: categoryIds);
      await _repository.upsertKitchenPrinter(updatedConfig);
      final updatedList = state.printers
          .map((p) => p.id == current.id ? updatedConfig : p)
          .toList();
      state = state.copyWith(printers: updatedList, error: null);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> updateCharsPerLine(int charsPerLine) async {
    try {
      final current = state.selectedPrinter;
      if (current == null) return;
      final updatedConfig = current.copyWith(
        charsPerLine: AppHelpers.clampCharsPerLine(charsPerLine),
      );
      await _repository.upsertKitchenPrinter(updatedConfig);
      final updatedList = state.printers
          .map((p) => p.id == current.id ? updatedConfig : p)
          .toList();
      state = state.copyWith(printers: updatedList, error: null);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void addOrUpdateDevice(BluetoothPrinter device) {
    final address = device.address;
    final name = device.deviceName;
    if (address == null || address.trim().isEmpty) return;
    final exists =
        state.devices.any((d) => d.address == address && d.deviceName == name);
    if (exists) return;
    state = state.copyWith(devices: [...state.devices, device], error: null);
  }

  Future<void> scan(PrinterType type, {bool isBle = false}) async {
    state = state.copyWith(isScanning: true, devices: [], error: null);
    try {
      await _discoverySubscription?.cancel();

      _discoverySubscription =
          _printerManager.discovery(type: type, isBle: isBle).listen((device) {
        try {
          final newDevice = BluetoothPrinter(
            deviceName: device.name,
            address: device.address,
            isBle: isBle,
            vendorId: device.vendorId,
            productId: device.productId,
            typePrinter: type,
          );
          if (!state.devices.any(
            (d) => d.address == device.address && d.deviceName == device.name,
          )) {
            state = state.copyWith(devices: [...state.devices, newDevice]);
          }
        } catch (e) {
          state = state.copyWith(isScanning: false, error: e.toString());
        }
      }, onError: (Object e, StackTrace _) {
        state = state.copyWith(isScanning: false, error: e.toString());
      }, onDone: () {
        state = state.copyWith(isScanning: false);
      });
    } catch (e) {
      state = state.copyWith(isScanning: false, error: e.toString());
    }
  }

  void clearDevices() {
    state = state.copyWith(devices: [], error: null);
  }

  Future<void> stopScan() async {
    try {
      await _discoverySubscription?.cancel();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isScanning: false);
    }
  }

  Future<void> connect(BluetoothPrinter device) async {
    final selected = state.selectedPrinter;
    if (selected == null) {
      state =
          state.copyWith(error: 'Please add/select a kitchen printer first.');
      return;
    }

    state = state.copyWith(isConnecting: true, error: null);
    try {
      await disconnect(clearConfig: false);

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

      if (connected ||
          (device.typePrinter == PrinterType.bluetooth && Platform.isAndroid)) {
        state = state.copyWith(
            selectedDevice: device, isConnected: true, isConnecting: false);

        final printerConfig = PrinterConfig(
          name: device.deviceName,
          address: device.address,
          vendorId: device.vendorId,
          productId: device.productId,
          isBle: device.isBle ?? false,
          type: device.typePrinter.index,
        );

        final updatedConfig = selected.copyWith(printerConfig: printerConfig);
        await _repository.upsertKitchenPrinter(updatedConfig);
        final updatedList = state.printers
            .map((p) => p.id == selected.id ? updatedConfig : p)
            .toList();
        state = state.copyWith(printers: updatedList);
      } else {
        state = state.copyWith(isConnecting: false, error: 'Connection failed');
      }
    } catch (e) {
      state = state.copyWith(isConnecting: false, error: e.toString());
    }
  }

  Future<void> disconnect({bool clearConfig = true}) async {
    String? disconnectError;
    PrinterType? typeToDisconnect;

    if (state.selectedDevice != null) {
      typeToDisconnect = state.selectedDevice!.typePrinter;
    } else {
      final selected = state.selectedPrinter;
      if (selected?.printerConfig != null) {
        final typeIndex = selected!.printerConfig!.type;
        if (typeIndex >= 0 && typeIndex < PrinterType.values.length) {
          typeToDisconnect = PrinterType.values[typeIndex];
        }
      }
    }

    if (typeToDisconnect != null) {
      try {
        await _printerManager.disconnect(type: typeToDisconnect);
      } catch (e) {
        disconnectError = e.toString();
      }
    }

    if (clearConfig) {
      final selected = state.selectedPrinter;
      if (selected != null) {
        final updatedConfig = selected.copyWith(printerConfig: null);
        try {
          await _repository.upsertKitchenPrinter(updatedConfig);
          final updatedList = state.printers
              .map((p) => p.id == selected.id ? updatedConfig : p)
              .toList();
          state = state.copyWith(printers: updatedList);
        } catch (e) {
          disconnectError ??= e.toString();
        }
      }
    }

    state = state.copyWith(
      isConnecting: false,
      selectedDevice: null,
      isConnected: false,
      error: disconnectError,
    );
  }

  @override
  void dispose() {
    try {
      _discoverySubscription?.cancel();
      _btStatusSubscription?.cancel();
      _usbStatusSubscription?.cancel();
    } catch (_) {
    } finally {
      super.dispose();
    }
  }
}
