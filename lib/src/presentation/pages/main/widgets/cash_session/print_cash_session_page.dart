// ignore_for_file: deprecated_member_use

import 'dart:developer';
import 'package:admin_desktop/src/core/utils/app_helpers.dart';
import 'package:admin_desktop/src/core/di/injection.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/settings/riverpod/printer_provider.dart';
import 'package:admin_desktop/src/repository/printer_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart';
import 'package:intl/intl.dart';
import 'package:admin_desktop/src/core/utils/local_storage.dart';
import 'package:admin_desktop/src/presentation/components/components.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:admin_desktop/src/models/data/bluetooth_printer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> printCashSessionReceipt({
  required BuildContext context,
  required WidgetRef ref,
  required Map<String, dynamic> sessionData,
}) async {
  var printerState = ref.read(printerProvider);
  var hasSelection =
      printerState.selectedDevice != null || printerState.savedConfig != null;
  if (!hasSelection) {
    await ref.read(printerProvider.notifier).init();
    if (!context.mounted) return;
    printerState = ref.read(printerProvider);
    hasSelection =
        printerState.selectedDevice != null || printerState.savedConfig != null;
  }
  if (!hasSelection) {
    _showNoPrinterSelectedWarning(context);
    log('Printing skipped: no printer selected (cash session)');
    return;
  }

  final printer = _resolveSelectedPrinter(printerState);
  if (printer == null) {
    _showNoPrinterSelectedWarning(context);
    log('Printing skipped: no printer selected (unable to resolve config)');
    return;
  }

  final repo = inject<PrinterRepository>();
  final savedConfig = await repo.getPrinterConfig();
  final charsPerLine = AppHelpers.clampCharsPerLine(savedConfig?.charsPerLine);
  final receipt = await _buildCashSessionReceipt(
    sessionData,
    charsPerLine: charsPerLine,
  );
  if (!context.mounted) return;
  final ok = await _sendEscPos(
    printer: printer,
    bytes: receipt.bytes,
    generator: receipt.generator,
  );
  if (!ok && context.mounted) {
    _showPrintFailedWarning(context);
  }
}

