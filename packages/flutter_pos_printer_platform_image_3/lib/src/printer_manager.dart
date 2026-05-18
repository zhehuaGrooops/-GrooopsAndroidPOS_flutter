import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';

enum PrinterType { bluetooth, usb, network }

class PrinterManager {
  final bluetoothPrinterConnector = BluetoothPrinterConnector.instance;
  final tcpPrinterConnector = TcpPrinterConnector.instance;
  final usbPrinterConnector = UsbPrinterConnector.instance;

  final Map<PrinterType, String?> _activeSessionKeyByType = {};
  final Map<PrinterType, List<String>> _sessionKeyHistoryByType = {};

  final Map<String, int> _sessionRefCountByKey = {};
  final Map<String, PrinterType> _sessionTypeByKey = {};
  final Map<String, BasePrinterInput> _modelBySessionKey = {};

  final Map<String, TcpPrinterConnector> _tcpConnectorBySessionKey = {};

  final Map<String, StreamController<PrinterDevice>> _activeDiscoveryControllers = {};
  final Map<String, List<PrinterDevice>> _activeDiscoveryCache = {};

  PrinterManager._();

  static PrinterManager _instance = PrinterManager._();

  static PrinterManager get instance => _instance;

  Stream<PrinterDevice> discovery({required PrinterType type, bool isBle = false, TcpPrinterInput? model}) {
    final discoveryKey = _buildDiscoveryKey(type: type, isBle: isBle, model: model);
    final existingController = _activeDiscoveryControllers[discoveryKey];
    if (existingController != null && !existingController.isClosed) {
      final cached = List<PrinterDevice>.unmodifiable(_activeDiscoveryCache[discoveryKey] ?? const <PrinterDevice>[]);
      if (cached.isEmpty) return existingController.stream;
      return (() async* {
        yield* Stream<PrinterDevice>.fromIterable(cached);
        yield* existingController.stream;
      })();
    }

    final controller = StreamController<PrinterDevice>.broadcast();
    _activeDiscoveryControllers[discoveryKey] = controller;
    _activeDiscoveryCache[discoveryKey] = <PrinterDevice>[];

    Stream<PrinterDevice> source;
    if (type == PrinterType.bluetooth && (Platform.isIOS || Platform.isAndroid)) {
      source = bluetoothPrinterConnector.discovery(isBle: isBle);
    } else if (type == PrinterType.usb && (Platform.isAndroid || Platform.isWindows)) {
      source = usbPrinterConnector.discovery();
    } else {
      source = tcpPrinterConnector.discovery(model: model);
    }

    late final StreamSubscription<PrinterDevice> sub;
    sub = source.listen(
      (event) {
        final cache = _activeDiscoveryCache[discoveryKey];
        if (cache != null &&
            !cache.any((d) => d.address == event.address && d.name == event.name)) {
          cache.add(event);
        }
        if (!controller.isClosed) controller.add(event);
      },
      onError: (Object e, StackTrace st) {
        if (!controller.isClosed) controller.addError(e, st);
      },
      onDone: () async {
        _activeDiscoveryControllers.remove(discoveryKey);
        _activeDiscoveryCache.remove(discoveryKey);
        if (!controller.isClosed) await controller.close();
        await sub.cancel();
      },
      cancelOnError: false,
    );

    return controller.stream;
  }

