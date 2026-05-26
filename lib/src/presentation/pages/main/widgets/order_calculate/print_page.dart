import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:admin_desktop/src/models/data/order_body_data.dart';
import 'package:admin_desktop/src/models/data/kitchen_printer_config.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/settings/riverpod/printer_provider.dart';
import 'package:admin_desktop/src/repository/orders_repository.dart';
import 'package:admin_desktop/src/repository/products_repository.dart';
import 'package:admin_desktop/src/repository/kitchen_printers_repository.dart';
import 'package:admin_desktop/src/repository/printer_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart';
import 'package:intl/intl.dart';
import 'package:admin_desktop/src/core/utils/utils.dart';
import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';
import 'package:admin_desktop/src/models/data/bluetooth_printer.dart';
import '../../../../../core/di/injection.dart';
import 'package:admin_desktop/src/core/constants/hive_boxes.dart';
import 'package:admin_desktop/src/core/db/hive_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../riverpod/provider/main_provider.dart';

class PrintPage extends ConsumerStatefulWidget {
  final String orderId;
  final bool isKitchen;
  final bool silent;
  final bool autoPop;
  final VoidCallback? onFinished;

  const PrintPage({
    super.key,
    required this.orderId,
    required this.isKitchen,
    this.silent = false,
    this.autoPop = true,
    this.onFinished,
  });

  @override
  ConsumerState<PrintPage> createState() => _PrintPageState();
}

class _PrintPageState extends ConsumerState<PrintPage> {
  String _companyTitle = '-';
  String _shopName = '';
  String _shopAddress = '';
  bool hideCustomer = false;
  bool hideTable = false;
  bool hideOrderFlow = false;
  bool _hasPrinted = false;
  bool _isDataReady = false;
  bool _systemDefaultPrinterChecked = false;
  bool? _hasSystemDefaultPrinter;

  // fetched order when loading directly from API (optional)
  OrderBodyData? _fetchedOrder;
  // cache product data fetched by stock id
  final Map<int, Map<String, dynamic>> _productCache = {};

  var printerManager = PrinterManager.instance;
  List<int>? pendingTask;
  Timer? _connectionTimeout;
  bool _hasFinished = false;

  Future<int> _readReceiptCharsPerLineFromHive() async {
    final repo = inject<PrinterRepository>();
    final config = await repo.getPrinterConfig();
    return AppHelpers.clampCharsPerLine(config?.charsPerLine);
  }

  Future<void> _fetchOrder(String orderId) async {
    if (orderId.isEmpty) return;
    setState(() {});
    try {
      final id = int.tryParse(orderId);
      if (id == null) {
        debugPrint('GenerateReceiptPage._fetchOrder: invalid id: $orderId');
        return;
      }

      final repo = inject<OrdersRepository>();
      final res = await repo.fetchOrderById(id);

      res.when(
        success: (data) async {
          try {
            final raw = Map<String, dynamic>.from(data.toJson());
            final dynamic shopJson = raw['shop'] ?? raw['shop_snapshot'];
            final Map<String, dynamic>? shopMap = shopJson is Map
                ? Map<String, dynamic>.from(shopJson)
                : null;
            final Map<String, dynamic>? translation =
                shopMap?['translation'] is Map
                    ? Map<String, dynamic>.from(shopMap!['translation'])
                    : null;
            final order =
                OrderBodyData.fromJson(Map<String, dynamic>.from(raw));
            if (mounted) {
              setState(() {
                _fetchedOrder = order;
                final title = (translation?['title'] ?? '').toString().trim();
                final address =
                    (translation?['address'] ?? '').toString().trim();
                _shopName = title;
                _shopAddress = address;
              });
              // Prefetch product details for enhanced products to show titles
              await _prefetchProductDetails();
              if (mounted) {
                setState(() {
                  _isDataReady = true;
                });
              }
            }
          } catch (e) {
            debugPrint('GenerateReceiptPage._fetchOrder parse error: $e');
          }
        },
        failure: (error, statusCode) {
          debugPrint(
              'GenerateReceiptPage._fetchOrder repository failure: $error');
        },
      );
    } catch (e) {
      debugPrint('GenerateReceiptPage._fetchOrder error: $e');
    }
  }

  Future<void> _prefetchProductDetails() async {
    if (_fetchedOrder == null) return;
    final ids = <int>{};
    for (final p in _fetchedOrder!.enhancedProducts ?? <dynamic>[]) {
      final stockId = _extractStockId(p);
      if (stockId != null && !_productCache.containsKey(stockId)) {
        ids.add(stockId);
      }
    }
    if (ids.isNotEmpty) await _batchFetchProducts(ids.toList());
  }

  Future<void> _batchFetchProducts(List<int> stockIds) async {
    try {
      final repo = inject<ProductsRepository>();
      final futures = stockIds.map((id) async {
        try {
          final res = await repo.getProductByStockId(id);
          return res.when<Map<String, dynamic>?>(
            success: (data) {
              try {
                return Map<String, dynamic>.from(data);
              } catch (_) {
                return null;
              }
            },
            failure: (_, __) => null,
          );
        } catch (_) {
          return null;
        }
      }).toList();

      final results = await Future.wait(futures);
      final newEntries = <int, Map<String, dynamic>>{};
      for (var i = 0; i < stockIds.length; i++) {
        final r = results[i];
        if (r != null) newEntries[stockIds[i]] = r;
      }
      if (newEntries.isNotEmpty && mounted) {
        setState(() {
          _productCache.addAll(newEntries);
        });
      }
    } catch (_) {}
  }

