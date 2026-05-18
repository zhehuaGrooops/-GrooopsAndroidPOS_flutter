import '../data/notification_transactions_data.dart';
import '../data/order_data.dart';
import '../data/translation.dart';

class OrderKitchenResponse {
  List<OrderData>? orders;
  Links? links;
  Meta? meta;

  OrderKitchenResponse({
    this.orders,
    this.links,
    this.meta,
  });

  OrderKitchenResponse copyWith({
    List<OrderData>? orders,
    Links? links,
    Meta? meta,
  }) =>
      OrderKitchenResponse(
        orders: orders ?? this.orders,
        links: links ?? this.links,
        meta: meta ?? this.meta,
      );

  factory OrderKitchenResponse.fromJson(Map<String, dynamic> json) =>
      OrderKitchenResponse(
        orders: json["data"] == null
            ? []
            : List<OrderData>.from(
                json["data"]!.map((x) => OrderData.fromJson(x))),
        links: json["links"] == null ? null : Links.fromJson(json["links"]),
        meta: json["meta"] == null ? null : Meta.fromJson(json["meta"]),
      );

  Map<String, dynamic> toJson() => {
        "data": orders == null
            ? []
            : List<dynamic>.from(orders!.map((x) => x.toJson())),
        "links": links?.toJson(),
        "meta": meta?.toJson(),
      };
}

class KitchenModel {
  int? id;
  int? active;
  int? shopId;
  Translation? translation;

  KitchenModel({
    this.id,
    this.active,
    this.shopId,
    this.translation,
  });

  KitchenModel copyWith({
    int? id,
    int? active,
    int? shopId,
    Translation? translation,
  }) =>
      KitchenModel(
        id: id ?? this.id,
        active: active ?? this.active,
        shopId: shopId ?? this.shopId,
        translation: translation ?? this.translation,
      );

  factory KitchenModel.fromJson(Map<String, dynamic> json) => KitchenModel(
        id: json["id"],
        active: json["active"],
        shopId: json["shop_id"],
        translation: json["translation"] == null
            ? null
            : Translation.fromJson(json["translation"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "active": active,
        "shop_id": shopId,
        "translation": translation?.toJson(),
      };
}
