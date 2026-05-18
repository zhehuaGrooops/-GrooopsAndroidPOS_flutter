import 'dart:convert';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_remix/flutter_remix.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../../presentation/theme/theme.dart';
import '../constants/constants.dart';
import 'local_storage.dart';

class AppHelpers {
  AppHelpers._();

  static int displayWidth(String text) {
    var width = 0;
    for (final rune in text.runes) {
      width += _runeDisplayWidth(rune);
    }
    return width;
  }

  static String centerAlignText(String text, int charsPerLine) {
    final width = charsPerLine <= 0 ? 0 : charsPerLine;
    if (width <= 0) return text;

    final lines = text.split('\n');
    final wrappedLines = <String>[];
    for (final line in lines) {
      wrappedLines.addAll(_wrapTextLine(line, width));
    }

    final centered = wrappedLines.map((line) {
      final contentWidth = displayWidth(line);
      if (contentWidth >= width) return line;
      final padTotal = width - contentWidth;
      final padLeft = padTotal ~/ 2;
      final padRight = padTotal - padLeft;
      return '${' ' * padLeft}$line${' ' * padRight}';
    }).toList();
    return centered.join('\n');
  }

  static String dividerLine(int charsPerLine, {String char = '-'}) {
    final width = charsPerLine <= 0 ? 0 : charsPerLine;
    if (width <= 0) return '';
    final c = char.isEmpty ? '-' : char[0];
    return c * width;
  }

  static int clampCharsPerLine(int? value, {int fallback = 48}) {
    final v = value ?? fallback;
    if (v < 10) return 10;
    if (v > 96) return 96;
    return v;
  }

  static List<String> _wrapTextLine(String line, int width) {
    if (line.isEmpty) return [''];
    if (displayWidth(line) <= width) return [line];

    final words = line.split(RegExp(r'\s+'));
    final wrapped = <String>[];
    var current = '';

    for (final word in words) {
      if (word.isEmpty) continue;

      if (displayWidth(word) > width) {
        if (current.isNotEmpty) {
          wrapped.add(current);
          current = '';
        }
        wrapped.addAll(_splitLongToken(word, width));
        continue;
      }

      final candidate = current.isEmpty ? word : '$current $word';
      if (displayWidth(candidate) <= width) {
        current = candidate;
        continue;
      }

      if (current.isNotEmpty) {
        wrapped.add(current);
      }
      current = word;
    }

    if (current.isNotEmpty) {
      wrapped.add(current);
    }

    return wrapped.isEmpty ? [''] : wrapped;
  }

  static List<String> _splitLongToken(String text, int width) {
    final parts = <String>[];
    final buffer = StringBuffer();
    var currentWidth = 0;

    for (final rune in text.runes) {
      final runeWidth = _runeDisplayWidth(rune);
      if (buffer.isNotEmpty && currentWidth + runeWidth > width) {
        parts.add(buffer.toString());
        buffer.clear();
        currentWidth = 0;
      }
      buffer.writeCharCode(rune);
      currentWidth += runeWidth;
    }

    if (buffer.isNotEmpty) {
      parts.add(buffer.toString());
    }

    return parts;
  }

  static int _runeDisplayWidth(int rune) {
    if (rune == 0) return 0;
    if (_isCombiningMark(rune)) return 0;
    if (_isWideRune(rune)) return 2;
    return 1;
  }

  static bool _isCombiningMark(int rune) {
    return (rune >= 0x0300 && rune <= 0x036F) ||
        (rune >= 0x1AB0 && rune <= 0x1AFF) ||
        (rune >= 0x1DC0 && rune <= 0x1DFF) ||
        (rune >= 0x20D0 && rune <= 0x20FF) ||
        (rune >= 0xFE20 && rune <= 0xFE2F);
  }

