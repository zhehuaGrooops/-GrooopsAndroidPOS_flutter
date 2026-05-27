import 'dart:convert';

import 'package:admin_desktop/src/core/utils/app_helpers.dart';
import 'package:admin_desktop/src/models/response/orders_paginate_response.dart';
import 'package:admin_desktop/src/models/response/single_order_response.dart';
import 'package:flutter/material.dart';

import '../../core/constants/constants.dart';
import '../../core/di/injection.dart';
import '../../core/handlers/handlers.dart';
import '../../core/utils/local_storage.dart';
import '../../models/models.dart';
import '../repository.dart';

class OrdersRepositoryImpl extends OrdersRepository {
  @override
  Future<ApiResult<CreateOrderResponse>> createOrder(
      OrderBodyData orderBody) async {
    try {
      final orderJson = orderBody.toJson();

      // Pretty print JSON with indentation
      const JsonEncoder encoder = JsonEncoder.withIndent('  ');
      final prettyJson = encoder.convert(orderJson);

      // Split into chunks to avoid truncation
      final lines = prettyJson.split('\n');
      debugPrint('==> ORDER CREATE REQUEST (${lines.length} lines):');

      for (int i = 0; i < lines.length; i += 10) {
        final chunk = lines.skip(i).take(10).join('\n');
        debugPrint(
            '==> Lines ${i + 1}-${(i + 10).clamp(0, lines.length)}: \n$chunk');
      }
      final client = inject<HttpService>().client(requireAuth: true);
      final response = await client.post(
        '/api/v1/dashboard/${LocalStorage.getUser()?.role}/orders',
        data: orderBody.toJson(),
      );

      return ApiResult.success(
        data: CreateOrderResponse.fromJson(response.data),
      );
    } catch (e, stackTrace) {
      debugPrint('==> order create failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'OrdersRepositoryImpl.createOrder',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<OrderKitchenResponseData>> getKitchenOrders({
    String? status,
    int? page,
    DateTime? from,
    DateTime? to,
    String? search,
  }) async {
    final data = {
      if (page != null) 'page': page,
      if (status != null && TrKeys.all != status)
        'status': TrKeys.newKey == status
            ? "accepted"
            : TrKeys.done == status
                ? "ready"
                : TrKeys.cancel == status
                    ? "canceled"
                    : status,
      if (TrKeys.all == status) 'statuses[0]': "accepted",
      if (TrKeys.all == status) 'statuses[1]': "ready",
      if (TrKeys.all == status) 'statuses[2]': "cooking",
      if (search != null) 'search': search,
      'perPage': 6,
      "empty-cook": 1,
      'lang': LocalStorage.getLanguage()?.locale ?? 'en',
    };
    try {
      final client = inject<HttpService>().client(requireAuth: true);
      final response = await client.get(
        '/api/v1/dashboard/cook/orders/paginate',
        queryParameters: data,
      );
      return ApiResult.success(
        data: OrderKitchenResponseData.fromJson(response.data),
      );
    } catch (e, stackTrace) {
      debugPrint('==> get order $status failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'OrdersRepositoryImpl.getKitchenOrders',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<dynamic>> updateOrderDetailStatus({
    required String status,
    int? orderId,
  }) async {
    final data = {'status': status};
    debugPrint('==> update order status data: ${jsonEncode(data)}');
    try {
      final client = inject<HttpService>().client(requireAuth: true);
      await client.post(
        LocalStorage.getUser()?.role == TrKeys.waiter
            ? '/api/v1/dashboard/waiter/order/details/$orderId/status/update'
            : LocalStorage.getUser()?.role == TrKeys.cook
                ? '/api/v1/dashboard/cook/order-detail/$orderId/status/update'
                : '/api/v1/dashboard/${LocalStorage.getUser()?.role}/order/details/$orderId/status',
        data: data,
      );
      return const ApiResult.success(
        data: null,
      );
    } catch (e, stackTrace) {
      debugPrint('==> update order status failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'OrdersRepositoryImpl.updateOrderDetailStatus',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<OrdersPaginateResponse>> getOrders({
    OrderStatus? status,
    int? page,
    DateTime? from,
    DateTime? to,
    String? search,
  }) async {
    String? statusText;
    switch (status) {
      case OrderStatus.accepted:
        statusText = 'accepted';
        break;
      case OrderStatus.ready:
        statusText = 'ready';
        break;
      case OrderStatus.onAWay:
        statusText = 'on_a_way';
        break;
      case OrderStatus.delivered:
        statusText = 'delivered';
        break;
      case OrderStatus.canceled:
        statusText = 'canceled';
        break;
      case OrderStatus.newOrder:
        statusText = 'new';
        break;
      case OrderStatus.cooking:
        statusText = 'cooking';
        break;
      default:
        statusText = null;
        break;
    }
    final data = {
      if (page != null) 'page': page,
      if (statusText != null) 'status': statusText,
      if (from != null)
        "date_from": from.toString().substring(0, from.toString().indexOf(" ")),
      if (to != null)
        "date_to": to.toString().substring(0, to.toString().indexOf(" ")),
      if (search != null) 'search': search,
      'perPage': to == null ? 7 : 15,
      if (LocalStorage.getUser()?.role == TrKeys.waiter)
        'delivery_type': 'dine_in',
      // if (LocalStorage.getUser()?.role == TrKeys.waiter)
      //   'empty-waiter': 1,
      'lang': LocalStorage.getLanguage()?.locale ?? 'en',
    };
    try {
      final client = inject<HttpService>().client(requireAuth: true);
      final response = await client.get(
        '/api/v1/dashboard/${LocalStorage.getUser()?.role}/orders/paginate',
        queryParameters: data,
      );
      return ApiResult.success(
        data: OrdersPaginateResponse.fromJson(response.data),
      );
    } catch (e, stackTrace) {
      debugPrint('==> get order $status failure: $e,$stackTrace');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'OrdersRepositoryImpl.getOrders',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<dynamic>> updateOrderStatus({
    required OrderStatus status,
    int? orderId,
  }) async {
    String? statusText;
    switch (status) {
      case OrderStatus.newOrder:
        statusText = 'new';
        break;
      case OrderStatus.accepted:
        statusText = 'accepted';
        break;
      case OrderStatus.ready:
        statusText = 'ready';
        break;
      case OrderStatus.onAWay:
        statusText = 'on_a_way';
        break;
      case OrderStatus.delivered:
        statusText = 'delivered';
        break;
      case OrderStatus.canceled:
        statusText = 'canceled';
        break;
      case OrderStatus.cooking:
        statusText = 'cooking';
        break;
    }

    final data = {'status': statusText};
    try {
      final client = inject<HttpService>().client(requireAuth: true);
      await client.post(
        LocalStorage.getUser()?.role == TrKeys.waiter
            ? '/api/v1/dashboard/waiter/order/$orderId/status/update'
            : '/api/v1/dashboard/${LocalStorage.getUser()?.role}/order/$orderId/status',
        data: data,
      );
      return const ApiResult.success(
        data: null,
      );
    } catch (e, stackTrace) {
      debugPrint('==> update order status failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'OrdersRepositoryImpl.updateOrderStatus',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<dynamic>> updateOrderStatusKitchen({
    required OrderStatus status,
    int? orderId,
  }) async {
    String? statusText;
    switch (status) {
      case OrderStatus.newOrder:
        statusText = 'new';
        break;
      case OrderStatus.accepted:
        statusText = 'accepted';
        break;
      case OrderStatus.cooking:
        statusText = 'cooking';
        break;
      case OrderStatus.ready:
        statusText = 'ready';
        break;
      case OrderStatus.onAWay:
        statusText = 'on_a_way';
        break;
      case OrderStatus.delivered:
        statusText = 'delivered';
        break;
      case OrderStatus.canceled:
        statusText = 'canceled';
        break;
    }

    final data = {'status': statusText};
    try {
      final client = inject<HttpService>().client(requireAuth: true);
      await client.post(
        '/api/v1/dashboard/cook/orders/$orderId/status/update',
        data: data,
      );
      return const ApiResult.success(
        data: null,
      );
    } catch (e, stackTrace) {
      debugPrint('==> update order status failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'OrdersRepositoryImpl.updateOrderStatusKitchen',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<SingleOrderResponse>> getOrderDetails({int? orderId}) async {
    try {
      final client = inject<HttpService>().client(requireAuth: true);
      final data = {
        'lang': LocalStorage.getLanguage()?.locale ?? 'en',
      };
      final response = await client.get(
          '/api/v1/dashboard/${LocalStorage.getUser()?.role}/orders/$orderId',
          queryParameters: data);
      return ApiResult.success(
        data: SingleOrderResponse.fromJson(response.data),
      );
    } catch (e, stackTrace) {
      debugPrint('==> get order details failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'OrdersRepositoryImpl.getOrderDetails',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<SingleOrderResponse>> getOrderDetailsKitchen(
      {int? orderId}) async {
    try {
      final client = inject<HttpService>().client(requireAuth: true);
      final data = {
        'lang': LocalStorage.getLanguage()?.locale ?? 'en',
      };
      final response = await client
          .get('/api/v1/dashboard/cook/orders/$orderId', queryParameters: data);
      return ApiResult.success(
        data: SingleOrderResponse.fromJson(response.data),
      );
    } catch (e, stackTrace) {
      debugPrint('==> get order details failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'OrdersRepositoryImpl.getOrderDetailsKitchen',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<dynamic>> setDeliverMan(
      {required int orderId, required int deliverymanId}) async {
    try {
      final client = inject<HttpService>().client(requireAuth: true);
      final data = {
        'deliveryman': deliverymanId,
      };
      final response = await client.post(
          '/api/v1/dashboard/${LocalStorage.getUser()?.role}/order/$orderId/deliveryman',
          data: data);
      return ApiResult.success(
        data: SingleOrderResponse.fromJson(response.data),
      );
    } catch (e, stackTrace) {
      debugPrint('==> get order details failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'OrdersRepositoryImpl.setDeliverMan',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult> deleteOrder({required int orderId}) async {
    final data = {'ids[0]': orderId};
    try {
      final client = inject<HttpService>().client(requireAuth: true);
      await client.delete(
        '/api/v1/dashboard/${LocalStorage.getUser()?.role}/orders/delete',
        queryParameters: data,
      );
      return const ApiResult.success(
        data: null,
      );
    } catch (e, stackTrace) {
      debugPrint('==> update order status failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'OrdersRepositoryImpl.deleteOrder',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<dynamic>> setOrderVoided({required int orderId}) async {
    try {
      return ApiResult.success(data: null);
    } catch (e, stackTrace) {
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'OrdersRepositoryImpl.setOrderVoided',
      );
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<OrderHiveModel>> fetchOrderById(int orderId) async {
    return ApiResult.failure(
      error: 'fetchOrderById is only supported in Hive repository implementation.',
    );
  }

  @override
  Future<ApiResult<dynamic>> addProductsToOrder({
    required int orderId,
    required List<EnhancedProductOrder> newItems,
  }) async {
    return const ApiResult.success(data: null);
  }

  @override
  Future<ApiResult<dynamic>> cancelOrderItem({
    required int orderId,
    required int stockId,
    int? itemIndex,
  }) async {
    return const ApiResult.success(data: null);
  }

  @override
  Future<ApiResult<dynamic>> finalizeOrderPayment({
    required int orderId,
    required num paidAmount,
    required num billDiscountAmount,
    String? billDiscountType,
    num? billDiscountPercent,
    required num roundingAmount,
    required num refundAmount,
    required String transactionId,
    required String queueNo,
  }) async {
    // HTTP impl does not manage local Hive order records.
    return const ApiResult.success(data: null);
  }

  /// Validates the order data returned from fetchOrderById and handles null cases.
  ///
  /// [order] The order model instance to validate.
  /// Provides meaningful error messages or returns a default value when null is encountered.
  dynamic validateOrderData(OrderHiveModel? order) {
    if (order == null) {
      const String errorMessage =
          'Order data is null or could not be retrieved from the database.';
      debugPrint('==> $errorMessage');
      return errorMessage;
    }

    // Additional validation for required fields
    if (order.id == null) {
      debugPrint('==> Order ID is missing. Returning default order model.');
      return OrderHiveModel(id: -1, status: 'unknown');
    }

    return order;
  }
}
