import 'dart:io';

import 'package:admin_desktop/src/core/di/injection.dart';
import 'package:admin_desktop/src/core/utils/app_helpers.dart';
import 'package:admin_desktop/src/models/data/printer_config.dart';
import 'package:admin_desktop/src/repository/printer_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';

Future<int> _readReceiptCharsPerLineFromHive() async {
  final repo = inject<PrinterRepository>();
  final config = await repo.getPrinterConfig();
  return AppHelpers.clampCharsPerLine(config?.charsPerLine);
}

Future<bool> testPrintAndNotify({
  required BuildContext context,
  required PrinterConfig config,
}) async {
  final ok = await _sendTestPrint(config: config);
  if (!context.mounted) return ok;
  AppHelpers.showSnackBar(
    context,
    ok ? 'Test print sent.' : 'Test print failed. Check printer connection.',
  );
  return ok;
}

Future<bool> _sendTestPrint({required PrinterConfig config}) async {
  if (config.type < 0 || config.type >= PrinterType.values.length) {
    return false;
  }
  final type = PrinterType.values[config.type];
  final name = (config.name ?? '').trim();
  final address = (config.address ?? '').trim();

  dynamic model;
  switch (type) {
    case PrinterType.usb:
      final vendorId = config.vendorId;
      final productId = config.productId;
      if (vendorId == null || productId == null) return false;
      model = UsbPrinterInput(
        name: name.isEmpty ? null : name,
        productId: productId,
        vendorId: vendorId,
      );
      break;
    case PrinterType.bluetooth:
      if (address.isEmpty) return false;
      model = BluetoothPrinterInput(
        name: name.isEmpty ? null : name,
        address: address,
        isBle: config.isBle,
        autoConnect: true,
      );
      break;
    case PrinterType.network:
      if (address.isEmpty) return false;
      model = TcpPrinterInput(ipAddress: address);
      break;
  }

  CapabilityProfile profile;
  try {
    profile = await CapabilityProfile.load(name: 'XP-N160I');
  } catch (_) {
    profile = await CapabilityProfile.load();
  }
  final charsPerLine = await _readReceiptCharsPerLineFromHive();
  final generator = Generator(PaperSize.mm80, profile);

  final bytes = <int>[
    ...generator.reset(),
    ...generator.setGlobalCodeTable('CP1252'),
    ...generator.text(AppHelpers.centerAlignText('TEST PRINT', charsPerLine)),
    ...generator.text(AppHelpers.centerAlignText(
        name.isEmpty ? 'Printer' : name, charsPerLine)),
    if (address.isNotEmpty)
      ...generator.text(AppHelpers.centerAlignText(address, charsPerLine)),
    ...generator.hr(),
    ...generator.text(DateTime.now().toLocal().toIso8601String()),
    ...generator.feed(1),
  ];

  final printerManager = PrinterManager.instance;
  try {
    final connected = await printerManager.connect(type: type, model: model);
    if (!connected && !(type == PrinterType.bluetooth && Platform.isAndroid)) {
      return false;
    }

    final bytesToSend = <int>[...bytes];
    if (type == PrinterType.bluetooth) {
      bytesToSend.addAll(generator.cut());
    } else {
      bytesToSend.addAll(generator.feed(2));
      bytesToSend.addAll(generator.cut());
    }

    return await printerManager.send(type: type, bytes: bytesToSend);
  } catch (_) {
    return false;
  } finally {
    try {
      await printerManager.disconnect(type: type);
    } catch (_) {}
  }
}
