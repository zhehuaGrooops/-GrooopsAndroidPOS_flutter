// ignore_for_file: prefer_null_aware_operators

import 'dart:async';
import 'package:admin_desktop/src/core/routes/app_router.dart';
import 'package:admin_desktop/src/models/data/order_data.dart';
import 'package:admin_desktop/src/models/response/product_calculate_response.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/constants/constants.dart';
import '../../../../../core/utils/utils.dart';
import '../../../../../models/models.dart';
import '../../../../../repository/repository.dart';
import '../../../../../core/di/injection.dart';
import '../state/main_state.dart';

class MainNotifier extends StateNotifier<MainState> {
  final ProductsRepository _productsRepository;
  final CategoriesRepository _categoriesRepository;
  final BrandsRepository _brandsRepository;
  final UsersRepository _usersRepository;

  Timer? _searchProductsTimer;
  Timer? _searchCategoriesTimer;
  Timer? _searchBrandsTimer;
  int _page = 0;

  MainNotifier(
    this._productsRepository,
    this._categoriesRepository,
    this._brandsRepository,
    this._usersRepository,
  ) : super(const MainState());

  changeIndex(int index) {
    state = state.copyWith(selectIndex: index);
  }

  setOrder(OrderData? order) {
    state = state.copyWith(selectedOrder: order);
  }

  setPriceDate(PriceDate? priceDate) {
    state = state.copyWith(priceDate: priceDate);
  }

  Future<void> fetchUserDetail({VoidCallback? checkYourNetwork}) async {
    final response = await _usersRepository.getProfileDetails();
    response.when(
      success: (data) async {},
      failure: (failure, status) {
        debugPrint('==> get user detail failure: $failure');
      },
    );
  }

  // TEST FUNCTION TO FORCE REFRESH
  void refreshProducts({
    BuildContext? context,
    ProductPricingTier? pricingTier,
    Map<int, num>? tierPrices, // optional client-side overrides
  }) {
    // Step 1: Immediately clear the product list and set loading state.
    // This is the most critical step for forcing a UI rebuild.
    _page = 0;
    state =
        state.copyWith(products: [], isProductsLoading: true, hasMore: true);

    // Step 2: Call the original fetch function to get the new data.
    fetchProducts(
      context: context,
      pricingTier: pricingTier,
      tierPrices: tierPrices,
      checkYourNetwork: context != null
          ? () {
              AppHelpers.showSnackBar(
                context,
                AppHelpers.getTranslation(TrKeys.checkYourNetworkConnection),
              );
            }
          : null,
    );
  }

  /// Reset notifier state for logout: cancel timers and clear product pagination/state.
  void resetForLogout() {
    _searchProductsTimer?.cancel();
    _searchCategoriesTimer?.cancel();
    _searchBrandsTimer?.cancel();
    _page = 0;
    state = const MainState(selectIndex: 0);
  }

  Future<void> fetchProducts({
    BuildContext? context,
    VoidCallback? checkYourNetwork,
    ProductPricingTier? pricingTier,
    Map<int, num>? tierPrices,
  }) async {
    if (!state.hasMore && _page != 0) {
      // Allow the first fetch even if hasMore is false
      return;
    }
    if (_page == 0) {
      // For the first page, clear the existing products and set the main loading flag
      state = state.copyWith(isProductsLoading: true, products: []);
    } else {
      // For subsequent pages, use the 'more loading' flag
      state = state.copyWith(isMoreProductsLoading: true);
    }

    final response = await _productsRepository.getProductsPaginate(
      page: ++_page,
      query: state.query.isEmpty ? null : state.query,
      shopId: state.selectedShop?.id,
      categoryId: state.selectedCategory?.id,
      brandId: state.selectedBrand?.id,
    );

    response.when(
      success: (data) {
        final newProducts = data.data ?? [];

        // Create a new list by combining the old and new products
        List<ProductData> updatedProducts =
            _page == 1 ? newProducts : [...state.products, ...newProducts];

        // If caller provided tierPrices (client-side overrides), apply them to the displayed products.
        if (tierPrices != null && tierPrices.isNotEmpty) {
          updatedProducts = updatedProducts.map((p) {
            final pid = p.id;
            if (pid != null && tierPrices.containsKey(pid)) {
              final num newPrice = tierPrices[pid] ?? (p.price ?? 0);
              // Update stocks list if present
              final List<Stocks>? stocks = p.stocks;
              if (stocks != null && stocks.isNotEmpty) {
                final newStocks = stocks.map((s) {
                  return s.copyWith(
                    price: newPrice,
                    totalPrice: newPrice * (s.quantity ?? 1),
                  );
                }).toList();
                return p.copyWith(stocks: newStocks);
              }

              // Fallback: update top-level price
              return p.copyWith(price: newPrice);
            }
            return p;
          }).toList();
        }

        // Replace the state with a new one
        state = state.copyWith(
          products: updatedProducts,
          isProductsLoading: false,
          isMoreProductsLoading: false,
          hasMore: newProducts.length >= 12,
        );
      },
      failure: (failure, status) {
        state = state.copyWith(
            isProductsLoading: false, isMoreProductsLoading: false);
        debugPrint('==> get products failure: $failure');
      },
    );
  }

