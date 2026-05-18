import 'package:admin_desktop/src/models/models.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../repository/repository.dart';
import '../di/injection.dart';

class CashDrawerCalculator {
  static Future<Map<String, dynamic>> computeSessionSummary({
    required List<OrderHiveModel> orders,
    required List<Map<String, dynamic>> transactions,
    required Map<String, dynamic> session,
    required List<Map<String, dynamic>> allSessionsToday,
    required Map<String, dynamic>? currentUser,
  }) async {
    final Map<String, dynamic> summary = {};
    summary['date'] = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // 1. Revenue Summary
    final revenueSummary = _computeRevenueSummary(transactions, orders);
    summary['revenue_summary'] = revenueSummary;

    // 2. Service Types
    summary['service_types'] = _computeServiceTypes(orders);

    // 3. MOP Collections
    summary['mop_collections'] =
        await _computeMopCollections(transactions, orders);

    // 4. Cashier Collections
    summary['cashier_collections'] = _computeCashierCollections(
      orders,
      currentUser,
    );

    // 5. Categories
    summary['categories'] = _computeCategories(orders);

    // 6. Tax Summary
    summary['tax_summary'] = _computeTaxSummary(revenueSummary);

    // 7. Sales Stats
    summary['sales_stats'] =
        _computeSalesStats(orders, transactions, summary['categories']);

    return summary;
  }

  static Map<String, dynamic> _computeRevenueSummary(
    List<Map<String, dynamic>> txs,
    List<OrderHiveModel> orders,
  ) {
    double totalServiceCharge = 0.0;
    double totalTax = 0.0;
    double totalRounding = 0.0;
    double totalRevenue = 0.0;
    double totalCashSales = 0.0;
    Map<String, double> revenueBreakdown = {};

    for (final tx in txs) {
      final String method = tx['payment_tag'] ?? tx['method'] ?? 'unknown';
      final orderId = tx['order_id'];

      // Validation: Find order and handle null/invalid cases
      final order = orders.firstWhere(
        (o) => o.id == orderId || o.meta?.serverId == orderId,
        orElse: () => OrderHiveModel(),
      );

      if (order.id == null ||
          order.body == null ||
          order.isVoided == true ||
          order.body?.isVoided == true) {
        continue;
      }

      double orderTax = 0.0;
      double orderServiceCharge = 0.0;
      final products = order.body?.enhancedProducts;
      if (products != null) {
        for (final ep in products) {
          orderServiceCharge += (ep.serviceChargeAmount).toDouble();
          orderTax += (ep.taxAmount).toDouble();
          totalCashSales +=
              (ep.originalPrice.toDouble() - ep.itemDiscountAmount.toDouble());
        }
      }
      totalServiceCharge += orderServiceCharge;
      totalTax += orderTax;
      totalCashSales = totalCashSales - (order.body?.billDiscountAmount ?? 0.0);

      // Laravel: $totalRevenue += (float) ($order->total_price ?? 0);
      totalRevenue += (order.totalPrice ?? 0).toDouble();

      // The breakdown for each payment method should be the "net" amount (total - tax - service charge)
      revenueBreakdown[method] = (revenueBreakdown[method] ?? 0.0) +
          (order.totalPrice ?? 0.0).toDouble() -
          orderTax -
          orderServiceCharge;

      totalRounding += (order.body?.roundingAmount ?? 0.0).toDouble();
    }

    final Map<String, dynamic> result = {};
    // revenueBreakdown.forEach((key, value) {
    //   result[key] = double.parse(value.toStringAsFixed(2));
    // });

    result['cash_sales'] = double.parse(totalCashSales.toStringAsFixed(2));
    result['service_charge'] =
        double.parse(totalServiceCharge.toStringAsFixed(2));
    result['tax'] = double.parse(totalTax.toStringAsFixed(2));
    result['rounding'] = double.parse(totalRounding.toStringAsFixed(2));
    result['total'] = double.parse(totalRevenue.toStringAsFixed(2));

    return result;
  }

  static Map<String, dynamic> _computeServiceTypes(
      List<OrderHiveModel> orders) {
    Map<String, double> typeAmounts = {};
    for (final order in orders) {
      if (order.id == null ||
          order.body == null ||
          order.isVoided == true ||
          order.body?.isVoided == true) {
        continue;
      }

      final type = order.body?.deliveryType ?? 'unknown';
      typeAmounts[type] =
          (typeAmounts[type] ?? 0) + (order.totalPrice ?? 0).toDouble();
    }

    double serviceTotal = typeAmounts.values.fold(0, (a, b) => a + b);
    List<Map<String, dynamic>> items = [];

    typeAmounts.forEach((type, amount) {
      final displayType = type.replaceAll('_', ' ').split(' ').map((str) {
        if (str.isEmpty) return "";
        return "${str[0].toUpperCase()}${str.substring(1)}";
      }).join(' ');

      double pct = serviceTotal > 0 ? (amount / serviceTotal) * 100 : 0.0;
      items.add({
        'type': displayType,
        'percentage': double.parse(pct.toStringAsFixed(2)),
        'amount': double.parse(amount.toStringAsFixed(2)),
      });
    });

    return {
      'items': items,
      'total': double.parse(serviceTotal.toStringAsFixed(2)),
    };
  }

