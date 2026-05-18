import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReceiptHelper {
  static const _receiptCounterKey = "receipt_counter";

  // Providers/callbacks can be set to return dynamic values (sync/async)
  static FutureOr<String> Function()? posProvider;
  static FutureOr<String> Function()? outletProvider;
  static FutureOr<String> Function()? terminalProvider;
  static FutureOr<String> Function()? cshProvider;

  static void setPosProvider(FutureOr<String> Function() provider) {
    posProvider = provider;
  }

  static void setOutletProvider(FutureOr<String> Function() provider) {
    outletProvider = provider;
  }

  static void setTerminalProvider(FutureOr<String> Function() provider) {
    terminalProvider = provider;
  }

  static void setCshProvider(FutureOr<String> Function() provider) {
    cshProvider = provider;
  }

  /// Generates a unique receipt ID and stores increment locally
  static Future<String> generateReceiptId() async {
    final prefs = await SharedPreferences.getInstance();

    // Get the last counter value from local storage
    int counter = prefs.getInt(_receiptCounterKey) ?? 1;

    // Resolve providers (allow sync or Future)
    FutureOr<String> resolve(FutureOr<String> Function()? p, String fallback) {
      if (p == null) return fallback;
      try {
        final r = p();
        return r;
      } catch (e) {
        return fallback;
      }
    }

    final posVal = await Future.value(resolve(posProvider, "POS"));
    final outletVal = await Future.value(resolve(outletProvider, "OUTLET"));
    final terminalVal = await Future.value(resolve(terminalProvider, "TERM"));
    final cshVal = await Future.value(resolve(cshProvider, "CSH"));

    // Pad counter to 9 digits
    final increment = counter.toString().padLeft(9, '0');

    // Save the next counter value back to local storage
    await prefs.setInt(_receiptCounterKey, counter + 1);

    final id = "$posVal-$outletVal-$terminalVal-$cshVal$increment";
    // Debug: log provider values and generated id
    try {
      debugPrint(
          'ReceiptHelper.generateReceiptId -> pos:$posVal outlet:$outletVal terminal:$terminalVal csh:$cshVal counter:$increment id:$id');
    } catch (_) {}

    return id;
  }
}