  void setProductsQuery(BuildContext context, String query,
      {ProductPricingTier? pricingTier, Map<int, num>? tierPrices}) {
    if (state.query == query) {
      return;
    }
    state = state.copyWith(query: query.trim());
    if (_searchProductsTimer?.isActive ?? false) {
      _searchProductsTimer?.cancel();
    }
    _searchProductsTimer = Timer(
      const Duration(milliseconds: 500),
      () {
        refreshProducts(
          context: context,
          pricingTier: pricingTier,
          tierPrices: tierPrices,
        );
      },
    );
  }

  Future<void> fetchCategories(
      {required BuildContext context, VoidCallback? checkYourNetwork}) async {
    state = state.copyWith(
      isCategoriesLoading: true,
      dropDownCategories: [],
      categories: [],
    );
    final response = await _categoriesRepository.searchCategories(
        state.categoryQuery.isEmpty ? null : state.categoryQuery);
    response.when(
      success: (data) async {
        final List<CategoryData> categories = data.data ?? [];
        state = state.copyWith(
          isCategoriesLoading: false,
          categories: categories,
        );
      },
      failure: (failure, status) {
        state = state.copyWith(isCategoriesLoading: false);
        if (status == 401) {
          context.replaceRoute(const LoginRoute());
          LocalStorage.clearStore();
        }
      },
    );
  }

  void setCategoriesQuery(BuildContext context, String query) {
    debugPrint('===> set categories query: $query');
    if (state.categoryQuery == query) {
      return;
    }
    state = state.copyWith(categoryQuery: query.trim());
    if (_searchCategoriesTimer?.isActive ?? false) {
      _searchCategoriesTimer?.cancel();
    }
    _searchCategoriesTimer = Timer(
      const Duration(milliseconds: 500),
      () {
        state = state.copyWith(categories: [], dropDownCategories: []);
        fetchCategories(
          context: context,
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

  void setSelectedCategory(
    BuildContext context,
    int index, {
    ProductPricingTier? pricingTier,
    Map<int, num>? tierPrices,
  }) {
    if (index == -1) {
      state = state.copyWith(selectedCategory: null, hasMore: true);
    } else {
      final category = state.categories[index];
      if (category.id != state.selectedCategory?.id) {
        state = state.copyWith(selectedCategory: category, hasMore: true);
      } else {
        state = state.copyWith(selectedCategory: null, hasMore: true);
      }
    }

    refreshProducts(
      context: context,
      pricingTier: pricingTier,
      tierPrices: tierPrices,
    );
    setCategoriesQuery(context, '');
  }

  void removeSelectedCategory(BuildContext context) {
    state = state.copyWith(selectedCategory: null, hasMore: true);
    refreshProducts(context: context);
  }

  Future<void> fetchBrands({VoidCallback? checkYourNetwork}) async {
    state = state.copyWith(
      isBrandsLoading: true,
      dropDownBrands: [],
      brands: [],
    );
    final response = await _brandsRepository
        .searchBrands(state.brandQuery.isEmpty ? null : state.brandQuery);
    response.when(
      success: (data) async {
        final List<BrandData> brands = data.data ?? [];
        List<DropDownItemData> dropdownBrands = [];
        for (int i = 0; i < brands.length; i++) {
          dropdownBrands.add(
            DropDownItemData(
              index: i,
              title: brands[i].title ?? 'No category title',
            ),
          );
        }
        state = state.copyWith(
          isBrandsLoading: false,
          brands: brands,
          dropDownBrands: dropdownBrands,
        );
      },
      failure: (failure, status) {
        state = state.copyWith(isBrandsLoading: false);
        debugPrint('==> get brands failure: $failure');
      },
    );
  }

  /// Open a cash session via API and store the session info locally
  Future<void> openCashSession(BuildContext context,
      {required Map<String, dynamic> body}) async {
    try {
      final repo = inject<CashSessionsRepository>();
      final response = await repo.openCashSession(body: body);
      response.when(success: (data) async {
        // store session data in local storage
        await LocalStorage.setCashSession(data ?? {});
        if (context.mounted) {
          AppHelpers.showSnackBar(
              context, AppHelpers.getTranslation(TrKeys.placeOrder));
        }
      }, failure: (failure, status) {
        if (context.mounted) AppHelpers.showSnackBar(context, failure);
      });
    } catch (e) {
      debugPrint('==> open cash session error: $e');
      if (context.mounted) {
        AppHelpers.showSnackBar(
            context, AppHelpers.getTranslation(TrKeys.placeOrder));
      }
    }
  }

  void setBrandsQuery(BuildContext context, String query) {
    if (state.brandQuery == query) {
      return;
    }
    state = state.copyWith(brandQuery: query.trim());
    if (_searchBrandsTimer?.isActive ?? false) {
      _searchBrandsTimer?.cancel();
    }
    _searchBrandsTimer = Timer(
      const Duration(milliseconds: 500),
      () {
        state = state.copyWith(brands: [], dropDownBrands: []);
        fetchBrands(
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

  void setSelectedBrand(BuildContext context, int index) {
    final brand = state.brands[index];
    state = state.copyWith(selectedBrand: brand, hasMore: true);
    refreshProducts(context: context);
    setBrandsQuery(context, '');
  }

  void removeSelectedBrand(BuildContext context) {
    state = state.copyWith(selectedBrand: null, hasMore: true);
    _page = 0;
    fetchProducts(
      context: context,
      checkYourNetwork: () {
        AppHelpers.showSnackBar(
          context,
          AppHelpers.getTranslation(TrKeys.checkYourNetworkConnection),
        );
      },
    );
  }
}
