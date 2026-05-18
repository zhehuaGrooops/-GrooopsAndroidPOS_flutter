import 'package:flutter/foundation.dart';
import 'addons_data.dart';
import 'bonus_data.dart';
import 'review_data.dart';
import 'translation.dart';
import 'product_pricing_tier.dart';
import 'shop_data.dart';

class ProductData {
  ProductData({
    int? id,
    String? uuid,
    int? shopId,
    int? categoryId,
    String? keywords,
    int? brandId,
    num? tax,
    num? price,
    num? totalPrice,
    num? discount,
    int? quantity,
    int? minQty,
    int? maxQty,
    int? interval,
    bool? active,
    bool? bonus,
    bool? vegetarian,
    bool? addon,
    String? status,
    String? img,
    String? createdAt,
    String? updatedAt,
    num? ratingAvg,
    dynamic ordersCount,
    Translation? translation,
    List<Properties>? properties,
    List<Stocks>? stocks,
    List<Addons>? addons,
    Stocks? stock,
    Category? category,
    Brand? brand,
    Unit? unit,
    ShopData? shop,
    List<ReviewData>? reviews,
    List<Galleries>? galleries,
    int? count,
    List<ProductPricingTier>? productPricingTiers,
    List<String>? locales,
    List<Translation>? translations,
  }) {
    _id = id;
    _uuid = uuid;
    _shopId = shopId;
    _categoryId = categoryId;
    _keywords = keywords;
    _brandId = brandId;
    _interval = interval;
    _tax = tax;
    _totalPrice = totalPrice;
    _discount = discount;
    _quantity = quantity;
    _tax = tax;
    _price = price;
    _minQty = minQty;
    _maxQty = maxQty;
    _active = active;
    _bonus = bonus;
    _vegetarian = vegetarian;
    _addon = addon;
    _status = status;
    _img = img;
    _createdAt = createdAt;
    _updatedAt = updatedAt;
    _ratingAvg = ratingAvg;
    _ordersCount = ordersCount;
    _translation = translation;
    _translations = translations;
    _properties = properties;
    _stocks = stocks;
    _addons = addons;
    _stock = stock;
    _category = category;
    _brand = brand;
    _unit = unit;
    _shop = shop;
    _reviews = reviews;
    _galleries = galleries;
    _count = count;
    _productPricingTiers = productPricingTiers;
    _locales = locales;
  }

