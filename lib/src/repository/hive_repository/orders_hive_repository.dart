import 'package:admin_desktop/src/core/constants/hive_boxes.dart';
import 'package:admin_desktop/src/core/constants/app_constants.dart';
import 'package:admin_desktop/src/core/handlers/handlers.dart';
import 'package:admin_desktop/src/models/data/order_data.dart';
import 'package:admin_desktop/src/models/models.dart';
import 'package:admin_desktop/src/models/response/orders_paginate_response.dart';
import 'package:admin_desktop/src/models/response/single_order_response.dart';
import 'package:admin_desktop/src/core/utils/local_storage.dart';

import 'package:hive/hive.dart';

import '../../core/db/hive_service.dart';
import '../../core/di/dependency_manager.dart';
import '../../core/sync/sync_service.dart';
import '../../core/utils/app_connectivity.dart';
import '../orders_repository.dart';
import '../../core/utils/app_helpers.dart';

class OrdersHiveRepository extends OrdersRepository {
  Future<Box> _box() => HiveService.openBox(HiveBoxes.orders);

  @override
  Future<ApiResult<CreateOrderResponse>> createOrder(
      OrderBodyData orderBody) async {
    try {
      // Deduct stock before creating order
      if (orderBody.enhancedProducts != null &&
          orderBody.enhancedProducts!.isNotEmpty) {
        for (final product in orderBody.enhancedProducts!) {
          await productsRepository.deductProductStock(
              product.stockId, product.quantity);
          if (product.addons != null) {
            for (final addon in product.addons!) {
              if (addon.countableId != null) {
                await productsRepository.deductAddonStock(
                    addon.countableId!, addon.quantity);
              }
            }
          }
        }
      } else if (orderBody.bagData.bagProducts != null) {
        for (final product in orderBody.bagData.bagProducts!) {
          if (product.stockId != null && product.quantity != null) {
            await productsRepository.deductProductStock(
                product.stockId!, product.quantity!);
            if (product.carts != null) {
              for (final addon in product.carts!) {
                if (addon.stockId != null && addon.quantity != null) {
                  // For basic products, we don't have countableId in EnhancedAddonOrder yet
                  // but we can try to use stockId if it was used as countableId before
                  await productsRepository.deductAddonStock(
                      addon.stockId!, addon.quantity!);
                }
              }
            }
          }
        }
      }

      final box = await _box();
      final int id = DateTime.now().millisecondsSinceEpoch ~/ 1000; // seconds
      final num lockedTotal = _calcLockedTotal(orderBody);
      await _getUserSnapshot(orderBody.userId);
      final currentUser = LocalStorage.getUser();
      final currentShop = await _getCurrentShopSnapshot();

      final order = OrderHiveModel(
        id: id,
        body: orderBody,
        paymentId: orderBody.bagData.selectedPayment?.id,
        status: AppHelpers.getDefaultOrderStatus(),
        totalPrice: lockedTotal,
        userSnapshot: currentUser?.toJson(),
        shopSnapshot: currentShop,
        meta: OrderMeta(
          syncStatus: 'pending',
          transactionStatus: 'pending',
          updatedAt: DateTime.now().toIso8601String(),
        ),
      );
      await box.put(id, order.toJson());

      // if (orderBody.bagData.selectedPayment?.id != null) {
      //   await paymentsRepository.createTransaction(
      //     orderId: id,
      //     paymentId: orderBody.bagData.selectedPayment!.id!,
      //   );
      // }

      // If online, push the order immediately
      int? serverId;
      if (await AppConnectivity.connectivity()) {
        final success = await SyncService().pushSingleOrder(id);
        if (success) {
          final updatedOrder = box.get(id);
          if (updatedOrder != null && updatedOrder is Map) {
            serverId = updatedOrder['_meta']?['serverId'];
          }
        }
      }

      final created = CreatedOrder(
          id: serverId ?? id,
          userId: orderBody.userId,
          price: lockedTotal,
          currencyPrice: lockedTotal,
          rate: orderBody.rate,
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String());
      return ApiResult.success(data: CreateOrderResponse(data: created));
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  num _calcLockedTotal(OrderBodyData body) {
    final products = body.enhancedProducts;
    if (products == null || products.isEmpty) return 0;

    double total = 0.0;

    for (final p in products) {
      total += p.finalPrice;
    }

    total -= (body.billDiscountAmount ?? 0.0);

    return total + (body.roundingAmount ?? 0.0);
  }

  Future<Map<String, dynamic>?> _getUserSnapshot(int? userId) async {
    if (userId == null) return null;

    final box = await HiveService.openBox(HiveBoxes.users);

    for (final raw in box.values) {
      if (raw is Map && raw['id'] == userId) {
        final map = Map<String, dynamic>.from(raw);

        // minimal normalization for UserData.fromJson
        return {
          'id': map['id'],
          'firstname': map['firstname'] ?? map['profile']?['firstname'],
          'lastname': map['lastname'] ?? map['profile']?['lastname'],
          'email': map['email'],
          'phone': map['phone'],
          'img': map['img'],
          'role': map['role'],
          'active': map['active'],
          'wallet': map['wallet'],
        };
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> _getCurrentShopSnapshot() async {
    final box = await HiveService.openBox(HiveBoxes.currentUserShop);
    final raw = box.get('current');
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  @override
  Future<ApiResult<OrdersPaginateResponse>> getOrders(
      {OrderStatus? status,
      int? page,
      DateTime? from,
      DateTime? to,
      String? search}) async {
    try {
      final box = await _box();
      final items = box.values
          .whereType<Map>()
          .map((e) => OrderHiveModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final filtered = items.where((e) {
        final s = e.status ?? '';
        final matchesStatus = status == null || s == _statusText(status);
        final title = (e.body?.note ?? '').toString().toLowerCase();
        final matchesQuery =
            search == null || title.contains(search.toLowerCase());
        return matchesStatus && matchesQuery;
      }).toList();
      final orders = filtered.map((e) {
        final json = e.toJson();
        json['total_price'] = e.totalPrice;
        json.remove('details');
        return OrderData.fromJson(json);
      }).toList();
      return ApiResult.success(
          data:
              OrdersPaginateResponse(data: OrderResponseData(orders: orders)));
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<dynamic>> updateOrderStatus(
      {required OrderStatus status, int? orderId}) async {
    try {
      final box = await _box();
      final key = orderId ?? '';
      if (box.containsKey(key)) {
        final order = OrderHiveModel.fromJson(
            Map<String, dynamic>.from(box.get(key) as Map));
        final updatedOrder = OrderHiveModel(
          id: order.id,
          body: order.body,
          paymentId: order.paymentId,
          status: _statusText(status),
          detailStatus: order.detailStatus,
          meta: OrderMeta(
            syncStatus: 'pending',
            updatedAt: DateTime.now().toIso8601String(),
          ),
        );
        await box.put(key, updatedOrder.toJson());
      }
      return const ApiResult.success(data: null);
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<dynamic>> updateOrderDetailStatus(
      {required String status, int? orderId}) async {
    try {
      final box = await _box();
      final key = orderId ?? '';
      if (box.containsKey(key)) {
        final order = OrderHiveModel.fromJson(
            Map<String, dynamic>.from(box.get(key) as Map));
        final updatedOrder = OrderHiveModel(
          id: order.id,
          body: order.body,
          paymentId: order.paymentId,
          status: order.status,
          detailStatus: status,
          meta: OrderMeta(
            syncStatus: 'pending',
            updatedAt: DateTime.now().toIso8601String(),
          ),
        );
        await box.put(key, updatedOrder.toJson());
      }
      return const ApiResult.success(data: null);
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<dynamic>> updateOrderStatusKitchen(
      {required OrderStatus status, int? orderId}) async {
    return updateOrderStatus(status: status, orderId: orderId);
  }

  @override
  Future<ApiResult<SingleOrderResponse>> getOrderDetails({int? orderId}) async {
    try {
      final box = await _box();
      final key = orderId ?? '';
      final map = box.get(key) as Map?;
      if (map != null) {
        final order = OrderHiveModel.fromJson(Map<String, dynamic>.from(map));
        return ApiResult.success(
            data:
                SingleOrderResponse(data: OrderData.fromJson(order.toJson())));
      }
      return ApiResult.failure(error: 'Not found');
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<SingleOrderResponse>> getOrderDetailsKitchen(
      {int? orderId}) async {
    return getOrderDetails(orderId: orderId);
  }

  @override
  Future<ApiResult<dynamic>> setDeliverMan(
      {required int orderId, required int deliverymanId}) async {
    try {
      final box = await _box();
      if (box.containsKey(orderId)) {
        final order = OrderHiveModel.fromJson(
            Map<String, dynamic>.from(box.get(orderId) as Map));
        final updatedOrder = OrderHiveModel(
          id: order.id,
          body: order.body,
          paymentId: order.paymentId,
          deliverymanId: deliverymanId,
          status: order.status,
          detailStatus: order.detailStatus,
          meta: OrderMeta(
            syncStatus: 'pending',
            updatedAt: DateTime.now().toIso8601String(),
          ),
        );
        await box.put(orderId, updatedOrder.toJson());
      }
      return const ApiResult.success(data: null);
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<dynamic>> deleteOrder({required int orderId}) async {
    try {
      final box = await _box();
      await box.delete(orderId);
      return const ApiResult.success(data: null);
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<dynamic>> setOrderVoided({required int orderId}) async {
    try {
      final box = await _box();

      dynamic hiveKey;
      Map<String, dynamic>? raw;

      for (final entry in box.toMap().entries) {
        final value = entry.value;
        if (value is Map) {
          final id = value['id'];
          final meta = value['_meta'] as Map?;
          final serverId = meta?['serverId'];

          if (id == orderId || serverId == orderId) {
            hiveKey = entry.key;
            raw = Map<String, dynamic>.from(value);
            break;
          }
        }
      }

      if (raw == null) {
        return const ApiResult.failure(error: 'Order not found');
      }

      final order = OrderHiveModel.fromJson(raw);

      if (order.isVoided == true) {
        return const ApiResult.failure(error: 'Order is already voided');
      }

      final orderBody = order.body;
      if (orderBody != null) {
        if (orderBody.enhancedProducts != null &&
            orderBody.enhancedProducts!.isNotEmpty) {
          for (final product in orderBody.enhancedProducts!) {
            await productsRepository.addProductStock(
              product.stockId,
              product.quantity,
            );
            if (product.addons != null) {
              for (final addon in product.addons!) {
                if (addon.countableId != null) {
                  await productsRepository.addAddonStock(
                    addon.countableId!,
                    addon.quantity,
                  );
                }
              }
            }
          }
        } else if (orderBody.bagData.bagProducts != null) {
          for (final product in orderBody.bagData.bagProducts!) {
            if (product.stockId != null && product.quantity != null) {
              await productsRepository.addProductStock(
                product.stockId!,
                product.quantity!,
              );
              if (product.carts != null) {
                for (final addon in product.carts!) {
                  if (addon.stockId != null && addon.quantity != null) {
                    // For basic products, we use stockId as countableId fallback
                    await productsRepository.addAddonStock(
                      addon.stockId!,
                      addon.quantity!,
                    );
                  }
                }
              }
            }
          }
        }
      }

      final updated = Map<String, dynamic>.from(raw);
      updated['is_voided'] = true;
      updated['sync_voided'] = false;

      final body = updated['body'];
      if (body is Map) {
        final updatedBody = Map<String, dynamic>.from(body);
        updatedBody['is_voided'] = true;
        updatedBody['sync_voided'] = false;
        updated['body'] = updatedBody;
      }

      await box.put(hiveKey, updated);
      return const ApiResult.success(data: null);
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<OrderKitchenResponseData>> getKitchenOrders(
      {String? status, int? page, String? search}) async {
    try {
      final box = await _box();
      final items = box.values
          .whereType<Map>()
          .where((e) => (e['status'] ?? '') == (status ?? 'cooking'))
          .toList();
      final orders = items
          .map((e) => OrderData.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return ApiResult.success(data: OrderKitchenResponseData(orders: orders));
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  /// Retrieves order data from Hive database using the provided order ID.
  ///
  /// Performs the following:
  /// 1. Retrieves raw data from the Hive box.
  /// 2. Validates existence of the data.
  /// 3. Converts the data to an [OrderHiveModel] instance.
  ///
  /// Throws or returns [ApiResult.failure] if:
  /// - The order ID doesn't exist.
  /// - Hive database access fails.
  /// - Data conversion fails.
  @override
  Future<ApiResult<OrderHiveModel>> fetchOrderById(int orderId) async {
    try {
      // 1. Retrieves order data from Hive database
      final box = await _box();

      // Search for the order by iterating through the box values and checking 'id' or '_meta.serverId'
      dynamic rawData;
      for (final element in box.values) {
        if (element is Map) {
          final id = element['id'];
          final meta = element['_meta'] as Map?;
          final serverId = meta?['serverId'];
          if (id == orderId || serverId == orderId) {
            rawData = element;
            break;
          }
        }
      }

      // Handle case where order ID doesn't exist
      if (rawData == null) {
        return ApiResult.failure(
          error: 'Order with ID $orderId not found in local database.',
        );
      }

      // 2. Returns the data mapped to an instance of OrderHiveModel class
      try {
        final order = OrderHiveModel.fromJson(
          Map<String, dynamic>.from(rawData as Map),
        );
        return ApiResult.success(data: order);
      } catch (e) {
        // Handle case where data conversion fails
        return ApiResult.failure(
          error: 'Failed to convert order data for ID $orderId: $e',
        );
      }
    } catch (e) {
      // Handle case where Hive database access fails
      return ApiResult.failure(
        error: 'Hive database access failed: $e',
      );
    }
  }

  String _statusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.newOrder:
        return 'new';
      case OrderStatus.accepted:
        return 'accepted';
      case OrderStatus.cooking:
        return 'cooking';
      case OrderStatus.ready:
        return 'ready';
      case OrderStatus.onAWay:
        return 'on_a_way';
      case OrderStatus.delivered:
        return 'delivered';
      default:
        return 'canceled';
    }
  }
}