  static Future<Map<String, dynamic>> _computeMopCollections(
    List<Map<String, dynamic>> txs,
    List<OrderHiveModel> orders,
  ) async {
    final paymentsRepo = inject<PaymentsRepository>();
    final paymentsResult = await paymentsRepo.getPayments();
    final List<PaymentData> payments = [];
    paymentsResult.when(
      success: (data) => payments.addAll(data.data ?? []),
      failure: (error, status) =>
          debugPrint('==> get payments failure: $error'),
    );

    final voidedOrderIds = orders
        .where((o) => o.isVoided == true || o.body?.isVoided == true)
        .map((o) => o.id)
        .toSet();

    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final tx in txs) {
      if (voidedOrderIds.contains(tx['order_id'])) continue;
      // Laravel: $t->paymentSystem?->tag ?? data_get($t->paymentProcess?->data, 'method', 'unknown');
      final method =
          tx['payment_id'] ?? tx['payment_tag'] ?? tx['method'] ?? 'unknown';
      grouped.putIfAbsent(method.toString(), () => []).add(tx);
    }

    List<Map<String, dynamic>> items = [];
    grouped.forEach((method, group) {
      // Find the payment method name from the pre-fetched payments
      String displayName = method;
      try {
        final paymentId = int.tryParse(method);
        final payment = payments.firstWhere(
          (p) => p.id == paymentId || p.tag == method,
          orElse: () => PaymentData(),
        );
        displayName = payment.translation?.title ?? payment.tag ?? method;
        displayName = displayName.replaceAll('_', ' ').split(' ').map((str) {
          if (str.isEmpty) return "";
          return "${str[0].toUpperCase()}${str.substring(1)}";
        }).join(' ');
      } catch (_) {}

      final orderIdsInGroup = group.map((tx) => tx['order_id']).toSet();
      double amount = orders
          .where((o) =>
              (orderIdsInGroup.contains(o.id) ||
                  orderIdsInGroup.contains(o.meta?.serverId)) &&
              o.isVoided != true &&
              o.body?.isVoided != true)
          .fold(
              0.0, (sum, order) => sum + (order.totalPrice ?? 0.0).toDouble());
      items.add({
        'method': displayName,
        'count': group.length,
        'amount': double.parse(amount.toStringAsFixed(2)),
      });
    });

    int totalCount = items.fold(0, (sum, item) => sum + (item['count'] as int));
    double totalAmount =
        items.fold(0.0, (sum, item) => sum + (item['amount'] as double));

