// To parse this JSON data, do
//
//     final tableInfoResponse = tableInfoResponseFromJson(jsonString);

import 'dart:convert';

import 'package:admin_desktop/src/models/data/table_info_data.dart';

TableInfoResponse tableInfoResponseFromJson(String str) =>
    TableInfoResponse.fromJson(json.decode(str));

String tableInfoResponseToJson(TableInfoResponse data) =>
    json.encode(data.toJson());

class TableInfoResponse {
  DateTime timestamp;
  bool status;
  String message;
  TableInfoData data;

  TableInfoResponse({
    required this.timestamp,
    required this.status,
    required this.message,
    required this.data,
  });

  factory TableInfoResponse.fromJson(Map<String, dynamic> json) =>
      TableInfoResponse(
        timestamp: DateTime.parse(json["timestamp"]),
        status: json["status"],
        message: json["message"],
        data: TableInfoData.fromJson(json["data"]),
      );

  Map<String, dynamic> toJson() => {
        "timestamp": timestamp.toIso8601String(),
        "status": status,
        "message": message,
        "data": data.toJson(),
      };
}
