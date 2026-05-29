import 'package:admin_desktop/src/core/constants/constants.dart';
import 'package:admin_desktop/src/models/data/order_body_data.dart';
import 'package:admin_desktop/src/presentation/components/buttons/send_email.dart';
import 'package:admin_desktop/src/presentation/components/components.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/order_calculate/print_page.dart';
import 'package:admin_desktop/src/repository/repository.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:admin_desktop/src/core/utils/app_helpers.dart';
import 'package:intl/intl.dart';
import 'package:admin_desktop/src/core/utils/local_storage.dart';
import '../../../../../core/di/injection.dart';
import 'package:admin_desktop/src/core/constants/hive_boxes.dart';
import 'package:admin_desktop/src/core/db/hive_service.dart';

class GenerateReceiptPage extends StatefulWidget {
  final String orderId;
  final bool isKitchen;

  const GenerateReceiptPage({
    super.key,
    required this.orderId,
    required this.isKitchen,
  });

  @override
  State<GenerateReceiptPage> createState() => _GenerateReceiptPageState();
}

class _GenerateReceiptPageState extends State<GenerateReceiptPage> {
  String _companyTitle = '-';
  String _shopName = '';
  String _shopAddress = '';

  bool hideCustomer = false;
  bool hideTable = false;
  bool hideOrderFlow = false;

  // fetched order when loading directly from API (optional)
  OrderBodyData? _fetchedOrder;
  // cache product data fetched by stock id
  final Map<int, Map<String, dynamic>> _productCache = {};
  OverlayEntry? _silentPrintEntry;

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