  Future<bool> connect({required PrinterType type, required BasePrinterInput model}) async {
    final newSessionKey = _buildSessionKey(type: type, model: model);
    final activeKey = _activeSessionKeyByType[type];
    final refCount = _sessionRefCountByKey[newSessionKey] ?? 0;

    if (type == PrinterType.network &&
        refCount > 0 &&
        _isConnectorLikelyConnected(type: type, model: model, sessionKey: newSessionKey)) {
      _pushActiveHistoryIfNeeded(type: type, currentActiveKey: activeKey, nextActiveKey: newSessionKey);
      _activeSessionKeyByType[type] = newSessionKey;
      _sessionRefCountByKey[newSessionKey] = refCount + 1;
      _sessionTypeByKey[newSessionKey] = type;
      _modelBySessionKey[newSessionKey] = model;
      return true;
    }

    if (type != PrinterType.network && refCount > 0) {
      _pushActiveHistoryIfNeeded(type: type, currentActiveKey: activeKey, nextActiveKey: newSessionKey);
      _activeSessionKeyByType[type] = newSessionKey;
      _sessionRefCountByKey[newSessionKey] = refCount + 1;
      _sessionTypeByKey[newSessionKey] = type;
      _modelBySessionKey[newSessionKey] = model;
      return await _switchPhysicalConnection(type: type, model: model);
    }

    if (type == PrinterType.bluetooth && (Platform.isIOS || Platform.isAndroid)) {
      try {
        final conn = await bluetoothPrinterConnector.connect(model as BluetoothPrinterInput);
        if (conn || (Platform.isAndroid && (bluetoothPrinterConnector.status == BTStatus.connected || bluetoothPrinterConnector.status == BTStatus.connecting))) {
          _pushActiveHistoryIfNeeded(type: type, currentActiveKey: activeKey, nextActiveKey: newSessionKey);
          _activeSessionKeyByType[type] = newSessionKey;
          _sessionRefCountByKey[newSessionKey] = refCount + 1;
          _sessionTypeByKey[newSessionKey] = type;
          _modelBySessionKey[newSessionKey] = model;
        }
        return conn;
      } catch (e) {
        debugPrint('PrinterManager.connect bluetooth error: $e');
        throw Exception('model must be type of BluetoothPrinterInput');
      }
    } else if (type == PrinterType.usb && (Platform.isAndroid || Platform.isWindows)) {
      try {
        final conn = await usbPrinterConnector.connect(model as UsbPrinterInput);
        if (conn || (Platform.isAndroid && usbPrinterConnector.status == USBStatus.connected)) {
          _pushActiveHistoryIfNeeded(type: type, currentActiveKey: activeKey, nextActiveKey: newSessionKey);
          _activeSessionKeyByType[type] = newSessionKey;
          _sessionRefCountByKey[newSessionKey] = refCount + 1;
          _sessionTypeByKey[newSessionKey] = type;
          _modelBySessionKey[newSessionKey] = model;
        }
        return conn;
      } catch (e) {
        debugPrint('PrinterManager.connect usb error: $e');
        throw Exception('model must be type of UsbPrinterInput');
      }
    } else {
      try {
        final connector = _getOrCreateTcpConnector(sessionKey: newSessionKey);
        final conn = await connector.connect(model as TcpPrinterInput);
        if (conn) {
          _pushActiveHistoryIfNeeded(type: type, currentActiveKey: activeKey, nextActiveKey: newSessionKey);
          _activeSessionKeyByType[type] = newSessionKey;
          _sessionRefCountByKey[newSessionKey] = refCount + 1;
          _sessionTypeByKey[newSessionKey] = type;
          _modelBySessionKey[newSessionKey] = model;
        } else {
          _removeTcpConnectorIfUnused(sessionKey: newSessionKey);
        }
        return conn;
      } catch (e) {
        debugPrint('PrinterManager.connect network error: $e');
        throw Exception('model must be type of TcpPrinterInput');
      }
    }
  }

  Future<bool> disconnect({required PrinterType type, int? delayMs, bool force = false}) async {
    if (force) {
      return await _forceDisconnectAllSessions(type: type, delayMs: delayMs);
    }

    final activeKey = _activeSessionKeyByType[type];
    if (activeKey == null) return true;

    final refCount = _sessionRefCountByKey[activeKey] ?? 0;
    if (refCount > 1) {
      _sessionRefCountByKey[activeKey] = refCount - 1;
      return true;
    }

    _sessionRefCountByKey.remove(activeKey);
    _sessionTypeByKey.remove(activeKey);
    _modelBySessionKey.remove(activeKey);

    final hasOtherInUse = _hasAnySessionInUse(type: type);
    final nextActiveKey = _restorePreviousActiveSessionKey(type: type);

    if (type == PrinterType.network) {
      final connector = _tcpConnectorBySessionKey.remove(activeKey);
      if (connector != null) {
        return await connector.disconnect(delayMs: delayMs);
      }
      return true;
    }

    if (!hasOtherInUse) {
      if (type == PrinterType.bluetooth && (Platform.isIOS || Platform.isAndroid)) {
        return await bluetoothPrinterConnector.disconnect(delayMs: delayMs);
      } else if (type == PrinterType.usb && (Platform.isAndroid || Platform.isWindows)) {
        return await usbPrinterConnector.disconnect(delayMs: delayMs);
      } else {
        final connector = _tcpConnectorBySessionKey.remove(activeKey);
        if (connector != null) {
          return await connector.disconnect(delayMs: delayMs);
        }
        return true;
      }
    }

    if (nextActiveKey != null) {
      final nextModel = _modelBySessionKey[nextActiveKey];
      if (nextModel != null) {
        await _switchPhysicalConnection(type: type, model: nextModel);
      }
    }
    return true;
  }

