// 'app_helpers.dart' functions are available via utils.dart import below
import 'package:admin_desktop/src/presentation/components/buttons/animation_button_effect.dart';
import 'package:admin_desktop/src/presentation/components/list_items/product_bag_item.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/right_side/note_dialog.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/right_side/order_information.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/right_side/riverpod/right_side_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_remix/flutter_remix.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../../generated/assets.dart';
import '../../../../../core/constants/constants.dart';
import '../../../../../core/di/dependency_manager.dart';
import '../../../../../core/di/injection.dart';
import '../../../../../core/utils/utils.dart';
import '../../../../../models/models.dart';
import '../../../../../repository/products_repository.dart';
import '../../../../components/components.dart';
import '../../../../theme/theme.dart';
import 'riverpod/right_side_provider.dart';
import '../../riverpod/provider/main_provider.dart';
import '../tables/riverpod/tables_provider.dart';
import '../../../../../core/hooks/order_hooks.dart';

class PageViewItem extends ConsumerStatefulWidget {
  final BagData bag;

  const PageViewItem({super.key, required this.bag});

  @override
  ConsumerState<PageViewItem> createState() => _PageViewItemState();
}

class _PageViewItemState extends ConsumerState<PageViewItem> {
  late TextEditingController coupon;
  // bill-level discount settings
  bool _billDiscountsLoading = false;
  bool _isOrdering = false;
  List<DiscountSetting> _billDiscounts = [];
  TextEditingController? _manualBillDiscountController;
  // store per-item discount selection keyed by stable product identifier (stockId/countableId/product id)
  final Map<String, String> _itemDiscounts = {};
  // cache discounts fetched by uuid on-demand to avoid snapshot persistence
  final Map<String, DiscountSetting?> _discountCache = {};
  final Set<String> _discountLoading = {};

  bool _productMatches(ProductData a, ProductData? b) {
    if (b == null) return false;
    final leftIds = <dynamic>[
      a.id,
      a.stock?.id,
      a.stock?.countableId,
      a.uuid,
      a.stock?.product?.uuid
    ];
    final rightIds = <dynamic>[
      b.id,
      b.stock?.id,
      b.stock?.countableId,
      b.uuid,
      b.stock?.product?.uuid
    ];
    for (final l in leftIds) {
      if (l == null) continue;
      for (final r in rightIds) {
        if (r == null) continue;
        if (l.toString() == r.toString()) return true;
      }
    }
    return false;
  }

  // produce a stable key for a product using any available stable ids (uuid, stock product uuid, stock id, countableId, id)
  String _productKey(ProductData? prod, int index) {
    final a = prod?.uuid;
    final b = prod?.stock?.product?.uuid;
    final c = prod?.stock?.id?.toString();
    final d = prod?.stock?.countableId?.toString();
    final e = prod?.id?.toString();
    // prefer uuid, then product uuid, then numeric ids as strings
    return a ?? b ?? c ?? d ?? e ?? index.toString();
  }

  // prefer a bag-product-based key (from BagProductData) which remains stable across server
  // recalculations. If bagProducts doesn't have an entry for index, fall back to _productKey.
  String _bagProductKey(
      List<BagProductData>? bagProducts, ProductData? prod, int index) {
    try {
      if (bagProducts != null && bagProducts.isNotEmpty) {
        // try to find a bag product that matches this product by stockId or parentId
        for (var i = 0; i < bagProducts.length; i++) {
          final bp = bagProducts[i];
          final bpStock = bp.stockId;
          final bpParent = bp.parentId;
          final prodStockId = prod?.stock?.id;

          if (prodStockId != null) {
            if (bpStock != null && bpStock == prodStockId) {
              final s = bpStock.toString();
              final p = bpParent?.toString();
              return 'bag_stock:$s:parent:${p ?? '0'}';
            }
            if (bpParent != null && bpParent == prodStockId) {
              final s = bpStock?.toString();
              final p = bpParent.toString();
              return 'bag_stock:${s ?? '0'}:parent:$p';
            }
          }
        }
        // If strict matching failed, try the flexible matcher and, if it finds
        // a bag entry, return a bag-based key for that entry so keys remain
        // stable across paginate/category changes.
        try {
          final flexIdx = _findBagProductIndexFlexible(bagProducts, prod);
          if (flexIdx >= 0 && flexIdx < bagProducts.length) {
            final bp = bagProducts[flexIdx];
            final s = bp.stockId?.toString();
            final p = bp.parentId?.toString();
            if (s != null) return 'bag_stock:$s:parent:${p ?? '0'}';
            return 'bag_index:$flexIdx';
          }
        } catch (_) {}
      }
    } catch (e) {
      // ignore and fallback
    }
    return _productKey(prod, index);
  }

  // find the index of a BagProductData matching a ProductData using stable ids
  int _findBagProductIndex(
      List<BagProductData>? bagProducts, ProductData? prod) {
    if (bagProducts == null || prod == null) return -1;

    // Try several id fallbacks to locate the matching BagProductData:
    // priority: stock.id, stock.countableId, product id, then parentId variants
    final prodStockId = prod.stock?.id;
    final prodCountableId = prod.stock?.countableId;
    final prodId = prod.id;

    for (int i = 0; i < bagProducts.length; i++) {
      final bp = bagProducts[i];
      // direct stock match
      if (prodStockId != null && bp.stockId == prodStockId) return i;
      // countable id match
      if (prodCountableId != null && bp.stockId == prodCountableId) return i;
      // product id match
      if (prodId != null && bp.stockId == prodId) return i;
      // parent id could match the stock on product (addons referencing parent)
      if (prodStockId != null && bp.parentId == prodStockId) return i;
      if (prodCountableId != null && bp.parentId == prodCountableId) return i;
      if (prodId != null && bp.parentId == prodId) return i;
    }

    return -1;
  }

