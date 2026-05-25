import 'package:admin_desktop/src/core/constants/hive_boxes.dart';
import 'package:admin_desktop/src/core/db/hive_service.dart';
import 'package:admin_desktop/src/models/data/product_data.dart';
import 'package:flutter/foundation.dart';

/// Validates addon quantities in cart against Hive stock.
/// Returns null if OK, or an error string describing the shortfall.
class AddonStockValidatorHook {
  const AddonStockValidatorHook();

  Future<String?> validate(List<ProductData> stocks) async {
    try {
      final box = await HiveService.openBox(HiveBoxes.products);

      // 1. Aggregate requested addon quantities and names from cart
      final Map<int, num> requestedAddons = {};
      final Map<int, String> addonNames = {};

      for (final s in stocks) {
        for (final addon in (s.addons ?? [])) {
          final id = addon.stockId;
          if (id != null) {
            requestedAddons[id] =
                (requestedAddons[id] ?? 0) + (addon.quantity ?? 0);
            addonNames[id] =
                addon.product?.translation?.title ?? 'Addon ($id)';
          }
        }
      }

      if (requestedAddons.isEmpty) return null;

      // 2. Scan Hive for available stock per countable_id
      final Map<int, num> availableStock = {};
      final Set<int> processedStockIds = {};

      for (final value in box.values) {
        if (value is! Map) continue;
        final productMap = Map<String, dynamic>.from(value);

        void checkStock(Map? stock) {
          if (stock == null) return;
          final sId = _num(stock['id'])?.toInt();
          if (sId != null && !processedStockIds.add(sId)) return;
          final cId = _num(stock['countable_id'])?.toInt();
          if (cId != null && requestedAddons.containsKey(cId)) {
            availableStock[cId] =
                (availableStock[cId] ?? 0) + (_num(stock['quantity']) ?? 0);
          }
          if (stock['addons'] is List) {
            for (final a in stock['addons']) {
              if (a is Map) {
                checkStock(a['stock'] ??
                    (a['product'] is Map ? a['product']['stock'] : null));
              }
            }
          }
        }

        checkStock(productMap['stock']);
        if (productMap['addons'] is List) {
          for (final a in productMap['addons']) {
            if (a is Map) {
              checkStock(a['stock'] ??
                  (a['product'] is Map ? a['product']['stock'] : null));
            }
          }
        }
        if (productMap['stocks'] is List) {
          for (final s in productMap['stocks']) {
            if (s is Map) checkStock(s);
          }
        }
      }

      // 3. Compare and collect errors
      final List<String> errors = [];
      final List<MapEntry<int, num>> entries = requestedAddons.entries.toList();
      for (int i = 0; i < entries.length; i++) {
        final id = entries[i].key;
        final requested = entries[i].value;
        final available = availableStock[id] ?? 0;
        if (requested > available) {
          final name = addonNames[id] ?? 'Addon ($id)';
          errors.add('$name (Request: $requested, Available: $available)');
        }
      }

      return errors.isNotEmpty
          ? 'Insufficient addon stock:\n${errors.join('\n')}'
          : null;
    } catch (e) {
      debugPrint('AddonStockValidatorHook error: $e');
      return null;
    }
  }

  num? _num(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v);
    return null;
  }
}
