import 'dart:convert';

HelpModel helpModelFromJson(String str) => HelpModel.fromJson(json.decode(str));

String helpModelToJson(HelpModel data) => json.encode(data.toJson());

class HelpModel {
  HelpModel({this.data});

  List<Datum>? data;

  factory HelpModel.fromJson(Map<String, dynamic> json) => HelpModel(
        data: json["data"] == null
            ? []
            : List<Datum>.from(json["data"].map((x) => Datum.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "data": data == null
            ? []
            : List<dynamic>.from(data!.map((x) => x.toJson())),
      };
}

class Datum {
  Datum({
    this.id,
    this.uuid,
    this.type,
    this.active,
    this.createdAt,
    this.updatedAt,
    this.translation,
    this.locales,
  });

  int? id;
  String? uuid;
  String? type;
  bool? active;
  DateTime? createdAt;
  DateTime? updatedAt;
  HelpTranslation? translation;
  List<String>? locales;

  factory Datum.fromJson(Map<String, dynamic> json) => Datum(
        id: json["id"],
        uuid: json["uuid"],
        type: json["type"],
        active: json["active"],
        createdAt: json["created_at"] != null
            ? DateTime.tryParse(json["created_at"])?.toLocal()
            : null,
        updatedAt: json["updated_at"] != null
            ? DateTime.tryParse(json["updated_at"])?.toLocal()
            : null,
        translation: json["translation"] != null
            ? HelpTranslation.fromJson(json["translation"])
            : null,
        locales: json["locales"] != null
            ? List<String>.from(json["locales"].map((x) => x))
            : [],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "uuid": uuid,
        "type": type,
        "active": active,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
        "translation": translation?.toJson(),
        "locales":
            locales == null ? [] : List<dynamic>.from(locales!.map((x) => x)),
      };
}

class HelpTranslation {
  HelpTranslation({
    this.id,
    this.locale,
    this.question,
    this.answer,
  });

  int? id;
  String? locale;
  String? question;
  String? answer;

  factory HelpTranslation.fromJson(Map<String, dynamic> json) =>
      HelpTranslation(
        id: json["id"],
        locale: json["locale"],
        question: json["question"],
        answer: json["answer"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "locale": locale,
        "question": question,
        "answer": answer,
      };
}
