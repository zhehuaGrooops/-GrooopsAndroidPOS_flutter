import 'package:admin_desktop/src/models/response/income_chart_response.dart';
import 'package:flutter/material.dart';

import '../../models/data/addons_data.dart';
import '../../models/data/bag_data.dart';

extension Time on DateTime {
  bool toEqualTime(DateTime time) {
    if (time.year != year) {
      return false;
    } else if (time.month != month) {
      return false;
    } else if (time.day != day) {
      return false;
    }
    return true;
  }

  bool toEqualTimeWithHour(DateTime time) {
    if (time.year != year) {
      return false;
    } else if (time.month != month) {
      return false;
    } else if (time.day != day) {
      return false;
    } else if (time.hour != hour) {
      return false;
    }
    return true;
  }

  TimeOfDay get toTime => TimeOfDay(hour: hour, minute: minute);

  DateTime addTime(TimeOfDay time) =>
      DateTime(year, month, day, time.hour, time.minute);
}

extension ExtendedIterable<E> on Iterable<E> {
  mapIndexed<T>(T Function(E e, int i) f) {
    var i = 0;
    return map((e) => f(e, i++)).toList();
  }
}

extension FindPriceIndex on List<num> {
  double findPriceIndex(num price) {
    if (price != 0) {
      int startIndex = 0;
      int endIndex = 0;
      for (int i = 0; i < length; i++) {
        if ((this[i]) >= price.toInt()) {
          startIndex = i;
          break;
        }
      }
      for (int i = 0; i < length; i++) {
        if ((this[i]) <= price) {
          endIndex = i;
        }
      }
      if (startIndex == endIndex) {
        return length.toDouble();
      }

      num a = this[startIndex] - this[endIndex];
      num b = price - this[endIndex];
      num c = b / a;
      return startIndex.toDouble() + c;
    } else {
      return 0;
    }
  }
}

extension FindPrice on List<IncomeChartResponse> {
  num findPrice(DateTime time) {
    num price = 0;
    for (int i = 0; i < length; i++) {
      if (this[i].time!.toEqualTime(time)) {
        price = this[i].totalPrice ?? 0;
      }
    }
    return price;
  }

  num findPriceWithHour(DateTime time) {
    num price = 0;
    for (int i = 0; i < length; i++) {
      if (this[i].time!.toEqualTimeWithHour(time)) {
        price = this[i].totalPrice ?? 0;
      }
    }
    return price;
  }
}

extension BoolParsing on String {
  bool toBool() {
    return this == "true" || this == "1";
  }
}

extension Search on List<BagProductData>? {
  String toUniqueString() {
    List<int> smth = this
            ?.map(
              (e) => e.stockId ?? 0,
            )
            .toList() ??
        [];
    smth.sort();
    return smth.join('');
  }
}

extension Search1 on List<Addons>? {
  String toUniqueString() {
    List<int> smth = this
            ?.map(
              (e) => e.stockId ?? 0,
            )
            .toList() ??
        [];
    smth.sort();
    return smth.join('');
  }
}
