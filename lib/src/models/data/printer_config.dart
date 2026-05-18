class PrinterConfig {
  final String? name;
  final String? address;
  final String? vendorId;
  final String? productId;
  final bool isBle;
  final int type; // 0: USB, 1: Bluetooth, 2: Network
  final int? charsPerLine;

  PrinterConfig({
    this.name,
    this.address,
    this.vendorId,
    this.productId,
    this.isBle = false,
    required this.type,
    this.charsPerLine,
  });

  PrinterConfig copyWith({
    String? name,
    String? address,
    String? vendorId,
    String? productId,
    bool? isBle,
    int? type,
    int? charsPerLine,
  }) {
    return PrinterConfig(
      name: name ?? this.name,
      address: address ?? this.address,
      vendorId: vendorId ?? this.vendorId,
      productId: productId ?? this.productId,
      isBle: isBle ?? this.isBle,
      type: type ?? this.type,
      charsPerLine: charsPerLine ?? this.charsPerLine,
    );
  }

  factory PrinterConfig.fromJson(Map<String, dynamic> json) {
    final rawType = json['type'];
    int resolvedType = 1;
    if (rawType is int) {
      resolvedType = rawType;
    } else if (rawType is String) {
      resolvedType = int.tryParse(rawType) ?? 1;
    }
    return PrinterConfig(
      name: json['name']?.toString(),
      address: json['address']?.toString(),
      vendorId: json['vendorId']?.toString(),
      productId: json['productId']?.toString(),
      isBle: json['isBle'] ?? false,
      type: resolvedType,
      charsPerLine: int.tryParse((json['charsPerLine'] ?? '').toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'vendorId': vendorId,
      'productId': productId,
      'isBle': isBle,
      'type': type,
      'charsPerLine': charsPerLine,
    };
  }
}