  static bool _isWideRune(int rune) {
    return (rune >= 0x1100 && rune <= 0x115F) || // Hangul Jamo init. consonants
        rune == 0x2329 ||
        rune == 0x232A ||
        (rune >= 0x2E80 && rune <= 0xA4CF) || // CJK ... Yi
        (rune >= 0xAC00 && rune <= 0xD7A3) || // Hangul Syllables
        (rune >= 0xF900 && rune <= 0xFAFF) || // CJK Compatibility Ideographs
        (rune >= 0xFE10 && rune <= 0xFE19) || // Vertical forms
        (rune >= 0xFE30 && rune <= 0xFE6F) || // CJK Compatibility Forms
        (rune >= 0xFF00 && rune <= 0xFF60) || // Fullwidth Forms
        (rune >= 0xFFE0 && rune <= 0xFFE6) || // Fullwidth symbol variants
        (rune >= 0x1F300 &&
            rune <= 0x1FAFF); // Emoji blocks (most are 2 cells on printers)
  }

  static String numberFormat(
    num? number, {
    String? symbol,
    int? decimalDigits,
  }) {
    number = number ?? 0;
    final currency = LocalStorage.getSelectedCurrency();
    if (currency.position == "before") {
      return NumberFormat.currency(
        customPattern: '\u00a4 #,###.#',
        symbol: (symbol ?? currency.symbol ?? ''),
        decimalDigits: decimalDigits ?? (number > 99999 ? 0 : 2),
      ).format(number);
    } else {
      return NumberFormat.currency(
        customPattern: '#,###.# \u00a4',
        symbol: (symbol ?? currency.symbol ?? ''),
        decimalDigits: decimalDigits ?? (number > 99999 ? 0 : 2),
      ).format(number);
    }
  }

  static String? getAppPhone() {
    final List<SettingsData> settings = LocalStorage.getSettingsList();
    for (final setting in settings) {
      if (setting.key == 'phone') {
        return setting.value;
      }
    }
    return '';
  }

  static String errorHandler(e) {
    try {
      return (e.runtimeType == DioException)
          ? ((e as DioException).response?.data["message"] == "Bad request."
              ? (e.response?.data["params"] as Map).values.first[0]
              : e.response?.data["message"])
          : e.toString();
    } catch (s) {
      try {
        return (e.runtimeType == DioException)
            ? ((e as DioException).response?.data.toString().substring(
                    (e.response?.data.toString().indexOf("<title>") ?? 0) + 7,
                    e.response?.data.toString().indexOf("</title") ?? 0))
                .toString()
            : e.toString();
      } catch (r) {
        try {
          return (e.runtimeType == DioException)
              ? ((e as DioException).response?.data["error"]["message"])
                  .toString()
              : e.toString();
        } catch (f) {
          return e.toString();
        }
      }
    }
  }

  /// Records a sanitized, non-PII error to Firebase Crashlytics.
  static void recordErrorToCrashlytics({
    required Object error,
    required StackTrace stackTrace,
    required String context,
    bool fatal = false,
  }) {
    try {
      final Object sanitizedError = _sanitizeErrorForCrashlytics(
        error: error,
        context: context,
        label: 'App',
      );

      unawaited(
        FirebaseCrashlytics.instance.recordError(
          sanitizedError,
          stackTrace,
          reason: context,
          fatal: fatal,
        ),
      );
    } catch (_) {}
  }

  /// Records a sanitized, non-PII error to Firebase Crashlytics for sync flows.
  static void recordSyncErrorToCrashlytics({
    required Object error,
    required StackTrace stackTrace,
    required String context,
    bool fatal = false,
  }) {
    try {
      final Object sanitizedError = _sanitizeErrorForCrashlytics(
        error: error,
        context: context,
        label: 'Sync',
      );

      unawaited(
        FirebaseCrashlytics.instance.recordError(
          sanitizedError,
          stackTrace,
          reason: context,
          fatal: fatal,
        ),
      );
    } catch (_) {}
  }

