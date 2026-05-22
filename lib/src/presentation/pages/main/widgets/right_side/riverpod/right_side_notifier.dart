import 'dart:async';
import 'package:admin_desktop/src/core/di/dependency_manager.dart';
import 'package:admin_desktop/src/models/data/table_data.dart';
import 'package:admin_desktop/src/models/response/product_calculate_response.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../../core/constants/constants.dart';
import '../../../../../../core/utils/utils.dart';
import '../../../../../../core/sync/sync_service.dart';
import '../../../../../../models/models.dart';
import 'right_side_provider.dart';
import 'right_side_state.dart';

class RightSideNotifier extends StateNotifier<RightSideState> {
  Timer? _searchUsersTimer;
  Timer? _searchSectionTimer;
  Timer? _searchTableTimer;

  String _phone = '';

  final Ref? _ref;

  RightSideNotifier(Ref? ref)
      : _ref = ref,
        super(const RightSideState());
  Timer? timer;

  /// Fetches the list of available pricing tiers from the backend.
  Future<void> fetchPricingTiers(BuildContext context) async {
    final response = await productsRepository.getProductPricingTiers();
    response.when(
      success: (data) {
        _ref?.read(pricingTiersProvider.notifier).state = data;

        // Ensure the selected tier still exists in the new data
        final currentSelected = _ref?.read(selectedPricingTierProvider);
        if (currentSelected != null) {
          final exists = data.any((t) =>
              t.title?.toLowerCase().trim() ==
              currentSelected.title?.toLowerCase().trim());
          if (!exists) {
            _ref?.read(selectedPricingTierProvider.notifier).state = null;
            fetchAndUpdateTierPrices(null);
          } else {
            // Update the selected tier with the one from the new list to maintain reference equality if needed
            final updatedTier = data.firstWhere((t) =>
                t.title?.toLowerCase().trim() ==
                currentSelected.title?.toLowerCase().trim());
            _ref?.read(selectedPricingTierProvider.notifier).state =
                updatedTier;
          }
        }
      },
      failure: (failure, status) {
        if (context.mounted) {
          AppHelpers.showSnackBar(
            context,
            AppHelpers.getTranslation(TrKeys.somethingWentWrongWithTheServer),
          );
        }
      },
    );
  }

  /// NEW: Fetches the prices for a specific tier and updates the cart.
  Future<void> fetchAndUpdateTierPrices(ProductPricingTier? tier) async {
    if (tier?.title == null) {
      // If tier is null or has no title, clear the prices and recalculate the cart
      state = state.copyWith(tierPrices: {});
      fetchCarts(isNotLoading: true);
      return;
    }

    // Fetch the list of products with special prices for the selected tier
    final response = await productsRepository.getTierProducts(tier!.title!);
    response.when(
      success: (data) {
        // Create a map of productId -> price from the API response
        final Map<int, num> newPrices = {
          for (var product in data)
            if (product.id != null) product.id!: product.price ?? 0
        };
        state = state.copyWith(tierPrices: newPrices);
        // After updating the price map, recalculate the cart to apply them
        fetchCarts(isNotLoading: true);
      },
      failure: (failure, status) {
        debugPrint('==> fetch tier prices failure: $failure');
        // If fetching fails, clear prices and recalculate with defaults
        state = state.copyWith(tierPrices: {});
        fetchCarts(isNotLoading: true);
      },
    );
  }

  /// Calculates the cart total, now with client-side price adjustments.
  Future<void> fetchCarts(
      {VoidCallback? checkYourNetwork, bool isNotLoading = false}) async {
    if (isNotLoading) {
      state = state.copyWith(isButtonLoading: true);
    } else {
      final bags = LocalStorage.getBags();
      state = state.copyWith(
        isProductCalculateLoading: true,
        paginateResponse: null,
        bags: bags,
        comment: bags.isNotEmpty && state.selectedBagIndex < bags.length
            ? (bags[state.selectedBagIndex].note ?? '')
            : '',
      );
    }

    final List<BagProductData> bagProducts =
        LocalStorage.getBags()[state.selectedBagIndex].bagProducts ?? [];
    if (bagProducts.isNotEmpty) {
      final response = await productsRepository.getAllCalculations(bagProducts,
          state.orderType, state.coupon, state.selectedBillDiscount?.id);

      response.when(
        success: (data) async {
          PriceDate? calc = data.data?.data;

          // ===== Price Tier Adjustment Logic ===================================
          if (state.tierPrices.isNotEmpty && calc?.stocks != null) {
            final List<ProductData> updatedStocks = [];
            for (var stock in calc!.stocks!) {
              final productId = stock.stock?.countableId ?? stock.id;
              if (state.tierPrices.containsKey(productId)) {
                // If we have a special price for this product, apply it
                final newPrice = state.tierPrices[productId]!;

                // Create an updated version of the nested 'stock' object with the new price
                final updatedInnerStock =
                    stock.stock?.copyWith(price: newPrice);

                // Now, create the updated product data using the new inner stock
                final updatedStock = stock.copyWith(
                  stock: updatedInnerStock,
                  price:
                      newPrice, // Also update the top-level price for consistency
                  totalPrice: newPrice * (stock.quantity ?? 1),
                );
                updatedStocks.add(updatedStock);
              } else {
                updatedStocks.add(stock); // Otherwise, keep the original
              }
            }
            // Recalculate total price based on our changes
            num newTotalPrice = updatedStocks.fold(
                0, (sum, item) => sum + (item.totalPrice ?? 0));
            calc = calc.copyWith(
              stocks: updatedStocks,
              totalPrice: newTotalPrice,
            );
          }
          // ====================================================================

          state = state.copyWith(
            isButtonLoading: false,
            isProductCalculateLoading: false,
            paginateResponse: calc,
          );
          // attempt to snapshot discount settings for persisted bag products
          // (this ensures UI can prefer snapshots after calculate returns)
          await _snapshotDiscountsForBagProducts();
        },
        failure: (failure, status) async {
          // Try to parse invalid stock_id from backend error
          final errorString = failure.toString();
          final regExp = RegExp(r'products[ .](\d+)[ .]stock_id');
          final match = regExp.firstMatch(errorString);
          if (match != null && match.groupCount >= 1) {
            final invalidIndex = int.tryParse(match.group(1)!);
            if (invalidIndex != null) {
              final bags = LocalStorage.getBags();
              if (bags.isNotEmpty && state.selectedBagIndex < bags.length) {
                final bag = bags[state.selectedBagIndex];
                final products =
                    List<BagProductData>.from(bag.bagProducts ?? []);
                if (invalidIndex < products.length) {
                  products.removeAt(invalidIndex);
                  bags[state.selectedBagIndex] =
                      bag.copyWith(bagProducts: products);
                  await LocalStorage.setBags(bags);
                  // Reload bag state from LocalStorage to ensure UI is in sync
                  final updatedBags = LocalStorage.getBags();
                  state = state.copyWith(
                    bags: updatedBags,
                  );
                }
              }
            }
          }
          state = state.copyWith(
            isProductCalculateLoading: false,
            isButtonLoading: false,
          );
          debugPrint('==> get product calculate failure: $failure');
        },
      );
    } else {
      // If the cart is empty, ensure loading state is turned off
      state = state.copyWith(
        isButtonLoading: false,
        isProductCalculateLoading: false,
      );
    }
  }

