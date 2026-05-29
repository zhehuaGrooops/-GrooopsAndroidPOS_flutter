/// Minimal active-order snapshot embedded in table list responses.
/// Uses a dedicated class (not OrderData) to avoid a circular import
/// between table_data.dart and order_data.dart.
class TableActiveOrder {
  final int? id;
  final String? status;
  final String? createdAt;
  final num? totalPrice;

  const TableActiveOrder({
    this.id,
    this.status,
    this.createdAt,
    this.totalPrice,
  });

  factory TableActiveOrder.fromJson(Map<String, dynamic> json) {
    return TableActiveOrder(
      id: json['id'] as int?,
      status: json['status'] as String?,
      createdAt: json['created_at'] as String?,
      totalPrice: json['total_price'] as num?,
    );
  }
}

class TableData {
  int? id;
  String? name;
  int? shopSectionId;
  int? tax;
  int? chairCount;
  bool? active;
  String? createdAt;
  String? updatedAt;
  ShopSection? shopSection;
  double? positionX;
  double? positionY;
  /// Active order attached by the backend when order status == 'new'. Null
  /// when the table has no open session. Read-only — never written back.
  TableActiveOrder? order;

  TableData(
      {this.id,
      this.name,
      this.shopSectionId,
      this.tax,
      this.chairCount,
      this.active,
      this.createdAt,
      this.updatedAt,
      this.shopSection,
      this.positionX,
      this.positionY,
      this.order});

  TableData.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    shopSectionId = json['shop_section_id'];
    tax = json['tax'];
    chairCount = json['chair_count'];
    active = json['active'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    shopSection = json['shop_section'] != null
        ? ShopSection.fromJson(Map<String, dynamic>.from(json['shop_section']))
        : null;
    positionX = (json['position_x'] as num?)?.toDouble();
    positionY = (json['position_y'] as num?)?.toDouble();
    order = json['order'] != null
        ? TableActiveOrder.fromJson(
            Map<String, dynamic>.from(json['order'] as Map))
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['shop_section_id'] = shopSectionId;
    data['tax'] = tax;
    data['chair_count'] = chairCount;
    data['active'] = active;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    if (shopSection != null) {
      data['shop_section'] = shopSection!.toJson();
    }
    data['position_x'] = positionX;
    data['position_y'] = positionY;
    // 'order' is not serialised — populated by server, never sent back.
    return data;
  }
}

class ShopSection {
  int? id;
  int? shopId;
  String? area;
  String? img;
  String? createdAt;
  String? updatedAt;
  Translation? translation;
  int? mapWidth;
  int? mapHeight;

  ShopSection(
      {this.id,
      this.shopId,
      this.area,
      this.img,
      this.createdAt,
      this.updatedAt,
      this.translation,
      this.mapWidth,
      this.mapHeight});

  ShopSection.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    shopId = json['shop_id'];
    area = json['area'];
    img = json['img'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
    translation = json['translation'] != null
        ? Translation.fromJson(Map<String, dynamic>.from(json['translation']))
        : null;
    mapWidth = (json['map_width'] as num?)?.toInt();
    mapHeight = (json['map_height'] as num?)?.toInt();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['shop_id'] = shopId;
    data['area'] = area;
    data['img'] = img;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    if (translation != null) {
      data['translation'] = translation!.toJson();
    }
    data['map_width'] = mapWidth;
    data['map_height'] = mapHeight;
    return data;
  }
}

class Translation {
  int? id;
  String? locale;
  String? title;

  Translation({this.id, this.locale, this.title});

  Translation.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    locale = json['locale'];
    title = json['title'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['locale'] = locale;
    data['title'] = title;
    return data;
  }
}
