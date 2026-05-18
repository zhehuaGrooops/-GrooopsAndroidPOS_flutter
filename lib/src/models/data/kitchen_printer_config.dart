import 'printer_config.dart';

class KitchenPrinterConfig {
  final String id;
  final PrinterConfig? printerConfig;
  final List<int> categoryIds;
  final int createdAt;
  final int? charsPerLine;

  KitchenPrinterConfig({
    required this.id,
    this.printerConfig,
    this.categoryIds = const [],
    required this.createdAt,
    this.charsPerLine,
  });

  KitchenPrinterConfig copyWith({
    String? id,
    PrinterConfig? printerConfig,
    List<int>? categoryIds,
    int? createdAt,
    int? charsPerLine,
  }) {
    return KitchenPrinterConfig(
      id: id ?? this.id,
      printerConfig: printerConfig ?? this.printerConfig,
      categoryIds: categoryIds ?? this.categoryIds,
      createdAt: createdAt ?? this.createdAt,
      charsPerLine: charsPerLine ?? this.charsPerLine,
    );
  }

  factory KitchenPrinterConfig.fromJson(Map<String, dynamic> json) {
    final rawCategoryIds = json['categoryIds'];
    final List<int> resolvedCategoryIds = (rawCategoryIds is List)
        ? rawCategoryIds
            .map((e) => int.tryParse(e.toString()))
            .whereType<int>()
            .toList()
        : <int>[];

    final rawPrinterConfig = json['printerConfig'];
    PrinterConfig? printerConfig;
    if (rawPrinterConfig is PrinterConfig) {
      printerConfig = rawPrinterConfig;
    } else if (rawPrinterConfig is Map) {
      printerConfig =
          PrinterConfig.fromJson(Map<String, dynamic>.from(rawPrinterConfig));
    }

    final rawCreatedAt = json['createdAt'];
    int createdAt = DateTime.now().millisecondsSinceEpoch;
    if (rawCreatedAt is int) {
      createdAt = rawCreatedAt;
    } else if (rawCreatedAt is String) {
      createdAt = int.tryParse(rawCreatedAt) ?? createdAt;
    }

    return KitchenPrinterConfig(
      id: json['id']?.toString() ?? '',
      printerConfig: printerConfig,
      categoryIds: resolvedCategoryIds,
      createdAt: createdAt,
      charsPerLine: int.tryParse((json['charsPerLine'] ?? '').toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'printerConfig': printerConfig?.toJson(),
      'categoryIds': categoryIds,
      'createdAt': createdAt,
      'charsPerLine': charsPerLine,
    };
  }
}
