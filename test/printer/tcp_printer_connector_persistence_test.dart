import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:flutter_test/flutter_test.dart';

// Validates that TCP (LAN) printing keeps the socket alive across multiple send calls.
void main() {
  test('TcpPrinterConnector keeps connection open across multiple sends',
      () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await server.close();
    });

    final acceptedSockets = <Socket>[];
    final receivedBytes = <int>[];
    final firstConnectionReady = Completer<void>();

    final serverSub = server.listen((socket) {
      acceptedSockets.add(socket);
      socket.listen(
        (Uint8List chunk) {
          receivedBytes.addAll(chunk);
          if (!firstConnectionReady.isCompleted) {
            firstConnectionReady.complete();
          }
        },
        onError: (_) {},
        onDone: () {},
        cancelOnError: true,
      );
    });
    addTearDown(() async {
      await serverSub.cancel();
      for (final s in acceptedSockets) {
        try {
          await s.close();
        } catch (_) {}
      }
    });

    final connector = TcpPrinterConnector.instance;
    final okConnect = await connector.connect(
      TcpPrinterInput(
        ipAddress: InternetAddress.loopbackIPv4.address,
        port: server.port,
        timeout: const Duration(seconds: 2),
      ),
    );
    expect(okConnect, isTrue);

    final ok1 = await connector.send([1, 2, 3]);
    await firstConnectionReady.future.timeout(const Duration(seconds: 2));
    final ok2 = await connector.send([4, 5, 6]);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(ok1, isTrue);
    expect(ok2, isTrue);
    expect(acceptedSockets.length, 1);
    expect(receivedBytes, containsAllInOrder(<int>[1, 2, 3, 4, 5, 6]));

    await connector.disconnect();
  });

  test('PrinterManager sends after TCP disconnect/reconnect', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await server.close();
    });

    final acceptedSockets = <Socket>[];
    final receivedBytes = <int>[];
    final firstByteReceived = Completer<void>();
    final secondByteReceived = Completer<void>();

    final serverSub = server.listen((socket) {
      acceptedSockets.add(socket);
      socket.listen(
        (Uint8List chunk) {
          receivedBytes.addAll(chunk);
          if (!firstByteReceived.isCompleted) {
            firstByteReceived.complete();
          } else if (!secondByteReceived.isCompleted) {
            secondByteReceived.complete();
          }
        },
        onError: (_) {},
        onDone: () {},
        cancelOnError: true,
      );
    });
    addTearDown(() async {
      await serverSub.cancel();
      for (final s in acceptedSockets) {
        try {
          await s.close();
        } catch (_) {}
      }
    });

    final manager = PrinterManager.instance;
    await manager.disconnect(type: PrinterType.network, force: true);

    final okConnect = await manager.connect(
      type: PrinterType.network,
      model: TcpPrinterInput(
        ipAddress: InternetAddress.loopbackIPv4.address,
        port: server.port,
        timeout: const Duration(seconds: 2),
      ),
    );
    expect(okConnect, isTrue);

    final ok1 = await manager.send(type: PrinterType.network, bytes: [1]);
    await firstByteReceived.future.timeout(const Duration(seconds: 2));
    expect(ok1, isTrue);
    expect(acceptedSockets.length, 1);

    await TcpPrinterConnector.instance.disconnect();

    final ok2 = await manager.send(type: PrinterType.network, bytes: [2]);
    await secondByteReceived.future.timeout(const Duration(seconds: 2));
    expect(ok2, isTrue);
    expect(acceptedSockets.length, greaterThanOrEqualTo(1));
    expect(receivedBytes, containsAllInOrder(<int>[1, 2]));

    await manager.disconnect(type: PrinterType.network, force: true);
  });
}