    super.initState();
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
        success: (data) {
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
                _fetchedOrder?.id = raw['_meta']?['serverId'];
                final title = (translation?['title'] ?? '').toString().trim();
                final address =
                    (translation?['address'] ?? '').toString().trim();
                _shopName = title;
                _shopAddress = address;
              });
              // Prefetch product details for enhanced products to show titles
              _prefetchProductDetails();
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
    } finally {
      if (mounted) {
        // no-op: mounted check kept intentionally (can update state here if needed)
      }
    }
  }

  void _prefetchProductDetails() {
    if (_fetchedOrder == null) return;
    final ids = <int>{};
    for (final p in _fetchedOrder!.enhancedProducts ?? <dynamic>[]) {
      final stockId = _extractStockId(p);
      if (stockId != null && !_productCache.containsKey(stockId)) {
        ids.add(stockId);
      }
    }
    if (ids.isNotEmpty) _batchFetchProducts(ids.toList());
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

  void _startSilentPrint() {
    if (!mounted) return;
    if (_silentPrintEntry != null) return;
    if ((_fetchedOrder?.transactionId ?? '').toString().isEmpty) return;

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      AppHelpers.showSnackBar(
        context,
        "Unable to start printing. Please try again.",
      );
      return;
    }

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) {
        return Positioned.fill(
          child: IgnorePointer(
            ignoring: true,
            child: Offstage(
              offstage: true,
              child: PrintPage(
                orderId: widget.orderId,
                isKitchen: widget.isKitchen,
                silent: true,
                autoPop: false,
                onFinished: () {
                  try {
                    entry.remove();
                  } catch (_) {}
                  if (mounted) {
                    _silentPrintEntry = null;
                  }
                },
              ),
            ),
          ),
        );
      },
    );

    _silentPrintEntry = entry;
    overlay.insert(entry);
    // AppHelpers.showSnackBar(context, "Printing receipt...");
  }

  @override
  void dispose() {
    try {
      _silentPrintEntry?.remove();
    } catch (_) {}
    _silentPrintEntry = null;
    super.dispose();
  }

  Widget buildRow(String label, num value,
      {String? symbol, bool isInt = false, double valueWidth = 100}) {
    final int decimalDigits = isInt ? 0 : 2;
    final String formatted = AppHelpers.numberFormat(
      value.toDouble(),
      symbol: symbol,
      decimalDigits: decimalDigits,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: valueWidth,
            child: Text(
              formatted,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Prefer data from the fetched order when available, otherwise fall back
    // to the local state/bag values.
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

    final subtotalAfterItemDiscount = originalSubtotal - totalItemLevelDiscount;
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

    return Padding(
      padding: EdgeInsets.all(16.r),
      child: SingleChildScrollView(
        // Wrapped with SingleChildScrollView
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Text("Queue No. (${_fetchedOrder?.queueNo ?? '-'})",
                textAlign: TextAlign.center),
            Text(_companyTitle, textAlign: TextAlign.center),
            if (_shopName.isNotEmpty) Text(_shopName, textAlign: TextAlign.center),
            if (_shopAddress.isNotEmpty)
              Text(_shopAddress, textAlign: TextAlign.center),
            hideTable
                ? SizedBox.shrink()
                : Text(sectionName, textAlign: TextAlign.center),
            8.verticalSpace,
            Text(
              "TAX INVOICE",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
            12.verticalSpace,
            Text("Doc No.: ${_fetchedOrder?.transactionId ?? '-'}"),
            if (_fetchedOrder?.deliveryType.toLowerCase() == 'dine_in' &&
                _fetchedOrder?.bagData.selectedTable?.name != null &&
                !hideTable)
              Text("Table: ${_fetchedOrder?.bagData.selectedTable?.name}"),
            Text("Opened at: $openedAt"),
            12.verticalSpace,

            // Item list header
            Row(
              children: [
                Expanded(
                  child: Text("Description",
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
                SizedBox(
                  width: 100,
                  child: Text("Amount ($currencySymbol)",
                      textAlign: TextAlign.right,
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const Divider(),

            // Item list
            ...?products?.map((s) {
              final productTitle = _productTitleFor(s);
              final qty = s.quantity;
              final amt = s.originalPrice;

              // Build product row + optional addon rows
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text("$productTitle x$qty")),
                      SizedBox(
                        width: 100,
                        child: Text(
                          AppHelpers.numberFormat(amt, symbol: currencySymbol),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  // Addons (if any)
                  if (s.addons != null && s.addons!.isNotEmpty)
                    ...s.addons!.map((a) {
                      final addonTitle = _addonsTitleFor(s, a);
                      final addonQty = a.quantity;
                      final addonPrice = a.price;
                      return Padding(
                        padding: const EdgeInsets.only(
                            left: 12.0, top: 2.0, bottom: 2.0),
                        child: Row(
                          children: [
                            Expanded(
                                child: Text(
                                    "$addonTitle (${AppHelpers.numberFormat(addonPrice / addonQty, symbol: currencySymbol)}) x $addonQty",
                                    style: TextStyle(fontSize: 13))),
                            SizedBox(
                              width: 100,
                              child: Text(
                                ' ',
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              );
            }),
            const Divider(),

            // Summary
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Service Type:",
                    style: GoogleFonts.inter(fontSize: 14.sp)),
                Text(
                  AppHelpers.getTranslation(serviceType),
                  style: GoogleFonts.inter(fontSize: 14.sp),
                  textAlign: TextAlign.right,
                ),
              ],
            ),
            buildRow("Item Count", products?.length.toDouble() ?? 0,
                symbol: "", isInt: true),
            buildRow("Total Qty", totalQty.toDouble(), symbol: "", isInt: true),
            buildRow("Subtotal", subtotal.toDouble(), symbol: currencySymbol),
            buildRow("Item Discount", totalItemLevelDiscount.toDouble() * -1,
                symbol: currencySymbol),
            buildRow("Service Charge", serviceCharge.toDouble(),
                symbol: currencySymbol),
            buildRow("SST Tax", srTaxAmt.toDouble(), symbol: currencySymbol),
            buildRow("Bill Discount", billDiscountValue.toDouble() * -1,
                symbol: currencySymbol),
            buildRow("Rounding Adjustment", rounding.toDouble(),
                symbol: currencySymbol),
            const Divider(),
            buildRow("NET TOTAL (TAX INCL.)", netTotal.toDouble(),
                symbol: currencySymbol),

            12.verticalSpace,

            // Payment info
            Builder(builder: (context) {
              final String paymentLabel = AppHelpers.getTranslation(
                  _fetchedOrder?.bagData.selectedPayment?.tag ?? '');

              num tendered = 0;
              if (_fetchedOrder?.paidAmount != null &&
                  (_fetchedOrder!.paidAmount ?? 0) > 0) {
                tendered = _fetchedOrder?.paidAmount ?? 0;
              } else {
                tendered = netTotal;
              }

              final num change =
                  (tendered - netTotal) > 0 ? (tendered - netTotal) : 0;

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(paymentLabel)),
                      SizedBox(
                        width: 100,
                        child: Text(
                          AppHelpers.numberFormat(tendered,
                              symbol: currencySymbol),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  if (change > 0)
                    buildRow('Change', change.toDouble(),
                        symbol: currencySymbol),
                ],
              );
            }),

            20.verticalSpace,

            // Tax summary
            Text("Tax Summary",
                style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(child: Text("Type")),
                SizedBox(
                    width: 100,
                    child: Text("Amt ($currencySymbol)",
                        textAlign: TextAlign.right)),
              ],
            ),
            6.verticalSpace,
            Row(
              children: [
                Expanded(child: Text("NON 0%")),
                SizedBox(
                  width: 100,
                  child: Text(
                    AppHelpers.numberFormat(subtotal - totalItemLevelDiscount,
                        symbol: currencySymbol),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            // Display Service Charge breakdown by percent
            for (final entry in serviceChargeByPercent.entries)
              if (entry.value > 0)
                Row(
                  children: [
                    Expanded(
                        child: Text(
                      "Service Charge (${double.tryParse(entry.key)?.toStringAsFixed(0)}%)",
                    )),
                    SizedBox(
                      width: 100,
                      child: Text(
                        AppHelpers.numberFormat(entry.value.toDouble(),
                            symbol: currencySymbol),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
            // Display Tax breakdown by percent
            for (final entry in taxByPercent.entries)
              if (entry.value > 0)
                Row(
                  children: [
                    Expanded(
                        child: Text(
                      "SST Tax (${double.tryParse(entry.key)?.toStringAsFixed(0)}%)",
                    )),
                    SizedBox(
                      width: 100,
                      child: Text(
                        AppHelpers.numberFormat(entry.value.toDouble(),
                            symbol: currencySymbol),
                        textAlign: TextAlign.right,
                      ),
                    )
                  ],
                ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '*belongs to service charges',
                style: GoogleFonts.inter(
                    fontSize: 12.sp, fontStyle: FontStyle.italic),
              ),
            ),
            const Divider(),

            // Footer
            Text("Thank You", textAlign: TextAlign.center),
            Text("Please Come Again", textAlign: TextAlign.center),
            Text("Closed at $closedAt", textAlign: TextAlign.center),
            Text("Issued by: ${picUsername()}", textAlign: TextAlign.center),
            20.verticalSpace,

            // Email button - use the directly fetched order when available
            // If fetch failed or not provided, pass null so InvoiceEmail disables sending.
            InvoiceEmail(orderData: _fetchedOrder),

            8.verticalSpace,

            // Print button
            LoginButton(
              title: AppHelpers.getTranslation(TrKeys.print),
              onPressed: (_fetchedOrder?.transactionId == null)
                  ? null
                  : () async {
                      try {
                        debugPrint(
                            'Print pressed: printing receipt id -> ${_fetchedOrder?.transactionId}');
                      } catch (_) {}
                      _startSilentPrint();
                    },
            ),
          ],
        ),
      ),
    );
  }
}
