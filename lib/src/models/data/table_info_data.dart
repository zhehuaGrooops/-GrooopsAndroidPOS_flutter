class TableInfoData {
  int id;
  int bookingId;
  int userId;
  int tableId;
  DateTime startDate;
  DateTime endDate;
  String status;

  TableInfoData({
    required this.id,
    required this.bookingId,
    required this.userId,
    required this.tableId,
    required this.startDate,
    required this.endDate,
    required this.status,
  });

  factory TableInfoData.fromJson(Map<String, dynamic> json) => TableInfoData(
        id: json["id"],
        bookingId: json["booking_id"],
        userId: json["user_id"],
        tableId: json["table_id"],
        startDate: DateTime.parse(json["start_date"]),
        endDate: DateTime.parse(json["end_date"]),
        status: json["status"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "booking_id": bookingId,
        "user_id": userId,
        "table_id": tableId,
        "start_date": startDate.toIso8601String(),
        "end_date": endDate.toIso8601String(),
        "status": status,
      };
}
