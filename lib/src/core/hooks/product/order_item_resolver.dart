import 'package:admin_desktop/src/repository/products_repository.dart';

/// Resolves a product detail map from the repository (UUID path or stockId path).
/// Also provides service-type matching for a given order type.
class OrderItemResolver {
  final ProductsRepository apiRepo;

  OrderItemResolver({required this.apiRepo});

  /// Fetches product details map. Tries UUID first, then stockId fallback.
  /// Returns null when neither resolves.
  Future<Map<String, dynamic>?> resolveProduct({
    String? uuid,
    int? stockId,
  }) async {
    if (uuid != null) {
      Map<String, dynamic>? result;
      final res = await apiRepo.getProductByUuid(uuid);
      res.when(success: (d) => result = d, failure: (_, __) {});
      return result;
    }
    if (stockId != null) {
      Map<String, dynamic>? result;
      final res = await apiRepo.getProductByStockId(stockId);
      res.when(success: (d) => result = d, failure: (_, __) {});
      return result;
    }
    return null;
  }

  /// Finds the service_type entry inside [productMap['category']['service_types']]
  /// that matches [orderTypeLower]. Returns null if no match.
  Map<String, dynamic>? matchServiceType(
    Map<String, dynamic> productMap,
    String orderTypeLower,
  ) {
    final List serviceTypes =
        (productMap['category'] as Map?)?['service_types'] ?? [];
    try {
      final match = serviceTypes.firstWhere(
        (st) {
          final name = (st['name'] as String? ?? '').toLowerCase();
          return orderTypeMatchesServiceName(orderTypeLower, name);
        },
        orElse: () => null,
      );
      return match != null ? Map<String, dynamic>.from(match as Map) : null;
    } catch (_) {
      return null;
    }
  }

  /// Order-type → service-name matching rules (5 conditions).
  static bool orderTypeMatchesServiceName(
    String orderTypeLower,
    String serviceName,
  ) {
    if (orderTypeLower == 'dine_in' && serviceName.contains('dine')) {
      return true;
    }
    if (orderTypeLower == 'pickup' &&
        (serviceName.contains('take') || serviceName.contains('away'))) {
      return true;
    }
    if (orderTypeLower == 'delivery' && serviceName.contains('delivery')) {
      return true;
    }
    if (orderTypeLower == 'grab_food' && serviceName.contains('grab')) {
      return true;
    }
    if (orderTypeLower == 'food_panda' && serviceName.contains('panda')) {
      return true;
    }
    return false;
  }
}