  Future<bool> send({required PrinterType type, required List<int> bytes}) async {
    Future<bool> _performSend() async {
      final activeKey = _activeSessionKeyByType[type];
      if (activeKey == null) return false;

      if (type == PrinterType.bluetooth && (Platform.isIOS || Platform.isAndroid)) {
        return await bluetoothPrinterConnector.send(bytes);
      } else if (type == PrinterType.usb && (Platform.isAndroid || Platform.isWindows)) {
        return await usbPrinterConnector.send(bytes);
      } else {
        final connector = _tcpConnectorBySessionKey[activeKey];
        if (connector == null) return false;
        return await connector.send(bytes);
      }
    }

    final result = await _performSend();
    if (result) return true;

    final activeKey = _activeSessionKeyByType[type];
    if (activeKey == null) return false;

    final lastModel = _modelBySessionKey[activeKey];
    if (lastModel == null) return false;

    final previousRefCount = _sessionRefCountByKey[activeKey] ?? 0;
    final reconnected = await connect(type: type, model: lastModel);
    _sessionRefCountByKey[activeKey] = previousRefCount;
    if (!reconnected) return false;

    return await _performSend();
  }

  Stream<BTStatus> get stateBluetooth => bluetoothPrinterConnector.currentStatus.cast<BTStatus>();
  Stream<USBStatus> get stateUSB => usbPrinterConnector.currentStatus.cast<USBStatus>();

  BTStatus get currentStatusBT => bluetoothPrinterConnector.status;
  USBStatus get currentStatusUSB => usbPrinterConnector.status;

  String _buildSessionKey({required PrinterType type, required BasePrinterInput model}) {
    if (type == PrinterType.bluetooth && model is BluetoothPrinterInput) {
      return 'bt:${model.address}|ble:${model.isBle ? 1 : 0}';
    }
    if (type == PrinterType.usb && model is UsbPrinterInput) {
      final vendorId = model.vendorId ?? '';
      final productId = model.productId ?? '';
      final name = model.name ?? '';
      return 'usb:$vendorId:$productId:$name';
    }
    if (type == PrinterType.network && model is TcpPrinterInput) {
      return 'tcp:${model.ipAddress}:${model.port}';
    }
    return '${type.name}:${model.runtimeType}';
  }

  String _buildDiscoveryKey({required PrinterType type, required bool isBle, TcpPrinterInput? model}) {
    if (type == PrinterType.network) {
      final ip = model?.ipAddress ?? '';
      final port = model?.port ?? 9100;
      return 'discovery:${type.name}:$ip:$port';
    }
    if (type == PrinterType.bluetooth) {
      return 'discovery:${type.name}:ble:${isBle ? 1 : 0}';
    }
    return 'discovery:${type.name}';
  }

  bool _isConnectorLikelyConnected({
    required PrinterType type,
    BasePrinterInput? model,
    String? sessionKey,
  }) {
    switch (type) {
      case PrinterType.bluetooth:
        return bluetoothPrinterConnector.status == BTStatus.connected || (Platform.isAndroid && bluetoothPrinterConnector.status == BTStatus.connecting);
      case PrinterType.usb:
        if (!Platform.isAndroid) return true;
        return usbPrinterConnector.status == USBStatus.connected;
      case PrinterType.network:
        final key = sessionKey ??
            (model is TcpPrinterInput ? _buildSessionKey(type: type, model: model) : _activeSessionKeyByType[type]);
        if (key == null) return false;
        final connector = _tcpConnectorBySessionKey[key];
        if (connector == null) return false;
        if (model is TcpPrinterInput) {
          return connector.isConnectedTo(ipAddress: model.ipAddress, port: model.port);
        }
        return connector.isConnected;
    }
  }

