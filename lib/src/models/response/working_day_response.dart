import 'dart:convert';
import '../data/working_day_data.dart';

WorkingDayResponse workingDayResponseFromJson(String str) =>
    WorkingDayResponse.fromJson(json.decode(str));

String workingDayResponseToJson(WorkingDayResponse data) =>
    json.encode(data.toJson());

class WorkingDayResponse {
  DateTime timestamp;
  bool status;
  String message;
  WorkingDayData data;

  WorkingDayResponse({
    required this.timestamp,
    required this.status,
    required this.message,
    required this.data,
  });

  factory WorkingDayResponse.fromJson(Map<String, dynamic> json) =>
      WorkingDayResponse(
        timestamp: DateTime.parse(json["timestamp"]),
        status: json["status"],
        message: json["message"],
        data: WorkingDayData.fromJson(json["data"]),
      );

  Map<String, dynamic> toJson() => {
        "timestamp": timestamp.toIso8601String(),
        "status": status,
        "message": message,
        "data": data.toJson(),
      };
}
