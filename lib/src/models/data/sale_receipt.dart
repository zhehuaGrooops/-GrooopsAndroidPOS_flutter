import 'dart:convert';

class SaleReceipt {
  final num calculatedTotal;
  final List<Map<String, dynamic>> calculationData;
  final Map<String, dynamic> groupedByCategory;
  final String? transactionId;

  SaleReceipt({
    required this.calculatedTotal,
    required this.calculationData,
    required this.groupedByCategory,
    this.transactionId,
  });

  factory SaleReceipt.fromMap(Map? m) {
    if (m == null) {
      return SaleReceipt(
          calculatedTotal: 0,
          calculationData: [],
          groupedByCategory: {},
          transactionId: null);
    }
    return SaleReceipt(
      calculatedTotal: m['calculatedTotal'] ?? 0,
      calculationData: (m['calculationData'] is List)
          ? List<Map<String, dynamic>>.from(m['calculationData'])
          : <Map<String, dynamic>>[],
      groupedByCategory: (m['groupedByCategory'] is Map)
          ? Map<String, dynamic>.from(m['groupedByCategory'])
          : <String, dynamic>{},
      transactionId:
          m['transaction_id']?.toString() ?? m['transactionId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'CalculatedTotal': calculatedTotal,
      'CalculationData': calculationData,
      'GroupedByCategory': groupedByCategory,
      'TransactionId': transactionId,
    };
  }

  @override
  String toString() => const JsonEncoder.withIndent('  ').convert(toJson());
}