  Future<bool> _switchPhysicalConnection({required PrinterType type, required BasePrinterInput model}) async {
    if (type == PrinterType.bluetooth && (Platform.isIOS || Platform.isAndroid)) {
      if (model is BluetoothPrinterInput) {
        try {
          return await bluetoothPrinterConnector.connect(model);
        } catch (_) {}
      }
      return false;
    }

    if (type == PrinterType.usb && (Platform.isAndroid || Platform.isWindows)) {
      if (model is UsbPrinterInput) {
        try {
          return await usbPrinterConnector.connect(model);
        } catch (_) {}
      }
      return false;
    }

    return false;
  }

  void _pushActiveHistoryIfNeeded({
    required PrinterType type,
    required String? currentActiveKey,
    required String nextActiveKey,
  }) {
    if (currentActiveKey == null) return;
    if (currentActiveKey == nextActiveKey) return;
    final history = _sessionKeyHistoryByType.putIfAbsent(type, () => <String>[]);
    if (history.isNotEmpty && history.last == currentActiveKey) return;
    history.add(currentActiveKey);
  }

  bool _hasAnySessionInUse({required PrinterType type}) {
    for (final entry in _sessionTypeByKey.entries) {
      if (entry.value != type) continue;
      final ref = _sessionRefCountByKey[entry.key] ?? 0;
      if (ref > 0) return true;
    }
    return false;
  }

  String? _restorePreviousActiveSessionKey({required PrinterType type}) {
    final history = _sessionKeyHistoryByType[type];
    if (history != null) {
      while (history.isNotEmpty) {
        final candidate = history.removeLast();
        final ref = _sessionRefCountByKey[candidate] ?? 0;
        if (ref > 0) {
          _activeSessionKeyByType[type] = candidate;
          return candidate;
        }
      }
    }

    for (final entry in _sessionTypeByKey.entries) {
      if (entry.value != type) continue;
      final ref = _sessionRefCountByKey[entry.key] ?? 0;
      if (ref > 0) {
        _activeSessionKeyByType[type] = entry.key;
        return entry.key;
      }
    }

    _activeSessionKeyByType.remove(type);
    return null;
  }

  TcpPrinterConnector _getOrCreateTcpConnector({required String sessionKey}) {
    return _tcpConnectorBySessionKey.putIfAbsent(sessionKey, () => TcpPrinterConnector());
  }

  void _removeTcpConnectorIfUnused({required String sessionKey}) {
    final refCount = _sessionRefCountByKey[sessionKey] ?? 0;
    if (refCount > 0) return;
    _tcpConnectorBySessionKey.remove(sessionKey);
  }

  Future<bool> _forceDisconnectAllSessions({required PrinterType type, int? delayMs}) async {
    final keysToClear = _sessionTypeByKey.entries
        .where((e) => e.value == type)
        .map((e) => e.key)
        .toList(growable: false);

    if (type == PrinterType.network) {
      for (final key in keysToClear) {
        _sessionRefCountByKey.remove(key);
        _sessionTypeByKey.remove(key);
        _modelBySessionKey.remove(key);
        final connector = _tcpConnectorBySessionKey.remove(key);
        if (connector != null) {
          try {
            await connector.disconnect(delayMs: delayMs);
          } catch (_) {}
        }
      }
      _activeSessionKeyByType.remove(type);
      _sessionKeyHistoryByType.remove(type);
      return true;
    }

    for (final key in keysToClear) {
      _sessionRefCountByKey.remove(key);
      _sessionTypeByKey.remove(key);
      _modelBySessionKey.remove(key);
    }

    _activeSessionKeyByType.remove(type);
    _sessionKeyHistoryByType.remove(type);

    if (type == PrinterType.bluetooth && (Platform.isIOS || Platform.isAndroid)) {
      return await bluetoothPrinterConnector.disconnect(delayMs: delayMs);
    } else if (type == PrinterType.usb && (Platform.isAndroid || Platform.isWindows)) {
      return await usbPrinterConnector.disconnect(delayMs: delayMs);
    } else {
      return true;
    }
  }
}
