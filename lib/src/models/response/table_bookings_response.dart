// To parse this JSON data, do
//
//     final tableBookingResponse = tableBookingResponseFromJson(jsonString);

import 'dart:convert';

import '../data/table_bookings_data.dart';

TableBookingResponse tableBookingResponseFromJson(String str) =>
    TableBookingResponse.fromJson(json.decode(str));

String tableBookingResponseToJson(TableBookingResponse data) =>
    json.encode(data.toJson());

class TableBookingResponse {
  List<TableBookingData> data;

  TableBookingResponse({required this.data});

  factory TableBookingResponse.fromJson(Map<String, dynamic> json) =>
      TableBookingResponse(
        data: List<TableBookingData>.from(
            json["data"].map((x) => TableBookingData.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "data": List<dynamic>.from(data.map((x) => x.toJson())),
      };
}