  // ... (All your other existing methods like setCoupon, fetchBags, etc., remain unchanged)
  // ... (The code below is the same as your original file)

  // ADD THIS NEW METHOD
  void updatePaginateResponse(PriceDate? newResponse) {
    state = state.copyWith(paginateResponse: newResponse);
  }

  void setCoupon(String coupon, BuildContext context) {
    state = state.copyWith(coupon: coupon, isActive: false);
    fetchCarts(
      checkYourNetwork: () {
        AppHelpers.showSnackBar(
          context,
          AppHelpers.getTranslation(TrKeys.checkYourNetworkConnection),
        );
      },
    );
  }

  setCalculate(String item) {
    if (item == "-1" && state.tempCalculate.isNotEmpty) {
      state = state.copyWith(
          tempCalculate:
              state.tempCalculate.substring(0, state.tempCalculate.length - 1),
          isCalculateConfirmed: false);
      return;
    } else if (state.tempCalculate.length > 25) {
      return;
    } else if (item == "." && state.tempCalculate.isEmpty) {
      state = state.copyWith(
          tempCalculate: "${state.tempCalculate}0$item",
          isCalculateConfirmed: false);
      return;
    } else if (item == "." && state.tempCalculate.contains(".")) {
      return;
    } else if (item != "-1") {
      state = state.copyWith(
          tempCalculate: state.tempCalculate + item,
          isCalculateConfirmed: false);
      return;
    }
  }

  // Add new method to confirm the calculation
  void confirmCalculate() {
    state = state.copyWith(
        calculate: state.tempCalculate, isCalculateConfirmed: true);
    // Only trigger API call here if needed
    // You can add your API call logic here
  }

  void setManualBillDiscountText(String text) {
    state = state.copyWith(manualBillDiscountText: text);
  }

  // Add method to clear the temp calculation
  void clearTempCalculate() {
    state = state.copyWith(tempCalculate: '', isCalculateConfirmed: false);
  }

  void clearCalculate() {
    state = state.copyWith(
      calculate: '',
      tempCalculate: '',
      isCalculateConfirmed: false,
    );
  }

  void setUpdate() {
    state = state.copyWith(isLogoImageLoading: true);
    state = state.copyWith(isLogoImageLoading: false);
  }

  Future<void> fetchBags() async {
    state = state.copyWith(isBagsLoading: true, bags: []);
    List<BagData> bags = LocalStorage.getBags();
    if (bags.isEmpty) {
      final BagData firstBag = BagData(
        index: 0,
        bagProducts: [],
        selectedCurrency: LocalStorage.getSelectedCurrency(),
      );
      LocalStorage.setBags([firstBag]);
      bags = [firstBag];
    }
    state = state.copyWith(
      bags: bags,
      isBagsLoading: false,
      selectedUser: bags[0].selectedUser,
      comment: bags[0].note ?? '',
      isActive: false,
      isPromoCodeLoading: false,
      coupon: null,
    );
  }

  Future<void> checkPromoCode(
    BuildContext context,
    String? promoCode,
  ) async {
    state = state.copyWith(isPromoCodeLoading: true, isActive: false);

    final response = await usersRepository.checkCoupon(
      coupon: promoCode ?? "",
      shopId: LocalStorage.getUser()?.role == TrKeys.waiter
          ? LocalStorage.getUser()?.invite?.shopId ?? 0
          : LocalStorage.getUser()?.shop?.id ?? 0,
    );
    response.when(
      success: (data) {
        state = state.copyWith(isPromoCodeLoading: false, isActive: true);
      },
      failure: (failure, status) {
        state = state.copyWith(
          isPromoCodeLoading: false,
          isActive: false,
        );
      },
    );
  }

  void addANewBag() {
    List<BagData> newBags = List.from(state.bags);
    PaymentData? defaultPayment;
    try {
      defaultPayment = state.payments.firstWhere(
        (element) => element.tag == 'cash',
        orElse: () => state.payments.first,
      );
    } catch (_) {}

    newBags.add(BagData(
        index: newBags.length,
        bagProducts: [],
        selectedPayment: defaultPayment,
        selectedCurrency: LocalStorage.getSelectedCurrency()));
    LocalStorage.setBags(newBags);
    state = state.copyWith(bags: newBags);
  }

  void setSelectedBagIndex(int index) {
    final selectedBag = state.bags[index];
    state = state.copyWith(
      selectedBagIndex: index,
      selectedBillDiscount: selectedBag.selectedBillDiscount,
      selectedUser: selectedBag.selectedUser,
      selectedPayment: selectedBag.selectedPayment,
      selectedCurrency: selectedBag.selectedCurrency,
      selectedAddress: selectedBag.selectedAddress,
      selectedSection: selectedBag.selectedSection,
      selectedTable: selectedBag.selectedTable,
      comment: selectedBag.note ?? '',
    );
  }

  void removeBag(int index) {
    List<BagData> bags = List.from(state.bags);
    List<BagData> newBags = [];
    bags.removeAt(index);
    for (int i = 0; i < bags.length; i++) {
      newBags.add(bags[i].copyWith(index: i));
    }
    LocalStorage.setBags(newBags);
    int selectedIndex = state.selectedBagIndex;
    if (selectedIndex == index) {
      selectedIndex = 0;
    } else if (selectedIndex > index) {
      selectedIndex--;
    }
    state = state.copyWith(
      bags: newBags,
      selectedBagIndex: selectedIndex,
      comment: newBags.isNotEmpty ? (newBags[selectedIndex].note ?? '') : '',
    );
  }