    return {
      'items': items,
      'count': totalCount,
      'total': double.parse(totalAmount.toStringAsFixed(2)),
    };
  }

  static Map<String, dynamic> _computeCashierCollections(
    List<OrderHiveModel> orders,
    Map<String, dynamic>? currentUser,
  ) {
    Map<int, Map<String, dynamic>> cashierMap = {};

    for (final order in orders) {
      if (order.id == null ||
          order.body == null ||
          order.isVoided == true ||
          order.body?.isVoided == true) {
        continue;
      }

      final userId = order.body?.userId;
      if (userId == null) continue;

      final amount = (order.totalPrice ?? 0.0).toDouble();

      if (cashierMap.containsKey(userId)) {
        cashierMap[userId]!['amount'] += amount;
      } else {
        String name = 'User $userId';
        if (currentUser != null && currentUser['id'] == userId) {
          final firstName = currentUser['firstname'] ?? '';
          final lastName = currentUser['lastname'] ?? '';
          name = '$firstName $lastName'.trim();
          if (name.isEmpty) name = 'Current User';
        }

        cashierMap[userId] = {
          'id': userId,
          'name': name,
          'amount': amount,
        };
      }
    }

    List<Map<String, dynamic>> items = cashierMap.values.map((c) {
      return {
        ...c,
        'amount': double.parse((c['amount'] as double).toStringAsFixed(2)),
      };
    }).toList();

    double total =
        items.fold(0.0, (sum, item) => sum + (item['amount'] as double));

    return {
      'items': items,
      'total': double.parse(total.toStringAsFixed(2)),
    };
  }

  static Map<String, dynamic> _computeCategories(List<OrderHiveModel> orders) {
    Map<int, Map<String, dynamic>> categoryMap = {};
    int totalQty = 0;
    double totalAmount = 0.0;

    for (final order in orders) {
      if (order.id == null ||
          order.body == null ||
          order.isVoided == true ||
          order.body?.isVoided == true) {
        continue;
      }

      // Laravel: $billDiscount = (float) ($order->total_discount ?? 0);
      double billDiscount = (order.body?.billDiscountAmount ?? 0.0).toDouble();
      double roundingAmount =
          (order.body?.roundingAmount ?? order.roundingAmount ?? 0.0)
              .toDouble();

      // Laravel: $detailsTotal = $billDiscount > 0 ? (float) $details->sum(fn($d) => (float) ($d->total_price ?? 0)) : 0.0;
      double detailsTotal = 0.0;
      final products = order.body?.enhancedProducts;
      if (products != null) {
        detailsTotal = products.fold(
            0.0,
            (sum, ep) =>
                sum +
                (ep.originalPrice -
                        ep.itemDiscountAmount +
                        ep.taxAmount +
                        ep.serviceChargeAmount)
                    .toDouble());
      }

      if (products != null) {
        for (final ep in products) {
          // Laravel: $qty = (int) ($od->quantity ?? 1);
          int qty = ep.quantity;
          totalQty += qty;

          final int catId = ep.categoryId ?? 0;
          final String catName = ep.categoryName ?? 'unknown';

          double baseAmount = (ep.originalPrice -
                  ep.itemDiscountAmount +
                  ep.taxAmount +
                  ep.serviceChargeAmount)
              .toDouble();
          double amount = baseAmount;

          // Laravel: Distribute bill-level discount proportionally
          if (detailsTotal > 0 && billDiscount > 0) {
            double discountShare = (baseAmount / detailsTotal) * billDiscount;
            amount -= discountShare;
          }

          // Distribute rounding adjustment proportionally
          if (detailsTotal > 0 && roundingAmount != 0) {
            double roundingShare = (baseAmount / detailsTotal) * roundingAmount;
            amount += roundingShare;
          }

          if (amount < 0) amount = 0;

          if (!categoryMap.containsKey(catId)) {
            categoryMap[catId] = {
              'id': catId,
              'name': catName,
              'qty': 0,
              'amount': 0.0,
            };
          }

          categoryMap[catId]!['qty'] += qty;
          categoryMap[catId]!['amount'] += amount;
          totalAmount += amount;
        }
      }
    }

    List<Map<String, dynamic>> items = categoryMap.values.map((c) {
      return {
        ...c,
        'amount': double.parse((c['amount'] as double).toStringAsFixed(2)),
      };
    }).toList();

    return {
      'items': items,
      'qty': totalQty,
      'total': double.parse(totalAmount.toStringAsFixed(2)),
    };
  }

  static Map<String, dynamic> _computeTaxSummary(
      Map<String, dynamic> revenueSummary) {
    // Laravel: $srGross = (float) ($revenue_summary['service_charge'] ?? 0);
    double srGross = (revenueSummary['service_charge'] ?? 0.0).toDouble();
    // Laravel: $srTax = (float) ($revenue_summary['tax'] ?? 0);
    double srTax = (revenueSummary['tax'] ?? 0.0).toDouble();
    double srNet = srGross + srTax;

    // Laravel: $nonGross = (float) ($revenue_summary['cash'] ?? 0);
    double nonGross = (revenueSummary['cash_sales'] ?? 0.0).toDouble();
    double nonTax = 0.0;
    double nonNet = nonGross;

    List<Map<String, dynamic>> items = [
      {
        'label': '*SR',
        'gross': double.parse(srGross.toStringAsFixed(2)),
        'tax': double.parse(srTax.toStringAsFixed(2)),
        'net': double.parse(srNet.toStringAsFixed(2)),
      },
      {
        'label': 'NON',
        'gross': double.parse(nonGross.toStringAsFixed(2)),
        'tax': double.parse(nonTax.toStringAsFixed(2)),
        'net': double.parse(nonNet.toStringAsFixed(2)),
      },
    ];

    double totalGross = srGross + nonGross;
    double totalTax = srTax;
    double totalNet = totalGross + totalTax;

    return {
      'items': items,
      'gross': double.parse(totalGross.toStringAsFixed(2)),
      'tax': double.parse(totalTax.toStringAsFixed(2)),
      'net': double.parse(totalNet.toStringAsFixed(2)),
    };
  }

  static Map<String, dynamic> _computeSalesStats(
    List<OrderHiveModel> orders,
    List<Map<String, dynamic>> txs,
    Map<String, dynamic> categoriesSummary,
  ) {
    // Since _computeCategories already excludes voided orders,
    // items_qty_sold is already the quantity of non-voided items.
    final soldItemsQty = (categoriesSummary['qty'] as num?)?.toInt() ?? 0;

    final voidedOrders = orders.where((o) {
      return o.isVoided == true || o.body?.isVoided == true;
    }).toList();

    final voidedOrderIds = voidedOrders.map((o) => o.id).toSet();
    final nonVoidedTxs =
        txs.where((tx) => !voidedOrderIds.contains(tx['order_id'])).toList();

    final voidedItemsQty = voidedOrders.fold<int>(0, (sum, o) {
      final products = o.body?.enhancedProducts;
      if (products == null) return sum;
      return sum + products.fold<int>(0, (pSum, p) => pSum + (p.quantity));
    });

    return {
      'bills_count': nonVoidedTxs.length,
      'items_qty_sold': soldItemsQty,
      'items_qty_refunded': voidedItemsQty,
      'voided_items_ordered': 0, // ToDo: implement void tracking
      'voided_items_printed': 0, // ToDo: implement void tracking
      'voided_items_paid': 0, // ToDo: implement void tracking
      'voided_settled_bills': voidedOrders.length,
    };
  }
}
