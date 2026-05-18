import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_pos_printer_platform_image_3/src/models/printer_device.dart';
import 'package:network_info_plus/network_info_plus.dart';

import 'package:flutter_pos_printer_platform_image_3/discovery.dart';
import 'package:flutter_pos_printer_platform_image_3/printer.dart';
import 'package:ping_discover_network_forked/ping_discover_network_forked.dart';

class TcpPrinterInput extends BasePrinterInput {
  final String ipAddress;
  final int port;
  final Duration timeout;
  TcpPrinterInput({
    required this.ipAddress,
    this.port = 9100,
    this.timeout = const Duration(seconds: 5),
  });
}

class TcpPrinterInfo {
  String address;
  TcpPrinterInfo({
    required this.address,
  });
}

class TcpPrinterConnector implements PrinterConnector<TcpPrinterInput> {
  TcpPrinterConnector._();
  static TcpPrinterConnector _instance = TcpPrinterConnector._();

  static TcpPrinterConnector get instance => _instance;

  TcpPrinterConnector();
  Socket? _socket;
  String? _connectedIpAddress;
  int? _connectedPort;

  bool get isConnected =>
      _socket != null && _connectedIpAddress != null && _connectedPort != null;

  bool isConnectedTo({required String ipAddress, required int port}) {
    return _socket != null &&
        _connectedIpAddress == ipAddress &&
        _connectedPort == port;
  }

  static Future<List<PrinterDiscovered<TcpPrinterInfo>>> discoverPrinters({String? ipAddress, int? port, Duration? timeOut}) async {
    final List<PrinterDiscovered<TcpPrinterInfo>> result = [];
    await runZonedGuarded(() async {
      try {
        final defaultPort = port ?? 9100;

        String? deviceIp;
        if (Platform.isAndroid || Platform.isIOS) {
          deviceIp = await NetworkInfo().getWifiIP();
        } else if (ipAddress != null) deviceIp = ipAddress;

        if (deviceIp == null || !deviceIp.contains('.')) return;

        final String subnet = deviceIp.substring(0, deviceIp.lastIndexOf('.'));

        final stream = NetworkAnalyzer.discover2(
          subnet,
          defaultPort,
          timeout: timeOut ?? Duration(milliseconds: 1000),
        );

        await for (var addr in stream
            .handleError((error) {
              print("Error during network discovery stream: $error");
            })
            .timeout(const Duration(seconds: 30), onTimeout: (sink) {
              print("Network discovery timed out");
              sink.close();
            })) {
          if (addr.exists) {
            result.add(PrinterDiscovered<TcpPrinterInfo>(name: "${addr.ip}:$defaultPort", detail: TcpPrinterInfo(address: addr.ip)));
          }
        }
      } catch (e) {
        print("Error discovering printers: $e");
      }
    }, (error, stack) {
      print("Caught unhandled error in discoverPrinters: $error");
    });

    return result;
  }

  /// Starts a scan for network printers.
  Stream<PrinterDevice> discovery({TcpPrinterInput? model}) {
    final controller = StreamController<PrinterDevice>();

    runZonedGuarded(() async {
      try {
        final defaultPort = model?.port ?? 9100;

        String? deviceIp;
        if (Platform.isAndroid || Platform.isIOS) {
          deviceIp = await NetworkInfo().getWifiIP();
        } else if (model?.ipAddress != null) {
          deviceIp = model!.ipAddress;
        } else {
          controller.close();
          return;
        }

        if (deviceIp == null || !deviceIp.contains('.')) {
          controller.close();
          return;
        }

        final String subnet = deviceIp.substring(0, deviceIp.lastIndexOf('.'));

        final stream = NetworkAnalyzer.discover2(
          subnet,
          defaultPort,
          timeout: model?.timeout ?? const Duration(milliseconds: 1000),
        );

        await for (var data in stream
            .handleError((error) {
              print("Error during network discovery stream: $error");
            })
            .timeout(const Duration(seconds: 30), onTimeout: (sink) {
              print("Network discovery timed out");
              sink.close();
            })) {
          if (data.exists) {
            controller.add(PrinterDevice(name: "${data.ip}:$defaultPort", address: data.ip));
          }
        }
      } catch (e) {
        print("Error discovering printers: $e");
      } finally {
        if (!controller.isClosed) controller.close();
      }
    }, (error, stack) {
      print("Caught unhandled error in discovery: $error");
      if (!controller.isClosed) controller.close();
    });

    return controller.stream;
  }

  @override
  Future<bool> send(List<int> bytes) async {
    try {
      // Keep the TCP connection open to allow multiple print jobs without reconnecting.
      _socket?.add(Uint8List.fromList(bytes));
      await _socket?.flush();
      return _socket != null;
    } catch (e) {
      debugPrint('Printer send failed: $e');
      try {
        _socket?.destroy();
      } catch (error) {}
    
      _socket = null;
      _connectedIpAddress = null;
      _connectedPort = null;
      return false;
    }
  }

  @override
  Future<bool> connect(TcpPrinterInput model) async {
    try {
      if (_socket != null &&
          _connectedIpAddress == model.ipAddress &&
          _connectedPort == model.port) {
        return true;
      }

      try {
        _socket?.destroy();
      } catch (_) {}
      _socket = null;

      _socket = await Socket.connect(model.ipAddress, model.port, timeout: model.timeout);
      _connectedIpAddress = model.ipAddress;
      _connectedPort = model.port;

      _socket?.listen(
        (_) {},
        onDone: () {
          _socket?.destroy();
          _socket = null;
          _connectedIpAddress = null;
          _connectedPort = null;
        },
        onError: (_) {
          _socket?.destroy();
          _socket = null;
          _connectedIpAddress = null;
          _connectedPort = null;
        },
        cancelOnError: true,
      );
      return true;
    } catch (e) {
      print(e);
      return false;
    }
  }

  /// [delayMs]: milliseconds to wait after destroying the socket
  @override
  Future<bool> disconnect({int? delayMs}) async {
    try {
      _socket?.destroy();
    } catch (_) {}
    _socket = null;
    _connectedIpAddress = null;
    _connectedPort = null;
    if (delayMs != null) {
      await Future.delayed(Duration(milliseconds: delayMs), () => null);
    }
    return true;
  }
}