  ProductData.fromJson(dynamic json) {
    try {
      _id = json['id'] ?? json['product_id'];
      _uuid = json['uuid'];
      _shopId = json['shop_id'];
      _interval = json['interval'];
      _active = json['active'];
      _bonus = json['bonus'];
      _vegetarian = json['vegetarian'];
      _addon = json['addon'];
      _status = json['status'];
      _categoryId = json['category_id'];
      _keywords = json['keywords'];
      _brandId = json['brand_id'];
      _tax = json['tax'];
      _price = json['price'];
      _quantity = json['quantity'];
      _discount = json['discount'];
      _totalPrice = json['total_price'];
      _minQty = json['min_qty'];
      _maxQty = json['max_qty'];
      _img = json['img'];
      _createdAt = json['created_at'];
      _updatedAt = json['updated_at'];
      _ratingAvg = json['rating_avg'];
      _ordersCount = json['orders_count'];
      _count = 0;
      if (json['locales'] != null) {
        _locales = List<String>.from(json['locales']);
      }
      _stock = json['stock'] != null ? Stocks.fromJson(json['stock']) : null;
      _translation = json['translation'] != null
          ? Translation.fromJson(json['translation'])
          : null;
      if (json['translations'] != null) {
        _translations = [];
        json['translations'].forEach((v) {
          _translations?.add(Translation.fromJson(v));
        });
      }
      if (json['properties'] != null) {
        _properties = [];
        json['properties'].forEach((v) {
          _properties?.add(Properties.fromJson(v));
        });
      }
      if (json['stocks'] != null) {
        _stocks = [];
        json['stocks'].forEach((v) {
          _stocks?.add(Stocks.fromJson(v));
        });
      }
      if (json['addons'] != null) {
        _addons = [];
        json['addons'].forEach((v) {
          _addons?.add(Addons.fromJson(v));
        });
      }
      _category =
          json['category'] != null ? Category.fromJson(json['category']) : null;
      _brand = json['brand'] != null ? Brand.fromJson(json['brand']) : null;
      _unit = json['unit'] != null ? Unit.fromJson(json['unit']) : null;
      _shop = json['shop'] != null ? ShopData.fromJson(json['shop']) : null;
      if (json['reviews'] != null) {
        _reviews = [];
        json['reviews'].forEach((v) {
          _reviews?.add(ReviewData.fromJson(v));
        });
      }

      if (json['galleries'] != null) {
        _galleries = [];
        json['galleries'].forEach((v) {
          _galleries?.add(Galleries.fromJson(v));
        });
      }
      if (json['product_pricing_tiers'] != null) {
        _productPricingTiers = [];
        json['product_pricing_tiers'].forEach((v) {
          final Map<String, dynamic> tierJson = Map<String, dynamic>.from(v);
          // Only add tiers that have translations AND a valid title
          final translations = tierJson['translations'];
          if (translations != null && (translations as List).isNotEmpty) {
            final firstTranslation = (translations).first;
            if (firstTranslation is Map && firstTranslation['title'] != null) {
              _productPricingTiers?.add(ProductPricingTier.fromJson(tierJson));
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Error parsing ProductData fromJson: $e");
      rethrow;
    }
  }

  int? _id;
  String? _uuid;
  int? _shopId;
  int? _interval;
  int? _categoryId;
  String? _keywords;
  int? _brandId;
  num? _tax;
  num? _price;
  int? _quantity;
  num? _totalPrice;
  num? _discount;
  int? _minQty;
  int? _maxQty;
  bool? _active;
  bool? _bonus;
  bool? _vegetarian;
  bool? _addon;
  String? _status;
  String? _img;
  String? _createdAt;
  String? _updatedAt;
  num? _ratingAvg;
  dynamic _ordersCount;
  Translation? _translation;
  List<Translation>? _translations;
  List<Properties>? _properties;
  List<Stocks>? _stocks;
  List<Addons>? _addons;
  Stocks? _stock;
  Category? _category;
  Brand? _brand;
  Unit? _unit;
  ShopData? _shop;
  List<ReviewData>? _reviews;
  List<Galleries>? _galleries;
  List<ProductPricingTier>? _productPricingTiers;
  List<String>? _locales;

  int? _count;

  ProductData copyWith({
    int? id,
    String? uuid,
    int? shopId,
    int? categoryId,
    String? keywords,
    int? brandId,
    num? tax,
    num? price,
    int? quantity,
    num? totalPrice,
    num? discount,
    int? minQty,
    int? maxQty,
    int? interval,
    bool? active,
    bool? bonus,
    bool? vegetarian,
    bool? addon,
    String? status,
    String? img,
    String? createdAt,
    String? updatedAt,
    num? ratingAvg,
    dynamic ordersCount,
    Translation? translation,
    List<Translation>? translations,
    List<Properties>? properties,
    List<Stocks>? stocks,
    Stocks? stock,
    List<Addons>? addons,
    Category? category,
    Brand? brand,
    Unit? unit,
    ShopData? shop,
    List<ReviewData>? reviews,
    List<Galleries>? galleries,
    List<ProductPricingTier>? productPricingTiers,
    List<String>? locales,
  }) {
    return ProductData(
      id: id ?? _id,
      interval: interval ?? _interval,
      uuid: uuid ?? _uuid,
      shopId: shopId ?? _shopId,
      categoryId: categoryId ?? _categoryId,
      keywords: keywords ?? _keywords,
      brandId: brandId ?? _brandId,
      tax: tax ?? _tax,
      price: price ?? _price,
      quantity: quantity ?? _quantity,
      totalPrice: totalPrice ?? _totalPrice,
      discount: discount ?? _discount,
      minQty: minQty ?? _minQty,
      maxQty: maxQty ?? _maxQty,
      active: active ?? _active,
      bonus: bonus ?? _bonus,
      vegetarian: vegetarian ?? _vegetarian,
      addon: addon ?? _addon,
      status: status ?? _status,
      img: img ?? _img,
      createdAt: createdAt ?? _createdAt,
      updatedAt: updatedAt ?? _updatedAt,
      ratingAvg: ratingAvg ?? _ratingAvg,
      ordersCount: ordersCount ?? _ordersCount,
      translation: translation ?? _translation,
      translations: translations ?? _translations,
      properties: properties ?? _properties,
      stocks: stocks ?? _stocks,
      stock: stock ?? _stock,
      addons: addons ?? _addons,
      category: category ?? _category,
      brand: brand ?? _brand,
      unit: unit ?? _unit,
      shop: shop ?? _shop,
      reviews: reviews ?? _reviews,
      galleries: galleries ?? _galleries,
      productPricingTiers: productPricingTiers ?? _productPricingTiers,
      locales: locales ?? _locales,
    );
  }

  int? get id => _id;

  num? get price => _price;

  int? get interval => _interval;

  String? get uuid => _uuid;

  int? get shopId => _shopId;

  int? get categoryId => _categoryId;

  String? get keywords => _keywords;

  int? get brandId => _brandId;

  num? get tax => _tax;

  int? get quantity => _quantity;

  num? get totalPrice => _totalPrice;

  num? get discount => _discount;

  int? get minQty => _minQty;

  int? get maxQty => _maxQty;

  bool? get active => _active;
  bool? get bonus => _bonus;
  bool? get vegetarian => _vegetarian;
  bool? get addon => _addon;
  String? get status => _status;

  String? get img => _img;

  String? get createdAt => _createdAt;

  String? get updatedAt => _updatedAt;

  num? get ratingAvg => _ratingAvg;

  dynamic get ordersCount => _ordersCount;

  Stocks? get stock => _stock;

  Translation? get translation => _translation;

  List<Translation>? get translations => _translations;

  List<Properties>? get properties => _properties;

  List<Stocks>? get stocks => _stocks;

  List<Addons>? get addons => _addons;

  Category? get category => _category;

  Brand? get brand => _brand;

  Unit? get unit => _unit;

  ShopData? get shop => _shop;

  int? get count => _count;

  List<ReviewData>? get reviews => _reviews;

  List<Galleries>? get galleries => _galleries;

  List<ProductPricingTier>? get productPricingTiers => _productPricingTiers;

  List<String>? get locales => _locales;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['id'] = _id;
    map['uuid'] = _uuid;
    map['shop_id'] = _shopId;
    map['bonus'] = _bonus;
    map['active'] = _active;
    map['vegetarian'] = _vegetarian;
    map['addon'] = _addon;
    map['status'] = _status;
    map['category_id'] = _categoryId;
    map['keywords'] = _keywords;
    map['brand_id'] = _brandId;
    map['interval'] = _interval;
    map['tax'] = _tax;
    map['min_qty'] = _minQty;
    map['max_qty'] = _maxQty;
    map['img'] = _img;
    map['created_at'] = _createdAt;
    map['updated_at'] = _updatedAt;
    map['rating_avg'] = _ratingAvg;
    map['orders_count'] = _ordersCount;
    if (_locales != null) {
      map['locales'] = _locales;
    }
    if (_translation != null) {
      map['translation'] = _translation?.toJson();
    }
    if (_translations != null) {
      map['translations'] = _translations?.map((v) => v.toJson()).toList();
    }
    if (_properties != null) {
      map['properties'] = _properties?.map((v) => v.toJson()).toList();
    }
    if (_stocks != null) {
      map['stocks'] = _stocks?.map((v) => v.toJson()).toList();
    }
    if (_stock != null) {
      map['stock'] = _stock?.toJson();
    }
    if (_addons != null) {
      map['addons'] = _addons?.map((v) => v.toJson()).toList();
    }
    if (_category != null) {
      map['category'] = _category?.toJson();
    }
    if (_brand != null) {
      map['brand'] = _brand?.toJson();
    }
    if (_unit != null) {
      map['unit'] = _unit?.toJson();
    }
    if (_shop != null) {
      map['shop'] = _shop?.toJson();
    }
    if (_reviews != null) {
      map['reviews'] = _reviews?.map((v) => v.toJson()).toList();
    }
    if (_galleries != null) {
      map['galleries'] = _galleries?.map((v) => v.toJson()).toList();
    }
    if (_productPricingTiers != null) {
      map['product_pricing_tiers'] =
          _productPricingTiers?.map((v) => v.toJson()).toList();
    }
    return map;
  }
}

class Unit {
  Unit({
    int? id,
    bool? active,
    String? position,
    String? createdAt,
    String? updatedAt,
    Translation? translation,
  }) {
    _id = id;
    _active = active;
    _position = position;
    _createdAt = createdAt;
    _updatedAt = updatedAt;
    _translation = translation;
  }

  Unit.fromJson(dynamic json) {
    try {
      _id = json['id'];
      _active = json['active'] == 1 || json['active'] == true;
      _position = json['position'];
      _createdAt = json['created_at'];
      _updatedAt = json['updated_at'];
      _translation = json['translation'] != null
          ? Translation.fromJson(json['translation'])
          : null;
    } catch (e) {
      debugPrint("Error parsing Unit fromJson: $e");
      rethrow;
    }
  }

  int? _id;
  bool? _active;
  String? _position;
  String? _createdAt;
  String? _updatedAt;
  Translation? _translation;

  Unit copyWith({
    int? id,
    bool? active,
    String? position,
    String? createdAt,
    String? updatedAt,
    Translation? translation,
  }) =>
      Unit(
        id: id ?? _id,
        active: active ?? _active,
        position: position ?? _position,
        createdAt: createdAt ?? _createdAt,
        updatedAt: updatedAt ?? _updatedAt,
        translation: translation ?? _translation,
      );

  int? get id => _id;

  bool? get active => _active;

  String? get position => _position;

  String? get createdAt => _createdAt;

  String? get updatedAt => _updatedAt;

  Translation? get translation => _translation;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['id'] = _id;
    map['active'] = _active;
    map['position'] = _position;
    map['created_at'] = _createdAt;
    map['updated_at'] = _updatedAt;
    if (_translation != null) {
      map['translation'] = _translation?.toJson();
    }
    return map;
  }
}

class Brand {
  Brand({
    int? id,
    String? uuid,
    String? title,
  }) {
    _id = id;
    _uuid = uuid;
    _title = title;
  }

  Brand.fromJson(dynamic json) {
    try {
      _id = json['id'];
      _uuid = json['uuid'];
      _title = json['title'];
    } catch (e) {
      debugPrint("Error parsing Brand fromJson: $e");
      rethrow;
    }
  }

  int? _id;
  String? _uuid;
  String? _title;

  Brand copyWith({
    int? id,
    String? uuid,
    String? title,
  }) =>
      Brand(
        id: id ?? _id,
        uuid: uuid ?? _uuid,
        title: title ?? _title,
      );

  int? get id => _id;

  String? get uuid => _uuid;

  String? get title => _title;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['id'] = _id;
    map['uuid'] = _uuid;
    map['title'] = _title;
    return map;
  }
}

class Category {
  Category({
    int? id,
    String? uuid,
    int? parentId,
    String? img,
    bool? active,
    int? discountSettingId,
    Translation? translation,
    DiscountSetting? discountSetting,
    List<dynamic>? serviceTypes,
  }) {
    _id = id;
    _uuid = uuid;
    _parentId = parentId;
    _img = img;
    _active = active;
    _discountSettingId = discountSettingId;
    _translation = translation;
    _discountSetting = discountSetting;
    _serviceTypes = serviceTypes;
  }

  Category.fromJson(dynamic json) {
    try {
      _id = json['id'];
      _uuid = json['uuid'];
      _parentId = json['parent_id'];
      _img = json['img'];
      _active = json['active'] == 1 || json['active'] == true;
      _discountSettingId = json['discount_setting_id'];
      _translation = json['translation'] != null
          ? Translation.fromJson(json['translation'])
          : null;
      _discountSetting = json['discount_setting'] != null
          ? DiscountSetting.fromJson(json['discount_setting'])
          : null;
      _serviceTypes = json['service_types'] != null
          ? List<dynamic>.from(json['service_types'])
          : null;
    } catch (e) {
      debugPrint("Error parsing Category fromJson: $e");
      rethrow;
    }
  }

  int? _id;
  String? _uuid;
  int? _parentId;
  String? _img;
  bool? _active;
  int? _discountSettingId;
  Translation? _translation;
  DiscountSetting? _discountSetting;
  List<dynamic>? _serviceTypes;

  Category copyWith({
    int? id,
    String? uuid,
    int? parentId,
    String? img,
    bool? active,
    int? discountSettingId,
    Translation? translation,
    DiscountSetting? discountSetting,
    List<dynamic>? serviceTypes,
  }) =>
      Category(
        id: id ?? _id,
        uuid: uuid ?? _uuid,
        parentId: parentId ?? _parentId,
        img: img ?? _img,
        active: active ?? _active,
        discountSettingId: discountSettingId ?? _discountSettingId,
        translation: translation ?? _translation,
        discountSetting: discountSetting ?? _discountSetting,
        serviceTypes: serviceTypes ?? _serviceTypes,
      );

  int? get id => _id;

  String? get uuid => _uuid;

  int? get parentId => _parentId;

  String? get img => _img;

  bool? get active => _active;

  int? get discountSettingId => _discountSettingId;

  Translation? get translation => _translation;
  DiscountSetting? get discountSetting => _discountSetting;
  List<dynamic>? get serviceTypes => _serviceTypes;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['id'] = _id;
    map['uuid'] = _uuid;
    map['parent_id'] = _parentId;
    map['img'] = _img;
    map['active'] = _active;
    map['discount_setting_id'] = _discountSettingId;
    if (_translation != null) {
      map['translation'] = _translation?.toJson();
    }
    if (_discountSetting != null) {
      map['discount_setting'] = _discountSetting?.toJson();
    }
    if (_serviceTypes != null) {
      map['service_types'] = _serviceTypes;
    }
    return map;
  }
}

class DiscountSetting {
  DiscountSetting({
    this.id,
    this.title,
    this.method,
    this.value,
    this.active,
    this.scope,
  });

