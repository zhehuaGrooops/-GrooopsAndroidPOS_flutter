import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/settings/riverpod/printer_provider.dart';
import 'package:admin_desktop/src/models/data/bluetooth_printer.dart';
import 'package:admin_desktop/src/core/utils/utils.dart';

class OpenDrawerDialog extends StatefulWidget {
  const OpenDrawerDialog({super.key});

  /// Opens the cash drawer using the same default printer behavior as PrintPage.
  ///
  /// This uses the app's saved printer config (via printerProvider). If none is
  /// saved, it checks whether the OS has a system default printer configured and
  /// shows a friendly message when missing.
  static Future<void> openDrawer(BuildContext context) async {
    final container = ProviderScope.containerOf(context, listen: false);

    void showMessage(String message) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      AppHelpers.showSnackBar(context, message);
    }

    try {
      await container.read(printerProvider.notifier).init();
    } catch (_) {}

    var printerState = container.read(printerProvider);
    var resolved = _resolveSelectedPrinterFromState(printerState);
    if (resolved == null) {
      try {
        await container.read(printerProvider.notifier).init();
      } catch (_) {}
      printerState = container.read(printerProvider);
      resolved = _resolveSelectedPrinterFromState(printerState);
    }

    if (resolved == null) {
      final hasDefault = await _checkSystemDefaultPrinterConfigured();
      if (!context.mounted) return;
      if (hasDefault == false) {
        final message = _translateWithFallback(
          'printer_setup_required_message',
          'No default printer is configured. Please set a default printer in your system settings, then configure a printer in the app Settings.',
        );
        showMessage(message);
        return;
      }

      final message = _translateWithFallback(
        'printer_not_selected_message',
        'No printer selected. Please configure a printer in the app Settings.',
      );
      showMessage(message);
      return;
    }

    try {
      if (!printerState.isConnected) {
        try {
          await container.read(printerProvider.notifier).connect(resolved);
          printerState = container.read(printerProvider);
        } catch (_) {}
      }

      if (printerState.error != null && printerState.error!.trim().isNotEmpty) {
        if (!context.mounted) return;
        showMessage('Failed to open drawer. ${printerState.error}');
        return;
      }

      final bytes = _drawerOpenBytes();
      final ok = await PrinterManager.instance.send(
        type: resolved.typePrinter,
        bytes: bytes,
      );
      if (!ok) {
        if (!context.mounted) return;
        showMessage(
          'Failed to open drawer. Please check printer connection/paper and try again.',
        );
      }
    } catch (e, st) {
      log('OpenDrawerDialog.openDrawer failed', error: e, stackTrace: st);
      if (!context.mounted) return;
      showMessage('Failed to open drawer: ${e.toString()}');
    }
  }

  @override
  State<OpenDrawerDialog> createState() => _OpenDrawerDialogState();
}

class _OpenDrawerDialogState extends State<OpenDrawerDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await OpenDrawerDialog.openDrawer(context);
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

BluetoothPrinter? _resolveSelectedPrinterFromState(dynamic printerState) {
  try {
    final selected = printerState.selectedDevice as BluetoothPrinter?;
    if (selected != null) return selected;

    final config = printerState.savedConfig;
    if (config == null) return null;
    if (config.type < 0 || config.type >= PrinterType.values.length) {
      return null;
    }
    return BluetoothPrinter(
      deviceName: config.name,
      address: config.address,
      vendorId: config.vendorId,
      productId: config.productId,
      isBle: config.isBle,
      typePrinter: PrinterType.values[config.type],
    );
  } catch (_) {
    return null;
  }
}

String _translateWithFallback(String key, String fallback) {
  try {
    final translations = LocalStorage.getTranslations();
    final v = translations[key];
    if (v is String && v.trim().isNotEmpty) return v;
  } catch (_) {}
  return fallback;
}

Future<bool?> _checkSystemDefaultPrinterConfigured() async {
  try {
    if (Platform.isWindows) {
      final result = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-Command',
          r'(Get-CimInstance Win32_Printer | Where-Object { $_.Default -eq $true } | Select-Object -First 1 -ExpandProperty Name)',
        ],
        runInShell: true,
      );
      final name = (result.stdout ?? '').toString().trim();
      return name.isNotEmpty;
    }

    if (Platform.isMacOS || Platform.isLinux) {
      final result = await Process.run(
        'lpstat',
        ['-d'],
        runInShell: true,
      );
      final out = (result.stdout ?? '').toString().trim();
      final err = (result.stderr ?? '').toString().trim();
      final combined = '$out\n$err'.trim();

      final match = RegExp(
        r'system\s+default\s+destination\s*:\s*(.+)',
        caseSensitive: false,
      ).firstMatch(combined);
      if (match != null) {
        final name = (match.group(1) ?? '').trim();
        return name.isNotEmpty;
      }

      final lowered = combined.toLowerCase();
      if (lowered.contains('no system default') ||
          lowered.contains('no default')) {
        return false;
      }

      if (result.exitCode != 0) {
        return null;
      }

      return false;
    }
  } catch (e, st) {
    log('Failed to detect system default printer', error: e, stackTrace: st);
  }
  return null;
}

List<int> _drawerPulseBytes(int pin) {
  final int m = (pin == 4) ? 1 : 0;
  const int t1 = 50;
  const int t2 = 250;
  return [27, 112, m, t1, t2];
}

List<int> _drawerOpenBytes() {
  final List<int> bytes = [];
  bytes.addAll([27, 64]); // ESC @
  bytes.addAll(_drawerPulseBytes(2));
  bytes.addAll(_drawerPulseBytes(4));
  return bytes;
}
