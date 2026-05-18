import 'package:admin_desktop/src/core/utils/local_storage.dart';
import 'package:admin_desktop/src/models/data/bag_data.dart';
import 'package:admin_desktop/src/models/data/currency_data.dart';
import 'package:admin_desktop/src/models/data/location_data.dart';
import 'package:admin_desktop/src/models/data/user_data.dart';

import '../../core/constants/constants.dart';

class OrderBodyData {
  int? id;
  final String? note;
  final int? userId;
  final num? deliveryFee;
  final int? currencyId;
  final int? tableId;
  final num? rate;
  final String deliveryType;
  final String? phone;
  final String? coupon;
  final LocationData? location;
  final AddressModel address;
  final String deliveryDate;
  final String deliveryTime;
  final BagData bagData;
  final List<EnhancedProductOrder>? enhancedProducts;
  final num? billDiscountAmount;
  final String? billDiscountType;
  final num? billDiscountPercent;
  final String? transactionId;
  final String? queueNo;
  final String? createdAt;
  final CurrencyData? currency;
  final UserData? user;
  final num? roundingAmount;
  final num? paidAmount;
  final num? refundAmount;
  final bool? isVoided;

  OrderBodyData({
    this.id,
    this.currencyId,
    this.rate,
    this.userId,
    this.deliveryFee,
    this.tableId,
    required this.deliveryType,
    required this.phone,
    this.coupon,
    this.location,
    required this.address,
    required this.deliveryDate,
    required this.deliveryTime,
    this.note,
    required this.bagData,
    this.enhancedProducts,
    this.billDiscountAmount,
    this.billDiscountType,
    this.billDiscountPercent,
    this.transactionId,
    this.queueNo,
    this.createdAt,
    this.currency,
    this.roundingAmount,
    this.paidAmount,
    this.refundAmount,
    this.isVoided,
    this.user,
  });

  Map toJson() {
    Map newMap = {};
    if (id != null) newMap['id'] = id;
    // Use enhanced products if available, otherwise fallback to basic
    if (enhancedProducts != null && enhancedProducts!.isNotEmpty) {
      newMap['products'] = enhancedProducts!.map((p) => p.toJson()).toList();
    } else {
      // Fallback to existing basic product structure
      List<Map<String, dynamic>> products = [];
      for (BagProductData stock in bagData.bagProducts ?? []) {
        List<Map<String, dynamic>> addons = [];
        for (BagProductData addon in stock.carts ?? []) {
          addons.add({
            'stock_id': addon.stockId,
            'quantity': addon.quantity,
          });
        }
        products.add({
          'stock_id': stock.stockId,
          'quantity': stock.quantity,
          if (addons.isNotEmpty) 'addons': addons,
        });
      }
      newMap['products'] = products;
    }
    newMap["currency_id"] = currencyId;
    newMap["rate"] = rate;
    if (phone?.isNotEmpty ?? false) newMap['phone'] = phone;
    newMap["shop_id"] = LocalStorage.getUser()?.role == TrKeys.waiter
        ? LocalStorage.getUser()?.invite?.shopId ?? 0
        : LocalStorage.getUser()?.shop?.id ?? 0;
    if (userId != null && userId != 0) newMap["user_id"] = userId;
    // if (deliveryFee != 0) newMap["delivery_fee"] = deliveryFee;
    newMap["delivery_type"] = deliveryType.toLowerCase();
    if (coupon != null && (coupon?.isNotEmpty ?? false)) {
      newMap["coupon"] = coupon;
    }
    if (note != null && (note?.isNotEmpty ?? false)) newMap["note"] = note;
    if (location != null) newMap["location"] = location?.toJson();
    // newMap["address"] = address.toJson();
    if (tableId != null) newMap["table_id"] = tableId;
    newMap["delivery_date"] = deliveryDate;
    newMap["delivery_time"] = deliveryTime;
    if (billDiscountAmount != null && billDiscountAmount! > 0) {
      newMap["bill_discount_amount"] = billDiscountAmount;
      newMap["bill_discount_type"] = billDiscountType;
      if (billDiscountPercent != null) {
        newMap["bill_discount_percent"] = billDiscountPercent;
      }
    }
    if (transactionId != null && transactionId!.isNotEmpty) {
      newMap['transaction_id'] = transactionId;
      newMap['doc_no'] = transactionId;
    }
    if (queueNo != null && queueNo!.isNotEmpty) {
      newMap['queue_no'] = queueNo;
    }
    if (createdAt != null && createdAt!.isNotEmpty) {
      newMap['created_at'] = createdAt;
    }
    if (roundingAmount != null && roundingAmount != 0) {
      newMap["rounding_amount"] = roundingAmount;
    }
    if (paidAmount != null) {
      newMap['paid_amount'] = paidAmount ?? 0;
    }
    if (refundAmount != null) {
      newMap['refund_amount'] = refundAmount ?? 0;
    }
    if (isVoided != null) {
      newMap["is_voided"] = isVoided;
    }
    if (user != null) newMap['user'] = user?.toJson();
    return newMap;
  }