  DiscountSetting.fromJson(dynamic json) {
    if (json == null) return;
    try {
      id = json['id'];
      title = json['title'];
      method = json['method'];
      // value can be string or number
      if (json['value'] is num) {
        value = json['value'];
      } else if (json['value'] is String) {
        value = num.tryParse(json['value']) ?? 0;
      } else {
        value = 0;
      }
      active = json['active'] == 1 || json['active'] == true;
      scope = json['scope'];
    } catch (e) {
      debugPrint("Error parsing DiscountSetting fromJson: $e");
      rethrow;
    }
  }

  int? id;
  String? title;
  String? method;
  num? value;
  bool? active;
  String? scope;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'method': method,
      'value': value,
      'active': active,
      'scope': scope,
    };
  }
}

class Stocks {
  Stocks({
    int? id,
    int? countableId,
    num? price,
    int? quantity,
    num? discount,
    num? tax,
    num? totalPrice,
    String? img,
    Translation? translation,
    BonusModel? bonus,
    List<Extras>? extras,
    List<Addons>? addons,
    ProductData? product,
  }) {
    _bonus = bonus;
    _id = id;
    _countableId = countableId;
    _price = price;
    _quantity = quantity;
    _discount = discount;
    _img = img;
    _translation = translation;
    _tax = tax;
    _totalPrice = totalPrice;
    _extras = extras;
    _addons = addons;
    _product = product;
  }

