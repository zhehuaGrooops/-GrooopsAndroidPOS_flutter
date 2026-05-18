import 'package:admin_desktop/src/core/constants/hive_boxes.dart';
import 'package:admin_desktop/src/core/handlers/handlers.dart';
import 'package:admin_desktop/src/core/utils/local_storage.dart';
import 'package:admin_desktop/src/models/models.dart';
import 'package:admin_desktop/src/models/response/product_calculate_response.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../core/db/hive_service.dart';
import '../products_repository.dart';

class ProductsHiveRepository extends ProductsRepository {
  Future<Box> _productsBox() => HiveService.openBox(HiveBoxes.products);
  Future<Box> _shopsBox() => HiveService.openBox(HiveBoxes.shops);
  Future<Box> _settingsBox() => HiveService.openBox(HiveBoxes.settings);
  Future<Box> _tiersBox() => HiveService.openBox(HiveBoxes.pricingTiers);
  Future<Box> _discountBox() => HiveService.openBox(HiveBoxes.discountSettings);

  @override
  Future<ApiResult<ProductsPaginateResponse>> getProductsPaginate({
    String? query,
    int? categoryId,
    int? brandId,
    int? shopId,
    required int page,
  }) async {
    try {
      final box = await _productsBox();
      final items = box.values.whereType<Map>().toList();
      final filtered = items.where((e) {
        final title = (((e['translation'] ?? {}) as Map)['title'] ?? '')
            .toString()
            .toLowerCase();
        final matchesQuery =
            query == null || title.contains(query.toLowerCase());
        final matchesCategory =
            categoryId == null || e['category_id'] == categoryId;
        final matchesBrand = brandId == null || e['brand_id'] == brandId;
        return matchesQuery && matchesCategory && matchesBrand;
      }).toList();
      final perPage = 12;
      final start = (page - 1) * perPage;
      final end = (start + perPage) > filtered.length
          ? filtered.length
          : (start + perPage);
      final pageItems = filtered.sublist(
          start < filtered.length ? start : filtered.length, end);
      final data = pageItems
          .map((e) => ProductData.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return ApiResult.success(
        data: ProductsPaginateResponse(data: data),
      );
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<ProductCalculateResponse>> getAllCalculations(
    List<BagProductData> bagProducts,
    String type,
    String? coupon,
    int? discountSettingId,
  ) async {
    try {
      final productCalc = await _buildCalculationResponse(
        bagProducts,
        type,
        coupon,
        discountSettingId,
      );
      return ApiResult.success(data: productCalc);
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> getProductByUuid(String uuid) async {
    try {
      final box = await _productsBox();
      for (final value in box.values) {
        if (value is Map && value['uuid'] == uuid) {
          return ApiResult.success(data: Map<String, dynamic>.from(value));
        }
      }
      return ApiResult.failure(error: 'Not found');
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<Map<String, dynamic>>> getProductByStockId(
      int stockId) async {
    try {
      final box = await _productsBox();
      for (final value in box.values) {
        if (value is! Map) continue;
        final map = Map<String, dynamic>.from(value);

        if (map['stock_id'] == stockId || map['id'] == stockId) {
          return ApiResult.success(data: map);
        }

        final stock = map['stock'];
        if (stock is Map && stock['id'] == stockId) {
          return ApiResult.success(data: map);
        }

        final stocks = map['stocks'];
        if (stocks is List) {
          for (final s in stocks) {
            if (s is Map && s['id'] == stockId) {
              return ApiResult.success(data: map);
            }
          }
        }
      }
      return ApiResult.failure(error: 'Not found');
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<List<DiscountSetting>>> getDiscountSettingsSelectPaginate({
    int? page,
    String? query,
  }) async {
    try {
      final box = await _discountBox();
      final items = box.values.whereType<Map>().toList();
      final filtered = items.where((e) {
        final title = (e['title'] ?? '').toString().toLowerCase();
        return query == null || title.contains(query.toLowerCase());
      }).toList();
      final result = filtered
          .map((e) => DiscountSetting.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return ApiResult.success(data: result);
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<List<ProductPricingTier>>> getProductPricingTiers() async {
    try {
      final box = await _tiersBox();
      final List<ProductPricingTier> allTiers = box.values
          .whereType<Map>()
          .map((e) => ProductPricingTier.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      // Final deduplication by title (case-insensitive) to ensure clean UI
      final Map<String, ProductPricingTier> uniqueTiers = {};
      for (final tier in allTiers) {
        final title = tier.title?.trim().toLowerCase();
        if (title != null &&
            title.isNotEmpty &&
            !uniqueTiers.containsKey(title)) {
          uniqueTiers[title] = tier;
        }
      }

      return ApiResult.success(data: uniqueTiers.values.toList());
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<List<ProductData>>> getTierProducts(String tierName) async {
    try {
      final searchName = tierName.trim();
      final box = await _productsBox();
      final List<ProductData> list = [];

      for (final value in box.values) {
        if (value is! Map) continue;
        final map = Map<String, dynamic>.from(value);

        final tiers = map['product_pricing_tiers'];
        if (tiers == null) {
          // Fallback to old structure if available
          if (map['tier_name']?.toString().trim().toLowerCase() ==
              searchName.toLowerCase()) {
            list.add(ProductData.fromJson(map));
          }
          continue;
        }

        if (tiers is List) {
          if (tiers.isEmpty) {}
          for (final tierMap in tiers) {
            if (tierMap is Map) {
              // Try to match the tier name with title, slug, or any translation
              String? title = tierMap['pricing_tier_name'] ?? tierMap['slug'];

              // Check all translations for a match
              if (tierMap['translations'] is List) {
                for (final t in (tierMap['translations'] as List)) {
                  if (t is Map && t['title'] != null) {
                    final tTitle = t['title'].toString().trim();
                    if (tTitle.toLowerCase() == searchName.toLowerCase()) {
                      title = t['title'];
                      break;
                    }
                  }
                }
              }

              final candidateTitle = title?.trim() ?? "";

              if (candidateTitle.toLowerCase() == searchName.toLowerCase()) {
                // Found a match! Create a copy of the product and override the price.
                final correctedProductMap = Map<String, dynamic>.from(map);
                final newPrice =
                    num.tryParse(tierMap['price']?.toString() ?? '0') ?? 0;
                correctedProductMap['price'] = newPrice;

                // Also update prices in the stocks list if it exists
                if (correctedProductMap['stocks'] is List) {
                  final List rawStocks =
                      List.from(correctedProductMap['stocks']);
                  final List<Map<String, dynamic>> stocks = [];
                  for (var s in rawStocks) {
                    if (s is Map) {
                      final stockMap = Map<String, dynamic>.from(s);
                      stockMap['price'] = newPrice;
                      stocks.add(stockMap);
                    }
                  }
                  correctedProductMap['stocks'] = stocks;
                }

                list.add(ProductData.fromJson(correctedProductMap));
                break; // Move to next product
              }
            }
          }
        } else if (map['tier_name']?.toString().trim() == searchName) {
          // Fallback for old structure
          list.add(ProductData.fromJson(map));
        }
      }

      return ApiResult.success(data: list);
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<void>> deductProductStock(int stockId, int quantity) async {
    try {
      final box = await _productsBox();
      for (var key in box.keys) {
        final value = box.get(key);
        if (value is! Map) continue;

        final productMap = Map<String, dynamic>.from(value);
        bool found = false;

        // Check main stock
        final mainStock = productMap['stock'];
        if (mainStock is Map && mainStock['id'] == stockId) {
          final currentQty = _num(mainStock['quantity']) ?? 0;
          if (currentQty < quantity) {
            return const ApiResult.failure(error: 'Insufficient stock');
          }
          final updatedStock = Map<String, dynamic>.from(mainStock);
          updatedStock['quantity'] = (currentQty - quantity).toInt();
          productMap['stock'] = updatedStock;

          // Also update product aggregate quantity
          final prodQty = _num(productMap['quantity']) ?? 0;
          productMap['quantity'] = (prodQty - quantity).toInt();

          found = true;
        }

        // Check nested stocks
        if (!found && productMap['stocks'] is List) {
          final stocks = List.from(productMap['stocks']);
          for (var i = 0; i < stocks.length; i++) {
            if (stocks[i] is Map && stocks[i]['id'] == stockId) {
              final currentQty = _num(stocks[i]['quantity']) ?? 0;
              if (currentQty < quantity) {
                return const ApiResult.failure(error: 'Insufficient stock');
              }
              final updatedStock = Map<String, dynamic>.from(stocks[i]);
              updatedStock['quantity'] = (currentQty - quantity).toInt();
              stocks[i] = updatedStock;
              productMap['stocks'] = stocks;

              // Also update product aggregate quantity
              final prodQty = _num(productMap['quantity']) ?? 0;
              productMap['quantity'] = (prodQty - quantity).toInt();

              found = true;
              break;
            }
          }
        }

        if (found) {
          await box.put(key, productMap);
          return const ApiResult.success(data: null);
        }
      }
      return const ApiResult.failure(error: 'Stock not found');
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<void>> addProductStock(int stockId, int quantity) async {
    try {
      final box = await _productsBox();
      for (var key in box.keys) {
        final value = box.get(key);
        if (value is! Map) continue;

        final productMap = Map<String, dynamic>.from(value);
        bool found = false;

        // Check main stock
        final mainStock = productMap['stock'];
        if (mainStock is Map && mainStock['id'] == stockId) {
          final currentQty = _num(mainStock['quantity']) ?? 0;
          final updatedStock = Map<String, dynamic>.from(mainStock);
          updatedStock['quantity'] = (currentQty + quantity).toInt();
          productMap['stock'] = updatedStock;

          // Also update product aggregate quantity
          final prodQty = _num(productMap['quantity']) ?? 0;
          productMap['quantity'] = (prodQty + quantity).toInt();

          found = true;
        }

        // Check nested stocks
        if (!found && productMap['stocks'] is List) {
          final stocks = List.from(productMap['stocks']);
          for (var i = 0; i < stocks.length; i++) {
            if (stocks[i] is Map && stocks[i]['id'] == stockId) {
              final currentQty = _num(stocks[i]['quantity']) ?? 0;
              final updatedStock = Map<String, dynamic>.from(stocks[i]);
              updatedStock['quantity'] = (currentQty + quantity).toInt();
              stocks[i] = updatedStock;
              productMap['stocks'] = stocks;

              // Also update product aggregate quantity
              final prodQty = _num(productMap['quantity']) ?? 0;
              productMap['quantity'] = (prodQty + quantity).toInt();

              found = true;
              break;
            }
          }
        }

        if (found) {
          await box.put(key, productMap);
          return const ApiResult.success(data: null);
        }
      }
      return const ApiResult.failure(error: 'Stock not found');
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<void>> deductAddonStock(
      int countableId, int quantity) async {
    return _updateAddonStock(countableId, -quantity);
  }

  @override
  Future<ApiResult<void>> addAddonStock(int countableId, int quantity) async {
    return _updateAddonStock(countableId, quantity);
  }

  Future<ApiResult<void>> _updateAddonStock(
      int countableId, int quantityDelta) async {
    try {
      final box = await _productsBox();

      for (var key in box.keys) {
        final value = box.get(key);
        if (value is! Map) continue;

        final productMap = Map<String, dynamic>.from(value);
        bool productUpdated = false;

        // Only check stock-level addons as per requirement
        if (productMap['stocks'] is List) {
          final stocks = List.from(productMap['stocks']);
          for (var i = 0; i < stocks.length; i++) {
            if (stocks[i] is! Map) continue;
            final stockMap = Map<String, dynamic>.from(stocks[i]);

            if (stockMap['addons'] is List) {
              final addons = List.from(stockMap['addons']);
              bool stockUpdated = false;

              for (var j = 0; j < addons.length; j++) {
                if (addons[j] is! Map) continue;
                final addonMap = Map<String, dynamic>.from(addons[j]);

                // Path: stocks.addons.product.stock.quantity
                // Identifier: stocks.addons.product.stock.countable_id
                final stock = addonMap['stock'];
                if (stock is Map &&
                    _num(stock['countable_id']) == countableId) {
                  final currentQty = _num(stock['quantity']) ?? 0;
                  debugPrint('currentQty: $currentQty');
                  debugPrint('quantityDelta: $quantityDelta');

                  final newQty = (currentQty + quantityDelta).toInt();
                  debugPrint('newQty: $newQty');

                  final updatedStock = Map<String, dynamic>.from(stock);
                  updatedStock['quantity'] = newQty;

                  addonMap['stock'] = updatedStock;
                  addons[j] = addonMap;
                  stockUpdated = true;
                }
              }

              if (stockUpdated) {
                stockMap['addons'] = addons;
                stocks[i] = stockMap;
                productUpdated = true;
              }
            }
          }

          if (productUpdated) {
            productMap['stocks'] = stocks;
            await box.put(key, productMap);
          }
        }
      }

      return const ApiResult.success(data: null);
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  /// Helper method to build a `ProductCalculateResponse` from local Hive data.
  Future<ProductCalculateResponse> _buildCalculationResponse(
    List<BagProductData> bagProducts,
    String type,
    String? coupon,
    int? discountSettingId,
  ) async {
    final productsBox = await _productsBox();

    final num rate = LocalStorage.getSelectedCurrency().rate ?? 1;

    // Best-effort shop lookup (needed for shop tax & returning shop object)
    final user = LocalStorage.getUser();
    final int shopId = user?.invite?.shopId ?? user?.shop?.id ?? 0;
    final ShopData? shop = await _findShopById(shopId);

    final num serviceFee = await _readServiceFee() * rate;
    final num tips = 0;
    num deliveryFee = 0;

    final List<ProductData> calculatedItems = [];
    num sumPrice = 0;
    num sumDiscount = 0;
    num sumTotalPrice = 0;

    for (final bag in bagProducts) {
      final int? stockId = bag.stockId;
      if (stockId == null) continue;

      final Map<String, dynamic>? productMap =
          _findProductMapByStockId(productsBox, stockId);
      if (productMap == null) continue;

      final Map<String, dynamic> stockMap = _buildStockMap(productMap, stockId);

      // Quantity normalization (Laravel actualQuantity)
      final int requestedQty = bag.quantity ?? 0;
      final int quantity = _actualQuantity(
          stockMap: stockMap, productMap: productMap, requested: requestedQty);
      if (quantity <= 0) continue;

      final num unitPrice =
          _num(stockMap['price']) ?? _num(productMap['price']) ?? 0;
      final num unitDiscount = _num(stockMap['actual_discount']) ??
          _num(stockMap['discount']) ??
          _num(productMap['discount']) ??
          0;
      final num unitTax = _taxPerUnit(
          stockMap: stockMap, productMap: productMap, unitPrice: unitPrice);

      num price = unitPrice * rate * quantity;
      num discount = unitDiscount * rate * quantity;
      num tax = unitTax * rate * quantity;
      num totalPrice = (price - discount + tax);
      if (totalPrice < 0) totalPrice = 0;

      final List<Map<String, dynamic>> addons = [];
      for (final addon in bag.carts ?? <BagProductData>[]) {
        final int? addonStockId = addon.stockId;
        if (addonStockId == null) continue;

        Map<String, dynamic>? addonProductMap;
        Map<String, dynamic>? addonStockMap;

        // Check in current product's top-level addons
        final productAddons = productMap['addons'];
        if (productAddons is List) {
          for (final a in productAddons) {
            if (a is Map && a['product'] is Map) {
              final ap = a['product'];
              final as = ap['stock'] ?? a['stock']; // Check both locations
              if (as is Map && as['id'] == addonStockId) {
                addonProductMap = Map<String, dynamic>.from(ap);
                addonStockMap = Map<String, dynamic>.from(as);
                break;
              }
            }
          }
        }

        final stockAddons = stockMap['addons'];
        if (stockAddons is List) {
          for (final a in stockAddons) {
            if (a is Map && a['product'] is Map) {
              final ap = a['product'];
              final as = ap['stock'] ?? a['stock']; // Check both locations
              if (as is Map && as['countable_id'] == addonStockId) {
                addonProductMap = Map<String, dynamic>.from(ap);
                addonStockMap = Map<String, dynamic>.from(as);
                break;
              }
            }
          }
        }

        // Fallback: search the whole box
        // if (addonProductMap == null) {
        //   addonProductMap = _findProductMapByStockId(productsBox, addonStockId);
        //   if (addonProductMap != null) {
        //     addonStockMap = _buildStockMap(addonProductMap, addonStockId);
        //   }
        // }

        if (addonProductMap == null || addonStockMap == null) {
          continue;
        }

        final int addonQty = _actualQuantity(
          stockMap: addonStockMap,
          productMap: addonProductMap,
          requested: addon.quantity ?? 0,
        );
        if (addonQty <= 0) continue;

        final num addonUnitPrice =
            _num(addonStockMap['price']) ?? _num(addonProductMap['price']) ?? 0;
        final num addonUnitDiscount = _num(addonStockMap['actual_discount']) ??
            _num(addonStockMap['discount']) ??
            _num(addonProductMap['discount']) ??
            0;
        final num addonUnitTax = _taxPerUnit(
            stockMap: addonStockMap,
            productMap: addonProductMap,
            unitPrice: addonUnitPrice);

        final num addonPrice = addonUnitPrice * rate * addonQty * quantity;
        final num addonDiscount =
            addonUnitDiscount * rate * addonQty * quantity;
        final num addonTax = addonUnitTax * rate * addonQty * quantity;
        num addonTotal = addonPrice - addonDiscount + addonTax;
        if (addonTotal < 0) addonTotal = 0;

        // Parent totals include addon amounts (Laravel behavior)
        price += addonPrice;
        discount += addonDiscount;
        tax += addonTax;
        totalPrice += addonTotal;

        final addonJson = <String, dynamic>{
          'id': addonStockMap['id'],
          'stock_id': addonStockId,
          'price': addonPrice,
          'quantity': addonQty * quantity,
          'total_price': addonTotal,
          'discount': addonDiscount,
          'tax': addonTax,
          'active': true,
          'product': addonProductMap,
          'stock': Map<String, dynamic>.from(addonStockMap)
            ..['id'] = addonStockId
            ..['price'] = addonUnitPrice * rate
            ..['quantity'] = addonQty
            ..['product'] = addonProductMap,
        };

        addons.add(addonJson);
      }

      final itemJson = <String, dynamic>{
        'id': stockId,
        'uuid': productMap['uuid'],
        'price': price + tax, // server returns item price INCLUDING tax
        'quantity': quantity,
        'tax': tax,
        'discount': discount,
        'total_price': totalPrice,
        'stock': stockMap
          ..['addons'] = addons, // Also put addons into stock for parsing
        'addons': addons,
        'translation': productMap['translation'],
        'category': productMap['category'],
        'brand': productMap['brand'],
        'unit': productMap['unit'],
        'img': productMap['img'],
      };

      final productData = ProductData.fromJson(itemJson);
      calculatedItems.add(productData);

      sumPrice += (itemJson['price'] as num);
      sumDiscount += discount;
      sumTotalPrice += totalPrice;
    }

    // Shop tax is computed from shop.tax% if shop available; Laravel currently has this commented
    // but still returns it as total_tax/total_shop_tax.
    num shopTax = 0;
    final num? shopTaxPercent = shop?.tax;
    if (shopTaxPercent != null && shopTaxPercent > 0 && shopTaxPercent <= 100) {
      shopTax = ((sumTotalPrice / rate) / 100 * shopTaxPercent) * rate;
      if (shopTax < 0) shopTax = 0;
    }

    // Coupon logic requires coupon storage + validation rules; keep 0 until coupons are cached.
    final num couponPrice = 0;

    // Final total: subtotal + deliveryFee + shopTax + serviceFee + tips - couponPrice
    num finalTotal =
        sumTotalPrice + deliveryFee + shopTax + serviceFee + tips - couponPrice;
    if (finalTotal < 0) finalTotal = 0;

    final priceDate = PriceDate(
      stocks: calculatedItems,
      totalTax: shopTax,
      price: sumPrice,
      totalShopTax: shopTax,
      totalPrice: finalTotal,
      totalDiscount: sumDiscount,
      deliveryFee: deliveryFee,
      serviceFee: serviceFee,
      rate: rate,
      couponPrice: couponPrice,
      shop: shop,
      km: null,
    );

    final response = ProductCalculateResponse(
      timestamp: DateTime.now(),
      status: true,
      message: 'Success',
      data: ProductCalculateResponseData(
        status: true,
        code: 'NO_ERROR',
        data: priceDate,
      ),
    );

    return response;
  }

  Map<String, dynamic>? _findProductMapByStockId(Box productsBox, int stockId) {
    for (final value in productsBox.values) {
      if (value is! Map) continue;
      final map = Map<String, dynamic>.from(value);

      // Check main stock
      final stock = map['stock'];
      if (stock is Map && stock['id'] == stockId) {
        return map;
      }

      // Check nested stocks
      final stocks = map['stocks'];
      if (stocks is List) {
        for (final s in stocks) {
          if (s is Map && s['id'] == stockId) {
            return map;
          }
        }
      }

      // Search in top-level addons list
      final addons = map['addons'];
      if (addons is List) {
        for (final addon in addons) {
          if (addon is Map && addon['product'] is Map) {
            final addonProduct = addon['product'];
            final addonStock = addonProduct['stock'];
            if (addonStock is Map && addonStock['id'] == stockId) {
              return Map<String, dynamic>.from(addonProduct);
            }
          }
        }
      }

      // Search in addons of the main stock
      if (stock is Map) {
        final stockAddons = stock['addons'];
        if (stockAddons is List) {
          for (final addon in stockAddons) {
            if (addon is Map && addon['product'] is Map) {
              final addonProduct = addon['product'];
              final addonStock = addonProduct['stock'];
              if (addonStock is Map && addonStock['id'] == stockId) {
                return Map<String, dynamic>.from(addonProduct);
              }
            }
          }
        }
      }

      // Search in addons of nested stocks
      if (stocks is List) {
        for (final s in stocks) {
          if (s is Map) {
            final stockAddons = s['addons'];
            if (stockAddons is List) {
              for (final addon in stockAddons) {
                if (addon is Map && addon['product'] is Map) {
                  final addonProduct = addon['product'];
                  final addonStock = addonProduct['stock'];
                  if (addonStock is Map && addonStock['id'] == stockId) {
                    return Map<String, dynamic>.from(addonProduct);
                  }
                }
              }
            }
          }
        }
      }

      // Fallback: direct ID match
      if (map['stock_id'] == stockId || map['id'] == stockId) return map;
    }
    return null;
  }

  Map<String, dynamic> _buildStockMap(
      Map<String, dynamic> productMap, int stockId) {
    // 1. Try to find the exact stock in main stock
    final mainStock = productMap['stock'];
    if (mainStock is Map && mainStock['id'] == stockId) {
      final map = Map<String, dynamic>.from(mainStock);
      map.putIfAbsent('product', () => productMap);
      return map;
    }

    // 2. Try to find the exact stock in nested stocks
    final stocks = productMap['stocks'];
    if (stocks is List) {
      final match = stocks.whereType<Map>().firstWhere(
            (s) => s['id'] == stockId,
            orElse: () => <dynamic, dynamic>{},
          );
      if (match.isNotEmpty) {
        final map = Map<String, dynamic>.from(match);
        map.putIfAbsent('id', () => stockId);
        map.putIfAbsent('product', () => productMap);
        map.putIfAbsent('countable_id', () => productMap['id']);
        return map;
      }
    }

    // 3. If it's a simple product and we're just matching product ID, return main stock anyway
    if (mainStock is Map) {
      final map = Map<String, dynamic>.from(mainStock);
      map.putIfAbsent('product', () => productMap);
      return map;
    }

    // Fallback: wrap product as stock-like payload.
    return <String, dynamic>{
      'id': stockId,
      'price': productMap['price'],
      'quantity': productMap['quantity'],
      'discount': productMap['discount'],
      'tax': productMap['tax'],
      'product': productMap,
      'countable_id': productMap['id'],
    };
  }

  int _actualQuantity({
    required Map<String, dynamic> stockMap,
    required Map<String, dynamic> productMap,
    required int requested,
  }) {
    final int minQty = (_num(productMap['min_qty']) ?? 0).toInt();
    final int maxQty = (_num(productMap['max_qty']) ?? 0).toInt();
    final int stockQty =
        (_num(stockMap['quantity']) ?? _num(productMap['quantity']) ?? 0)
            .toInt();

    int qty = requested;
    if (minQty > 0 && qty < minQty) qty = minQty;
    if (maxQty > 0 && qty > maxQty) qty = maxQty;

    if (stockQty <= 0) return 0;
    if (qty > stockQty) return stockQty;
    return qty;
  }

  num _taxPerUnit({
    required Map<String, dynamic> stockMap,
    required Map<String, dynamic> productMap,
    required num unitPrice,
  }) {
    final num? explicitTaxPrice = _num(stockMap['tax_price']);
    if (explicitTaxPrice != null) return explicitTaxPrice;

    // Some payloads store tax percent in `tax`.
    final num? taxPercent = _num(productMap['tax']) ?? _num(stockMap['tax']);
    if (taxPercent != null && taxPercent >= 0 && taxPercent <= 100) {
      return unitPrice / 100 * taxPercent;
    }
    return 0;
  }

  num? _num(dynamic value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value);
    return null;
  }

  Future<ShopData?> _findShopById(int shopId) async {
    if (shopId == 0) return null;
    final box = await _shopsBox();
    for (final value in box.values) {
      if (value is Map && value['id'] == shopId) {
        return ShopData.fromJson(Map<String, dynamic>.from(value));
      }
    }
    return null;
  }

  Future<num> _readServiceFee() async {
    final box = await _settingsBox();
    for (final value in box.values) {
      if (value is! Map) continue;
      final map = Map<String, dynamic>.from(value);
      if (map['key'] == 'service_fee') {
        final fee = _num(map['value']);
        return fee ?? 0;
      }
    }
    return 0;
  }
}
