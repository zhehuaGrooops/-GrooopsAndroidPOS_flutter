import 'dart:async';
import 'dart:io';

import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PrinterManager supports multiple TCP sessions and shared ref counting', () async {
    final serverA = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final serverB = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);

    final subscriptions = <StreamSubscription<Socket>>[];
    subscriptions.add(serverA.listen((socket) {}));
    subscriptions.add(serverB.listen((socket) {}));

    try {
      await PrinterManager.instance.disconnect(type: PrinterType.network, force: true);

      final modelA = TcpPrinterInput(
        ipAddress: InternetAddress.loopbackIPv4.address,
        port: serverA.port,
        timeout: const Duration(seconds: 2),
      );
      final modelB = TcpPrinterInput(
        ipAddress: InternetAddress.loopbackIPv4.address,
        port: serverB.port,
        timeout: const Duration(seconds: 2),
      );

      expect(await PrinterManager.instance.connect(type: PrinterType.network, model: modelA), isTrue);
      expect(await PrinterManager.instance.send(type: PrinterType.network, bytes: <int>[0x1B, 0x40]), isTrue);

      expect(await PrinterManager.instance.connect(type: PrinterType.network, model: modelB), isTrue);
      expect(await PrinterManager.instance.send(type: PrinterType.network, bytes: <int>[0x1B, 0x40]), isTrue);

      expect(await PrinterManager.instance.disconnect(type: PrinterType.network), isTrue);
      expect(await PrinterManager.instance.send(type: PrinterType.network, bytes: <int>[0x1B, 0x40]), isTrue);

      expect(await PrinterManager.instance.connect(type: PrinterType.network, model: modelA), isTrue);
      expect(await PrinterManager.instance.disconnect(type: PrinterType.network), isTrue);
      expect(await PrinterManager.instance.send(type: PrinterType.network, bytes: <int>[0x1B, 0x40]), isTrue);

      expect(await PrinterManager.instance.disconnect(type: PrinterType.network), isTrue);
      expect(await PrinterManager.instance.send(type: PrinterType.network, bytes: <int>[0x1B, 0x40]), isFalse);
    } finally {
      try {
        await PrinterManager.instance.disconnect(type: PrinterType.network, force: true);
      } catch (_) {}

      for (final s in subscriptions) {
        try {
          await s.cancel();
        } catch (_) {}
      }
      await serverA.close();
      await serverB.close();
    }
  });
}