  // Flexible matcher: try additional heuristics (product uuid, stock.product.uuid,
  // stringified comparisons and parentId variants) to locate a bag entry when
  // strict numeric id matching fails. This helps when server paginate responses
  // omit some id variants.
  int _findBagProductIndexFlexible(
      List<BagProductData>? bagProducts, ProductData? prod) {
    if (bagProducts == null || prod == null) return -1;

    final prodUuid = prod.uuid?.toString();
    final prodStockUuid = prod.stock?.product?.uuid?.toString();
    final prodStockIdStr = prod.stock?.id?.toString();
    final prodCountableStr = prod.stock?.countableId?.toString();
    final prodIdStr = prod.id?.toString();

    for (int i = 0; i < bagProducts.length; i++) {
      final bp = bagProducts[i];
      // compare by numeric ids first (if present)
      if (bp.stockId != null) {
        final s = bp.stockId.toString();
        if (s == prodStockIdStr || s == prodCountableStr || s == prodIdStr) {
          return i;
        }
      }
      // compare parent id
      if (bp.parentId != null) {
        final p = bp.parentId.toString();
        if (p == prodStockIdStr || p == prodCountableStr || p == prodIdStr) {
          return i;
        }
      }
      // compare uuids
      // no-op: deep nested cart uuid checks omitted to keep matcher cheap
      // Compare stringified identifiers in a best-effort way
      try {
        final bpStockStr = bp.stockId?.toString() ?? '';
        final bpParentStr = bp.parentId?.toString() ?? '';
        if (bpStockStr.isNotEmpty &&
            (bpStockStr == prodUuid || bpStockStr == prodStockUuid)) {
          return i;
        }
        if (bpParentStr.isNotEmpty &&
            (bpParentStr == prodUuid || bpParentStr == prodStockUuid)) {
          return i;
        }
      } catch (_) {}
    }
    return -1;
  }

