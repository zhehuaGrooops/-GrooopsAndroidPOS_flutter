// ignore_for_file: deprecated_member_use

import 'package:admin_desktop/src/core/constants/constants.dart';
import 'package:admin_desktop/src/core/di/injection.dart';
import 'package:admin_desktop/src/core/utils/utils.dart';
import 'package:admin_desktop/src/presentation/components/components.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/cash_session/print_cash_session_page.dart';
import 'package:admin_desktop/src/presentation/theme/app_style.dart';
import 'package:admin_desktop/src/repository/printer_repository.dart';
import 'package:flutter/material.dart';

import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class GenerateCashSessionPage extends StatelessWidget {
  final Map<String, dynamic>? sessionData;

  const GenerateCashSessionPage({super.key, required this.sessionData});

  @override
  Widget build(BuildContext context) {
    // sessionData might be the full response (e.g. {"data": {...}}) or already the inner data
    Map<String, dynamic> data;
    final sd = sessionData;
    if (sd == null) {
      data = {};
    } else if (sd.containsKey('data') && sd['data'] is Map) {
      data = Map<String, dynamic>.from(sd['data'] as Map);
    } else {
      data = Map<String, dynamic>.from(sd);
    }

    // transactions summary may use snake_case or camelCase depending on backend
    final summary = (data['transactions_summary'] ??
        data['transactionsSummary'] ??
        {}) as Map<String, dynamic>;
    final revenue = (summary['revenue_summary'] ??
        summary['revenueSummary'] ??
        {}) as Map<String, dynamic>;
    final mop = (summary['mop_collections'] ?? summary['mopCollections'] ?? {})
        as Map<String, dynamic>;
    final cashier = (summary['cashier_collections'] ??
        summary['cashierCollections'] ??
        {}) as Map<String, dynamic>;
    final categories = (summary['categories'] ?? {}) as Map<String, dynamic>;
    final serviceTypes = (summary['service_types'] ??
        summary['serviceTypes'] ??
        {}) as Map<String, dynamic>;
    final taxSummary = (summary['tax_summary'] ?? summary['taxSummary'] ?? {})
        as Map<String, dynamic>;
    final salesStats = (summary['sales_stats'] ?? summary['salesStats'] ?? {})
        as Map<String, dynamic>;

    Widget sectionTitle(String title) => Padding(
          padding: EdgeInsets.only(top: 14.r, bottom: 8.r),
          child: Text(title,
              style: GoogleFonts.inter(
                  fontSize: 18.sp, fontWeight: FontWeight.w700)),
        );

    String formatMoney(dynamic v) {
      // Always show currency with 2 decimals and append $
      if (v == null) return AppHelpers.numberFormat(0);
      if (v is num) return AppHelpers.numberFormat(v);
      if (v is String) {
        final parsed = num.tryParse(v.replaceAll(',', ''));
        if (parsed != null) return AppHelpers.numberFormat(parsed);
        return v;
      }
      return v.toString();
    }

    // Table row builder for 2-column table
    Widget twoColTable(List<List<String>> rows,
        {bool border = true, bool headerBold = false, bool hasHeader = false}) {
      return Table(
        columnWidths: const {0: FlexColumnWidth(6), 1: FlexColumnWidth(4)},
        border: border
            ? TableBorder.symmetric(
                inside: BorderSide.none, outside: BorderSide.none)
            : null,
        children: rows.asMap().entries.map((entry) {
          final i = entry.key;
          final r = entry.value;
          final isHeader = hasHeader && i == 0;
          return TableRow(children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.r, horizontal: 6.r),
              child: Text(r[0],
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: isHeader ? FontWeight.w700 : FontWeight.w500,
                  )),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.r, horizontal: 6.r),
              child: Text(r[1],
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      fontWeight: isHeader || headerBold
                          ? FontWeight.w700
                          : FontWeight.w600)),
            ),
          ]);
        }).toList(),
      );
    }

    // Table row builder for 3-column table
    Widget threeColTable(List<List<String>> rows,
        {bool border = true, bool headerBold = false}) {
      return Table(
        columnWidths: const {
          0: FlexColumnWidth(5),
          1: FlexColumnWidth(4),
          2: FlexColumnWidth(4),
        },
        border: border
            ? TableBorder.symmetric(
                inside: BorderSide.none, outside: BorderSide.none)
            : null,
        children: rows.asMap().entries.map((entry) {
          final i = entry.key;
          final r = entry.value;
          final isHeader = i == 0;
          final isTotal = i == rows.length - 1 && rows.length > 1;
          return TableRow(children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.r, horizontal: 6.r),
              child: Text(r[0],
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight:
                        isHeader || isTotal ? FontWeight.w700 : FontWeight.w500,
                  )),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.r, horizontal: 6.r),
              child: Text(r[1],
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      fontWeight: isHeader || isTotal || headerBold
                          ? FontWeight.w700
                          : FontWeight.w600)),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.r, horizontal: 6.r),
              child: Text(r[2],
                  textAlign: TextAlign.right,
                  style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      fontWeight: isHeader || isTotal || headerBold
                          ? FontWeight.w700
                          : FontWeight.w600)),
            ),
          ]);
        }).toList(),
      );
    }

    // Table row builder for 4-column table
    Widget fourColTable(List<List<String>> rows,
        {bool border = false, bool headerBold = false}) {
      return Table(
        columnWidths: const {
          0: FlexColumnWidth(3),
          1: FlexColumnWidth(2.5),
          2: FlexColumnWidth(2.5),
          3: FlexColumnWidth(2.5),
        },
        border: border
            ? TableBorder.symmetric(
                inside: BorderSide(color: AppStyle.iconButtonBack, width: 0.5),
                outside: BorderSide.none)
            : null,
        children: rows.asMap().entries.map((entry) {
          final i = entry.key;
          final r = entry.value;
          final isHeader = i == 0;
          final isTotal = i == rows.length - 1 && rows.length > 1;
          return TableRow(
            children: r.asMap().entries.map((cellEntry) {
              final cellIdx = cellEntry.key;
              final cellText = cellEntry.value;
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 8.r, horizontal: 4.r),
                child: Text(
                  cellText,
                  textAlign: cellIdx == 0 ? TextAlign.left : TextAlign.right,
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    fontWeight: isHeader || isTotal || headerBold
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          );
        }).toList(),
      );
    }

    return Container(
      decoration: BoxDecoration(
          color: AppStyle.white, borderRadius: BorderRadius.circular(10.r)),
      padding: EdgeInsets.all(14.r),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<int>(
              future: () async {
                final repo = inject<PrinterRepository>();
                final config = await repo.getPrinterConfig();
                return AppHelpers.clampCharsPerLine(config?.charsPerLine);
              }(),
              builder: (context, snapshot) {
                final dateLine =
                    'Report Date: ${data['opened_at'] ?? data['started_at'] ?? ''}';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Day Report',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.robotoMono(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    6.verticalSpace,
                    Text(
                      dateLine,
                      textAlign: TextAlign.left,
                      style: GoogleFonts.robotoMono(fontSize: 11.sp),
                    ),
                  ],
                );
              },
            ),
            const Divider(),
            12.verticalSpace,
            sectionTitle('Revenue Summary'),
            twoColTable([
              [
                'Cash Sales',
                formatMoney(revenue['cash_sales'] ??
                    revenue['cash'] ??
                    revenue['total'] ??
                    0)
              ],
              ['Service Charge', formatMoney(revenue['service_charge'] ?? 0)],
              ['Tax', formatMoney(revenue['tax'] ?? 0)],
              ['Rounding', formatMoney(revenue['rounding'] ?? 0)],
              ['Total', formatMoney(revenue['total'] ?? 0)],
            ], headerBold: true),
            12.verticalSpace,
            sectionTitle('Service Type'),
            Builder(builder: (context) {
              List<dynamic> items = [];
              if (serviceTypes['items'] is List) {
                items = serviceTypes['items'] as List;
              } else if (summary['service_type'] is List) {
                items = summary['service_type'] as List;
              }

              if (items.isEmpty) {
                return twoColTable([
                  [
                    'Table Service',
                    AppHelpers.numberFormat(
                        summary['table_service_amount'] ?? 0)
                  ]
                ]);
              }

              double totalAmount = 0;
              // Assuming no explicit quantity for service types, but we'll sum it if available or just show '-'
              // To match other tables, we will track totalQty if possible.

              List<List<String>> rows = [];
              // Header
              rows.add(['', 'Percentage', 'Amount (RM)']);

              for (var e in items) {
                final name = '${e['type'] ?? e['name'] ?? ''}';
                final amount = e['amount'] ?? 0;

                num a = 0;
                if (amount is num) {
                  a = amount;
                } else if (amount is String) {
                  a = num.tryParse(amount.replaceAll(',', '')) ?? 0;
                }

                totalAmount += a.toDouble();

                rows.add([
                  name,
                  e['percentage'] != null ? '${e['percentage']}%' : '',
                  AppHelpers.numberFormat(a, symbol: '').trim()
                ]);
              }

              // Total
              rows.add([
                'Total',
                '',
                AppHelpers.numberFormat(totalAmount, symbol: '').trim()
              ]);

              return threeColTable(rows, headerBold: true);
            }),
            12.verticalSpace,
            sectionTitle('MOP Collections'),
            Builder(builder: (context) {
              final items = mop['items'] as List?;

              if (items == null || items.isEmpty) {
                return twoColTable([
                  [
                    'Total Collections',
                    AppHelpers.numberFormat(mop['total'] ?? 0)
                  ]
                ]);
              }

              double totalAmount = 0;
              num totalQty = 0;

              List<List<String>> rows = [];
              // Header
              rows.add(['', 'Count', 'Amount (RM)']);

              for (var e in items) {
                final name = '${e['method'] ?? ''}';
                final qty = e['count'] ?? e['qty'] ?? 0;
                final amount = e['amount'] ?? 0;

                num q = 0;
                if (qty is num) {
                  q = qty;
                } else if (qty is String) {
                  q = num.tryParse(qty) ?? 0;
                }

                num a = 0;
                if (amount is num) {
                  a = amount;
                } else if (amount is String) {
                  a = num.tryParse(amount.replaceAll(',', '')) ?? 0;
                }

                totalQty += q;
                totalAmount += a.toDouble();

                rows.add([
                  name,
                  '$q',
                  AppHelpers.numberFormat(a, symbol: '').trim()
                ]);
              }

              // Total
              rows.add([
                'Total',
                '$totalQty',
                AppHelpers.numberFormat(totalAmount, symbol: '').trim()
              ]);

              return threeColTable(rows, headerBold: true);
            }),
            12.verticalSpace,
            sectionTitle('Cashier Collections'),
            if (cashier['items'] is List)
              twoColTable(List<List<String>>.from((cashier['items'] as List)
                  .map((e) => [
                        '${e['name'] ?? ''}',
                        AppHelpers.numberFormat(e['amount'] ?? 0)
                      ])))
            else
              twoColTable([
                ['Total', AppHelpers.numberFormat(cashier['total'] ?? 0)]
              ]),
            // sectionTitle('Opening / Closing'),
            // if (summary['opening_closing'] is List)
            //   ...List<Widget>.from((summary['opening_closing'] as List).map(
            //       (e) => keyValueRow(e['label'] ?? '',
            //           AppHelpers.numberFormat(e['amount'] ?? 0))))
            // else
            //   keyValueRow('Opening Balance',
            //       formatMoney(summary['opening_balance'] ?? 0)),
            12.verticalSpace,
            sectionTitle('Sales by Items'),
            Builder(builder: (context) {
              List<dynamic> items = [];
              if (summary['items'] is List) {
                items = summary['items'] as List;
              } else if (categories['items'] is List) {
                items = categories['items'] as List;
              }

              if (items.isEmpty) {
                return twoColTable([
                  [
                    'Items Sold',
                    '${summary['items_count'] ?? salesStats['items_qty_sold'] ?? 0}'
                  ]
                ]);
              }

              double totalAmount = 0;
              num totalQty = 0;

              List<List<String>> rows = [];
              // Header
              rows.add(['', 'Qty', 'Amount (RM)']);

              for (var e in items) {
                final name = '${e['title'] ?? e['name'] ?? ''}';
                final qty = e['qty'] ?? e['quantity'] ?? 0;
                final amount = e['amount'] ?? e['total'] ?? 0;

                num q = 0;
                if (qty is num) {
                  q = qty;
                } else if (qty is String) {
                  q = num.tryParse(qty) ?? 0;
                }

                num a = 0;
                if (amount is num) {
                  a = amount;
                } else if (amount is String) {
                  a = num.tryParse(amount.replaceAll(',', '')) ?? 0;
                }

                totalQty += q;
                totalAmount += a.toDouble();

                rows.add([
                  name,
                  '$q',
                  AppHelpers.numberFormat(a, symbol: '').trim()
                ]);
              }

              // Total
              rows.add([
                'Total',
                '$totalQty',
                AppHelpers.numberFormat(totalAmount, symbol: '').trim()
              ]);

              return threeColTable(rows, headerBold: true);
            }),
            12.verticalSpace,
            sectionTitle('Tax Summary'),
            // Tax summary: 4-column table as per image
            if (taxSummary['items'] is List)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  fourColTable([
                    ['', 'Gross (RM)', 'Tax (RM)', 'Net (RM)'],
                    ...(taxSummary['items'] as List).map((e) => [
                          '${e['label'] ?? e['name'] ?? ''}',
                          AppHelpers.numberFormat(e['gross'] ?? 0, symbol: '')
                              .trim(),
                          AppHelpers.numberFormat(e['tax'] ?? 0, symbol: '')
                              .trim(),
                          AppHelpers.numberFormat(e['net'] ?? 0, symbol: '')
                              .trim(),
                        ]),
                    [
                      'Total',
                      AppHelpers.numberFormat(taxSummary['gross'] ?? 0,
                              symbol: '')
                          .trim(),
                      AppHelpers.numberFormat(taxSummary['tax'] ?? 0,
                              symbol: '')
                          .trim(),
                      AppHelpers.numberFormat(taxSummary['net'] ?? 0,
                              symbol: '')
                          .trim(),
                    ]
                  ], border: false),
                  if ((taxSummary['items'] as List).any((e) =>
                      (e['label'] ?? e['name'] ?? '')
                          .toString()
                          .contains('*SR')))
                    Padding(
                      padding: EdgeInsets.only(top: 8.r),
                      child: Text(
                        '**belong to service charges',
                        style: GoogleFonts.inter(
                          fontSize: 12.sp,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              )
            else if (summary['tax_lines'] is List)
              twoColTable(List<List<String>>.from(
                  (summary['tax_lines'] as List).map((e) => [
                        '${e['name'] ?? ''} ${e['percentage'] != null ? '(${e['percentage']}%)' : ''}',
                        formatMoney(e['amount'] ?? 0)
                      ])))
            else
              twoColTable([
                ['Tax', AppHelpers.numberFormat(revenue['tax'] ?? 0)]
              ]),
            // sectionTitle('Best Sellers'),
            // if (summary['best_sellers'] is List)
            //   twoColTable(List<List<String>>.from(
            //       (summary['best_sellers'] as List).map((e) => [
            //             '${e['name'] ?? ''}',
            //             '${e['qty'] ?? 0} / ${formatMoney(e['amount'] ?? 0)}'
            //           ])))
            // else
            //   twoColTable([
            //     ['Top Item', summary['top_item']?.toString() ?? '-']
            //   ]),
            12.verticalSpace,
            sectionTitle('Sales Statistics'),
            twoColTable([
              ['', 'Quantity'],
              [
                'Bill Count',
                '${salesStats['bills_count'] ?? summary['bills_count'] ?? 0}'
              ],
              [
                'Item Qty Sold',
                '${salesStats['items_qty_sold'] ?? summary['items_count'] ?? 0}'
              ],
              ['Item Qty Refunded', '${salesStats['items_qty_refunded'] ?? 0}'],
              [
                'Voided Items Ordered',
                '${salesStats['voided_items_ordered'] ?? 0}'
              ],
              [
                'Voided Items Printed',
                '${salesStats['voided_items_printed'] ?? 0}'
              ],
              ['Voided Items Paid', '${salesStats['voided_items_paid'] ?? 0}'],
              [
                'Voided Settled Bills',
                '${salesStats['voided_settled_bills'] ?? 0}'
              ],
            ], border: false, hasHeader: true),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    'Printed At: ${DateTime.now().toLocal().toString().split('.').first}',
                    style: GoogleFonts.inter(fontSize: 12.sp)),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    'Printed By: ${'${LocalStorage.getUser()?.firstname ?? ''} ${LocalStorage.getUser()?.lastname ?? ''}'}',
                    style: GoogleFonts.inter(fontSize: 12.sp)),
              ],
            ),
            12.verticalSpace,
            Row(
              children: [
                Expanded(
                  child: Consumer(
                    builder: (context, ref, child) => LoginButton(
                      title: AppHelpers.getTranslation(TrKeys.print),
                      onPressed: () async {
                        if (!context.mounted) return;
                        await printCashSessionReceipt(
                          context: context,
                          ref: ref,
                          sessionData: data,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
