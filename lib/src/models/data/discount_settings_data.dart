class DiscountSettingsData {
  int? id;
  String? title;
  String? method;
  String? value;
  bool? active;
  String? scope;

  DiscountSettingsData(
      {this.id, this.title, this.method, this.value, this.active, this.scope});

  DiscountSettingsData.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    title = json['title'];
    method = json['method'];
    value = json['value'];
    active = json['active'];
    scope = json['scope'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['title'] = title;
    data['method'] = method;
    data['value'] = value;
    data['active'] = active;
    data['scope'] = scope;
    return data;
  }
}