  void removeOrderedBag(BuildContext context) {
    List<BagData> bags = List.from(state.bags);
    List<BagData> newBags = [];
    bags.removeAt(state.selectedBagIndex);
    if (bags.isEmpty) {
      final BagData firstBag = BagData(index: 0, bagProducts: []);
      newBags = [firstBag];
    } else {
      for (int i = 0; i < bags.length; i++) {
        newBags.add(bags[i].copyWith(index: i));
      }
    }
    LocalStorage.setBags(newBags);
    state = state.copyWith(
      bags: newBags,
      selectedBagIndex: 0,
      selectedUser: null,
      selectedAddress: null,
      selectedCurrency: null,
      selectedPayment: null,
      orderType: TrKeys.dine,
      comment: newBags[0].note ?? '',
    );
    setInitialBagData(context, newBags[0]);
  }

  /// Persist and update bags in state without triggering a full recalculation.
  /// Use this when only bag metadata changed (like selectedDiscount) and you
  /// don't want to call the server to recalculate totals immediately.
  void updateBags(List<BagData> bags, {bool persist = true}) {
    if (persist) LocalStorage.setBags(bags);
    state = state.copyWith(bags: bags);
  }

  Future<void> fetchUsers({VoidCallback? checkYourNetwork}) async {
    state = state.copyWith(
      isUsersLoading: true,
      dropdownUsers: [],
      users: [],
    );
    final response = await usersRepository.searchUsers(
        query: state.usersQuery.isEmpty ? null : state.usersQuery);
    response.when(
      success: (data) async {
        final List<UserData> users = data.users ?? [];
        List<DropDownItemData> dropdownUsers = [];
        for (int i = 0; i < users.length; i++) {
          dropdownUsers.add(
            DropDownItemData(
              index: i,
              title: '${users[i].firstname} ${users[i].lastname ?? ""}',
            ),
          );
        }
        state = state.copyWith(
          isUsersLoading: false,
          users: users,
          dropdownUsers: dropdownUsers,
        );
      },
      failure: (failure, status) {
        state = state.copyWith(isUsersLoading: false);
        debugPrint('==> get users failure: $failure');
      },
    );
  }

  Future<void> fetchSections({VoidCallback? checkYourNetwork}) async {
    state = state.copyWith(isSectionLoading: true, sections: []);
    final response = await tableRepository.getSection(
        query: state.sectionQuery.isEmpty ? null : state.sectionQuery);
    response.when(
      success: (data) async {
        final sections = data.data ?? [];
        final selectedSection = state.selectedSection ??
            (sections.isNotEmpty ? sections.first : null);

        state = state.copyWith(
          isSectionLoading: false,
          sections: sections,
          selectedSection: selectedSection,
        );
      },
      failure: (failure, status) {
        state = state.copyWith(isSectionLoading: false);
        debugPrint('==> get sections failure: $failure');
      },
    );
  }

  Future<void> fetchTables({VoidCallback? checkYourNetwork}) async {
    state = state.copyWith(isTableLoading: true, tables: []);
    final response = await tableRepository.getTables(
        query: state.tableQuery.isEmpty ? null : state.tableQuery,
        shopSectionId: state.selectedSection?.id);
    response.when(
      success: (data) async {
        state = state.copyWith(
          isTableLoading: false,
          tables: data.data ?? [],
        );
      },
      failure: (failure, status) {
        state = state.copyWith(isTableLoading: false);
        debugPrint('==> get tables failure: $failure');
      },
    );
  }

  void setStatusNote(String value) {}

  void setPhone(String value) {
    _phone = value.trim();
  }

  void setUsersQuery(BuildContext context, String query) {
    state = state.copyWith(usersQuery: query.trim());

    if (_searchUsersTimer?.isActive ?? false) {
      _searchUsersTimer?.cancel();
    }
    _searchUsersTimer = Timer(
      const Duration(milliseconds: 500),
      () {
        state = state.copyWith(users: [], dropdownUsers: []);
        fetchUsers(
          checkYourNetwork: () {
            AppHelpers.showSnackBar(
              context,
              AppHelpers.getTranslation(TrKeys.checkYourNetworkConnection),
            );
          },
        );
      },
    );
  }

  void setSectionQuery(BuildContext context, String query) {
    state = state.copyWith(sectionQuery: query.trim());

    if (_searchSectionTimer?.isActive ?? false) {
      _searchSectionTimer?.cancel();
    }
    _searchSectionTimer = Timer(
      const Duration(milliseconds: 500),
      () {
        state = state.copyWith(sections: []);
        fetchSections(
          checkYourNetwork: () {
            AppHelpers.showSnackBar(
              context,
              AppHelpers.getTranslation(TrKeys.checkYourNetworkConnection),
            );
          },
        );
      },
    );
  }

  void setTableQuery(BuildContext context, String query) {
    state = state.copyWith(tableQuery: query.trim());

    if (_searchTableTimer?.isActive ?? false) {
      _searchTableTimer?.cancel();
    }
    _searchTableTimer = Timer(
      const Duration(milliseconds: 500),
      () {
        state = state.copyWith(sections: []);
        fetchTables(
          checkYourNetwork: () {
            AppHelpers.showSnackBar(
              context,
              AppHelpers.getTranslation(TrKeys.checkYourNetworkConnection),
            );
          },
        );
      },
    );
  }

  void setSelectedUser(BuildContext context, int index) {
    final user = state.users[index];
    final bags = LocalStorage.getBags();
    final bag = bags[state.selectedBagIndex].copyWith(selectedUser: user);
    bags[state.selectedBagIndex] = bag;
    LocalStorage.setBags(bags);
    state = state.copyWith(
      bags: bags,
      selectedUser: user,
      selectUserError: null,
    );
    fetchUserDetails(
      checkYourNetwork: () {
        AppHelpers.showSnackBar(
          context,
          AppHelpers.getTranslation(TrKeys.checkYourNetworkConnection),
        );
      },
    );
    setUsersQuery(context, '');
  }

  void setSelectedSection(BuildContext context, int index) {
    final section = state.sections[index];
    final bags = LocalStorage.getBags();
    final bag = bags[state.selectedBagIndex].copyWith(selectedSection: section);
    bags[state.selectedBagIndex] = bag;
    LocalStorage.setBags(bags);
    state = state.copyWith(
      bags: bags,
      selectedSection: section,
      selectSectionError: null,
    );
    setSectionQuery(context, '');
  }

