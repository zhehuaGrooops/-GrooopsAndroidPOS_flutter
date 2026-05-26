import 'package:admin_desktop/src/models/response/orders_paginate_response.dart';
import 'package:admin_desktop/src/models/response/single_order_response.dart';

import '../core/constants/app_constants.dart';
import '../core/handlers/handlers.dart';
import '../models/models.dart';

abstract class OrdersRepository {
  Future<ApiResult<CreateOrderResponse>> createOrder(OrderBodyData orderBody);

  Future<ApiResult<OrdersPaginateResponse>> getOrders({
    OrderStatus? status,
    int? page,
    DateTime? from,
    DateTime? to,
    String? search,
  });

  Future<ApiResult<dynamic>> updateOrderStatus({
    required OrderStatus status,
    int? orderId,
  });
  Future<ApiResult<dynamic>> updateOrderDetailStatus({
    required String status,
    int? orderId,
  });
  Future<ApiResult<dynamic>> updateOrderStatusKitchen({
    required OrderStatus status,
    int? orderId,
  });

  Future<ApiResult<SingleOrderResponse>> getOrderDetails({int? orderId});

  Future<ApiResult<SingleOrderResponse>> getOrderDetailsKitchen({int? orderId});

  Future<ApiResult<dynamic>> setDeliverMan(
      {required int orderId, required int deliverymanId});

  Future<ApiResult<dynamic>> setOrderVoided({required int orderId});

  Future<ApiResult<dynamic>> deleteOrder({required int orderId});

  Future<ApiResult<OrderKitchenResponseData>> getKitchenOrders({
    String? status,
    int? page,
    String? search,
  });

  /// Fetches an order from the Hive database by its ID.
  ///
  /// [orderId] The unique identifier of the order to retrieve.
  /// Returns an [ApiResult] containing the [OrderHiveModel] if found,
  /// or a failure if the order does not exist or an error occurs.
  Future<ApiResult<OrderHiveModel>> fetchOrderById(int orderId);

  Future<ApiResult<dynamic>> addProductsToOrder({
    required int orderId,
    required List<EnhancedProductOrder> newItems,
  });

  Future<ApiResult<dynamic>> cancelOrderItem({
    required int orderId,
    required int stockId,
  });

  /// Patches a Hive order with payment finalisation details captured at cashout.
  /// Called by [cashoutTableOrder] before submitting the payment transaction.
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
  });
}
