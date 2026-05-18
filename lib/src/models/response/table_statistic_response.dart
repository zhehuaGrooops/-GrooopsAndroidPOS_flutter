import 'dart:convert';

import 'package:admin_desktop/src/models/data/table_statistics_data.dart';

TableStatisticResponse tableStatisticResponseFromJson(String str) =>
    TableStatisticResponse.fromJson(json.decode(str));

String tableStatisticResponseToJson(TableStatisticResponse data) =>
    json.encode(data.toJson());

class TableStatisticResponse {
  DateTime timestamp;
  bool status;
  String message;
  TableStatisticData data;

  TableStatisticResponse({
    required this.timestamp,
    required this.status,
    required this.message,
    required this.data,
  });

  factory TableStatisticResponse.fromJson(Map<String, dynamic> json) =>
      TableStatisticResponse(
        timestamp: DateTime.parse(json["timestamp"]),
        status: json["status"],
        message: json["message"],
        data: TableStatisticData.fromJson(json["data"]),
      );

  Map<String, dynamic> toJson() => {
        "timestamp": timestamp.toIso8601String(),
        "status": status,
        "message": message,
        "data": data.toJson(),
      };
}