BluetoothPrinter? _resolveSelectedPrinter(dynamic printerState) {
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

void _showNoPrinterSelectedWarning(BuildContext context) {
  final message = _translateWithFallback(
    'printer_not_selected_message',
    'No printer selected. Please configure a printer in the app Settings.',
  );
  AppHelpers.showSnackBar(context, message);
}

void _showPrintFailedWarning(BuildContext context) {
  AppHelpers.showSnackBar(
    context,
    'Printing failed. Please check printer connection/paper and try again.',
  );
}

Future<bool> _sendEscPos({
  required BluetoothPrinter printer,
  required List<int> bytes,
  required Generator generator,
}) async {
  final bytesToSend = <int>[...bytes];
  if (printer.typePrinter == PrinterType.bluetooth) {
    bytesToSend.addAll(generator.cut());
  } else {
    bytesToSend.addAll(generator.feed(2));
    bytesToSend.addAll(generator.cut());
  }

  try {
    return await PrinterManager.instance.send(
      type: printer.typePrinter,
      bytes: bytesToSend,
    );
  } catch (e, st) {
    log(
      'Cash session printing failed with exception',
      error: e,
      stackTrace: st,
    );
    return false;
  }
}

typedef _CashSessionReceipt = ({List<int> bytes, Generator generator});

Future<_CashSessionReceipt> _buildCashSessionReceipt(
  Map<String, dynamic> sessionData, {
  required int charsPerLine,
}) async {
  // Normalize payload (some APIs wrap payload under `data`)
  final raw = sessionData;
  final data = raw['data'] is Map
      ? Map<String, dynamic>.from(raw['data'] as Map)
      : Map<String, dynamic>.from(raw);
  final summary = (data['transactions_summary'] is Map)
      ? (data['transactions_summary'] as Map)
      : <String, dynamic>{};
  final revenue = (summary['revenue_summary'] is Map)
      ? (summary['revenue_summary'] as Map)
      : <String, dynamic>{};

  final profile = await CapabilityProfile.load(name: 'XP-N160I');
  final generator = Generator(PaperSize.mm80, profile);

  String toTitleCase(String s) {
    final str = s.toString();
    if (str.isEmpty) return ' ';
    final parts = str.replaceAll('_', ' ').split(' ');
    return parts
        .map((p) => p.isEmpty ? '' : '${p[0].toUpperCase()}${p.substring(1)}')
        .join(' ');
  }

  String fmtNum(dynamic v) {
    try {
      if (v == null) return '0.00';
      if (v is num) return NumberFormat('#,##0.00', 'en_US').format(v);
      final parsed = double.tryParse(v.toString());
      return NumberFormat('#,##0.00', 'en_US').format(parsed ?? 0);
    } catch (_) {
      final res = v.toString();
      return res.isEmpty ? ' ' : res;
    }
  }

  String fmtDate(dynamic v) {
    try {
      if (v == null) return ' ';
      final s = v.toString();
      // try parse ISO, otherwise return raw
      final dt = DateTime.tryParse(s);
      if (dt != null) {
        return DateFormat('dd-MM-yy').format(dt.toLocal());
      }
      return s.isEmpty ? ' ' : s;
    } catch (_) {
      final res = v.toString();
      return res.isEmpty ? ' ' : res;
    }
  }

  List<int> bytes = [];
  // ensure printer is in a known default state (clear justification/underline/bold etc)
  bytes += generator.reset();
  bytes += generator.setGlobalCodeTable('CP1252');

  // Header
  bytes += generator.setStyles(const PosStyles(fontType: PosFontType.fontA));
  bytes += generator.text(
    AppHelpers.centerAlignText('DAY REPORT', charsPerLine ~/ 2),
    styles: const PosStyles(
        align: PosAlign.left,
        bold: true,
        underline: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2),
    containsChinese: true,
  );
  bytes += generator.text(' ');

  // Reported Date
  bytes += generator.row([
    PosColumn(
      width: 5,
      text: '  Reported Date:',
      styles: const PosStyles(align: PosAlign.left, bold: true),
      containsChinese: true,
    ),
    PosColumn(
      width: 7,
      text: fmtDate(summary['date'] ?? ''),
      styles: const PosStyles(align: PosAlign.left, bold: false),
      containsChinese: true,
    ),
  ]);
  bytes += generator.text(' ');

  // Revenue summary (print known keys first in friendly order)
  if (revenue.isNotEmpty) {
    bytes += generator.row([
      PosColumn(
          width: 6,
          text: 'Revenue Summary',
          styles: const PosStyles(align: PosAlign.left, bold: true),
          containsChinese: true),
      PosColumn(
          width: 6,
          text: 'Amount (RM)',
          styles: const PosStyles(align: PosAlign.right, bold: true),
          containsChinese: true),
    ]);
    final ordered = <String>[
      'cash',
      'wallet',
      'paytabs',
      'flutter-wave',
      'paystack',
      'mercado-pago',
      'razorpay',
      'stripe',
      'paypal',
    ];
    for (final key in ordered) {
      if (revenue.containsKey(key)) {
        bytes += generator.row([
          PosColumn(
              width: 6,
              text: toTitleCase(key),
              styles: const PosStyles(align: PosAlign.left),
              containsChinese: true),
          PosColumn(
              width: 6,
              text: fmtNum(revenue[key]),
              styles: const PosStyles(align: PosAlign.right),
              containsChinese: true),
        ]);
      }
    }
    // any remaining keys
    for (final entry in revenue.entries) {
      if (ordered.contains(entry.key)) continue;
      bytes += generator.row([
        PosColumn(
            width: 6,
            text: toTitleCase(entry.key),
            styles: const PosStyles(align: PosAlign.left),
            containsChinese: true),
        PosColumn(
            width: 6,
            text: fmtNum(entry.value),
            styles: const PosStyles(align: PosAlign.right),
            containsChinese: true),
      ]);
    }
    bytes += generator.text(' ');
  }

  // Service types
  if (summary['service_types'] is Map &&
      (summary['service_types']['items'] is List)) {
    bytes += generator.row([
      PosColumn(
        width: 4,
        text: 'Service Type',
        styles: const PosStyles(align: PosAlign.left, bold: true),
      ),
      PosColumn(
        width: 4,
        text: 'Percentage',
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
      PosColumn(
        width: 4,
        text: 'Amount (RM)',
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);
    for (final e in summary['service_types']['items']) {
      final name = e['type'] ?? e['name'] ?? ' ';
      final percentage = fmtNum(e['percentage'] ?? 0);
      final amount = fmtNum(e['amount'] ?? 0);
      bytes += generator.row([
        PosColumn(
            width: 4,
            text: '$name',
            styles: const PosStyles(align: PosAlign.left),
            containsChinese: true),
        PosColumn(
            width: 4,
            text: percentage,
            styles: const PosStyles(align: PosAlign.right),
            containsChinese: true),
        PosColumn(
            width: 4,
            text: amount,
            styles: const PosStyles(align: PosAlign.right),
            containsChinese: true),
      ]);
    }
    bytes += generator.row([
      PosColumn(
          width: 4,
          text: 'Total',
          styles: const PosStyles(align: PosAlign.left),
          containsChinese: true),
      PosColumn(
          width: 4,
          text: ' ',
          styles: const PosStyles(align: PosAlign.right),
          containsChinese: true),
      PosColumn(
          width: 4,
          text: fmtNum(summary['service_types']['total'] ?? 0),
          styles: const PosStyles(align: PosAlign.right),
          containsChinese: true),
    ]);
    bytes += generator.text(' ');
  }

  // Collections (method of payment)
  if (summary['mop_collections'] is Map &&
      (summary['mop_collections']['items'] is List)) {
    bytes += generator.row([
      PosColumn(
        width: 4,
        text: 'MOP Collections',
        styles: const PosStyles(align: PosAlign.left, bold: true),
      ),
      PosColumn(
        width: 4,
        text: 'Count',
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
      PosColumn(
        width: 4,
        text: 'Amount (RM)',
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);
    for (final e in summary['mop_collections']['items']) {
      final method = e['method'] ?? e['name'] ?? ' ';
      final count = fmtNum(e['count'] ?? 0);
      final amount = fmtNum(e['amount'] ?? e['total'] ?? 0);
      bytes += generator.row([
        PosColumn(
            width: 4,
            text: '$method',
            styles: const PosStyles(align: PosAlign.left),
            containsChinese: true),
        PosColumn(
            width: 4,
            text: count,
            styles: const PosStyles(align: PosAlign.right),
            containsChinese: true),
        PosColumn(
            width: 4,
            text: amount,
            styles: const PosStyles(align: PosAlign.right),
            containsChinese: true),
      ]);
    }
    bytes += generator.row([
      PosColumn(
          width: 4,
          text: 'Total',
          styles: const PosStyles(align: PosAlign.left),
          containsChinese: true),
      PosColumn(
          width: 4,
          text: fmtNum(summary['mop_collections']['count'] ?? 0),
          styles: const PosStyles(align: PosAlign.right),
          containsChinese: true),
      PosColumn(
          width: 4,
          text: fmtNum(summary['mop_collections']['total'] ?? 0),
          styles: const PosStyles(align: PosAlign.right),
          containsChinese: true),
    ]);
    bytes += generator.text(' ');
  }

  // Cashier collections
  if (summary['cashier_collections'] is Map &&
      (summary['cashier_collections']['items'] is List)) {
    bytes += generator.row([
      PosColumn(
          width: 6,
          text: 'Cashier Collections',
          styles: const PosStyles(align: PosAlign.left, bold: true),
          containsChinese: true),
      PosColumn(
          width: 6,
          text: 'Amount (RM)',
          styles: const PosStyles(align: PosAlign.right, bold: true),
          containsChinese: true),
    ]);
    for (final e in summary['cashier_collections']['items']) {
      final name = e['name'] ?? ' ';
      final amount = fmtNum(e['amount'] ?? 0);
      bytes += generator.row([
        PosColumn(
            width: 6,
            text: '$name',
            styles: const PosStyles(align: PosAlign.left),
            containsChinese: true),
        PosColumn(
            width: 6,
            text: amount,
            styles: const PosStyles(align: PosAlign.right),
            containsChinese: true),
      ]);
    }
    bytes += generator.row([
      PosColumn(
          width: 6,
          text: 'Total',
          styles: const PosStyles(align: PosAlign.left),
          containsChinese: true),
      PosColumn(
          width: 6,
          text: fmtNum(summary['cashier_collections']['total'] ?? 0),
          styles: const PosStyles(align: PosAlign.right),
          containsChinese: true),
    ]);
    bytes += generator.text(' ');
  }

  // Categories
  if (summary['categories'] is Map &&
      (summary['categories']['items'] is List)) {
    bytes += generator.row([
      PosColumn(
          width: 4,
          text: 'Sales by Items',
          styles: const PosStyles(align: PosAlign.left, bold: true),
          containsChinese: true),
      PosColumn(
          width: 4,
          text: 'Qty',
          styles: const PosStyles(align: PosAlign.right, bold: true),
          containsChinese: true),
      PosColumn(
          width: 4,
          text: 'Amount (RM)',
          styles: const PosStyles(align: PosAlign.right, bold: true),
          containsChinese: true),
    ]);
    for (final e in summary['categories']['items']) {
      final name = e['name'] ?? ' ';
      final qty = fmtNum(e['qty'] ?? 0);
      final amount = fmtNum(e['amount'] ?? 0);
      bytes += generator.row([
        PosColumn(
            width: 4,
            text: '$name',
            styles: const PosStyles(align: PosAlign.left),
            containsChinese: true),
        PosColumn(
            width: 4,
            text: qty,
            styles: const PosStyles(align: PosAlign.right),
            containsChinese: true),
        PosColumn(
            width: 4,
            text: amount,
            styles: const PosStyles(align: PosAlign.right),
            containsChinese: true),
      ]);
    }
    bytes += generator.row([
      PosColumn(
          width: 4,
          text: 'Total',
          styles: const PosStyles(align: PosAlign.left),
          containsChinese: true),
      PosColumn(
          width: 4,
          text: fmtNum(summary['categories']['qty'] ?? 0),
          styles: const PosStyles(align: PosAlign.right),
          containsChinese: true),
      PosColumn(
          width: 4,
          text: fmtNum(summary['categories']['total'] ?? 0),
          styles: const PosStyles(align: PosAlign.right),
          containsChinese: true),
    ]);
    bytes += generator.text(' ');
  }

  // Tax summary
  if (summary['tax_summary'] is Map &&
      (summary['tax_summary']['items'] is List)) {
    bytes += generator.row([
      PosColumn(
        width: 3,
        text: 'Tax Summary',
        styles: const PosStyles(align: PosAlign.left, bold: true),
      ),
      PosColumn(
        width: 3,
        text: 'Gross (RM)',
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
      PosColumn(
        width: 3,
        text: 'Tax (RM)',
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
      PosColumn(
        width: 3,
        text: 'Net (RM)',
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);
    for (final e in summary['tax_summary']['items']) {
      final name = e['label'] ?? e['tax'] ?? ' ';
      final gross = fmtNum(e['gross'] ?? 0);
      final tax = fmtNum(e['tax'] ?? 0);
      final net = fmtNum(e['net'] ?? e['total'] ?? 0);
      bytes += generator.row([
        PosColumn(
            width: 3,
            text: '$name',
            styles: const PosStyles(align: PosAlign.left),
            containsChinese: true),
        PosColumn(
            width: 3,
            text: gross,
            styles: const PosStyles(align: PosAlign.right),
            containsChinese: true),
        PosColumn(
            width: 3,
            text: tax,
            styles: const PosStyles(align: PosAlign.right),
            containsChinese: true),
        PosColumn(
            width: 3,
            text: net,
            styles: const PosStyles(align: PosAlign.right),
            containsChinese: true),
      ]);
    }
    bytes += generator.row([
      PosColumn(
          width: 3,
          text: 'Total',
          styles: const PosStyles(align: PosAlign.left),
          containsChinese: true),
      PosColumn(
          width: 3,
          text: fmtNum(summary['tax_summary']['gross'] ?? 0),
          styles: const PosStyles(align: PosAlign.right),
          containsChinese: true),
      PosColumn(
          width: 3,
          text: fmtNum(summary['tax_summary']['tax'] ?? 0),
          styles: const PosStyles(align: PosAlign.right),
          containsChinese: true),
      PosColumn(
          width: 3,
          text: fmtNum(summary['tax_summary']['net'] ?? 0),
          styles: const PosStyles(align: PosAlign.right),
          containsChinese: true),
    ]);
  }

  bytes += generator.row([
    PosColumn(
      width: 12,
      text: '   **belong to service charges',
      styles:
          const PosStyles(align: PosAlign.left, fontType: PosFontType.fontB),
      containsChinese: true,
    )
  ]);
  bytes += generator.text(' ');
  bytes += generator.setStyles(const PosStyles(
      fontType: PosFontType.fontA)); // Reset to default font type

  // Sales stats (counts)
  if (summary['sales_stats'] is Map) {
    bytes += generator.row([
      PosColumn(
          width: 6,
          text: 'Sales Statistics',
          styles: const PosStyles(align: PosAlign.left, bold: true),
          containsChinese: true),
      PosColumn(
          width: 6,
          text: 'Quantity',
          styles: const PosStyles(align: PosAlign.right, bold: true),
          containsChinese: true),
    ]);
    (summary['sales_stats'] as Map).forEach((k, v) {
      bytes += generator.row([
        PosColumn(
            width: 6,
            text: toTitleCase(k),
            styles: const PosStyles(align: PosAlign.left),
            containsChinese: true),
        PosColumn(
            width: 6,
            text: v?.toString() ?? '0',
            styles: const PosStyles(align: PosAlign.right),
            containsChinese: true),
      ]);
    });
    bytes += generator.text(' ');
  }

  // Footer
  bytes += generator.row([
    PosColumn(
      width: 4,
      text: '  Printed At:',
      styles: const PosStyles(align: PosAlign.left, bold: true),
      containsChinese: true,
    ),
    PosColumn(
      width: 8,
      text: DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now()),
      styles: const PosStyles(align: PosAlign.left, bold: false),
      containsChinese: true,
    ),
  ]);
  final user = LocalStorage.getUser();
  final printedBy = '${user?.firstname ?? ' '} ${user?.lastname ?? ' '}'.trim();
  final printedByDisplay =
      printedBy.isNotEmpty ? printedBy : (user?.email ?? ' ');
  bytes += generator.row([
    PosColumn(
      width: 4,
      text: '  Printed By:',
      styles: const PosStyles(align: PosAlign.left, bold: true),
      containsChinese: true,
    ),
    PosColumn(
      width: 8,
      text: printedByDisplay,
      styles: const PosStyles(align: PosAlign.left, bold: false),
      containsChinese: true,
    ),
  ]);

  return (bytes: bytes, generator: generator);
}

class PrintCashSessionPage extends ConsumerWidget {
  final Map<String, dynamic> sessionData;

  const PrintCashSessionPage({super.key, required this.sessionData});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConfirmButton(
          paddingSize: 32,
          onTap: () async {
            if (!context.mounted) return;
            await printCashSessionReceipt(
              context: context,
              ref: ref,
              sessionData: sessionData,
            );
          },
          title: 'Print',
        ),
      ),
    );
  }
}