  void setSelectedTable(BuildContext context, int index) {
    final table = state.tables[index];
    final bags = LocalStorage.getBags();
    final bag = bags[state.selectedBagIndex].copyWith(selectedTable: table);
    bags[state.selectedBagIndex] = bag;
    LocalStorage.setBags(bags);
    state = state.copyWith(
      bags: bags,
      selectedTable: table,
      selectTableError: null,
    );
    setTableQuery(context, '');
  }

  void removeSelectedUser() {
    final List<BagData> bags = List.from(LocalStorage.getBags());
    final BagData bag = bags[state.selectedBagIndex]
        .copyWith(selectedUser: null, selectedAddress: null);
    bags[state.selectedBagIndex] = bag;
    LocalStorage.setBags(bags);
    state = state.copyWith(bags: bags, selectedUser: null);
  }

  void removeSelectedSection() {
    final List<BagData> bags = List.from(LocalStorage.getBags());
    final BagData bag =
        bags[state.selectedBagIndex].copyWith(selectedSection: null);
    bags[state.selectedBagIndex] = bag;
    LocalStorage.setBags(bags);
    state = state.copyWith(bags: bags, selectedSection: null);
  }

  void removeSelectedTable() {
    final List<BagData> bags = List.from(LocalStorage.getBags());
    final BagData bag =
        bags[state.selectedBagIndex].copyWith(selectedTable: null);
    bags[state.selectedBagIndex] = bag;
    LocalStorage.setBags(bags);
    state = state.copyWith(bags: bags, selectedTable: null);
  }

  Future<void> fetchUserDetails({VoidCallback? checkYourNetwork}) async {
    state = state.copyWith(isUserDetailsLoading: true);
    final response =
        await usersRepository.getUserDetails(state.selectedUser?.uuid ?? '');
    response.when(
      success: (data) async {
        state = state.copyWith(
          isUserDetailsLoading: false,
          selectedUser: data.data,
        );
      },
      failure: (failure, status) {
        state = state.copyWith(isUserDetailsLoading: false);
        debugPrint('==> get users details failure: $failure');
      },
    );
  }

  void presetTableContext(TableData table, {ShopSection? section}) {
    setSelectedOrderType(TrKeys.dine);
    final bags = LocalStorage.getBags();
    if (bags.isEmpty) return;
    final idx = state.selectedBagIndex;
    final updatedBag = bags[idx].copyWith(
      selectedTable: table,
      selectedSection: section ?? bags[idx].selectedSection,
    );
    bags[idx] = updatedBag;
    LocalStorage.setBags(bags);
    state = state.copyWith(
      bags: bags,
      selectedTable: table,
      selectedSection: section ?? state.selectedSection,
      selectTableError: null,
      selectSectionError: null,
    );
  }

  /// Creates an initial dine-in order in Hive and syncs to backend if online.
  /// Returns the order ID on success, or null on failure.
  Future<int?> initDineInOrder({
    required int tableId,
    required List<Map<String, dynamic>> items,
    required BuildContext context,
  }) async {
    final enhancedProducts = items.map((item) {
      final addonsList =
          List<Map<String, dynamic>>.from(item['addons'] as List? ?? []);
      final num preTax = item['totalPrice'] as num;
      final num taxAmt = (item['taxAmount'] as num?) ?? 0;
      final num scAmt = (item['serviceChargeAmount'] as num?) ?? 0;
      final num? taxPct = item['taxPercent'] as num?;
      final num? scPct = item['serviceChargePercent'] as num?;
      final String? scType = item['serviceChargeType'] as String?;
      return EnhancedProductOrder(
        stockId: (item['stockId'] as num).toInt(),
        countableId: item['countableId'] as int?,
        quantity: (item['quantity'] as num).toInt(),
        originalPrice: preTax,
        finalPrice: preTax + taxAmt + scAmt,
        itemDiscountAmount: 0,
        serviceChargeAmount: scAmt,
        serviceChargeType: (scType?.isNotEmpty ?? false) ? scType : null,
        serviceChargePercent: (scPct ?? 0) > 0 ? scPct : null,
        taxAmount: taxAmt,
        taxPercent: (taxPct ?? 0) > 0 ? taxPct : null,
        categoryId: item['categoryId'] as int?,
        categoryName: item['categoryName'] as String?,
        addons: addonsList
            .map((a) => EnhancedAddonOrder(
                  stockId: (a['stockId'] as num).toInt(),
                  countableId: a['countableId'] as int?,
                  quantity: (a['quantity'] as num).toInt(),
                  price: a['price'] as num,
                ))
            .toList(),
      );
    }).toList();

    final now = DateTime.now();
    final data = OrderBodyData(
      bagData: BagData(
        selectedCurrency: state.selectedCurrency,
        selectedTable: state.selectedTable,
        selectedSection: state.selectedSection,
        selectedPayment: state.selectedPayment,
        selectedUser: state.selectedUser,
        selectedAddress: state.selectedAddress,
      ),
      deliveryType: TrKeys.dine,
      tableId: tableId,
      currencyId: state.selectedCurrency?.id,
      rate: state.selectedCurrency?.rate ?? 0,
      phone: LocalStorage.getUser()?.phone ?? '',
      address: AddressModel(),
      deliveryDate: DateFormat('yyyy-MM-dd').format(now),
      deliveryTime: DateFormat('HH:mm').format(now),
      enhancedProducts: enhancedProducts,
      paidAmount: 0,
      queueNo: '1'.padLeft(4, '0'),
      createdAt: now.toIso8601String(),
    );

    int? orderId;
    final response = await ordersRepository.createOrder(data);
    response.when(
      success: (res) {
        orderId = res.data?.id;
      },
      failure: (failure, status) {
        if (context.mounted) {
          AppHelpers.showSnackBar(context, failure);
        }
      },
    );
    return orderId;
  }