  factory OrderBodyData.fromJson(Map<String, dynamic> json) {
    return OrderBodyData(
      id: json['id'],
      note: json['note'],
      userId: json['user_id'],
      deliveryFee: json['delivery_fee'],
      currencyId: json['currency_id'],
      tableId: json['table_id'],
      rate: json['rate'],
      deliveryType: json['delivery_type'] ?? 'pickup',
      phone: json['phone'],
      coupon: json['coupon'],
      location: json['location'] != null
          ? LocationData.fromJson(json['location'])
          : null,
      address: AddressModel.fromJson(json['address']),
      deliveryDate: json['delivery_date'] ?? '',
      deliveryTime: json['delivery_time'] ?? '',
      bagData: json['bag_data'] != null
          ? BagData.fromJson(json['bag_data'])
          : BagData(),
      enhancedProducts: json['enhanced_products'] != null
          ? (json['enhanced_products'] as List)
              .map((e) => EnhancedProductOrder.fromJson(e as Map))
              .toList()
          : (json['products'] != null
              ? (json['products'] as List)
                  .map((e) => EnhancedProductOrder.fromJson(e as Map))
                  .toList()
              : null),
      billDiscountAmount: json['bill_discount_amount'],
      billDiscountType: json['bill_discount_type'],
      billDiscountPercent: json['bill_discount_percent'],
      transactionId: json['transaction_id'],
      queueNo: json['queue_no'],
      createdAt: json['created_at'],
      currency: json['currency'] != null
          ? CurrencyData.fromJson(json['currency'])
          : (json['selected_currency'] != null
              ? CurrencyData.fromJson(json['selected_currency'])
              : null),
      roundingAmount: json['rounding_amount'],
      paidAmount: json['paid_amount'],
      refundAmount: json['refund_amount'],
      isVoided: _parseBool(json['is_voided']),
      user: json['user'] != null ? UserData.fromJson(json['user']) : null,
    );
  }