  static Object _sanitizeErrorForCrashlytics({
    required Object error,
    required String context,
    required String label,
  }) {
    if (error is DioException) {
      final int? statusCode = error.response?.statusCode;
      final String method = error.requestOptions.method;
      final String path =
          _sanitizePathForCrashlytics(error.requestOptions.path);
      final String type = error.type.name;
      return Exception(
        '$label error ($context): DioException(type=$type, statusCode=$statusCode, method=$method, path=$path)',
      );
    }

    return Exception('$label error ($context): ${error.runtimeType}');
  }

  static String _sanitizePathForCrashlytics(String path) {
    var sanitized = path.split('?').first;
    sanitized = sanitized.replaceAll(RegExp(r'/\d+'), '/:id');
    sanitized = sanitized.replaceAll(
      RegExp(
        r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
      ),
      ':uuid',
    );
    return sanitized;
  }

  static bool isNumberRequiredToOrder() {
    if (LocalStorage.getSettingsList()
        .any((element) => element.key == "before_order_phone_required")) {
      return LocalStorage.getSettingsList()
              .firstWhere(
                  (element) => element.key == "before_order_phone_required")
              .value ==
          '1';
    }
    return false;
  }

  static bool getAutoPrint() {
    final List<SettingsData> settings = LocalStorage.getSettingsList();
    for (final setting in settings) {
      if (setting.key == 'auto_print_order') {
        return setting.value == "1";
      }
    }
    return false;
  }

  static String? getAppName() {
    final List<SettingsData> settings = LocalStorage.getSettingsList();
    for (final setting in settings) {
      if (setting.key == 'title') {
        return setting.value;
      }
    }
    return '';
  }

  static String? getInitialLocale() {
    final List<SettingsData> settings = LocalStorage.getSettingsList();
    for (final setting in settings) {
      if (setting.key == 'lang') {
        return setting.value;
      }
    }
    return null;
  }

  static String? getDefaultOrderStatus() {
    final List<SettingsData> settings = LocalStorage.getSettingsList();
    for (final setting in settings) {
      if (setting.key == 'default_order_status') {
        return setting.value;
      }
    }
    return null;
  }

  static double? getInitialLatitude() {
    final List<SettingsData> settings = LocalStorage.getSettingsList();
    for (final setting in settings) {
      if (setting.key == 'location') {
        final String? latString =
            setting.value?.substring(0, setting.value?.indexOf(','));
        if (latString == null) {
          return null;
        }
        final double? lat = double.tryParse(latString);
        return lat;
      }
    }
    return null;
  }

  static double? getInitialLongitude() {
    final List<SettingsData> settings = LocalStorage.getSettingsList();
    for (final setting in settings) {
      if (setting.key == 'location') {
        final String? latString =
            setting.value?.substring(0, setting.value?.indexOf(','));
        if (latString == null) {
          return null;
        }
        final String? lonString = setting.value
            ?.substring((latString.length) + 2, setting.value?.length);
        if (lonString == null) {
          return null;
        }
        final double lon = double.parse(lonString);
        return lon;
      }
    }
    return null;
  }