  Future<int?> reorderDineInOrder({
    required int orderId,
    required List<Map<String, dynamic>> items,
    required BuildContext context,
  }) async {
    final newProducts = items.map((item) {
      final addonsList = List<Map<String, dynamic>>.from(item['addons'] as List? ?? []);
      final num preTax = item['totalPrice'] as num;
      final num taxAmt = (item['taxAmount'] as num?) ?? 0;
      final num scAmt = (item['serviceChargeAmount'] as num?) ?? 0;
      final num? taxPct = item['taxPercent'] as num?;
      final num? scPct = item['serviceChargePercent'] as num?;
      final String? scType = item['serviceChargeType'] as String?;
      return EnhancedProductOrder(
        stockId: (item['stockId'] as num).toInt(),
        countableId: item['countableId'] as int?,
        quantity: (item['quantity'] as num).toInt(),
        originalPrice: preTax,
        finalPrice: preTax + taxAmt + scAmt,
        itemDiscountAmount: 0,
        serviceChargeAmount: scAmt,
        serviceChargeType: (scType?.isNotEmpty ?? false) ? scType : null,
        serviceChargePercent: (scPct ?? 0) > 0 ? scPct : null,
        taxAmount: taxAmt,
        taxPercent: (taxPct ?? 0) > 0 ? taxPct : null,
        categoryId: item['categoryId'] as int?,
        categoryName: item['categoryName'] as String?,
        addons: addonsList
            .map((a) => EnhancedAddonOrder(
                  stockId: (a['stockId'] as num).toInt(),
                  countableId: a['countableId'] as int?,
                  quantity: (a['quantity'] as num).toInt(),
                  price: a['price'] as num,
                ))
            .toList(),
      );
    }).toList();

    await ordersRepository.addProductsToOrder(orderId: orderId, newItems: newProducts);
    return orderId;
  }

  Future<void> cashoutTableOrder({
    required BuildContext context,
    required int orderId,
    required int paymentId,
    required Function(int effectiveId) onSuccess,
  }) async {
    state = state.copyWith(isOrderLoading: true);
    try {
      int? serverId;
      final orderResult = await ordersRepository.fetchOrderById(orderId);
      orderResult.when(
        success: (order) => serverId = order.meta?.serverId,
        failure: (_, __) {},
      );

      if (serverId == null && await AppConnectivity.connectivity()) {
        await SyncService().pushSingleOrder(orderId);
        final updated = await ordersRepository.fetchOrderById(orderId);
        updated.when(
          success: (order) => serverId = order.meta?.serverId,
          failure: (_, __) {},
        );
      }

      final effectiveId = serverId ?? orderId;

      await paymentsRepository.createTransaction(
        orderId: effectiveId,
        paymentId: paymentId,
      );

      if (serverId != null && await AppConnectivity.connectivity()) {
        await SyncService().submitPaymentTransaction(serverId!, hiveKey: orderId);
        await SyncService().updateOrderStatusOnBackend(serverId!, 'delivered');
      }

      if (context.mounted) removeOrderedBag(context);
      state = state.copyWith(isOrderLoading: false);
      onSuccess(effectiveId);
    } catch (e) {
      state = state.copyWith(isOrderLoading: false);
      if (context.mounted) {
        AppHelpers.showSnackBar(context, e.toString());
      }
    }
  }

  /// Prints kitchen slip for reorder. No-op if printer not configured.
  Future<void> printKitchenSlipForReorder(
    BuildContext context, {
    required int tableId,
    required List<Map<String, dynamic>> newItems,
    required TableData tableData,
  }) async {
    debugPrint('printKitchenSlipForReorder: table=${tableData.name}, items=${newItems.length}');
  }

  void setSelectedOrderType(String? type) {
    PaymentData? selectedPayment = state.selectedPayment;
    if (state.selectedPayment?.tag != 'cash') {
      final List<PaymentData> payments = List.from(state.payments);
      selectedPayment = payments.firstWhere((e) => e.tag == 'cash',
          orElse: () => PaymentData());
    }
    state = state.copyWith(
      orderType: type ?? state.orderType,
      selectedPayment: selectedPayment,
      selectPaymentError: null,
      selectUserError: null,
      selectAddressError: null,
      selectCurrencyError: null,
      selectTableError: null,
      selectSectionError: null,
    );
  }

  void setSelectedAddress({AddressData? address}) {
    final List<BagData> bags = List.from(LocalStorage.getBags());

    final user = bags[state.selectedBagIndex].selectedUser;
    final BagData bag = bags[state.selectedBagIndex]
        .copyWith(selectedAddress: address, selectedUser: user);
    bags[state.selectedBagIndex] = bag;
    LocalStorage.setBags(bags);
    state = state.copyWith(bags: bags, selectedAddress: address);
  }

  Future<void> setInitialBagData(BuildContext context, BagData bag) async {
    state = state.copyWith(
        selectedAddress: bag.selectedAddress,
        selectedUser: bag.selectedUser,
        selectedCurrency: bag.selectedCurrency,
        selectedPayment: bag.selectedPayment,
        selectedBillDiscount: bag.selectedBillDiscount,
        orderType: state.orderType.isEmpty ? TrKeys.dine : state.orderType);
    if (bag.selectedUser != null) {
      fetchUserDetails(
        checkYourNetwork: () {
          AppHelpers.showSnackBar(
            context,
            AppHelpers.getTranslation(TrKeys.checkYourNetworkConnection),
          );
        },
      );
    }
    await fetchCarts(
      checkYourNetwork: () {
        AppHelpers.showSnackBar(
          context,
          AppHelpers.getTranslation(TrKeys.checkYourNetworkConnection),
        );
      },
    );

    // after carts/products loaded, attach discountSetting snapshot to bag products
    await _snapshotDiscountsForBagProducts();
  }

  // new helper: attach known discountSetting to stored BagProductData so UI stays stable
  Future<void> _snapshotDiscountsForBagProducts() async {
    try {
      final List<BagData> bags = List.from(LocalStorage.getBags());
      final int selIdx = state.selectedBagIndex;
      if (selIdx < 0 || selIdx >= bags.length) return;
      final bagProducts =
          List<BagProductData>.from(bags[selIdx].bagProducts ?? []);
      final stocks = state.paginateResponse?.stocks ?? [];

      bool changed = false;
      for (int i = 0; i < bagProducts.length; i++) {
        final bp = bagProducts[i];
        // skip if already has snapshot
        if (bp.selectedDiscountSetting != null) continue;

        // try to find a matching product in current paginateResponse
        final match = stocks.firstWhere(
            (p) =>
                (p.stock?.id != null && p.stock?.id == bp.stockId) ||
                (p.stock?.countableId != null &&
                    p.stock?.countableId == bp.stockId) ||
                (p.id != null && p.id == bp.stockId),
            orElse: () => ProductData());

        final DiscountSetting? ds = match.category?.discountSetting ??
            match.stock?.product?.category?.discountSetting;

        if (ds != null) {
          bagProducts[i] = bp.copyWith(selectedDiscountSetting: ds);
          changed = true;
        }
      }

      if (changed) {
        bags[selIdx] = bags[selIdx].copyWith(bagProducts: bagProducts);
        LocalStorage.setBags(bags);
        state = state.copyWith(bags: bags);
      } else {
        // If some bag products are still missing snapshots, attempt a
        // paginated backfill from the products paginate endpoint. This
        // helps when the server only returns products for the currently
        // selected category, but the bag contains items from other
        // categories.
        final bool anyMissing =
            bagProducts.any((bp) => bp.selectedDiscountSetting == null);
        if (anyMissing) {
          await _backfillDiscountSettingsFromPaginate(
              bagProducts: bagProducts, bags: bags, selIdx: selIdx);
        }
      }
    } catch (e) {
      debugPrint('snapshotDiscountsForBagProducts failed: $e');
    }
  }