  Map<String, dynamic> toRawJson() {
    return {
      'note': note,
      'user_id': userId,
      'delivery_fee': deliveryFee,
      'currency_id': currencyId,
      'table_id': tableId,
      'rate': rate,
      'delivery_type': deliveryType,
      'phone': phone,
      'coupon': coupon,
      'location': location?.toJson(),
      'address': address.toJson(),
      'delivery_date': deliveryDate,
      'delivery_time': deliveryTime,
      'bag_data': bagData.toJson(),
      'enhanced_products': enhancedProducts?.map((e) => e.toJson()).toList(),
      'bill_discount_amount': billDiscountAmount,
      'bill_discount_type': billDiscountType,
      'bill_discount_percent': billDiscountPercent,
      'transaction_id': transactionId,
      'currency': currency?.toJson(),
      'selected_currency': currency?.toJson(),
      'user': user?.toJson(),
      'queue_no': queueNo,
      'created_at': createdAt,
      'rounding_amount': roundingAmount,
      'paid_amount': paidAmount,
      'refund_amount': refundAmount,
      'is_voided': isVoided,
    };
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

// ADD: Enhanced Product Order Class
class EnhancedProductOrder {
  final int stockId;
  final int? countableId;
  final int quantity;
  final num originalPrice;
  final num finalPrice;

  // Item-level discount details
  final num itemDiscountAmount;
  final String? itemDiscountType; // 'percent' or 'amount'
  final num? itemDiscountPercent;

  // Service charge details
  final num serviceChargeAmount;
  final String? serviceChargeType; // e.g., 'dine_in', 'takeaway'
  final num? serviceChargePercent;

  // Tax details
  final num taxAmount;
  final num? taxPercent;

  // Category info
  final String? categoryName;
  final int? categoryId;

  // Addons
  final List<EnhancedAddonOrder>? addons;

  EnhancedProductOrder({
    required this.stockId,
    this.countableId,
    required this.quantity,
    required this.originalPrice,
    required this.finalPrice,
    required this.itemDiscountAmount,
    this.itemDiscountType,
    this.itemDiscountPercent,
    required this.serviceChargeAmount,
    this.serviceChargeType,
    this.serviceChargePercent,
    required this.taxAmount,
    this.taxPercent,
    this.categoryName,
    this.categoryId,
    this.addons,
  });

  Map<String, dynamic> toJson() {
    return {
      'stock_id': stockId,
      if (countableId != null) 'countable_id': countableId,
      'quantity': quantity,
      'original_price': originalPrice,
      'final_price': finalPrice,
      'item_discount_amount': itemDiscountAmount,
      'item_discount_type': itemDiscountType,
      'item_discount_percent': itemDiscountPercent,
      'service_charge_amount': serviceChargeAmount,
      'service_charge_type': serviceChargeType,
      'service_charge_percent': serviceChargePercent ?? 0,
      'tax_amount': taxAmount,
      'tax_percent': taxPercent ?? 0,
      'category_name': categoryName,
      'category_id': categoryId,
      if (addons != null && addons!.isNotEmpty)
        'addons': addons!.map((a) => a.toJson()).toList(),
    };
  }

  factory EnhancedProductOrder.fromJson(Map json) {
    return EnhancedProductOrder(
      stockId: json['stock_id'] ?? 0,
      countableId: json['countable_id'],
      quantity: json['quantity'] ?? 0,
      originalPrice: json['original_price'] ?? 0,
      finalPrice: json['final_price'] ?? 0,
      itemDiscountAmount: json['item_discount_amount'] ?? 0,
      itemDiscountType: json['item_discount_type'],
      itemDiscountPercent: json['item_discount_percent'],
      serviceChargeAmount: json['service_charge_amount'] ?? 0,
      serviceChargeType: json['service_charge_type'],
      serviceChargePercent: json['service_charge_percent'],
      taxAmount: json['tax_amount'] ?? 0,
      taxPercent: json['tax_percent'],
      categoryName: json['category_name'],
      categoryId: json['category_id'],
      addons: json['addons'] != null
          ? (json['addons'] as List)
              .map((e) => EnhancedAddonOrder.fromJson(e as Map))
              .toList()
          : null,
    );
  }
}

// ADD: Enhanced Addon Order Class
class EnhancedAddonOrder {
  final int stockId;
  final int? countableId;
  final int quantity;
  final num price;

  EnhancedAddonOrder({
    required this.stockId,
    this.countableId,
    required this.quantity,
    required this.price,
  });

  Map<String, dynamic> toJson() {
    return {
      'stock_id': stockId,
      if (countableId != null) 'countable_id': countableId,
      'quantity': quantity,
      'price': price,
    };
  }

  factory EnhancedAddonOrder.fromJson(Map json) {
    return EnhancedAddonOrder(
      stockId: json['stock_id'] ?? 0,
      countableId: json['countable_id'],
      quantity: json['quantity'] ?? 0,
      price: json['price'] ?? 0,
    );
  }
}

class AddressModel {
  final String? address;
  final String? office;
  final String? house;
  final String? floor;

  AddressModel({
    this.address,
    this.office,
    this.house,
    this.floor,
  });

  Map toJson() {
    return {
      "address": address,
      "office": office,
      "house": house,
      "floor": floor
    };
  }

  factory AddressModel.fromJson(Map? data) {
    return AddressModel(
      address: data?["address"],
      office: data?["office"],
      house: data?["house"],
      floor: data?["floor"],
    );
  }
}

class ProductOrder {
  final int stockId;
  final num price;
  final int quantity;
  final num tax;
  final num discount;
  final num totalPrice;

  ProductOrder({
    required this.stockId,
    required this.price,
    required this.quantity,
    required this.tax,
    required this.discount,
    required this.totalPrice,
  });

  @override
  String toString() {
    return "{\"stock_id\":$stockId, \"price\":$price, \"qty\":$quantity, \"tax\":$tax, \"discount\":$discount, \"total_price\":$totalPrice}";
  }
}
