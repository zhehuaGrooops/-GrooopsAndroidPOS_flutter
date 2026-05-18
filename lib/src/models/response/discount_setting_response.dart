import '../data/discount_settings_data.dart';

class DiscountSettingResponse {
  String? timestamp;
  bool? status;
  String? message;
  List<DiscountSettingsData>? data;

  DiscountSettingResponse(
      {this.timestamp, this.status, this.message, this.data});

  DiscountSettingResponse.fromJson(Map<String, dynamic> json) {
    timestamp = json['timestamp'];
    status = json['status'];
    message = json['message'];
    data = List<DiscountSettingsData>.from(
        json["data"].map((x) => DiscountSettingsData.fromJson(x)));
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['timestamp'] = timestamp;
    data['status'] = status;
    data['message'] = message;
    if (this.data != null) {
      data['data'] = List<dynamic>.from(this.data!.map((x) => x.toJson()));
    }
    return data;
  }
}