  Stocks.fromJson(dynamic json) {
    try {
      _bonus =
          json?["bonus"] != null ? BonusModel.fromJson(json["bonus"]) : null;
      _id = json?['id'];
      _countableId = json?['countable_id'];
      _price = json?['price'];
      _img = json?["product"]?["img"];
      if (json["product"]?["translation"] != null) {
        _translation = Translation.fromJson(json["product"]["translation"]);
      }
      _quantity = json?['quantity'];
      _discount = json?['discount'];
      _tax = json?['tax'];
      _totalPrice = json?['total_price'];
      if (json?['extras'] != null) {
        _extras = [];
        if (json?['extras'].runtimeType != bool) {
          json?['extras'].forEach((v) {
            _extras?.add(Extras.fromJson(v));
          });
        }
      }
      if (json?['stock_extras'] != null) {
        _extras = [];
        if (json?['stock_extras'].runtimeType != bool) {
          json?['stock_extras'].forEach((v) {
            _extras?.add(Extras.fromJson(v));
          });
        }
      }
      if (json?['addons'] != null) {
        _addons = [];
        json?['addons'].forEach((v) {
          _addons?.add(Addons.fromJson(v));
        });
      }
      _product = (json?['product'] != null
          ? ProductData.fromJson(json['product'])
          : (json?['countable'] != null
              ? ProductData.fromJson(json["countable"])
              : null));
      if (json?['pricing_tiers'] != null) {
        _pricingTiers = [];
        json?['pricing_tiers'].forEach((v) {
          _pricingTiers?.add(StockPricingTier.fromJson(v));
        });
      }
    } catch (e) {
      debugPrint("Error parsing Stocks fromJson: $e");
      rethrow;
    }
  }

