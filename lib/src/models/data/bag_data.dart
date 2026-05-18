import 'address_data.dart';
import 'table_data.dart';
import 'user_data.dart';
import 'currency_data.dart';
import 'package:admin_desktop/src/models/data/product_data.dart';

import '../response/payments_response.dart';

class BagData {
  BagData({
    int? index,
    UserData? selectedUser,
    TableData? selectedTable,
    ShopSection? selectedSection,
    AddressData? selectedAddress,
    CurrencyData? selectedCurrency,
    PaymentData? selectedPayment,
    List<BagProductData>? bagProducts,
    DiscountSetting? selectedBillDiscount,
    String? note,
  }) {
    _index = index;
    _selectedUser = selectedUser;
    _selectedAddress = selectedAddress;
    _selectedCurrency = selectedCurrency;
    _selectedPayment = selectedPayment;
    _bagProducts = bagProducts;
    _selectedTable = selectedTable;
    _selectedSection = selectedSection;
    _selectedBillDiscount = selectedBillDiscount;
    _note = note;
  }

  BagData.fromJson(dynamic json) {
    _index = json['index'];
    _note = json['note'];
    _selectedUser = json['selected_user'] != null
        ? UserData.fromJson(json['selected_user'])
        : null;
    _selectedTable = json['selected_table'] != null
        ? TableData.fromJson(json['selected_table'])
        : null;
    _selectedSection = json['selected_section'] != null
        ? ShopSection.fromJson(json['selected_section'])
        : null;
    _selectedAddress = json['selected_address'] != null
        ? AddressData.fromJson(json['selected_address'])
        : null;
    _selectedCurrency = json['selected_currency'] != null
        ? CurrencyData.fromJson(json['selected_currency'])
        : null;
    _selectedPayment = json['selected_payment'] != null
        ? PaymentData.fromJson(json['selected_payment'])
        : null;
    _selectedBillDiscount = json['selected_bill_discount'] != null
        ? DiscountSetting.fromJson(json['selected_bill_discount'])
        : null;
    if (json['bag_products'] != null) {
      _bagProducts = [];
      json['bag_products'].forEach((v) {
        _bagProducts?.add(BagProductData.fromJson(v));
      });
    }
  }

  int? _index;
  UserData? _selectedUser;
  TableData? _selectedTable;
  ShopSection? _selectedSection;
  AddressData? _selectedAddress;
  CurrencyData? _selectedCurrency;
  PaymentData? _selectedPayment;
  List<BagProductData>? _bagProducts;
  DiscountSetting? _selectedBillDiscount;
  String? _note;

  BagData copyWith({
    int? index,
    UserData? selectedUser,
    ShopSection? selectedSection,
    TableData? selectedTable,
    AddressData? selectedAddress,
    CurrencyData? selectedCurrency,
    PaymentData? selectedPayment,
    List<BagProductData>? bagProducts,
    DiscountSetting? selectedBillDiscount,
    String? note,
  }) =>
      BagData(
        index: index ?? _index,
        selectedUser: selectedUser,
        selectedSection: selectedSection,
        selectedTable: selectedTable,
        selectedAddress: selectedAddress,
        selectedCurrency: selectedCurrency ?? _selectedCurrency,
        selectedPayment: selectedPayment ?? _selectedPayment,
        bagProducts: bagProducts ?? _bagProducts,
        selectedBillDiscount: selectedBillDiscount ?? _selectedBillDiscount,
        note: note ?? _note,
      );

  int? get index => _index;

  String? get note => _note;

  UserData? get selectedUser => _selectedUser;

  TableData? get selectedTable => _selectedTable;

  ShopSection? get selectedSection => _selectedSection;

  AddressData? get selectedAddress => _selectedAddress;

  CurrencyData? get selectedCurrency => _selectedCurrency;

  PaymentData? get selectedPayment => _selectedPayment;

  List<BagProductData>? get bagProducts => _bagProducts;

  DiscountSetting? get selectedBillDiscount => _selectedBillDiscount;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['index'] = _index;
    if (_selectedUser != null) {
      map['selected_user'] = _selectedUser?.toJson();
    }
    if (_selectedTable != null) {
      map['selected_table'] = _selectedTable?.toJson();
    }
    if (_selectedSection != null) {
      map['selected_section'] = _selectedSection?.toJson();
    }
    if (_selectedAddress != null) {
      map['selected_address'] = _selectedAddress?.toJson();
    }
    if (_selectedCurrency != null) {
      map['selected_currency'] = _selectedCurrency?.toJson();
    }
    if (_selectedPayment != null) {
      map['selected_payment'] = _selectedPayment?.toJson();
    }
    if (_selectedBillDiscount != null) {
      map['selected_bill_discount'] = _selectedBillDiscount?.toJson();
    }
    if (_note != null) {
      map['note'] = _note;
    }
    if (_bagProducts != null) {
      map['bag_products'] = _bagProducts?.map((v) => v.toJsonInsert()).toList();
    }
    return map;
  }
}

class BagProductData {
  final int? stockId;
  final int? parentId;
  final int? quantity;
  final List<BagProductData>? carts;
  final String? selectedDiscount;
  final DiscountSetting? selectedDiscountSetting;

  BagProductData({
    this.stockId,
    this.parentId,
    this.quantity,
    this.carts,
    this.selectedDiscount,
    this.selectedDiscountSetting,
  });

  factory BagProductData.fromJson(Map data) {
    List<BagProductData> newList = [];
    data["products"]?.forEach((e) {
      newList.add(BagProductData.fromJson(e));
    });
    return BagProductData(
      stockId: data["stock_id"],
      parentId: data["parent_id"],
      quantity: data["quantity"],
      carts: newList,
      selectedDiscount: data['selected_discount']?.toString(),
      selectedDiscountSetting: data['selected_discount_setting'] != null
          ? DiscountSetting.fromJson(
              Map<String, dynamic>.from(data['selected_discount_setting']))
          : null,
    );
  }

  BagProductData copyWith(
      {int? quantity,
      String? selectedDiscount,
      DiscountSetting? selectedDiscountSetting}) {
    return BagProductData(
        stockId: stockId,
        parentId: parentId,
        quantity: quantity ?? this.quantity,
        carts: carts,
        selectedDiscount: selectedDiscount ?? this.selectedDiscount,
        selectedDiscountSetting:
            selectedDiscountSetting ?? this.selectedDiscountSetting);
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (stockId != null) map["stock_id"] = stockId;
    if (parentId != null) map["parent_id"] = parentId;
    if (quantity != null) map["quantity"] = quantity;
    if (selectedDiscount != null) map['selected_discount'] = selectedDiscount;
    if (selectedDiscountSetting != null) {
      map['selected_discount_setting'] = selectedDiscountSetting?.toJson();
    }
    return map;
  }

  Map<String, dynamic> toJsonInsert() {
    final map = <String, dynamic>{};
    if (stockId != null) map["stock_id"] = stockId;
    if (quantity != null) map["quantity"] = quantity;
    if (selectedDiscount != null) map['selected_discount'] = selectedDiscount;
    if (selectedDiscountSetting != null) {
      map['selected_discount_setting'] = selectedDiscountSetting?.toJson();
    }
    if (carts != null) map["products"] = toJsonCart();
    return map;
  }

  List<Map<String, dynamic>> toJsonCart() {
    List<Map<String, dynamic>> list = [];
    carts?.forEach((element) {
      final map = <String, dynamic>{};
      map["stock_id"] = element.stockId;
      map["quantity"] = element.quantity;
      if (element.parentId != null) map["parent_id"] = element.parentId;
      list.add(map);
    });

    return list;
  }
}
