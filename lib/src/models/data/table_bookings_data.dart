class TableBookingData {
  int? id;
  int? bookingId;
  int? userId;
  int? tableId;
  DateTime? startDate;
  DateTime? endDate;
  String? status;
  Booking? booking;
  User? user;
  Table? table;

  TableBookingData({
    required this.id,
    required this.bookingId,
    required this.userId,
    required this.tableId,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.booking,
    required this.user,
    this.table,
  });

  TableBookingData copyWith({
    int? id,
    int? bookingId,
    int? userId,
    int? tableId,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    Booking? booking,
    User? user,
    Table? table,
  }) =>
      TableBookingData(
        id: id ?? this.id,
        bookingId: bookingId ?? this.bookingId,
        userId: userId ?? this.userId,
        tableId: tableId ?? this.tableId,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        status: status ?? this.status,
        booking: booking ?? this.booking,
        user: user ?? this.user,
        table: table ?? this.table,
      );
  factory TableBookingData.fromJson(Map<String, dynamic> json) =>
      TableBookingData(
        id: json["id"],
        bookingId: json["booking_id"],
        userId: json["user_id"],
        tableId: json["table_id"],
        startDate:
            DateTime.tryParse(json["start_date"] ?? '') ?? DateTime.now(),
        endDate: DateTime.tryParse(json["end_date"] ?? '') ?? DateTime.now(),
        status: json["status"],
        booking:
            json["booking"] == null ? null : Booking.fromJson(json["booking"]),
        user: json["user"] == null ? null : User.fromJson(json["user"]),
        table: json["table"] == null ? null : Table.fromJson(json["table"]),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "booking_id": bookingId,
        "user_id": userId,
        "table_id": tableId,
        "start_date": startDate?.toIso8601String(),
        "end_date": endDate?.toIso8601String(),
        "status": status,
        "booking": booking?.toJson(),
        "user": user?.toJson(),
        "table": table?.toJson(),
      };
}

class Booking {
  int? id;
  int? maxTime;

  Booking({
    required this.id,
    required this.maxTime,
  });

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
        id: json["id"],
        maxTime: json["max_time"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "max_time": maxTime,
      };
}

class Table {
  int id;
  String name;
  int shopSectionId;
  int chairCount;
  bool active;

  Table({
    required this.id,
    required this.name,
    required this.shopSectionId,
    required this.chairCount,
    required this.active,
  });

  factory Table.fromJson(Map<String, dynamic> json) => Table(
        id: json["id"],
        name: json["name"],
        shopSectionId: json["shop_section_id"],
        chairCount: json["chair_count"],
        active: json["active"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "shop_section_id": shopSectionId,
        "chair_count": chairCount,
        "active": active,
      };
}

class User {
  int id;
  String uuid;
  String firstname;
  String lastname;
  bool emptyP;
  int active;
  String role;
  String? img;

  User({
    required this.id,
    required this.uuid,
    required this.firstname,
    required this.lastname,
    required this.emptyP,
    required this.active,
    required this.role,
    this.img,
  });

  User copyWith({
    int? id,
    String? uuid,
    String? firstname,
    String? lastname,
    bool? emptyP,
    int? active,
    String? role,
    String? img,
  }) =>
      User(
        id: id ?? this.id,
        uuid: uuid ?? this.uuid,
        firstname: firstname ?? this.firstname,
        lastname: lastname ?? this.lastname,
        emptyP: emptyP ?? this.emptyP,
        active: active ?? this.active,
        role: role ?? this.role,
        img: img ?? this.img,
      );

  factory User.fromJson(Map json) => User(
        id: json["id"],
        uuid: json["uuid"],
        firstname: json["firstname"],
        lastname: json["lastname"],
        emptyP: json["empty_p"],
        active: json["active"],
        role: json["role"],
        img: json["img"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "uuid": uuid,
        "firstname": firstname,
        "lastname": lastname,
        "empty_p": emptyP,
        "active": active,
        "role": role,
        "img": img,
      };
}

class Links {
  String first;
  String last;
  dynamic prev;
  dynamic next;

  Links({
    required this.first,
    required this.last,
    this.prev,
    this.next,
  });

  factory Links.fromJson(Map<String, dynamic> json) => Links(
        first: json["first"],
        last: json["last"],
        prev: json["prev"],
        next: json["next"],
      );

  Map<String, dynamic> toJson() => {
        "first": first,
        "last": last,
        "prev": prev,
        "next": next,
      };
}

class Meta {
  int currentPage;
  int from;
  int lastPage;
  List<Link> links;
  String path;
  int perPage;
  int to;
  int total;

  Meta({
    required this.currentPage,
    required this.from,
    required this.lastPage,
    required this.links,
    required this.path,
    required this.perPage,
    required this.to,
    required this.total,
  });

  factory Meta.fromJson(Map<String, dynamic> json) => Meta(
        currentPage: json["current_page"],
        from: json["from"],
        lastPage: json["last_page"],
        links: List<Link>.from(json["links"].map((x) => Link.fromJson(x))),
        path: json["path"],
        perPage: json["per_page"],
        to: json["to"],
        total: json["total"],
      );

  Map<String, dynamic> toJson() => {
        "current_page": currentPage,
        "from": from,
        "last_page": lastPage,
        "links": List<dynamic>.from(links.map((x) => x.toJson())),
        "path": path,
        "per_page": perPage,
        "to": to,
        "total": total,
      };
}

class Link {
  String? url;
  String label;
  bool active;

  Link({
    this.url,
    required this.label,
    required this.active,
  });

  factory Link.fromJson(Map<String, dynamic> json) => Link(
        url: json["url"],
        label: json["label"],
        active: json["active"],
      );

  Map<String, dynamic> toJson() => {
        "url": url,
        "label": label,
        "active": active,
      };
}