  static void showAlertDialog({
    required BuildContext context,
    required Widget child,
    double radius = 16,
  }) {
    AlertDialog alert = AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(radius.r),
        ),
      ),
      contentPadding: EdgeInsets.all(20.r),
      iconPadding: EdgeInsets.zero,
      content: child,
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }

  static showSnackBar(BuildContext context, String title,
      {bool isIcon = false}) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.clearSnackBars();
    final snackBar = SnackBar(
      backgroundColor: AppStyle.white,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
      margin: EdgeInsets.fromLTRB(MediaQuery.of(context).size.width - 400.w, 0,
          32, MediaQuery.of(context).size.height - 160.h),
      content: Row(
        children: [
          if (isIcon)
            Padding(
              padding: EdgeInsets.only(right: 8.r),
              child: const Icon(
                FlutterRemix.checkbox_circle_fill,
                color: AppStyle.primary,
              ),
            ),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppStyle.black,
              ),
            ),
          ),
        ],
      ),
      action: SnackBarAction(
        label: AppHelpers.getTranslation(TrKeys.close),
        disabledTextColor: AppStyle.black,
        textColor: AppStyle.black,
        onPressed: () {
          try {
            messenger.hideCurrentSnackBar();
          } catch (_) {}
        },
      ),
    );
    try {
      messenger.showSnackBar(snackBar);
    } catch (_) {}
  }

  static String getTranslation(String trKey) {
    final Map<String, dynamic> translations = LocalStorage.getTranslations();
    if (AppConstants.autoTrn) {
      return (translations[trKey] ??
          (trKey.isNotEmpty
              ? trKey.replaceAll(".", " ").replaceAll("_", " ").replaceFirst(
                  trKey.substring(0, 1), trKey.substring(0, 1).toUpperCase())
              : ''));
    } else {
      return translations[trKey] ?? trKey;
    }
  }

  static ExtrasType getExtraTypeByValue(String? value) {
    switch (value) {
      case 'color':
        return ExtrasType.color;
      case 'text':
        return ExtrasType.text;
      case 'image':
        return ExtrasType.image;
      default:
        return ExtrasType.text;
    }
  }

  static DateTime getMinTime(String openTime) {
    final int openHour = int.parse(openTime.substring(3, 5)) == 0
        ? int.parse(openTime.substring(0, 2))
        : int.parse(openTime.substring(0, 2)) + 1;
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day, openHour);
  }

  static DateTime getMaxTime(String closeTime) {
    final int closeHour = int.parse(closeTime.substring(0, 2));
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day, closeHour);
  }

  static String getOrderStatusText(OrderStatus value) {
    switch (value) {
      case OrderStatus.newOrder:
        return "new";
      case OrderStatus.accepted:
        return "accepted";
      case OrderStatus.cooking:
        return "cooking";
      case OrderStatus.ready:
        return "ready";
      case OrderStatus.onAWay:
        return "on_a_way";
      case OrderStatus.delivered:
        return "delivered";
      default:
        return "canceled";
    }
  }

  static OrderStatus getOrderStatus(String? value, {bool? isNextStatus}) {
    if (isNextStatus ?? false) {
      switch (value) {
        case 'new':
          return OrderStatus.accepted;
        case 'accepted':
          return OrderStatus.cooking;
        case 'cooking':
          return OrderStatus.ready;
        case 'ready':
          return OrderStatus.onAWay;
        case 'on_a_way':
          return OrderStatus.delivered;
        default:
          return OrderStatus.canceled;
      }
    } else {
      switch (value) {
        case 'new':
          return OrderStatus.newOrder;
        case 'accepted':
          return OrderStatus.accepted;
        case 'cooking':
          return OrderStatus.cooking;
        case 'ready':
          return OrderStatus.ready;
        case 'on_a_way':
          return OrderStatus.onAWay;
        case 'delivered':
          return OrderStatus.delivered;
        default:
          return OrderStatus.canceled;
      }
    }
  }

  static String getPinCodeText(int index) {
    switch (index) {
      case 0:
        return "1";
      case 1:
        return "2";
      case 2:
        return "3";
      case 3:
        return "4";
      case 4:
        return "5";
      case 5:
        return "6";
      case 6:
        return "7";
      case 7:
        return "8";
      case 8:
        return "9";
      case 10:
        return "0";
      default:
        return "0";
    }
  }

  static Widget getStatusType(String text) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 2.r, horizontal: 10.r),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100.r),
        color: text == "new"
            ? AppStyle.blue
            : text == "accept"
                ? Colors.deepPurple
                : text == "ready"
                    ? AppStyle.rate
                    : AppStyle.primary,
      ),
      child: Text(
        getTranslation(text),
        style: GoogleFonts.inter(
          fontSize: 12.sp,
          color: AppStyle.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  static PositionModel fixedTable(int n) {
    int top = 0;
    int left = 0;
    int right = 0;
    int bottom = 0;
    if (n == 1) {
      top = 1;
    } else if (n == 2) {
      top = 1;
      bottom = 1;
    } else if (n == 3) {
      top = 1;
      bottom = 1;
      left = 1;
    } else if (n == 4) {
      top = 1;
      bottom = 1;
      left = 1;
      right = 1;
    } else if (n > 4 && n <= 10) {
      top = ((n - 2) / 2).ceil();
      bottom = ((n - 2) / 2).floor();
      left = 1;
      right = 1;
    } else if (n > 10) {
      top = ((n - 4) / 2).ceil();
      bottom = ((n - 4) / 2).floor();
      left = 2;
      right = 2;
    }

    return PositionModel(top: top, left: left, right: right, bottom: bottom);
  }

  static Color getStatusColor(String? value) {
    switch (value) {
      case 'pending':
        return AppStyle.pendingDark;
      case 'new':
        return AppStyle.blueColor;
      case 'accepted':
        return AppStyle.deepPurple;
      case 'ready':
      case 'progress':
        return AppStyle.revenueColor;
      case 'on_a_way':
        return AppStyle.black;
      case 'unpublished':
      case 'cooking':
        return AppStyle.orange;
      case 'published':
      case 'active':
      case 'true':
      case 'delivered':
      case 'cash':
      case 'paid':
      case 'approved':
        return AppStyle.green;
      case 'inactive':
      case 'false':
      case 'null':
      case 'canceled':
      case 'cancel':
        return AppStyle.red;
      default:
        return AppStyle.primary;
    }
  }

  static String getNextOrderStatus(String value) {
    switch (value) {
      case "new":
        return "accepted";
      case "accepted":
        return "cooking";
      case "cooking":
        return "ready";
      case "ready":
        return "ended";
      default:
        return "canceled";
    }
  }

  static void debugPrintFormatted(dynamic data) {
    const int chunkSize = 4000; // safe for Android logcat limits
    String message = '';

    try {
      if (data == null) {
        message = 'null';
      } else if (data is String) {
        message = data;
      } else {
        dynamic payload;
        // Try common model serialization methods
        try {
          payload = (data as dynamic).toRawJson();
        } catch (_) {
          try {
            payload = (data as dynamic).toJson();
          } catch (_) {
            payload = null;
          }
        }

        if (payload == null) {
          // fallback: if object is Map/List, use it; otherwise stringify
          if (data is Map || data is List) {
            message = const JsonEncoder.withIndent('  ').convert(data);
          } else {
            message = data.toString();
          }
        } else if (payload is String) {
          final trimmed = payload.trim();
          if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
            try {
              final decoded = jsonDecode(trimmed);
              message = const JsonEncoder.withIndent('  ').convert(decoded);
            } catch (_) {
              message = payload;
            }
          } else {
            // try to encode then pretty print
            try {
              final encoded = jsonEncode(payload);
              final decoded = jsonDecode(encoded);
              message = const JsonEncoder.withIndent('  ').convert(decoded);
            } catch (_) {
              message = payload.toString();
            }
          }
        } else if (payload is Map || payload is List) {
          message = const JsonEncoder.withIndent('  ').convert(payload);
        } else {
          message = payload.toString();
        }
      }
    } catch (_) {
      try {
        message = data.toString();
      } catch (_) {
        message = '<unprintable object>';
      }
    }

    final header =
        '╔═ DEBUG ${DateTime.now().toIso8601String()} ═════════════════════════════════════════';
    debugPrint(header);

    final lines = message.split('\n');
    for (final line in lines) {
      if (line.isEmpty) {
        debugPrint('');
        continue;
      }
      for (int i = 0; i < line.length; i += chunkSize) {
        final endIndex =
            (i + chunkSize < line.length) ? i + chunkSize : line.length;
        debugPrint(line.substring(i, endIndex));
      }
    }

    debugPrint(
        '╚════════════════════════════════════════════════════════════════════════════');
  }
}
