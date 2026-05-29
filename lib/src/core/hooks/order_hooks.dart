import 'package:admin_desktop/src/core/di/injection.dart';
import 'package:admin_desktop/src/core/hooks/calculation/order_calculation_hook.dart';
import 'package:admin_desktop/src/core/hooks/product/enhanced_product_hook.dart';
import 'package:admin_desktop/src/core/hooks/stock/addon_stock_validator_hook.dart';
import 'package:admin_desktop/src/repository/products_repository.dart';

export 'calculation/order_calculation_hook.dart' show OrderCalculationResult;
export 'product/enhanced_product_hook.dart';
export 'stock/addon_stock_validator_hook.dart';

/// Facade that exposes all order-calculation sub-hooks from a single entry point.
///
/// Usage:
/// ```dart
/// final hooks = OrderHooks();
/// final result = await hooks.calculation.calculate(...);
/// final enhanced = hooks.enhancedProduct.build(...);
/// final error = await hooks.addonValidator.validate(...);
/// ```
class OrderHooks {
  late final OrderCalculationHook calculation;
  late final EnhancedProductHook enhancedProduct;
  late final AddonStockValidatorHook addonValidator;

  OrderHooks() {
    final repo = inject<ProductsRepository>();
    calculation = OrderCalculationHook(apiRepo: repo, hiveRepo: repo);
    enhancedProduct = const EnhancedProductHook();
    addonValidator = const AddonStockValidatorHook();
  }
}
