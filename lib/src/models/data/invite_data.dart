class InviteData {
  int? id;
  int? shopId;
  int? userId;
  String? role;
  String? status;
  DateTime? createdAt;
  DateTime? updatedAt;

  InviteData({
    this.id,
    this.shopId,
    this.userId,
    this.role,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  InviteData copyWith({
    int? id,
    int? shopId,
    int? userId,
    String? role,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      InviteData(
        id: id ?? this.id,
        shopId: shopId ?? this.shopId,
        userId: userId ?? this.userId,
        role: role ?? this.role,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  factory InviteData.fromJson(Map<String, dynamic> json) => InviteData(
        id: json["id"],
        shopId: json["shop_id"],
        userId: json["user_id"],
        role: json["role"],
        status: json["status"],
        createdAt: DateTime.parse(json["created_at"]),
        updatedAt: DateTime.parse(json["updated_at"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "shop_id": shopId,
        "user_id": userId,
        "role": role,
        "status": status,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
      };
}
