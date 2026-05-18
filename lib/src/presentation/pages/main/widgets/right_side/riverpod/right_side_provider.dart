import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:admin_desktop/src/models/models.dart';
import 'right_side_notifier.dart';
import 'right_side_state.dart';

final rightSideProvider =
    StateNotifierProvider<RightSideNotifier, RightSideState>(
  (ref) => RightSideNotifier(ref),
);

/// ---------- NEW: Filter state ----------

/// Provider to hold the list of available pricing tiers
final pricingTiersProvider =
    StateProvider<List<ProductPricingTier>>((ref) => []);

/// Selected pricing tier (null = no filter)
final selectedPricingTierProvider =
    StateProvider<ProductPricingTier?>((ref) => null);

/// Convenience combined filters (optional)
final currentFiltersProvider =
    Provider<({ProductPricingTier? pricingTier})>((ref) {
  final pricing = ref.watch(selectedPricingTierProvider);
  return (pricingTier: pricing);
});