  int? _id;
  int? _countableId;
  num? _price;
  int? _quantity;
  num? _discount;
  String? _img;
  Translation? _translation;
  num? _tax;
  BonusModel? _bonus;
  num? _totalPrice;
  List<Extras>? _extras;
  ProductData? _product;
  List<Addons>? _addons;
  List<StockPricingTier>? _pricingTiers;

  Stocks copyWith({
    int? id,
    int? countableId,
    num? price,
    int? quantity,
    String? img,
    Translation? translation,
    num? discount,
    num? tax,
    BonusModel? bonus,
    num? totalPrice,
    List<Extras>? extras,
    List<Addons>? addons,
    ProductData? product,
    List<StockPricingTier>? pricingTiers,
  }) =>
      Stocks(
          bonus: bonus ?? _bonus,
          id: id ?? _id,
          countableId: countableId ?? _countableId,
          price: price ?? _price,
          img: img ?? _img,
          translation: translation ?? _translation,
          quantity: quantity ?? _quantity,
          discount: discount ?? _discount,
          tax: tax ?? _tax,
          totalPrice: totalPrice ?? _totalPrice,
          extras: extras ?? _extras,
          product: product ?? _product,
          addons: addons ?? _addons);

  int? get id => _id;

  int? get countableId => _countableId;