  /// Try to fetch product pages and attach discountSetting to persisted
  /// BagProductData instances that still lack a snapshot. Limits pages to
  /// avoid excessive network usage.
  Future<void> _backfillDiscountSettingsFromPaginate({
    required List<BagProductData> bagProducts,
    required List<BagData> bags,
    required int selIdx,
    int maxPages = 5,
  }) async {
    try {
      final missingIndices = <int>[];
      for (int i = 0; i < bagProducts.length; i++) {
        if (bagProducts[i].selectedDiscountSetting == null) {
          missingIndices.add(i);
        }
      }
      if (missingIndices.isEmpty) return;

      bool changed = false;
      for (int page = 1;
          page <= maxPages && missingIndices.isNotEmpty;
          page++) {
        final response = await productsRepository.getProductsPaginate(
          page: page,
        );

        // If call failed, continue to next page or break to avoid waste
        await response.when(
          success: (data) async {
            final List<ProductData> products = data.data ?? [];
            if (products.isEmpty) return;

            // Attempt to match each missing bag product to any product on this page
            for (final prod in products) {
              for (final idx in List<int>.from(missingIndices)) {
                final bp = bagProducts[idx];
                final bool matches =
                    (prod.stock?.id != null && prod.stock?.id == bp.stockId) ||
                        (prod.stock?.countableId != null &&
                            prod.stock?.countableId == bp.stockId) ||
                        (prod.id != null && prod.id == bp.stockId) ||
                        (prod.id != null && prod.id == bp.parentId);

                if (matches) {
                  final DiscountSetting? ds = prod.category?.discountSetting ??
                      prod.stock?.product?.category?.discountSetting;
                  if (ds != null) {
                    bagProducts[idx] = bp.copyWith(selectedDiscountSetting: ds);
                    missingIndices.remove(idx);
                    changed = true;
                    // continue searching others
                  }
                }
              }
            }
          },
          failure: (failure, status) {
            // ignore and continue
          },
        );
      }

      if (changed) {
        bags[selIdx] = bags[selIdx].copyWith(bagProducts: bagProducts);
        LocalStorage.setBags(bags);
        state = state.copyWith(bags: bags);
      }
    } catch (e) {
      debugPrint('_backfillDiscountSettingsFromPaginate failed: $e');
    }
  }

  Future<void> fetchCurrencies({VoidCallback? checkYourNetwork}) async {
    state = state.copyWith(isCurrenciesLoading: true, currencies: []);
    final response = await currenciesRepository.getCurrencies();
    response.when(
      success: (data) async {
        final currencies = data.data ?? [];
        state = state.copyWith(
          isCurrenciesLoading: false,
          currencies: currencies,
        );
        if (state.selectedCurrency == null && currencies.isNotEmpty) {
          setSelectedCurrency(currencies.first.id);
        }
      },
      failure: (failure, status) {
        state = state.copyWith(isCurrenciesLoading: false);
        debugPrint('==> get currencies failure: $failure');
      },
    );
  }

  void setSelectedCurrency(int? currencyId) {
    final List<BagData> bags = List.from(LocalStorage.getBags());
    final user = bags[state.selectedBagIndex].selectedUser;
    final address = bags[state.selectedBagIndex].selectedAddress;
    CurrencyData? currencyData;
    for (final currency in state.currencies) {
      if (currencyId == currency.id) {
        currencyData = currency;
        break;
      }
    }
    final BagData bag = bags[state.selectedBagIndex].copyWith(
      selectedAddress: address,
      selectedUser: user,
      selectedCurrency: currencyData,
    );
    bags[state.selectedBagIndex] = bag;
    LocalStorage.setBags(bags);
    state = state.copyWith(bags: bags, selectedCurrency: currencyData);
    fetchCarts(checkYourNetwork: () {}, isNotLoading: true);
  }

  Future<void> fetchPayments({VoidCallback? checkYourNetwork}) async {
    state = state.copyWith(isPaymentsLoading: true, payments: []);
    final response = await paymentsRepository.getPayments();
    response.when(
      success: (data) async {
        final List<PaymentData> payments = data.data ?? [];
        List<PaymentData> filteredPayments = [];
        PaymentData? selectedPayment;
        for (final payment in payments) {
          if (payment.tag == 'cash' ||
              payment.tag == 'e-wallet' ||
              payment.tag == 'visacard' ||
              payment.tag == 'rhb_dnqr' ||
              payment.tag == 'mastercard') {
            filteredPayments.add(payment);
          }
          if (payment.tag == 'cash') {
            selectedPayment = payment;
          }
        }
        if (selectedPayment == null && filteredPayments.isNotEmpty) {
          selectedPayment = filteredPayments.first;
        }

        // Update bags that don't have a selected payment yet
        final List<BagData> updatedBags = state.bags.map((bag) {
          if (bag.selectedPayment == null) {
            return bag.copyWith(selectedPayment: selectedPayment);
          }
          return bag;
        }).toList();

        LocalStorage.setBags(updatedBags);

        state = state.copyWith(
          isPaymentsLoading: false,
          payments: filteredPayments,
          selectedPayment: state.selectedPayment ?? selectedPayment,
          bags: updatedBags,
        );
      },
      failure: (failure, status) {
        state = state.copyWith(isPaymentsLoading: false);
        debugPrint('==> get payments failure: $failure');
      },
    );
  }

  void onDnqrSelected(PaymentData paymentData) {
    // Implement any special handling needed when RHB DNQR is selected
    // For example, you might want to set a flag in state or perform additional validation
    debugPrint('RHB DNQR payment method selected: ${paymentData.tag}');
  }

