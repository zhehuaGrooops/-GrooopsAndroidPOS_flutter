import 'package:admin_desktop/src/models/models.dart';

class OrderHiveModel {
  final int? id;
  final OrderBodyData? body;
  final int? paymentId;
  final int? deliverymanId;
  final String? status;
  final String? detailStatus;
  final OrderMeta? meta;
  final num? totalPrice;
  final num? roundingAmount;
  final bool? isVoided;
  final bool? syncVoided;
  Map<String, dynamic>? userSnapshot;
  Map<String, dynamic>? shopSnapshot;

  OrderHiveModel({
    this.id,
    this.body,
    this.paymentId,
    this.deliverymanId,
    this.status,
    this.detailStatus,
    this.meta,
    this.totalPrice,
    this.roundingAmount,
    this.isVoided,
    this.syncVoided,
    this.userSnapshot,
    this.shopSnapshot,
  });

  factory OrderHiveModel.fromJson(Map<String, dynamic> json) {
    return OrderHiveModel(
      id: json['id'],
      body: json['body'] != null
          ? OrderBodyData.fromJson(Map<String, dynamic>.from(json['body']))
          : null,
      paymentId: json['payment_id'],
      deliverymanId: json['deliveryman_id'],
      status: json['status'],
      detailStatus: json['detail_status'],
      meta: json['_meta'] != null
          ? OrderMeta.fromJson(Map<String, dynamic>.from(json['_meta']))
          : null,
      totalPrice: json['total_price'],
      roundingAmount: json['rounding_amount'],
      isVoided: _parseBool(json['is_voided']),
      syncVoided: _parseBool(json['sync_voided']),
      userSnapshot: json['user_snapshot'] != null
          ? Map<String, dynamic>.from(json['user_snapshot'])
          : null,
        shopSnapshot: json['shop_snapshot'] != null
          ? Map<String, dynamic>.from(json['shop_snapshot'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'id': id,
      'body': body?.toRawJson(),
      ...?body?.toRawJson(),
      'payment_id': paymentId,
      if (deliverymanId != null) 'deliveryman_id': deliverymanId,
      'status': status,
      if (detailStatus != null) 'detail_status': detailStatus,
      '_meta': meta?.toJson(),
      'total_discount': body?.billDiscountAmount,
      'total_price': totalPrice ?? _calculateTotalPrice(body),
      'rounding_amount': roundingAmount ?? body?.roundingAmount,
      if (isVoided != null) 'is_voided': isVoided,
      if (syncVoided != null) 'sync_voided': syncVoided,
    };

    if (userSnapshot != null) {
      data['user_snapshot'] = userSnapshot;
    }

    if (shopSnapshot != null) {
      data['shop_snapshot'] = shopSnapshot;
    }

    // Ensure compatibility with OrderData.fromJson by mapping enhanced_products to details
    if (body?.enhancedProducts != null) {
      data['details'] = body!.enhancedProducts!
          .map((ep) => {
                'origin_price': ep.originalPrice,
                'tax': ep.taxAmount,
                'service_charge': ep.serviceChargeAmount,
                'discount': ep.itemDiscountAmount,
                'quantity': ep.quantity,
                'total_price': ep.finalPrice,
                'stock': {
                  'product': {
                    'category': {
                      'id': ep.categoryId ?? 0,
                      'translation': {'title': ep.categoryName ?? 'unknown'}
                    }
                  }
                }
              })
          .toList();
    }

    return data;
  }

  num _calculateTotalPrice(OrderBodyData? body) {
    if (body == null || body.enhancedProducts == null) return 0.0;
    double total = 0.0;
    for (var product in body.enhancedProducts!) {
      total += (product.originalPrice +
              product.taxAmount +
              product.serviceChargeAmount -
              product.itemDiscountAmount) *
          product.quantity;
    }
    total -= (body.billDiscountAmount ?? 0.0);
    return total + (body.roundingAmount ?? 0.0);
  }

  static bool? _parseBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.trim().toLowerCase();
      if (v == 'true' || v == '1') return true;
      if (v == 'false' || v == '0') return false;
    }
    return null;
  }
}

class OrderMeta {
  final String? syncStatus;
  final String? transactionStatus;
  final String? updatedAt;
  final String? transactionUpdatedAt;
  final int? serverId;

  OrderMeta({
    this.syncStatus,
    this.transactionStatus,
    this.updatedAt,
    this.transactionUpdatedAt,
    this.serverId,
  });

  factory OrderMeta.fromJson(Map<String, dynamic> json) {
    return OrderMeta(
      syncStatus: json['syncStatus'],
      transactionStatus: json['transactionStatus'],
      updatedAt: json['updatedAt'],
      transactionUpdatedAt: json['transactionUpdatedAt'],
      serverId: json['serverId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'syncStatus': syncStatus,
      if (transactionStatus != null) 'transactionStatus': transactionStatus,
      'updatedAt': updatedAt,
      if (transactionUpdatedAt != null)
        'transactionUpdatedAt': transactionUpdatedAt,
      if (serverId != null) 'serverId': serverId,
    };
  }
}