  num? get price => _price;

  String? get img => _img;

  Translation? get translation => _translation;

  int? get quantity => _quantity;

  num? get discount => _discount;

  num? get tax => _tax;

  num? get totalPrice => _totalPrice;

  BonusModel? get bonus => _bonus;

  List<Addons>? get addons => _addons;

  List<Extras>? get extras => _extras;

  ProductData? get product => _product;

  List<StockPricingTier>? get pricingTiers => _pricingTiers;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['id'] = _id;
    map['countable_id'] = _countableId;
    map['price'] = _price;
    map['quantity'] = _quantity;
    map['discount'] = _discount;
    map['tax'] = _tax;
    map['total_price'] = _totalPrice;
    if (_extras != null) {
      map['extras'] = _extras?.map((v) => v.toJson()).toList();
    }
    if (_addons != null) {
      map['addons'] = _addons?.map((v) => v.toJson()).toList();
    }
    if (_product != null) {
      map['product'] = _product?.toJson();
    }
    if (_pricingTiers != null) {
      map['pricing_tiers'] = _pricingTiers?.map((v) => v.toJson()).toList();
    }
    return map;
  }
}

class StockPricingTier {
  int? id;
  int? stockId;
  int? minQuantity;
  num? price;
  String? status;

  StockPricingTier({
    this.id,
    this.stockId,
    this.minQuantity,
    this.price,
    this.status,
  });