  void setSelectedPayment(int? paymentId) {
    final List<BagData> bags = List.from(LocalStorage.getBags());
    final user = bags[state.selectedBagIndex].selectedUser;
    final address = bags[state.selectedBagIndex].selectedAddress;
    PaymentData? paymentData;
    for (final payment in state.payments) {
      if (paymentId == payment.id) {
        paymentData = payment;
        break;
      }
    }
    final BagData bag = bags[state.selectedBagIndex].copyWith(
      selectedAddress: address,
      selectedUser: user,
      selectedPayment: paymentData,
    );
    bags[state.selectedBagIndex] = bag;
    LocalStorage.setBags(bags);
    state = state.copyWith(bags: bags, selectedPayment: paymentData);
  }

  void setSelectedBillDiscount(DiscountSetting? discount) {
    // Update the in-memory state and persist the change to LocalStorage.
    // Also update the `bags` list in state so UI that reads
    // `state.bags[state.selectedBagIndex].selectedBillDiscount` rebuilds
    // correctly and reflects the new selection immediately.
    try {
      final List<BagData> bags = List<BagData>.from(state.bags);
      final BagData oldBag = bags[state.selectedBagIndex];
      // BagData.copyWith currently treats `null` as "no change" for
      // selectedBillDiscount. Build a new BagData explicitly so passing
      // `null` will clear the bag's selectedBillDiscount as intended.
      final BagData updatedBag = BagData(
        index: oldBag.index,
        selectedUser: oldBag.selectedUser,
        selectedTable: oldBag.selectedTable,
        selectedSection: oldBag.selectedSection,
        selectedAddress: oldBag.selectedAddress,
        selectedCurrency: oldBag.selectedCurrency,
        selectedPayment: oldBag.selectedPayment,
        bagProducts: oldBag.bagProducts,
        selectedBillDiscount: discount,
      );
      bags[state.selectedBagIndex] = updatedBag;
      // persist
      LocalStorage.setBags(bags);
      // update state: both the selectedBillDiscount and the bags array
      state = state.copyWith(bags: bags, selectedBillDiscount: discount);
    } catch (e) {
      debugPrint('==> persist selected bill discount failed: $e');
      // fallback: still update selectedBillDiscount in state
      state = state.copyWith(selectedBillDiscount: discount);
    }

    fetchCarts(isNotLoading: true);
  }

  void setDate(DateTime date) {
    state = state.copyWith(orderDate: date);
  }

  void setTime(TimeOfDay time) {
    state = state.copyWith(orderTime: time);
  }

  void clearBag() {
    var newPagination = state.paginateResponse?.copyWith(stocks: []);
    state = state.copyWith(paginateResponse: newPagination);
    List<BagData> bags = List.from(LocalStorage.getBags());
    bags[state.selectedBagIndex] =
        bags[state.selectedBagIndex].copyWith(bagProducts: []);
    LocalStorage.setBags(bags);
  }

  void deleteProductFromBag(BuildContext context, BagProductData bagProduct) {
    final List<BagProductData> bagProducts = List.from(
        LocalStorage.getBags()[state.selectedBagIndex].bagProducts ?? []);
    int index = 0;
    for (int i = 0; i < bagProducts.length; i++) {
      if (bagProducts[i].stockId == bagProduct.stockId) {
        index = i;
        break;
      }
    }
    bagProducts.removeAt(index);
    List<BagData> bags = List.from(LocalStorage.getBags());
    bags[state.selectedBagIndex] =
        bags[state.selectedBagIndex].copyWith(bagProducts: bagProducts);
    LocalStorage.setBags(bags);
    fetchCarts(
      checkYourNetwork: () {
        AppHelpers.showSnackBar(
          context,
          AppHelpers.getTranslation(TrKeys.checkYourNetworkConnection),
        );
      },
    );
  }

  void deleteProductCount({
    required BagProductData? bagProductData,
    required int productIndex,
  }) {
    List<ProductData>? listOfProduct = state.paginateResponse?.stocks;
    listOfProduct?.removeAt(productIndex);
    PriceDate? data = state.paginateResponse;
    PriceDate? newData = data?.copyWith(stocks: listOfProduct);
    state = state.copyWith(paginateResponse: newData);
    final List<BagProductData> bagProducts =
        LocalStorage.getBags()[state.selectedBagIndex].bagProducts ?? [];
    bagProducts.removeAt(productIndex);

    List<BagData> bags = List.from(LocalStorage.getBags());
    bags[state.selectedBagIndex] =
        bags[state.selectedBagIndex].copyWith(bagProducts: bagProducts);
    LocalStorage.setBags(bags);

    fetchCarts(isNotLoading: true);
  }

  Future<void> decreaseProductCount({required int productIndex}) async {
    timer?.cancel();
    ProductData? product = state.paginateResponse?.stocks?[productIndex];

    if ((product?.quantity ?? 1) > 1) {
      ProductData? newProduct = product?.copyWith(
        quantity: ((product.quantity ?? 0) - 1),
      );
      List<ProductData>? listOfProduct = state.paginateResponse?.stocks;
      listOfProduct?.removeAt(productIndex);
      listOfProduct?.insert(productIndex, newProduct ?? ProductData());
      PriceDate? data = state.paginateResponse;
      PriceDate? newData = data?.copyWith(stocks: listOfProduct);
      state = state.copyWith(paginateResponse: newData);
      final List<BagProductData> bagProducts =
          LocalStorage.getBags()[state.selectedBagIndex].bagProducts ?? [];
      BagProductData newProductData = bagProducts[productIndex]
          .copyWith(quantity: (bagProducts[productIndex].quantity ?? 0) - 1);
      bagProducts.removeAt(productIndex);
      bagProducts.insert(productIndex, newProductData);

      List<BagData> bags = List.from(LocalStorage.getBags());
      bags[state.selectedBagIndex] =
          bags[state.selectedBagIndex].copyWith(bagProducts: bagProducts);
      LocalStorage.setBags(bags);
    } else {
      List<ProductData>? listOfProduct = state.paginateResponse?.stocks;
      listOfProduct?.removeAt(productIndex);
      PriceDate? data = state.paginateResponse;
      PriceDate? newData = data?.copyWith(stocks: listOfProduct);
      state = state.copyWith(paginateResponse: newData);
      final List<BagProductData> bagProducts =
          LocalStorage.getBags()[state.selectedBagIndex].bagProducts ?? [];
      for (int i = 0; i < bagProducts.length; i++) {
        if (bagProducts[i].stockId == product?.stock?.id) {
          bagProducts.removeAt(i);

          if (bagProducts.isNotEmpty) {
            final response = await productsRepository.getAllCalculations(
                bagProducts,
                state.orderType,
                state.coupon,
                state.selectedBillDiscount?.id);

            response.when(
              success: (data) {},
              failure: (error, statusCode) {
                clearBag();
              },
            );
          } else {
            clearBag();
          }
          break;
        }
      }

      List<BagData> bags = List.from(LocalStorage.getBags());
      bags[state.selectedBagIndex] =
          bags[state.selectedBagIndex].copyWith(bagProducts: bagProducts);
      LocalStorage.setBags(bags);
    }
    timer = Timer(
      const Duration(milliseconds: 500),
      () => fetchCarts(isNotLoading: true),
    );
  }