  @override
  void initState() {
    super.initState();
    coupon = TextEditingController();
    _manualBillDiscountController = TextEditingController();
    _manualBillDiscountController?.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (!mounted) return;
      ref
          .read(rightSideProvider.notifier)
          .setInitialBagData(context, widget.bag);
      _fetchBillDiscounts();
    });
  }

  @override
  void dispose() {
    coupon.dispose();
    _manualBillDiscountController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(rightSideProvider.notifier);
    final state = ref.watch(rightSideProvider);
    final mainState = ref.watch(mainProvider);
    // Keep the manual bill discount TextField in sync with the currently
    // selected bag's custom discount (if any). If the bag has a non-preset
    // selectedBillDiscount we show its numeric value in the controller so the
    // manual amount is bag-scoped instead of global.
    try {
      final bagDiscount =
          state.bags[state.selectedBagIndex].selectedBillDiscount;
      final isPreset = findMatchingDiscount(bagDiscount) != null;
      final String newText =
          (bagDiscount != null && !isPreset && (bagDiscount.value != null))
              ? bagDiscount.value.toString()
              : '';
      if ((_manualBillDiscountController?.text ?? '') != newText) {
        // update controller text without causing additional setState here;
        // the controller listener will update visuals as needed.
        _manualBillDiscountController?.text = newText;
      }
    } catch (_) {}
    // Reconcile _itemDiscounts with current products in the bag and persisted bag entries.
    // Do NOT prune discounts simply because a product is not visible in the current paginate page
    // (that was causing discounts to disappear when switching categories). Instead keep keys for
    // both visible products and persisted bag products and remove only keys that no longer map
    // to any bag product or visible product.
    try {
      final currentStocks = state.paginateResponse?.stocks ?? [];
      final bagProducts = state.bags[state.selectedBagIndex].bagProducts ?? [];

      // Build the set of valid keys: keys for current stocks + keys for persisted bagProducts
      final validKeys = <String>{};
      for (var i = 0; i < currentStocks.length; i++) {
        final prod = currentStocks[i];
        validKeys.add(_bagProductKey(bagProducts, prod, i));
      }

      // helper: stable key for a bag product entry independent of currentStocks ordering
      String keyForBagProduct(BagProductData bp, int idx) {
        final s = bp.stockId?.toString();
        final p = bp.parentId?.toString();
        if (s != null) return 'bag_stock:$s:parent:${p ?? '0'}';
        // fallback: use bag-index style key to avoid collisions
        return 'bag_index:$idx';
      }

      for (var i = 0; i < bagProducts.length; i++) {
        validKeys.add(keyForBagProduct(bagProducts[i], i));
      }

      // Remove only keys that don't belong to either visible stocks or persisted bag entries
      _itemDiscounts.removeWhere((k, v) => !validKeys.contains(k));

      // seed in-memory map from persisted bagProducts.selectedDiscount so price calc uses same values
      try {
        for (var i = 0; i < bagProducts.length; i++) {
          final bp = bagProducts[i];
          final sd = bp.selectedDiscount;
          final k = keyForBagProduct(bp, i);
          if (sd != null && sd.isNotEmpty) {
            _itemDiscounts[k] = sd; // persist selection in memory
          } else {
            _itemDiscounts.remove(k); // Clear if no discount
          }
        }
      } catch (e) {
        // ignore
      }
    } catch (e) {
      // keep existing map if anything unexpected happens
    }
    return AbsorbPointer(
      // keep absorbing for major blocking loads but allow interactions during product calculate
      absorbing: state.isUserDetailsLoading ||
          state.isPaymentsLoading ||
          state.isBagsLoading ||
          state.isUsersLoading ||
          state.isCurrenciesLoading,
      child: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10.r),
                    color: AppStyle.white,
                  ),
                  child: (state.paginateResponse?.stocks?.isNotEmpty ?? false)
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: EdgeInsets.only(
                                top: 8.r,
                                right: 24.r,
                                left: 24.r,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    AppHelpers.getTranslation(TrKeys.products),
                                    style: GoogleFonts.inter(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w500),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      notifier.clearBag();
                                    },
                                    child: Padding(
                                      padding: EdgeInsets.all(8.r),
                                      child: const Icon(
                                        FlutterRemix.delete_bin_line,
                                        color: AppStyle.red,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount:
                                  state.paginateResponse?.stocks?.length ?? 0,
                              itemBuilder: (context, index) {
                                final prod =
                                    state.paginateResponse?.stocks?[index];
                                final keyId = _bagProductKey(
                                    state.bags[state.selectedBagIndex]
                                        .bagProducts,
                                    prod,
                                    index);
                                // prefer persisted selection stored on BagProductData (matched by id), then local map, then default
                                final bagProducts = state
                                    .bags[state.selectedBagIndex].bagProducts;
                                int matchedIndex =
                                    _findBagProductIndex(bagProducts, prod);
                                // Fallback to flexible matcher if strict match failed
                                if (!(matchedIndex >= 0 &&
                                    matchedIndex <
                                        (bagProducts?.length ?? 0))) {
                                  matchedIndex = _findBagProductIndexFlexible(
                                      bagProducts, prod);
                                }
                                String persisted = '';
                                try {
                                  if (matchedIndex >= 0) {
                                    persisted = bagProducts?[matchedIndex]
                                            .selectedDiscount ??
                                        '';
                                  }
                                } catch (e) {
                                  persisted = '';
                                }
                                final selected = persisted.isNotEmpty
                                    ? persisted
                                    : (_itemDiscounts[keyId] ?? 'default');

                                // compute discountSetting for this product
                                // instead of persisting snapshots we fetch discountSetting
                                // on-demand by product UUID (non-blocking) and cache results
                                DiscountSetting? itemDiscountSetting;
                                try {
                                  final prodUuid =
                                      prod?.stock?.product?.uuid ?? prod?.uuid;
                                  // if we have a cached value, use it
                                  if (prodUuid != null &&
                                      _discountCache.containsKey(prodUuid)) {
                                    itemDiscountSetting =
                                        _discountCache[prodUuid];
                                  }

                                  // fallback to category info present on the product payload
                                  itemDiscountSetting ??=
                                      prod?.category?.discountSetting ??
                                          prod?.stock?.product?.category
                                              ?.discountSetting;

                                  // as an inexpensive sync fallback, try to read from mainState products
                                  if (itemDiscountSetting == null) {
                                    try {
                                      final match = mainState.products
                                          .firstWhere(
                                              (p) => _productMatches(p, prod),
                                              orElse: () => ProductData());
                                      itemDiscountSetting =
                                          match.category?.discountSetting ??
                                              match.stock?.product?.category
                                                  ?.discountSetting;
                                    } catch (_) {}
                                  }

                                  // If still unknown, fetch product by uuid in background and cache it.
                                  if (itemDiscountSetting == null &&
                                      prodUuid != null &&
                                      !_discountLoading.contains(prodUuid)) {
                                    _discountLoading.add(prodUuid);
                                    final repo = inject<ProductsRepository>();
                                    repo.getProductByUuid(prodUuid).then((res) {
                                      res.when(
                                        success: (data) {
                                          final Map<String, dynamic> pd = data;
                                          // parse DiscountSetting from the returned payload if present
                                          DiscountSetting? ds;
                                          try {
                                            // helper to map nested payload into model objects
                                            // The repository returns the raw product JSON under the Map
                                            // We can attempt to construct a ProductData if necessary
                                            // but for safety extract nested category discount fields if present
                                            final cat = pd['category'];
                                            if (cat is Map<String, dynamic>) {
                                              final rawDs =
                                                  cat['discount_setting'] ??
                                                      cat['discountSetting'];
                                              if (rawDs
                                                  is Map<String, dynamic>) {
                                                ds = DiscountSetting.fromJson(
                                                    rawDs);
                                              }
                                            }
                                            if (ds == null &&
                                                pd['stock'] is Map) {
                                              final stock = pd['stock']
                                                  as Map<String, dynamic>;
                                              final product = stock['product'];
                                              if (product
                                                  is Map<String, dynamic>) {
                                                final cat2 =
                                                    product['category'];
                                                if (cat2
                                                    is Map<String, dynamic>) {
                                                  final rawDs = cat2[
                                                          'discount_setting'] ??
                                                      cat2['discountSetting'];
                                                  if (rawDs
                                                      is Map<String, dynamic>) {
                                                    ds = DiscountSetting
                                                        .fromJson(rawDs);
                                                  }
                                                }
                                              }
                                            }
                                          } catch (_) {}
                                          if (mounted) {
                                            setState(() {
                                              _discountCache[prodUuid] = ds;
                                            });
                                          }
                                        },
                                        failure: (f, s) {
                                          if (mounted) {
                                            setState(() {
                                              _discountCache[prodUuid] = null;
                                            });
                                          }
                                        },
                                      );
                                    }).whenComplete(() {
                                      _discountLoading.remove(prodUuid);
                                    });
                                  }
                                } catch (e) {
                                  // ignore unexpected errors and leave itemDiscountSetting null
                                }

                                return CartOrderItem(
                                  symbol: widget.bag.selectedCurrency?.symbol,
                                  add: () {
                                    notifier.increaseProductCount(
                                        productIndex: index);
                                  },
                                  remove: () {
                                    notifier.decreaseProductCount(
                                        productIndex: index);
                                  },
                                  cart:
                                      state.paginateResponse?.stocks?[index] ??
                                          ProductData(),
                                  delete: () {
                                    notifier.deleteProductCount(
                                      bagProductData: state
                                          .bags[state.selectedBagIndex]
                                          .bagProducts?[index],
                                      productIndex: index,
                                    );
                                  },
                                  discountSelection: selected,
                                  externalDiscountSetting: itemDiscountSetting,
                                  onDiscountChanged: (val) {
                                    // Local UI state updated synchronously
                                    if (mounted) {
                                      setState(() {
                                        final newVal = val ?? 'default';
                                        _itemDiscounts[keyId] = newVal;
                                      });
                                    }

                                    // Persist selection into LocalStorage and update provider state
                                    try {
                                      final List<BagData> bags =
                                          List<BagData>.from(state.bags);
                                      final List<BagProductData> bpList =
                                          List<BagProductData>.from(
                                              bags[state.selectedBagIndex]
                                                      .bagProducts ??
                                                  []);
                                      final matchIdx =
                                          _findBagProductIndex(bpList, prod);
                                      int effectiveMatchIdx = matchIdx;
                                      if (!(matchIdx >= 0 &&
                                          matchIdx < bpList.length)) {
                                        // Try a flexible match as a fallback
                                        effectiveMatchIdx =
                                            _findBagProductIndexFlexible(
                                                bpList, prod);
                                      }
                                      if (effectiveMatchIdx >= 0 &&
                                          effectiveMatchIdx < bpList.length) {
                                        final bp = bpList[effectiveMatchIdx];
                                        // Persist only the selectedDiscount string.
                                        // Do NOT persist the DiscountSetting snapshot here;
                                        // we will fetch discountSetting on-demand when needed.
                                        final updated = bp.copyWith(
                                          selectedDiscount:
                                              _itemDiscounts[keyId],
                                        );
                                        bpList.removeAt(effectiveMatchIdx);
                                        bpList.insert(
                                            effectiveMatchIdx, updated);
                                        bags[state.selectedBagIndex] =
                                            bags[state.selectedBagIndex]
                                                .copyWith(bagProducts: bpList);
                                        // Use notifier.updateBags to persist and update state
                                        try {
                                          ref
                                              .read(rightSideProvider.notifier)
                                              .updateBags(bags);
                                        } catch (e) {
                                          // fallback to direct local persist if notifier unavailable
                                          LocalStorage.setBags(bags);
                                        }
                                      }
                                    } catch (e) {
                                      // ignore persistence failures
                                    }
                                  },
                                );
                              },
                            ),
                            8.verticalSpace,
                            Column(
                              children: [
                                Padding(
                                  padding:
                                      REdgeInsets.symmetric(horizontal: 20),
                                  child: Row(
                                    children: [
                                      Text(
                                        AppHelpers.getTranslation(TrKeys.add),
                                        style: GoogleFonts.inter(
                                            color: AppStyle.black,
                                            fontSize: 14.sp),
                                      ),
                                      const Spacer(),
                                      // InkWell(
                                      //   onTap: () {
                                      //     AppHelpers.showAlertDialog(
                                      //         context: context,
                                      //         child: const PromoCodeDialog());
                                      //   },
                                      //   child: AnimationButtonEffect(
                                      //     child: Container(
                                      //       padding: EdgeInsets.symmetric(
                                      //           vertical: 10.r,
                                      //           horizontal: 18.r),
                                      //       decoration: BoxDecoration(
                                      //           color: AppStyle.addButtonColor,
                                      //           borderRadius:
                                      //               BorderRadius.circular(
                                      //                   10.r)),
                                      //       child: Text(
                                      //         AppHelpers.getTranslation(
                                      //             TrKeys.promoCode),
                                      //         style: GoogleFonts.inter(
                                      //             fontSize: 14.sp),
                                      //       ),
                                      //     ),
                                      //   ),
                                      // ),
                                      26.horizontalSpace,
                                      InkWell(
                                        onTap: () {
                                          AppHelpers.showAlertDialog(
                                              context: context,
                                              child: const NoteDialog());
                                        },
                                        child: AnimationButtonEffect(
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                                vertical: 10.r,
                                                horizontal: 18.r),
                                            decoration: BoxDecoration(
                                                color: AppStyle.addButtonColor,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        10.r)),
                                            child: Text(
                                              AppHelpers.getTranslation(
                                                  TrKeys.note),
                                              style: GoogleFonts.inter(
                                                  fontSize: 14.sp),
                                            ),
                                          ),
                                        ),
                                      ),
                                      12.horizontalSpace,
                                    ],
                                  ),
                                ),
                                8.verticalSpace,
                                const Divider(),
                                8.verticalSpace,
                                // bill-level discount row
                                Padding(
                                  padding:
                                      REdgeInsets.symmetric(horizontal: 20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            AppHelpers.getTranslation(
                                                'Bill discount'),
                                            style: GoogleFonts.inter(
                                                fontSize: 14.sp,
                                                color: AppStyle.black),
                                          ),
                                          12.horizontalSpace,
                                          Expanded(
                                            child: Align(
                                              alignment: Alignment.centerRight,
                                              child: _billDiscountsLoading
                                                  ? SizedBox(
                                                      width: 160.r,
                                                      height: 40.r,
                                                      child: Center(
                                                          child: SizedBox(
                                                              width: 16.r,
                                                              height: 16.r,
                                                              child: CircularProgressIndicator(
                                                                  strokeWidth:
                                                                      2.r))),
                                                    )
                                                  : Container(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                              horizontal: 8.r),
                                                      decoration: BoxDecoration(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      8.r),
                                                          border: Border.all(
                                                              color: AppStyle
                                                                  .border
                                                                  .withOpacity(
                                                                      0.6))),
                                                      child: DropdownButton<
                                                          DiscountSetting?>(
                                                        underline:
                                                            const SizedBox
                                                                .shrink(),
                                                        value: findMatchingDiscount(state
                                                            .bags[state
                                                                .selectedBagIndex]
                                                            .selectedBillDiscount),
                                                        hint: Text(
                                                            AppHelpers
                                                                .getTranslation(
                                                                    'Bill discount'),
                                                            style: GoogleFonts
                                                                .inter(
                                                                    fontSize:
                                                                        14.sp)),
                                                        items: [
                                                          DropdownMenuItem<
                                                              DiscountSetting?>(
                                                            value: null,
                                                            child: Text(
                                                                AppHelpers
                                                                    .getTranslation(
                                                                        'Custom'),
                                                                style: GoogleFonts
                                                                    .inter(
                                                                        fontSize:
                                                                            14.sp)),
                                                          ),
                                                          ..._billDiscounts.map((e) => DropdownMenuItem<
                                                                  DiscountSetting?>(
                                                              value: e,
                                                              child: Text(
                                                                  '${e.id ?? ''} - ${e.title ?? ''}',
                                                                  style: GoogleFonts.inter(
                                                                      fontSize:
                                                                          14.sp))))
                                                        ],
                                                        onChanged: (val) {
                                                          ref
                                                              .read(
                                                                  rightSideProvider
                                                                      .notifier)
                                                              .setSelectedBillDiscount(
                                                                  val);
                                                        },
                                                      ),
                                                    ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      // Custom input on second line if Custom is selected
                                      if (findMatchingDiscount(state
                                              .bags[state.selectedBagIndex]
                                              .selectedBillDiscount) ==
                                          null)
                                        Padding(
                                          padding: EdgeInsets.only(
                                              top: 8.r, left: 0, right: 0),
                                          child: Row(
                                            children: [
                                              Expanded(child: SizedBox()),
                                              if ((widget.bag.selectedCurrency
                                                          ?.symbol ??
                                                      LocalStorage
                                                              .getSelectedCurrency()
                                                          .symbol) !=
                                                  null) ...[
                                                Padding(
                                                  padding: EdgeInsets.only(
                                                      right: 4.r),
                                                  child: Text(
                                                    (widget.bag.selectedCurrency
                                                            ?.symbol ??
                                                        LocalStorage
                                                                .getSelectedCurrency()
                                                            .symbol)!,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 14.sp,
                                                      color: AppStyle.black,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                              SizedBox(
                                                width: 120.r,
                                                height: 36.r,
                                                child: TextField(
                                                  controller:
                                                      _manualBillDiscountController,
                                                  keyboardType:
                                                      const TextInputType
                                                          .numberWithOptions(
                                                          decimal: true),
                                                  inputFormatters: [
                                                    FilteringTextInputFormatter
                                                        .allow(RegExp(
                                                            r'[0-9\.,]')),
                                                  ],
                                                  onChanged: (v) {
                                                    if (mounted) {
                                                      setState(() {});
                                                    }
                                                    final text = v
                                                        .replaceAll(',', '.')
                                                        .trim();
                                                    final parsed =
                                                        num.tryParse(text);
                                                    if (parsed != null &&
                                                        parsed > 0) {
                                                      final custom =
                                                          DiscountSetting(
                                                        id: null,
                                                        title: 'Custom',
                                                        method: 'amount',
                                                        value: parsed,
                                                      );
                                                      ref
                                                          .read(
                                                              rightSideProvider
                                                                  .notifier)
                                                          .setSelectedBillDiscount(
                                                              custom);
                                                    } else {
                                                      final customZero =
                                                          DiscountSetting(
                                                        id: null,
                                                        title: 'Custom',
                                                        method: 'amount',
                                                        value: 0,
                                                      );
                                                      ref
                                                          .read(
                                                              rightSideProvider
                                                                  .notifier)
                                                          .setSelectedBillDiscount(
                                                              customZero);
                                                    }
                                                  },
                                                  decoration: InputDecoration(
                                                    isDense: true,
                                                    contentPadding:
                                                        EdgeInsets.symmetric(
                                                            horizontal: 8.r,
                                                            vertical: 8.r),
                                                    border: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8.r)),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                _price(state),
                              ],
                            ),
                            28.verticalSpace,
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            170.verticalSpace,
                            Container(
                              width: 142.r,
                              height: 142.r,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8.r),
                                color: AppStyle.dontHaveAccBtnBack,
                              ),
                              alignment: Alignment.center,
                              child: Image.asset(
                                Assets.pngNoProducts,
                                width: 87.r,
                                height: 60.r,
                                fit: BoxFit.cover,
                              ),
                            ),
                            14.verticalSpace,
                            Text(
                              '${AppHelpers.getTranslation(TrKeys.thereAreNoItemsInThe)} ${AppHelpers.getTranslation(TrKeys.bag).toLowerCase()}',
                              style: GoogleFonts.inter(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -14 * 0.02,
                                color: AppStyle.black,
                              ),
                            ),
                            SizedBox(height: 170.r, width: double.infinity),
                          ],
                        ),
                ),
                15.verticalSpace,
              ],
            ),
          ),
          BlurLoadingWidget(
            isLoading: state.isUserDetailsLoading ||
                state.isPaymentsLoading ||
                state.isBagsLoading ||
                state.isUsersLoading ||
                state.isCurrenciesLoading ||
                state.isProductCalculateLoading,
          ),
        ],
      ),
    );
  }

  Column _price(RightSideState state) {
    // compute client-side adjusted subtotal based on per-item discount selections
    final mainState = ref.watch(mainProvider);
    final priceData = state.paginateResponse;

    num effectiveSubtotal = 0;
    num originalSubtotal = 0; // sum of item prices before per-item discounts
    final stocks = priceData?.stocks ?? [];
    for (int i = 0; i < stocks.length; i++) {
      final p = stocks[i];
      final keyId =
          _bagProductKey(state.bags[state.selectedBagIndex].bagProducts, p, i);
      // addons
      num addonsTotal = 0;
      for (final e in (p.addons ?? [])) {
        addonsTotal += (e.price ?? 0);
      }
      final num productPrice = (p.stock?.price ?? 0) * (p.quantity ?? 1);
      num base = productPrice + addonsTotal;
      originalSubtotal += productPrice + addonsTotal;

      // prefer category discount setting from calculate response
      // Prefer persisted snapshot on bagProducts if available (user-selected)
      final bagProducts = state.bags[state.selectedBagIndex].bagProducts;
      int bpMatchIdx = _findBagProductIndex(bagProducts, p);
      // fallback to flexible matcher when strict id matching fails
      if (!(bpMatchIdx >= 0 && bpMatchIdx < (bagProducts?.length ?? 0))) {
        bpMatchIdx = _findBagProductIndexFlexible(bagProducts, p);
      }
      DiscountSetting? discountSetting;
      if (bpMatchIdx >= 0) {
        discountSetting = bagProducts?[bpMatchIdx].selectedDiscountSetting;
      }
      // fallback to category discountSetting from calculate response
      discountSetting ??= p.category?.discountSetting ??
          p.stock?.product?.category?.discountSetting;

      // fallback: if calculate response didn't include discountSetting,
      // try to find it from the main product paginate list (UI product list)
      // which is provided by MainNotifier (mainProvider).
      if (discountSetting == null) {
        try {
          final match = mainState.products.firstWhere(
              (prod) => _productMatches(prod, p),
              orElse: () => ProductData());
          discountSetting = match.category?.discountSetting ??
              match.stock?.product?.category?.discountSetting;
        } catch (e) {
          // ignore lookup errors
        }
      }

      // If still null, try cached on-demand lookup by uuid and trigger background fetch
      try {
        final prodUuid = p.stock?.product?.uuid ?? p.uuid;
        if (prodUuid != null) {
          if (_discountCache.containsKey(prodUuid)) {
            discountSetting = discountSetting ?? _discountCache[prodUuid];
          } else if (!_discountLoading.contains(prodUuid)) {
            // trigger background fetch; result will update UI when ready
            _discountLoading.add(prodUuid);
            final repo = inject<ProductsRepository>();
            repo.getProductByUuid(prodUuid).then((res) {
              res.when(
                success: (data) {
                  DiscountSetting? ds;
                  try {
                    final Map<String, dynamic> pd = data;
                    final cat = pd['category'];
                    if (cat is Map<String, dynamic>) {
                      final rawDs =
                          cat['discount_setting'] ?? cat['discountSetting'];
                      if (rawDs is Map<String, dynamic>) {
                        ds = DiscountSetting.fromJson(rawDs);
                      }
                    }
                    if (ds == null && pd['stock'] is Map) {
                      final stock = pd['stock'] as Map<String, dynamic>;
                      final product = stock['product'];
                      if (product is Map<String, dynamic>) {
                        final cat2 = product['category'];
                        if (cat2 is Map<String, dynamic>) {
                          final rawDs = cat2['discount_setting'] ??
                              cat2['discountSetting'];
                          if (rawDs is Map<String, dynamic>) {
                            ds = DiscountSetting.fromJson(rawDs);
                          }
                        }
                      }
                    }
                  } catch (_) {}
                  if (mounted) {
                    setState(() {
                      _discountCache[prodUuid] = ds;
                    });
                  }
                },
                failure: (f, s) {
                  if (mounted) {
                    setState(() {
                      _discountCache[prodUuid] = null;
                    });
                  }
                },
              );
            }).whenComplete(() {
              _discountLoading.remove(prodUuid);
            });
          }
        }
      } catch (_) {}

      // prefer persisted selection from bagProducts if available
      String sel = 'default';
      try {
        final bagProducts = state.bags[state.selectedBagIndex].bagProducts;
        int matchIdx = _findBagProductIndex(bagProducts, p);
        if (!(matchIdx >= 0 && matchIdx < (bagProducts?.length ?? 0))) {
          matchIdx = _findBagProductIndexFlexible(bagProducts, p);
        }
        if (matchIdx >= 0) {
          final persisted = bagProducts?[matchIdx].selectedDiscount;
          if (persisted != null && persisted.isNotEmpty) {
            sel = persisted;
          } else {
            sel = _itemDiscounts[keyId] ?? 'default';
          }
        } else {
          sel = _itemDiscounts[keyId] ?? 'default';
        }
      } catch (e) {
        sel = _itemDiscounts[keyId] ?? 'default';
      }
      if (sel == 'with' && discountSetting != null) {
        if (discountSetting.method == 'percent') {
          base -= productPrice * ((discountSetting.value ?? 0) / 100);
        } else if (discountSetting.method == 'amount') {
          base -= (discountSetting.value ?? 0);
        }
      }
      if (base < 0) base = 0;
      effectiveSubtotal += base;
    }

    // compute bill-level discount separately so subtotal remains the sum of items
    // num billDiscountValue = 0;
    // try {
    //   if (state.selectedBillDiscount != null) {
    //     final bill = state.selectedBillDiscount!;
    //     if ((bill.scope ?? '').toLowerCase() == 'bill') {
    //       if (bill.method == 'percent') {
    //         billDiscountValue = (effectiveSubtotal * ((bill.value ?? 0) / 100));
    //       } else if (bill.method == 'amount') {
    //         billDiscountValue = (bill.value ?? 0);
    //       }
    //     }
    //   } else {
    //     final textRaw = _manualBillDiscountText.isNotEmpty
    //         ? _manualBillDiscountText
    //         : (_manualBillDiscountController?.text ?? '');
    //     final text = textRaw.replaceAll(',', '.').trim();
    //     final numVal = num.tryParse(text) ?? 0;
    //     if (numVal > 0) billDiscountValue = numVal;
    //   }
    // } catch (e) {
    //   // ignore compute errors
    // }

    // subtotalBeforeBill should be the original subtotal (before item-level discounts)
    // so that the discount row can be shown and subtracted once. Using
    // effectiveSubtotal here caused the item-level discount to be subtracted twice.
    final num subtotalBeforeBill = originalSubtotal;

    // if user applied per-item discounts locally, compute that total so we can
    // show it in the discount row even if the server calculate doesn't include it
    final num itemLevelDiscount =
        (originalSubtotal - effectiveSubtotal).clamp(0, double.infinity);

    // compute discount row (item-level discounts + coupon); bill discount is shown separately
    final num couponPrice = state.paginateResponse?.couponPrice ?? 0;
    final num discountRowValue =
        (itemLevelDiscount + couponPrice).clamp(0, double.infinity);

    // compute displayed total deterministically from components so UI matches rows:
    final num tax = state.paginateResponse?.totalTax ?? 0;
    final num serviceFee = state.paginateResponse?.serviceFee ?? 0;
    final num deliveryFee = state.paginateResponse?.deliveryFee ?? 0;
    final num displayedTotal = (subtotalBeforeBill -
            itemLevelDiscount +
            // billDiscountValue +
            tax +
            serviceFee +
            deliveryFee -
            couponPrice)
        .clamp(0, double.infinity);

    return Column(
      children: [
        8.verticalSpace,
        const Divider(),
        8.verticalSpace,
        Padding(
          padding: REdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              _priceItem(
                title: TrKeys.subtotal,
                price: subtotalBeforeBill,
                symbol: widget.bag.selectedCurrency?.symbol,
              ),
              _priceItem(
                title: TrKeys.tax,
                price: state.paginateResponse?.totalTax,
                symbol: widget.bag.selectedCurrency?.symbol,
              ),
              _priceItem(
                title: TrKeys.serviceFee,
                price: state.paginateResponse?.serviceFee,
                symbol: widget.bag.selectedCurrency?.symbol,
              ),
              _priceItem(
                title: TrKeys.deliveryFee,
                price: state.paginateResponse?.deliveryFee,
                symbol: widget.bag.selectedCurrency?.symbol,
              ),
              _priceItem(
                title: TrKeys.discount,
                price: discountRowValue,
                symbol: widget.bag.selectedCurrency?.symbol,
                isDiscount: true,
              ),
              _priceItem(
                title: TrKeys.promoCode,
                price: state.paginateResponse?.couponPrice,
                symbol: widget.bag.selectedCurrency?.symbol,
                isDiscount: true,
              ),
            ],
          ),
        ),
        8.verticalSpace,
        const Divider(),
        8.verticalSpace,
        Padding(
          padding: REdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppHelpers.getTranslation(TrKeys.totalPrice),
                    style: GoogleFonts.inter(
                      color: AppStyle.black,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.4,
                    ),
                  ),
                  Text(
                    AppHelpers.numberFormat(
                      displayedTotal, // deterministic total from components
                      symbol: widget.bag.selectedCurrency?.symbol,
                    ),
                    style: GoogleFonts.inter(
                      color: AppStyle.black,
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
              24.verticalSpace,
              LoginButton(
                isLoading: state.isButtonLoading || _isOrdering,
                isActive: !state.isButtonLoading && !_isOrdering,
                title: AppHelpers.getTranslation(TrKeys.order),
                titleColor: AppStyle.black,
                onPressed: (state.isButtonLoading || _isOrdering)
                    ? null
                    : () async {
                  setState(() => _isOrdering = true);
                  try {
                  final tablesState = ref.read(tablesProvider);
                  final activeTable = tablesState.activeOrderTable;

                  if (activeTable != null) {
                    final tableId = activeTable.id ?? 0;
                    final isReorder =
                        tablesState.tableTimers.containsKey(tableId);
                    final tablesNotifier = ref.read(tablesProvider.notifier);
                    final rightNotifier = ref.read(rightSideProvider.notifier);

                    final stocks = state.paginateResponse?.stocks ?? [];

                    // Use OrderCalculationHook for SC/tax/discount — same
                    // logic as normal order flow, all 5 order types supported.
                    final hooks = OrderHooks();
                    final bagProds =
                        state.bags[state.selectedBagIndex].bagProducts;
                    final calcResult = await hooks.calculation.calculate(
                      stocks: stocks,
                      orderType: state.orderType,
                      bagProducts: bagProds,
                    );
                    final enhancedProducts = hooks.enhancedProduct.build(
                      stocks: stocks,
                      calculationData: calcResult.calculationData,
                      orderType: state.orderType,
                    );

                    // Lightweight display map for LocalStorage.setTableItems
                    // (used by TableActiveDialog to show items in active order).
                    // Use stockId-keyed lookup from calculationData (same approach
                    // as EnhancedProductHook) so SC/tax amounts are correct even
                    // when stocks from the same category are non-contiguous.
                    final calcByStockIdDisplay = <int, Map<String, dynamic>>{};
                    for (final entry in calcResult.calculationData) {
                      if (entry.containsKey('billDiscountAmount')) continue;
                      final sid = entry['stockId'];
                      if (sid == null) continue;
                      final key =
                          sid is int ? sid : (sid as num).toInt();
                      calcByStockIdDisplay[key] = entry;
                    }

                    final displayItems =
                        List.generate(stocks.length, (i) {
                      final stock = stocks[i];
                      final qty = stock.quantity ?? 1;
                      final unitPrice = stock.stock?.price ?? 0;
                      final addonsTotal = (stock.addons ?? [])
                          .fold<num>(0, (s, a) => s + (a.price ?? 0));
                      final total = (unitPrice * qty) + addonsTotal;
                      final stockId = stock.stock?.id;
                      final cd = stockId != null
                          ? (calcByStockIdDisplay[stockId] ??
                              <String, dynamic>{})
                          : <String, dynamic>{};
                      return <String, dynamic>{
                        'stockId': stockId ?? 0,
                        'countableId': stock.stock?.countableId,
                        'uuid': stock.stock?.product?.uuid,
                        'productName':
                            stock.stock?.product?.translation?.title ?? '',
                        'quantity': qty,
                        'totalPrice': total,
                        'taxAmount': cd['taxAmount'] ?? 0,
                        'serviceChargeAmount': cd['serviceChargeAmount'] ?? 0,
                        'taxPercent': cd['taxPercent'] ?? 0,
                        'serviceChargePercent': cd['serviceChargePercent'] ?? 0,
                        'serviceChargeType': cd['serviceChargeType'] ?? '',
                        'categoryId': stock.stock?.product?.category?.id,
                        'categoryName':
                            stock.stock?.product?.category?.translation?.title,
                        'addonNames': (stock.addons ?? [])
                            .map((a) => a.product?.translation?.title ?? '')
                            .where((s) => s.isNotEmpty)
                            .toList(),
                        'addons': (stock.addons ?? [])
                            .map((a) => <String, dynamic>{
                                  'stockId': a.id ?? 0,
                                  'countableId': a.stockId,
                                  'quantity': a.quantity ?? 1,
                                  'price': a.price ?? 0,
                                })
                            .toList(),
                      };
                    });

                    if (enhancedProducts.isEmpty) return;

                    if (isReorder) {
                      final existingOrderId =
                          tablesState.tableOrders[tableId];
                      if (existingOrderId == null) return;
                      final ok = await rightNotifier.reorderDineInOrder(
                        orderId: existingOrderId,
                        enhancedProducts: enhancedProducts,
                        context: context,
                      );
                      if (ok == null || !mounted) return;
                      final existing = LocalStorage.getTableItems(tableId);
                      await LocalStorage.setTableItems(
                          tableId, [...existing, ...displayItems]);
                      await rightNotifier.printKitchenSlipForReorder(
                        context,
                        tableId: tableId,
                        newItems: displayItems,
                        tableData: activeTable,
                      );
                      rightNotifier.clearCalculate();
                      rightNotifier.clearBag();
                      tablesNotifier.exitTableOrdering();
                    } else {
                      // Generate doc no at init time — stored in the order and
                      // reused at cashout (not regenerated there).
                      String? initTransactionId;
                      final int? numericShopId =
                          LocalStorage.getUser()?.shop?.id ??
                              LocalStorage.getUser()?.invite?.shopId;
                      final String shopId = (numericShopId ?? 0).toString();
                      String terminalId = '';
                      try {
                        final termRes = await settingsRepository.getTerminalID();
                        termRes.when(
                          success: (id) { terminalId = id ?? ''; },
                          failure: (_, __) {},
                        );
                      } catch (_) {}
                      final prefix = 'POS-S$shopId-$terminalId-CSH';
                      final txnResult = await settingsRepository.generateTransactionID(prefix);
                      txnResult.when(
                        success: (docNo) {
                          if (docNo != null && docNo.isNotEmpty) initTransactionId = docNo;
                        },
                        failure: (_, __) {},
                      );
                      if (initTransactionId == null) {
                        if (mounted) AppHelpers.showSnackBar(context, 'Failed to obtain doc no. Order not created.');
                        return;
                      }

                      int? conflictServerId;
                      final orderId = await rightNotifier.initDineInOrder(
                        tableId: tableId,
                        enhancedProducts: enhancedProducts,
                        context: context,
                        transactionId: initTransactionId,
                        onConflict: (id) => conflictServerId = id,
                      );

                      // 409 conflict: table already has an active order on server.
                      if (conflictServerId != null) {
                        if (!mounted) return;
                        final confirmed = await _showTableConflictDialog(
                            context, conflictServerId!);
                        if (confirmed != true || !mounted) return;
                        // Add items to existing server order via reorder endpoint.
                        final ok = await rightNotifier.reorderDineInOrder(
                          orderId: conflictServerId!,
                          enhancedProducts: enhancedProducts,
                          context: context,
                        );
                        if (ok == null || !mounted) return;
                        final existing = LocalStorage.getTableItems(tableId);
                        await LocalStorage.setTableItems(
                            tableId, [...existing, ...displayItems]);
                        // ignore: use_build_context_synchronously
                        await rightNotifier.printKitchenSlipForReorder(
                          context,
                          tableId: tableId,
                          newItems: displayItems,
                          tableData: activeTable,
                        );
                        tablesNotifier.setTableOrder(tableId, conflictServerId!);
                        rightNotifier.clearCalculate();
                        rightNotifier.clearBag();
                        return;
                      }

                      if (orderId == null || !mounted) return;
                      await LocalStorage.setTableItems(
                          tableId, displayItems);
                      tablesNotifier.setTableOrder(tableId, orderId);
                      rightNotifier.clearCalculate();
                      rightNotifier.clearBag();
                    }
                    return;
                  }

                  // Normal (non-table) flow
                  final num totalDiscount = itemLevelDiscount + couponPrice;
                  AppHelpers.showAlertDialog(
                    context: context,
                    child: OrderInformation(
                      subtotal: subtotalBeforeBill,
                      totalDiscount: totalDiscount,
                      finalTotal: displayedTotal,
                    ),
                  );
                  } finally {
                    if (mounted) setState(() => _isOrdering = false);
                  }
                },
              )
            ],
          ),
        ),
      ],
    );
  }

  /// Shows a confirmation dialog when the server reports that the selected
  /// table already has an active order (409 TABLE_HAS_ACTIVE_ORDER).
  /// Returns `true` if the user confirms adding to the existing order.
  Future<bool?> _showTableConflictDialog(
      BuildContext ctx, int conflictServerId) {
    return showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text(
          AppHelpers.getTranslation('Active Order Detected'),
          style: GoogleFonts.inter(
              fontSize: 18.sp, fontWeight: FontWeight.w600),
        ),
        content: Text(
          AppHelpers.getTranslation(
              'This table already has an active order (#$conflictServerId). '
              'Do you want to add your items to it?'),
          style: GoogleFonts.inter(fontSize: 14.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(
              AppHelpers.getTranslation(TrKeys.cancel),
              style: GoogleFonts.inter(color: AppStyle.red),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppStyle.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r)),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(
              AppHelpers.getTranslation(TrKeys.confirm),
              style: GoogleFonts.inter(color: AppStyle.white),
            ),
          ),
        ],
      ),
    );
  }

  // fetch bill-level discount settings from backend
  Future<void> _fetchBillDiscounts() async {
    if (mounted) {
      setState(() {
        _billDiscountsLoading = true;
      });
    }
    try {
      final repo = inject<ProductsRepository>();
      final res = await repo.getDiscountSettingsSelectPaginate(page: 1);
      res.when(
        success: (data) {
          // mirror the web behavior: filter by scope == 'bill'
          final filtered = data
              .where((d) => (d.scope ?? '').toLowerCase() == 'bill')
              .toList();
          if (mounted) {
            setState(() {
              _billDiscounts = filtered;
            });
          }
        },
        failure: (error, statusCode) {
          // failure ignored for bill discount fetch
        },
      );
    } catch (e) {
      // ignore fetch errors
    } finally {
      if (mounted) {
        setState(() {
          _billDiscountsLoading = false;
        });
      }
    }
  }

  _priceItem({
    required String title,
    required num? price,
    required String? symbol,
    bool isDiscount = false,
  }) {
    return (price ?? 0) != 0
        ? Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppHelpers.getTranslation(title),
                    style: GoogleFonts.inter(
                      color: isDiscount ? AppStyle.red : AppStyle.black,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.4,
                    ),
                  ),
                  Text(
                    (isDiscount ? "-" : '') +
                        AppHelpers.numberFormat(price, symbol: symbol),
                    style: GoogleFonts.inter(
                      color: isDiscount ? AppStyle.red : AppStyle.black,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
              12.verticalSpace,
            ],
          )
        : const SizedBox.shrink();
  }

  DiscountSetting? findMatchingDiscount(DiscountSetting? selectedDiscount) {
    // Ensure the DropdownButton `value` is one of the `items` by returning
    // the actual object instance from `_billDiscounts` when ids match.
    // If no matching preset exists, return null so the Dropdown shows 'Custom'.
    if (selectedDiscount == null) return null;
    try {
      for (final discount in _billDiscounts) {
        if (discount.id == selectedDiscount.id) return discount;
      }
    } catch (_) {}
    return null;
  }
}