  StockPricingTier.fromJson(dynamic json) {
    id = json['id'];
    stockId = json['stock_id'];
    minQuantity = json['min_quantity'];
    price = json['price'];
    status = json['status'];
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['id'] = id;
    map['stock_id'] = stockId;
    map['min_quantity'] = minQuantity;
    map['price'] = price;
    map['status'] = status;
    return map;
  }
}

class Extras {
  Extras({
    int? id,
    int? extraGroupId,
    String? value,
    Group? group,
  }) {
    _id = id;
    _extraGroupId = extraGroupId;
    _value = value;
    _active = active;
    _group = group;
  }

  Extras.fromJson(dynamic json) {
    _id = json['id'];
    _extraGroupId = json['extra_group_id'];
    _value = json['value'];
    _group = json['group'] != null ? Group.fromJson(json['group']) : null;
  }

  int? _id;
  int? _extraGroupId;
  String? _value;
  bool? _active;
  Group? _group;

  Extras copyWith({
    int? id,
    int? extraGroupId,
    String? value,
    bool? active,
    Group? group,
  }) =>
      Extras(
        id: id ?? _id,
        extraGroupId: extraGroupId ?? _extraGroupId,
        value: value ?? _value,
        group: group ?? _group,
      );

  int? get id => _id;

  int? get extraGroupId => _extraGroupId;

  String? get value => _value;

  bool? get active => _active;

  Group? get group => _group;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['id'] = _id;
    map['extra_group_id'] = _extraGroupId;
    map['value'] = _value;
    map['active'] = _active;
    if (_group != null) {
      map['group'] = _group?.toJson();
    }
    return map;
  }
}

class Group {
  Group({
    int? id,
    String? type,
    bool? active,
    Translation? translation,
  }) {
    _id = id;
    _type = type;
    _active = active;
    _translation = translation;
  }

  Group.fromJson(dynamic json) {
    try {
      _id = json['id'];
      _type = json['type'];
      _translation = json['translation'] != null
          ? Translation.fromJson(json['translation'])
          : null;
    } catch (e) {
      debugPrint("Error parsing Group fromJson: $e");
      rethrow;
    }
  }

  int? _id;
  String? _type;
  bool? _active;
  Translation? _translation;

  Group copyWith({
    int? id,
    String? type,
    bool? active,
    Translation? translation,
  }) =>
      Group(
        id: id ?? _id,
        type: type ?? _type,
        active: active ?? _active,
        translation: translation ?? _translation,
      );

  int? get id => _id;

  String? get type => _type;

  bool? get active => _active;

  Translation? get translation => _translation;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['id'] = _id;
    map['type'] = _type;
    map['active'] = _active;
    if (_translation != null) {
      map['translation'] = _translation?.toJson();
    }
    return map;
  }
}

class Properties {
  Properties({
    String? locale,
    String? key,
    String? value,
  }) {
    _locale = locale;
    _key = key;
    _value = value;
  }

  Properties.fromJson(dynamic json) {
    try {
      _locale = json['locale'];
      _key = json['key'];
      _value = json['value'];
    } catch (e) {
      debugPrint("Error parsing Properties fromJson: $e");
      rethrow;
    }
  }

  String? _locale;
  String? _key;
  String? _value;

  Properties copyWith({
    String? locale,
    String? key,
    String? value,
  }) =>
      Properties(
        locale: locale ?? _locale,
        key: key ?? _key,
        value: value ?? _value,
      );

  String? get locale => _locale;

  String? get key => _key;

  String? get value => _value;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['locale'] = _locale;
    map['key'] = _key;
    map['value'] = _value;
    return map;
  }
}