  void increaseProductCount({required int productIndex}) {
    timer?.cancel();
    ProductData? product = state.paginateResponse?.stocks?[productIndex];
    ProductData? newProduct = product?.copyWith(
      quantity: ((product.quantity ?? 0) + 1),
    );
    List<ProductData>? listOfProduct = state.paginateResponse?.stocks;
    listOfProduct?.removeAt(productIndex);
    listOfProduct?.insert(productIndex, newProduct ?? ProductData());
    PriceDate? data = state.paginateResponse;
    PriceDate? newData = data?.copyWith(stocks: listOfProduct);
    state = state.copyWith(paginateResponse: newData);
    final List<BagProductData> bagProducts =
        LocalStorage.getBags()[state.selectedBagIndex].bagProducts ?? [];

    BagProductData newProductData = bagProducts[productIndex]
        .copyWith(quantity: (bagProducts[productIndex].quantity ?? 0) + 1);
    bagProducts.removeAt(productIndex);
    bagProducts.insert(productIndex, newProductData);

    List<BagData> bags = List.from(LocalStorage.getBags());
    bags[state.selectedBagIndex] =
        bags[state.selectedBagIndex].copyWith(bagProducts: bagProducts);
    LocalStorage.setBags(bags);
    timer = Timer(
      const Duration(milliseconds: 500),
      () => fetchCarts(isNotLoading: true),
    );
  }

  Future<void> placeOrder({
    VoidCallback? checkYourNetwork,
    VoidCallback? openSelectDeliveriesDrawer,
  }) async {
    bool active = true;
    final globalSettings = LocalStorage.getSettingsList();
    final bool hideTable = globalSettings
            .firstWhere((element) => element.key == 'hide_table',
                orElse: () => SettingsData(value: '0'))
            .value ==
        '1';
    if (state.orderType == TrKeys.dine && !hideTable) {
      if (state.selectedSection == null) {
        active = false;
        state = state.copyWith(selectSectionError: TrKeys.selectSection);
      }
      if (state.selectedTable == null && !hideTable) {
        active = false;
        state = state.copyWith(selectTableError: TrKeys.selectTable);
      }
    }

    if (state.selectedCurrency == null) {
      active = false;
      state = state.copyWith(selectCurrencyError: TrKeys.selectCurrency);
    }
    if (state.selectedPayment == null) {
      active = false;
      state = state.copyWith(selectPaymentError: TrKeys.selectPayment);
    }

    if (state.orderType == TrKeys.delivery) {
      if (state.selectedUser?.phone?.isEmpty ?? true) {
        state = state.copyWith(
            selectedUser: state.selectedUser?.copyWith(phone: _phone));
      }
    }
    if (active) {
      openSelectDeliveriesDrawer?.call();
    }
  }

  setNote(String note) {
    final List<BagData> bags = List.from(state.bags);
    if (state.selectedBagIndex >= 0 && state.selectedBagIndex < bags.length) {
      final bag = bags[state.selectedBagIndex].copyWith(note: note);
      bags[state.selectedBagIndex] = bag;
      LocalStorage.setBags(bags);
      state = state.copyWith(comment: note, bags: bags);
    } else {
      state = state.copyWith(comment: note);
    }
  }

  Future createOrder(BuildContext context, OrderBodyData data,
      {Function(int orderId)? onSuccess}) async {
    state = state.copyWith(isOrderLoading: true);
    // final num wallet = state.selectedUser?.wallet?.price ?? 0;
    //Remove this validation as per requested by Client for Enhancement
    // if (data.bagData.selectedPayment?.tag == "wallet" &&
    //     wallet < (state.paginateResponse?.totalPrice ?? 0)) {
    //   if (context.mounted) {
    //     AppHelpers.showSnackBar(
    //         context, AppHelpers.getTranslation(TrKeys.notEnoughMoney));
    //   }

    //   state = state.copyWith(isOrderLoading: false);
    //   return;
    // }
    final response = await ordersRepository.createOrder(data);
    response.when(
      success: (res) async {
        switch (data.bagData.selectedPayment?.tag) {
          case 'cash':
            paymentsRepository.createTransaction(
                orderId: res.data?.id ?? 0,
                paymentId: data.bagData.selectedPayment?.id ?? 1);
            break;
          case 'wallet':
            paymentsRepository.createTransaction(
                orderId: res.data?.id ?? 0,
                paymentId: data.bagData.selectedPayment?.id ?? 1);
            break;
          default:
            paymentsRepository.createTransaction(
                orderId: res.data?.id ?? 0,
                paymentId: data.bagData.selectedPayment?.id ?? 1);
            break;
        }
        state = state.copyWith(isOrderLoading: false);
        removeOrderedBag(context);
        onSuccess?.call(res.data?.id ?? 0);
      },
      failure: (failure, status) async {
        // Try to parse invalid stock_id from backend error
        final errorString = failure.toString();
        final regExp = RegExp(r'products[ .](\d+)[ .]stock_id');
        final match = regExp.firstMatch(errorString);
        if (match != null && match.groupCount >= 1) {
          final invalidIndex = int.tryParse(match.group(1)!);
          if (invalidIndex != null) {
            final bags = LocalStorage.getBags();
            if (bags.isNotEmpty && state.selectedBagIndex < bags.length) {
              final bag = bags[state.selectedBagIndex];
              final products = List<BagProductData>.from(bag.bagProducts ?? []);
              if (invalidIndex < products.length) {
                products.removeAt(invalidIndex);
                bags[state.selectedBagIndex] =
                    bag.copyWith(bagProducts: products);
                await LocalStorage.setBags(bags);
                // Reload bag state from LocalStorage to ensure UI is in sync
                final updatedBags = LocalStorage.getBags();
                state = state.copyWith(
                  bags: updatedBags,
                );
              }
            }
          }
        }
        state = state.copyWith(isOrderLoading: false);
        if (context.mounted) {
          AppHelpers.showSnackBar(context, failure);
        }
      },
    );
  }
}