  int? _extractStockId(dynamic p) {
    try {
      // Try common field names used across models
      if (p == null) return null;
      // dynamic access for typed objects
      try {
        final dynamic v = p;
        if (v.stockId is int) return v.stockId as int;
      } catch (_) {}
      return null;
    } catch (_) {
      return null;
    }
  }

  String _productTitleFor(dynamic s) {
    final fallback = s?.toString() ?? '-';
    try {
      final stockId = _extractStockId(s);
      if (stockId == null) return fallback;

      final cached = _productCache[stockId];
      if (cached == null) return fallback;

      dynamic translation;
      if (cached['translation'] is Map) {
        translation = cached['translation'];
      } else if (cached['product'] is Map &&
          (cached['product'] as Map)['translation'] is Map) {
        translation = (cached['product'] as Map)['translation'];
      }

      if (translation is Map) {
        final title = translation['title'];
        if (title != null && title.toString().isNotEmpty) {
          return title.toString();
        }
      }
    } catch (_) {}

    return fallback;
  }

  String _addonsTitleFor(dynamic s, dynamic addon) {
    final fallback = s?.toString() ?? '-';
    try {
      final stockId = _extractStockId(s);
      if (stockId == null) return fallback;

      final cached = _productCache[stockId];
      if (cached == null) return fallback;

      // extract target addon stock id from provided addon param
      int? targetAddonStockId;
      try {
        final dynamic a = addon;
        if (a is Map) {
          final stockField = a['stock'];
          if (stockField is Map && stockField['id'] is int) {
            targetAddonStockId = stockField['id'] as int;
          } else if (a['stockId'] is int) {
            targetAddonStockId = a['stockId'] as int;
          } else if (a['id'] is int) {
            targetAddonStockId = a['id'] as int;
          }
        } else {
          if (a?.stockId is int) {
            targetAddonStockId = a.stockId as int;
          } else if (a?.id is int) {
            targetAddonStockId = a.id as int;
          }
        }
      } catch (_) {
        targetAddonStockId = null;
      }
      if (targetAddonStockId == null) return fallback;

      // Iterate stocks and their addons (safer than assuming stocks[0])
      final stocks = cached['stocks'];
      if (stocks is List) {
        for (final stock in stocks) {
          if (stock is Map) {
            final addons = stock['addons'];
            if (addons is List) {
              for (final aEntry in addons) {
                if (aEntry is Map) {
                  int? entryStockId;
                  final dynamic stockField = aEntry['stock'];
                  if (stockField is Map && stockField['id'] is int) {
                    entryStockId = stockField['id'] as int;
                  } else if (aEntry['stockId'] is int) {
                    entryStockId = aEntry['stockId'] as int;
                  } else if (aEntry['id'] is int) {
                    entryStockId = aEntry['id'] as int;
                  }

                  if (entryStockId != null &&
                      entryStockId == targetAddonStockId) {
                    final t = aEntry['translation'] ??
                        (aEntry['product'] is Map
                            ? aEntry['product']['translation']
                            : null);
                    if (t is Map && (t['title'] ?? '').toString().isNotEmpty) {
                      return t['title'].toString();
                    }
                  }
                }
              }
            }
          }
        }
      }
    } catch (_) {}

    return fallback;
  }

  Future<void> _fetchCompanyTitle() async {
    try {
      final box = await HiveService.openBox(HiveBoxes.settings);
      final items = box.values.whereType<Map>().toList();
      if (items.isNotEmpty) {
        String fetchedTitle = '-';

        for (final s in items) {
          final key = (s['key'] ?? '').toString().toLowerCase();
          if (key == 'title') {
            final value = (s['value'] ?? '').toString();
            if (value.isNotEmpty) {
              fetchedTitle = value;
              break;
            }
          }
        }

        if (mounted) {
          setState(() {
            _companyTitle = fetchedTitle;
          });
        }
      }
    } catch (_) {}
  }

  @override
  void initState() {
    _fetchOrder(widget.orderId);
    _fetchCompanyTitle();

    final settings = LocalStorage.getSettingsList();
    for (var element in settings) {
      if (element.key == 'hide_customer') {
        hideCustomer = element.value == '1' || element.value == 'true';
      } else if (element.key == 'hide_table') {
        hideTable = element.value == '1' || element.value == 'true';
      } else if (element.key == 'hide_order_flow') {
        hideOrderFlow = element.value == '1' || element.value == 'true';
      }
    }

    // Ensure initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(printerProvider.notifier).init();
    });

    super.initState();
  }

  void _finish({required bool success}) {
    if (_hasFinished) return;
    _hasFinished = true;
    _connectionTimeout?.cancel();
    try {
      widget.onFinished?.call();
    } catch (_) {}
    if (widget.autoPop && mounted) {
      Navigator.of(context).pop();
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

  void _showSystemPrinterSetupWarning() {
    final message = _translateWithFallback(
      'printer_setup_required_message',
      'No default printer is configured. Please set a default printer in your system settings, then configure a printer in the app Settings.',
    );
    AppHelpers.showSnackBar(context, message);
  }

  void _showNoPrinterSelectedWarning() {
    final message = _translateWithFallback(
      'printer_not_selected_message',
      'No printer selected. Please configure a printer in the app Settings.',
    );
    AppHelpers.showSnackBar(context, message);
  }

  Future<bool?> _checkSystemDefaultPrinterConfigured() async {
    if (_systemDefaultPrinterChecked) return _hasSystemDefaultPrinter;
    _systemDefaultPrinterChecked = true;
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
        _hasSystemDefaultPrinter = name.isNotEmpty;
        return _hasSystemDefaultPrinter;
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
          _hasSystemDefaultPrinter = name.isNotEmpty;
          return _hasSystemDefaultPrinter;
        }

        final lowered = combined.toLowerCase();
        if (lowered.contains('no system default') ||
            lowered.contains('no default')) {
          _hasSystemDefaultPrinter = false;
          return _hasSystemDefaultPrinter;
        }

        if (result.exitCode != 0) {
          _hasSystemDefaultPrinter = null;
          return _hasSystemDefaultPrinter;
        }

        _hasSystemDefaultPrinter = false;
        return _hasSystemDefaultPrinter;
      }
    } catch (e, st) {
      log('Failed to detect system default printer', error: e, stackTrace: st);
    }
    _hasSystemDefaultPrinter = null;
    return _hasSystemDefaultPrinter;
  }

  Future<void> _maybeWarnMissingSystemDefaultPrinter() async {
    // if (_hasShownSystemPrinterSetupWarning) return;
    if (!mounted) return;
    final hasDefault = await _checkSystemDefaultPrinterConfigured();
    if (!mounted) return;
    if (hasDefault == false) {
      // _hasShownSystemPrinterSetupWarning = true;
      _showSystemPrinterSetupWarning();
      return;
    }
    _showNoPrinterSelectedWarning();
  }

  void _showPrintFailedWarning() {
    AppHelpers.showSnackBar(
      context,
      "Printing failed. Please check printer connection/paper and try again.",
    );
  }

  BluetoothPrinter? _resolveSelectedPrinter() {
    final printerState = ref.read(printerProvider);
    final selected = printerState.selectedDevice;
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
  }

  Future<bool> _printReceiveTest() async {
    try {
      List<int> bytes = [];

      final profile = await CapabilityProfile.load(name: 'XP-N160I');
      final generator = Generator(PaperSize.mm80, profile);
      final charsPerLine = await _readReceiptCharsPerLineFromHive();
      final divider = AppHelpers.dividerLine(charsPerLine);

      final List<EnhancedProductOrder>? products =
          _fetchedOrder?.enhancedProducts;
      final currencySymbol = _fetchedOrder?.bagData.selectedCurrency?.symbol;

      num originalSubtotal = 0;
      num totalItemLevelDiscount = 0;
      num totalServiceCharge = 0;
      num totalTax = 0;

      // prepare maps to group service charge and tax by percentage
      final Map<String, num> serviceChargeByPercent = {};
      final Map<String, num> taxByPercent = {};

      // prepare maps to group service charge and tax by category name
      final Map<String, num> serviceChargeByCat = {};
      final Map<String, num> taxByCat = {};
      final Map<String, num> serviceChargePercentByCat = {};
      final Map<String, num> taxPercentByCat = {};
      final Map<String, String> categoryDisplay = {};
      Map<String, num> displayServiceChargeByPercent = {};
      Map<String, num> displayTaxByPercent = {};

      if (_fetchedOrder != null &&
          _fetchedOrder!.enhancedProducts != null &&
          _fetchedOrder!.enhancedProducts!.isNotEmpty) {
        // Build totals from fetched order details
        // temporary map to compute origin sums per category for percent calculation
        final Map<String, num> originSumByCat = {};

        for (final d in _fetchedOrder!.enhancedProducts!) {
          final num qty = (d.quantity) as num;
          final num origin = (d.originalPrice);
          final num taxAmt = (d.taxAmount);
          final num scAmt = (d.serviceChargeAmount);
          final num itemDisc = (d.itemDiscountAmount);

          originalSubtotal += origin;
          totalItemLevelDiscount += itemDisc;
          totalServiceCharge += scAmt;
          totalTax += taxAmt;

          final catName = d.categoryName ?? 'Others';
          final key = catName.toLowerCase();
          categoryDisplay[key] = catName;

          // aggregate service charge and tax by percentage
          final scPercent = d.serviceChargePercent?.toString() ?? '0';
          serviceChargeByPercent[scPercent] =
              (serviceChargeByPercent[scPercent] ?? 0) + scAmt;
          final taxPercent = d.taxPercent?.toString() ?? '0';
          taxByPercent[taxPercent] = (taxByPercent[taxPercent] ?? 0) + taxAmt;

          serviceChargeByCat[key] = (serviceChargeByCat[key] ?? 0) + scAmt;
          serviceChargePercentByCat[key] = d.serviceChargePercent ?? 0;
          taxByCat[key] = (taxByCat[key] ?? 0) + taxAmt;
          taxPercentByCat[key] = d.taxPercent ?? 0;
          originSumByCat[key] = (originSumByCat[key] ?? 0) + (origin * qty);
        }

        // Sort serviceChargeByPercent and taxByPercent keys (low to high)
        displayServiceChargeByPercent = Map.fromEntries(
            serviceChargeByPercent.entries.toList()
              ..sort((a, b) => (double.tryParse(a.key) ?? 0)
                  .compareTo(double.tryParse(b.key) ?? 0)));
        serviceChargeByPercent.clear();
        serviceChargeByPercent.addAll(displayServiceChargeByPercent);

        displayTaxByPercent = Map.fromEntries(taxByPercent.entries.toList()
          ..sort((a, b) => (double.tryParse(a.key) ?? 0)
              .compareTo(double.tryParse(b.key) ?? 0)));
        taxByPercent.clear();
        taxByPercent.addAll(displayTaxByPercent);
      }

      final subtotalAfterItemDiscount =
          originalSubtotal - totalItemLevelDiscount;
      final subtotalWithTaxesAndFees =
          subtotalAfterItemDiscount + totalServiceCharge + totalTax;

      // Determine bill discount value: prefer fetched order's total discount if available
      num billDiscountValue = 0;
      if ((_fetchedOrder?.billDiscountAmount ?? 0) > 0) {
        billDiscountValue = _fetchedOrder!.billDiscountAmount ?? 0;
      }

      final num finalTotal = (subtotalWithTaxesAndFees - billDiscountValue)
          .clamp(0, double.infinity);
      final rounding = (finalTotal * 20).round() / 20 - finalTotal;
      final netTotal = finalTotal + rounding;

      // For display keep the old labels but use the aggregated values
      final subtotal = originalSubtotal;
      final serviceCharge = totalServiceCharge;
      final srTaxAmt = totalTax;
      final totalQty = products?.fold<int>(
              0, (sum, s) => sum + ((s.quantity) as num).toInt()) ??
          0;

      final openedAt = DateFormat('yyyy-MM-dd HH:mm:ss').format(
          DateTime.tryParse(_fetchedOrder?.createdAt ?? '') ?? DateTime.now());
      final closedAt = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

      final sectionName = (hideTable
              ? 'N/A'
              : _fetchedOrder?.bagData.selectedSection?.translation?.title) ??
          'N/A';
      final serviceType = _fetchedOrder?.deliveryType ?? 'N/A';

      String picUsername() {
        // Fallback to logged-in user from local storage
        try {
          final local = LocalStorage.getUser();
          if (local != null) {
            final fn = (local.firstname ?? '').trim();
            final ln = (local.lastname ?? '').trim();
            final combined = ('$fn $ln').trim();
            if (combined.isNotEmpty) {
              return combined;
            }
          }
        } catch (_) {}
        return 'Unknown';
      }

      // ==== HEADER ====
      // Use cached company title and align header exactly with the on-screen preview
      bytes += generator.reset();
      bytes += generator.setGlobalCodeTable('CP1252');
      bytes += generator.setStyles(const PosStyles(align: PosAlign.left));
      bytes += generator.text(
        AppHelpers.centerAlignText(
          'Queue No. (${_fetchedOrder?.queueNo ?? "-"})',
          charsPerLine,
        ),
        styles: const PosStyles(align: PosAlign.left, bold: true),
      );
      bytes += generator.text(
        AppHelpers.centerAlignText(_companyTitle, charsPerLine),
        styles: const PosStyles(align: PosAlign.left),
        containsChinese: true,
      );
      if (_shopName.isNotEmpty) {
        bytes += generator.text(
          AppHelpers.centerAlignText(_shopName, charsPerLine),
          styles: const PosStyles(align: PosAlign.left),
          containsChinese: true,
        );
      }
      if (_shopAddress.isNotEmpty) {
        bytes += generator.text(
          AppHelpers.centerAlignText(_shopAddress, charsPerLine),
          styles: const PosStyles(align: PosAlign.left),
          containsChinese: true,
        );
      }
      hideTable
          ? null
          : bytes += generator.text(
              AppHelpers.centerAlignText(sectionName, charsPerLine),
              styles: const PosStyles(align: PosAlign.left),
              containsChinese: true,
            );
      bytes += generator.text(
        AppHelpers.centerAlignText('TAX INVOICE', charsPerLine),
        styles: const PosStyles(align: PosAlign.left, bold: true),
      );
      bytes += generator.text(divider,
          styles: const PosStyles(align: PosAlign.left));

      // ==== INFO ====
      bytes += generator.text('  Doc No.: ${_fetchedOrder?.transactionId}',
          containsChinese: true);
      if (_fetchedOrder?.deliveryType.toLowerCase() == 'dine_in' &&
          _fetchedOrder?.bagData.selectedTable?.name != null &&
          !hideTable) {
        bytes += generator.text(
            '  Table: ${_fetchedOrder?.bagData.selectedTable?.name}',
            containsChinese: true);
      }
      bytes += generator.text('  Opened at: $openedAt');
      bytes += generator.text(divider,
          styles: const PosStyles(align: PosAlign.left));

      // ==== ITEMS ====
      bytes += generator.row([
        PosColumn(
            width: 8, text: "Description", styles: const PosStyles(bold: true)),
        PosColumn(
            width: 4,
            text: "Amount ($currencySymbol)",
            styles: const PosStyles(bold: true, align: PosAlign.right)),
      ]);

      bytes += generator.text(divider,
          styles: const PosStyles(align: PosAlign.left));

      for (final s in products!) {
        final productTitle = _productTitleFor(s);
        final qty = s.quantity;
        final amt = s.originalPrice;

        bytes += generator.row([
          PosColumn(
              width: 8, text: "$productTitle x$qty", containsChinese: true),
          PosColumn(
              width: 4,
              text: AppHelpers.numberFormat(amt, symbol: currencySymbol),
              styles: const PosStyles(align: PosAlign.right),
              containsChinese: true),
        ]);

        for (final EnhancedAddonOrder addon in s.addons ?? []) {
          String addonTitle = _addonsTitleFor(s, addon);
          int addonQty = addon.quantity;
          num addonPrice = addon.price;

          bytes += generator.row([
            PosColumn(
                width: 8,
                text:
                    " $addonTitle (${AppHelpers.numberFormat(addonPrice / addonQty, symbol: currencySymbol)} x $addonQty)",
                containsChinese: true),
            PosColumn(
                width: 4,
                text: ' ',
                styles: const PosStyles(align: PosAlign.right),
                containsChinese: true),
          ]);
        }
      }

      bytes += generator.text(divider,
          styles: const PosStyles(align: PosAlign.left));

      // ==== SUMMARY ====
      bytes += generator.text(
          "  Service Type: ${AppHelpers.getTranslation(serviceType)}",
          containsChinese: true);
      bytes += generator.row([
        PosColumn(width: 8, text: "Item Count", containsChinese: true),
        PosColumn(
            width: 4,
            text: "${products.length.toInt()}",
            styles: const PosStyles(align: PosAlign.right),
            containsChinese: true),
      ]);
      bytes += generator.row([
        PosColumn(width: 8, text: "Total Qty", containsChinese: true),
        PosColumn(
            width: 4,
            text: "${totalQty.toInt()}",
            styles: const PosStyles(align: PosAlign.right),
            containsChinese: true),
      ]);
      bytes += generator.row([
        PosColumn(width: 8, text: "Subtotal", containsChinese: true),
        PosColumn(
            width: 4,
            text: AppHelpers.numberFormat(subtotal.toDouble(),
                symbol: currencySymbol),
            styles: const PosStyles(align: PosAlign.right),
            containsChinese: true),
      ]);

      // Print total discount (item-level + bill-level) similar to on-screen receipt
      bytes += generator.row([
        PosColumn(width: 8, text: "Item Discount", containsChinese: true),
        PosColumn(
            width: 4,
            text: AppHelpers.numberFormat(
                totalItemLevelDiscount.toDouble() * -1,
                symbol: currencySymbol),
            styles: const PosStyles(align: PosAlign.right),
            containsChinese: true),
      ]);
      bytes += generator.row([
        PosColumn(width: 8, text: "Service Charge", containsChinese: true),
        PosColumn(
            width: 4,
            text: AppHelpers.numberFormat(serviceCharge.toDouble(),
                symbol: currencySymbol),
            styles: const PosStyles(align: PosAlign.right),
            containsChinese: true),
      ]);
      bytes += generator.row([
        PosColumn(width: 8, text: "SST Tax", containsChinese: true),
        PosColumn(
            width: 4,
            text: AppHelpers.numberFormat(srTaxAmt.toDouble(),
                symbol: currencySymbol),
            styles: const PosStyles(align: PosAlign.right),
            containsChinese: true),
      ]);

      bytes += generator.row([
        PosColumn(width: 8, text: "Bill Discount", containsChinese: true),
        PosColumn(
            width: 4,
            text: AppHelpers.numberFormat(billDiscountValue.toDouble() * -1,
                symbol: currencySymbol),
            styles: const PosStyles(align: PosAlign.right),
            containsChinese: true),
      ]);

      bytes += generator.row([
        PosColumn(width: 8, text: "Rounding Adjustment", containsChinese: true),
        PosColumn(
            width: 4,
            text: AppHelpers.numberFormat(rounding.toDouble(),
                symbol: currencySymbol),
            styles: const PosStyles(align: PosAlign.right),
            containsChinese: true),
      ]);

      bytes += generator.text(divider,
          styles: const PosStyles(align: PosAlign.left));
      bytes += generator.row([
        PosColumn(
            width: 8,
            text: "NET TOTAL (TAX INCL.)",
            styles: const PosStyles(
              bold: true,
              height: PosTextSize.size2,
            ),
            containsChinese: true),
        PosColumn(
            width: 4,
            text: AppHelpers.numberFormat(netTotal.toDouble(),
                symbol: currencySymbol),
            styles: const PosStyles(
                bold: true, align: PosAlign.right, height: PosTextSize.size2),
            containsChinese: true),
      ]);

      bytes += generator.text(" ");

      bytes += generator.text(divider,
          styles: const PosStyles(align: PosAlign.left));

      // Payment info: method, tendered amount and change
      final String paymentLabelRaw = AppHelpers.getTranslation(
          _fetchedOrder?.bagData.selectedPayment?.tag ?? '');
      final String paymentLabel =
          paymentLabelRaw.isEmpty ? 'Payment' : paymentLabelRaw;
      num tendered = 0;
      if (_fetchedOrder?.paidAmount != null &&
          (_fetchedOrder!.paidAmount ?? 0) > 0) {
        tendered = _fetchedOrder?.paidAmount ?? 0;
      } else {
        tendered = netTotal;
      }
      final num change = (tendered - netTotal) > 0 ? (tendered - netTotal) : 0;

      // Print payment method and amount on single line, e.g. "Cash    46.15"
      bytes += generator.row([
        PosColumn(width: 8, text: paymentLabel, containsChinese: true),
        PosColumn(
            width: 4,
            text: AppHelpers.numberFormat(tendered, symbol: currencySymbol),
            styles: const PosStyles(align: PosAlign.right),
            containsChinese: true),
      ]);
      // Only print change when positive
      if (change > 0) {
        bytes += generator.row([
          PosColumn(width: 8, text: "Change", containsChinese: true),
          PosColumn(
              width: 4,
              text: AppHelpers.numberFormat(change, symbol: currencySymbol),
              styles: const PosStyles(align: PosAlign.right),
              containsChinese: true),
        ]);
      }

      // ==== TAX SUMMARY ====
      bytes += generator.text(" ");
      bytes += generator.text("  Tax Summary",
          styles: const PosStyles(bold: true, align: PosAlign.left),
          containsChinese: true);
      bytes += generator.row([
        PosColumn(width: 8, text: "Type", containsChinese: true),
        PosColumn(
            width: 4,
            text: "Amt ($currencySymbol)",
            styles: const PosStyles(align: PosAlign.right),
            containsChinese: true),
      ]);

      // NON 0% row: amount from Subtotal, tax always 0.00
      bytes += generator.row([
        PosColumn(width: 8, text: "NON 0%", containsChinese: true),
        PosColumn(
            width: 4,
            text: AppHelpers.numberFormat(
                (subtotal - totalItemLevelDiscount).toDouble(),
                symbol: currencySymbol),
            styles: const PosStyles(align: PosAlign.right),
            containsChinese: true),
      ]);

      for (final entry in serviceChargeByPercent.entries) {
        if (entry.value > 0) {
          bytes += generator.row([
            PosColumn(
                width: 8,
                text:
                    "Service Charge (${double.tryParse(entry.key)?.toStringAsFixed(0)}%)",
                containsChinese: true),
            PosColumn(
                width: 4,
                text: AppHelpers.numberFormat(entry.value.toDouble(),
                    symbol: currencySymbol),
                styles: const PosStyles(align: PosAlign.right),
                containsChinese: true),
          ]);
        }
      }

      for (final entry in taxByPercent.entries) {
        if (entry.value > 0) {
          bytes += generator.row([
            PosColumn(
                width: 8,
                text:
                    "SST Tax (${double.tryParse(entry.key)?.toStringAsFixed(0)}%)",
                containsChinese: true),
            PosColumn(
                width: 4,
                text: AppHelpers.numberFormat(entry.value.toDouble(),
                    symbol: currencySymbol),
                styles: const PosStyles(align: PosAlign.right),
                containsChinese: true),
          ]);
        }
      }

      // Note indicating SR belongs to service charges
      bytes += generator.text("  *belongs to service charges",
          styles: const PosStyles(align: PosAlign.left), containsChinese: true);
      bytes += generator.text(divider,
          styles: const PosStyles(align: PosAlign.left));

      // ==== FOOTER ====
      bytes += generator.text(
        AppHelpers.centerAlignText("Thank You", charsPerLine),
        styles: const PosStyles(align: PosAlign.left, bold: true),
        containsChinese: true,
      );
      bytes += generator.text(
        AppHelpers.centerAlignText("Please Come Again", charsPerLine),
        styles: const PosStyles(align: PosAlign.left),
        containsChinese: true,
      );
      bytes += generator.text(
        AppHelpers.centerAlignText("Closed at $closedAt", charsPerLine),
        styles: const PosStyles(align: PosAlign.left),
        containsChinese: true,
      );
      bytes += generator.text(
        AppHelpers.centerAlignText("Issued by: ${picUsername()}", charsPerLine),
        styles: const PosStyles(align: PosAlign.left),
        containsChinese: true,
      );

      bytes += generator.feed(2);
      bytes += generator.cut();

      return await _printEscPos(bytes, generator);
    } catch (e, st) {
      debugPrint('Exception in _printReceiveTest: $e');
      debugPrint('$st');
      return false;
    }
  }

  Future<bool> _printKitchenReceipt() async {
    try {
      final profile = await CapabilityProfile.load(name: 'XP-N160I');
      final generator = Generator(PaperSize.mm80, profile);
      final receiptCharsPerLine = await _readReceiptCharsPerLineFromHive();

      final List<EnhancedProductOrder>? products =
          _fetchedOrder?.enhancedProducts;

      final kitchenCategories = <int, List<EnhancedProductOrder>>{};
      final categoryDisplay = <int, String>{};

      // If caller provided groupedByCategory (from OrderCalculate), use it directly.
      if (_fetchedOrder != null &&
          _fetchedOrder!.enhancedProducts != null &&
          _fetchedOrder!.enhancedProducts!.isNotEmpty) {
        for (final p in products!) {
          final categoryId = p.categoryId ?? -1;
          categoryDisplay[categoryId] = p.categoryName ?? 'Others';
          kitchenCategories.putIfAbsent(categoryId, () => []);
          kitchenCategories[categoryId]!.add(p);
        }
      }

      final kitchenPrintersRepository = inject<KitchenPrintersRepository>();
      final kitchenPrinterConfigs =
          await kitchenPrintersRepository.getKitchenPrinters();
      final kitchenPrinterById = <String, KitchenPrinterConfig>{
        for (final p in kitchenPrinterConfigs) p.id: p,
      };
      final defaultKitchenCharsPerLine = AppHelpers.clampCharsPerLine(
        kitchenPrinterConfigs.isNotEmpty
            ? kitchenPrinterConfigs.first.charsPerLine
            : null,
      );

      // Iterate over each category
      var allOk = true;
      for (var entry in kitchenCategories.entries) {
        final categoryId = entry.key;
        final items = entry.value;
        final categoryName = categoryDisplay[categoryId] ?? 'Others';

        debugPrint('Category: $categoryName');
        // prepare header values
        final serviceTypeLabel =
            _fetchedOrder?.deliveryType.toString().toLowerCase() ?? '';
        String orderTypeLine = 'ORDER';
        if (serviceTypeLabel.contains('delivery')) {
          orderTypeLine = 'DELIVERY ORDER';
        } else if (serviceTypeLabel.contains('dine')) {
          orderTypeLine = 'DINE IN';
        } else if (serviceTypeLabel.contains('pickup')) {
          orderTypeLine = 'PICKUP ORDER';
        } else if (serviceTypeLabel.contains('grab')) {
          orderTypeLine = 'GRAB ORDER';
        } else if (serviceTypeLabel.contains('foodpanda')) {
          orderTypeLine = 'FOODPANDA ORDER';
        }
        final printedAt =
            DateFormat('dd MMM yyyy hh:mm:ssa').format(DateTime.now());

        String picUsername() {
          // Fallback to logged-in user from local storage
          try {
            final local = LocalStorage.getUser();
            if (local != null) {
              final fn = (local.firstname ?? '').trim();
              final ln = (local.lastname ?? '').trim();
              final combined = ('$fn $ln').trim();
              if (combined.isNotEmpty) {
                return combined;
              }
            }
          } catch (_) {}
          return 'Unknown';
        }

        final matchedPrinters = kitchenPrinterConfigs.where((p) {
          final printerConfig = p.printerConfig;
          if (printerConfig == null) return false;
          if (categoryId < 0) return false;
          return p.categoryIds.contains(categoryId);
        }).toList();

        List<int> buildCategoryBytes(int charsPerLine) {
          final divider = AppHelpers.dividerLine(charsPerLine);
          final categoryBytes = <int>[];
          categoryBytes.addAll(generator.reset());
          categoryBytes.addAll(generator.setGlobalCodeTable('CP1252'));
          categoryBytes.addAll(generator
              .setStyles(const PosStyles(align: PosAlign.left, bold: true)));
          categoryBytes.addAll(generator.text(
            AppHelpers.centerAlignText(
                'Queue No. (${_fetchedOrder?.queueNo ?? "-"})', charsPerLine),
            styles: const PosStyles(align: PosAlign.left, bold: true),
            containsChinese: true,
          ));
          categoryBytes.addAll(generator.text(
            AppHelpers.centerAlignText(orderTypeLine, charsPerLine),
            styles: const PosStyles(align: PosAlign.left),
            containsChinese: true,
          ));
          categoryBytes.addAll(generator.text(
            AppHelpers.centerAlignText(categoryName, charsPerLine),
            styles: const PosStyles(align: PosAlign.left),
            containsChinese: true,
          ));
          categoryBytes.addAll(generator.text(
            AppHelpers.centerAlignText('--- NEW ORDER ---', charsPerLine),
            styles: const PosStyles(align: PosAlign.left),
            containsChinese: true,
          ));
          categoryBytes.addAll(generator.text(
            AppHelpers.centerAlignText(
                _fetchedOrder?.transactionId ?? 'Order ID', charsPerLine),
            styles: const PosStyles(align: PosAlign.left, bold: true),
            containsChinese: true,
          ));
          categoryBytes.addAll(generator.text(' '));

          if (_fetchedOrder?.deliveryType.toLowerCase() == 'dine_in' &&
              _fetchedOrder?.bagData.selectedTable?.name != null &&
              !hideTable) {
            categoryBytes.addAll(generator.row([
              PosColumn(
                width: 12,
                text: 'Table: ${_fetchedOrder?.bagData.selectedTable?.name}',
                styles: const PosStyles(align: PosAlign.left),
                containsChinese: true,
              ),
            ]));
          }

          categoryBytes.addAll(generator.text(divider,
              styles: const PosStyles(align: PosAlign.left)));

          int categoryQtySum = 0;
          for (var s in items) {
            final productTitle = _productTitleFor(s);
            final qty = s.quantity;
            categoryQtySum += qty;

            categoryBytes.addAll(generator.row([
              PosColumn(width: 8, text: productTitle, containsChinese: true),
              PosColumn(
                width: 4,
                text: ' $qty',
                styles: const PosStyles(align: PosAlign.right),
                containsChinese: true,
              ),
            ]));

            if (s.addons != null && s.addons!.isNotEmpty) {
              for (final EnhancedAddonOrder addon in s.addons!) {
                final addonTitle = _addonsTitleFor(s, addon);
                final addonQty = addon.quantity;
                categoryBytes.addAll(generator.row([
                  PosColumn(
                    width: 8,
                    text: ' $addonTitle - $addonQty',
                    containsChinese: true,
                  ),
                  PosColumn(
                    width: 4,
                    text: ' ',
                    styles: const PosStyles(align: PosAlign.right),
                    containsChinese: true,
                  ),
                ]));
              }
            }
          }
          categoryBytes.addAll(generator.text(divider,
              styles: const PosStyles(align: PosAlign.left)));

          categoryBytes.addAll(generator.row([
            PosColumn(width: 8, text: 'Total Qty', containsChinese: true),
            PosColumn(
              width: 4,
              text: '$categoryQtySum',
              styles: const PosStyles(align: PosAlign.right),
              containsChinese: true,
            ),
          ]));

          categoryBytes.addAll(generator.text(' '));
          categoryBytes.addAll(generator.text(
            AppHelpers.centerAlignText('Printed at $printedAt', charsPerLine),
            styles: const PosStyles(align: PosAlign.left),
            containsChinese: true,
          ));
          categoryBytes.addAll(generator.text(
            AppHelpers.centerAlignText('by ${picUsername()}', charsPerLine),
            styles: const PosStyles(align: PosAlign.left),
            containsChinese: true,
          ));

          categoryBytes.addAll(generator.feed(2));
          categoryBytes.addAll(generator.cut());
          return categoryBytes;
        }

        Future<bool> sendToKitchenPrinter({
          required PrinterType type,
          required dynamic model,
          required List<int> bytes,
        }) async {
          try {
            final connected =
                await printerManager.connect(type: type, model: model);
            if (!connected &&
                !(type == PrinterType.bluetooth && Platform.isAndroid)) {
              return false;
            }
            return await printerManager.send(type: type, bytes: bytes);
          } catch (_) {
            return false;
          } finally {
            try {
              await printerManager.disconnect(type: type);
            } catch (_) {}
          }
        }

        if (matchedPrinters.isEmpty) {
          debugPrint('No matching kitchen printer for category: $categoryName');
          allOk = (await _printEscPos(
                  buildCategoryBytes(receiptCharsPerLine), generator)) &&
              allOk;
          continue;
        }

        for (final printer in matchedPrinters) {
          final resolved = kitchenPrinterById[printer.id] ?? printer;
          final printerConfig = resolved.printerConfig;
          if (printerConfig == null) continue;
          final kitchenCharsPerLine = AppHelpers.clampCharsPerLine(
            resolved.charsPerLine ?? defaultKitchenCharsPerLine,
          );

          final rawType = printerConfig.type;
          final type = (rawType >= 0 && rawType < PrinterType.values.length)
              ? PrinterType.values[rawType]
              : PrinterType.bluetooth;

          bool ok = false;
          switch (type) {
            case PrinterType.usb:
              ok = await sendToKitchenPrinter(
                type: type,
                model: UsbPrinterInput(
                  name: printerConfig.name,
                  productId: printerConfig.productId,
                  vendorId: printerConfig.vendorId,
                ),
                bytes: buildCategoryBytes(kitchenCharsPerLine),
              );
              break;
            case PrinterType.bluetooth:
              final address = printerConfig.address;
              if (address == null || address.trim().isEmpty) {
                ok = false;
              } else {
                ok = await sendToKitchenPrinter(
                  type: type,
                  model: BluetoothPrinterInput(
                    name: printerConfig.name,
                    address: address,
                    isBle: printerConfig.isBle,
                    autoConnect: true,
                  ),
                  bytes: buildCategoryBytes(kitchenCharsPerLine),
                );
              }
              break;
            case PrinterType.network:
              final address = printerConfig.address;
              if (address == null || address.trim().isEmpty) {
                ok = false;
              } else {
                ok = await sendToKitchenPrinter(
                  type: type,
                  model: TcpPrinterInput(ipAddress: address),
                  bytes: buildCategoryBytes(kitchenCharsPerLine),
                );
              }
              break;
          }

          allOk = ok && allOk;
        }
      }
      return allOk;
    } catch (e, st) {
      debugPrint('Exception in _printKitchenReceipt: $e');
      debugPrint('$st');
      return false;
    }
  }

  /// print ticket
  Future<bool> _printEscPos(List<int> bytes, Generator generator) async {
    var printerState = ref.read(printerProvider);
    var hasSelection =
        printerState.selectedDevice != null || printerState.savedConfig != null;
    if (!hasSelection) {
      await ref.read(printerProvider.notifier).init();
      printerState = ref.read(printerProvider);
      hasSelection = printerState.selectedDevice != null ||
          printerState.savedConfig != null;
    }
    if (!hasSelection) {
      await _maybeWarnMissingSystemDefaultPrinter();
      log('Printing skipped: no printer selected (silent)');
      return false;
    }

    final bluetoothPrinter = _resolveSelectedPrinter();
    if (bluetoothPrinter == null) {
      await _maybeWarnMissingSystemDefaultPrinter();
      log('Printing skipped: no printer selected (unable to resolve config)');
      return false;
    }

    try {
      debugPrint("Sending Receipt to Printer ...");
      final ok = await printerManager.send(
        type: bluetoothPrinter.typePrinter,
        bytes: bytes,
      );
      if (!ok) {
        _showPrintFailedWarning();
        log(
          'PrinterManager.send returned false',
          error:
              'type=${bluetoothPrinter.typePrinter} name=${bluetoothPrinter.deviceName} address=${bluetoothPrinter.address}',
        );
      }
      return ok;
    } catch (e, st) {
      _showPrintFailedWarning();
      log(
        'Printing failed with exception',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  Future<void> _executeAutoPrint() async {
    try {
      final receiptOk = await _printReceiveTest();
      var kitchenOk = true;
      if (widget.isKitchen) {
        kitchenOk = await _printKitchenReceipt();
      }
      final ok = receiptOk && kitchenOk;
      if (!ok) {
        _showPrintFailedWarning();
      }
      _finish(success: ok);
    } catch (e, st) {
      _showPrintFailedWarning();
      log('Auto print failed', error: e, stackTrace: st);
      _finish(success: false);
    }
  }

  @override
  void dispose() {
    _connectionTimeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(printerProvider);

    // Auto-print logic
    if (_isDataReady && !_hasPrinted) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (_hasPrinted || !mounted) return;

        var latest = ref.read(printerProvider);
        var hasSelectionLatest =
            latest.selectedDevice != null || latest.savedConfig != null;
        var resolvedPrinter = _resolveSelectedPrinter();
        if (!hasSelectionLatest || resolvedPrinter == null) {
          await ref.read(printerProvider.notifier).init();
          latest = ref.read(printerProvider);
          hasSelectionLatest =
              latest.selectedDevice != null || latest.savedConfig != null;
          resolvedPrinter = _resolveSelectedPrinter();
        }
        if (!hasSelectionLatest || resolvedPrinter == null) {
          _hasPrinted = true;
          await _maybeWarnMissingSystemDefaultPrinter();
          debugPrint("No Printer is selected.");
          _finish(success: false);
          return;
        }

        if (latest.error != null && latest.error!.trim().isNotEmpty) {
          _hasPrinted = true;
          _showPrintFailedWarning();
          log('Printing failed due to printer state error',
              error: latest.error);
          _finish(success: false);
          return;
        }

        if (!latest.isConnected) {
          _connectionTimeout ??= Timer(const Duration(seconds: 10), () {
            if (!mounted || _hasPrinted) return;
            final latest = ref.read(printerProvider);
            if (!latest.isConnected) {
              _hasPrinted = true;
              _showPrintFailedWarning();
              log('Printing aborted: printer not connected (timeout)');
              _finish(success: false);
            }
          });
          return;
        }

        _hasPrinted = true;
        if (!context.mounted) return;
        AppHelpers.showSnackBar(context, "Printing receipt...");
        _executeAutoPrint();
      });
    }

    if (widget.silent) {
      return const SizedBox.shrink();
    }

    if (state.isConnected) {
      return const SizedBox.shrink();
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 12),
          const Text("Printer not connected",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to Settings
              // Assuming we are in MainPage context or can access it
              ref.read(mainProvider.notifier).changeIndex(7);
            },
            child: const Text("Configure in Settings"),
          )
        ],
      ),
    );
  }
}
