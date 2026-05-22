import 'dart:async';
import 'package:admin_desktop/src/core/constants/constants.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../models/models.dart';
import '../db/hive_service.dart';
import '../constants/hive_boxes.dart';
import '../utils/utils.dart';
import '../handlers/handlers.dart';
import 'sync_models.dart';

/// Handler for order synchronization tasks.
class OrderSyncHandler {
  final HttpService _httpService;
  final StreamSink<SyncProgress> _progressSink;

  OrderSyncHandler({
    required HttpService httpService,
    required StreamSink<SyncProgress> progressSink,
  })  : _httpService = httpService,
        _progressSink = progressSink;

  /// Gets a Dio client with appropriate authentication.
  Dio _getClient({required bool requireAuth}) {
    return _httpService.client(requireAuth: requireAuth);
  }

  /// Pushes pending orders from local Hive storage to the server.
  ///
  /// Returns `true` if the process completes successfully, `false` otherwise.
  Future<bool> pushOrders() async {
    try {
      debugPrint("Pushing orders data to server...");
      final box = await HiveService.openBox(HiveBoxes.orders);
      final pending = box.values
          .whereType<Map>()
          .where((e) => e['_meta']?['syncStatus'] == 'pending')
          .toList();

      int processed = 0;
      List<String> errors = [];
      for (final e in pending) {
        final key = e['id'];
        if (key == null) continue;

        final success = await pushSingleOrder(key);
        if (success) {
          processed++;
        } else {
          errors.add("Error pushing order $key");
        }
      }

      _progressSink.add(SyncProgress(
          phase: 'push',
          entity: 'orders',
          processed: processed,
          total: pending.length,
          errors: errors));

      debugPrint("Finish push orders data to server.");
      return true;
    } catch (e, stackTrace) {
      debugPrint("Error pushing orders: $e");
      AppHelpers.recordSyncErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'OrderSyncHandler.pushOrders',
      );
      _progressSink.add(SyncProgress(
          phase: 'push',
          entity: 'orders',
          processed: 0,
          total: 0,
          errors: [e.toString()]));
      return false;
    }
  }

  /// Pushes a single order to the server by its Hive key.
  Future<bool> pushSingleOrder(dynamic key) async {
    try {
      final box = await HiveService.openBox(HiveBoxes.orders);
      final e = box.get(key);
      if (e == null || e is! Map) return false;

      final rawBody = Map<String, dynamic>.from((e['body'] ?? {}) as Map);
      final orderBody = OrderBodyData.fromJson(rawBody);
      final body = orderBody.toJson();

      // Fetch role from the users list with the userid from body variable
      final usersBox = await HiveService.openBox(HiveBoxes.users);
      final userDataMap = usersBox.get(orderBody.userId);
      String role = LocalStorage.getUser()?.role ?? '';
      if (userDataMap != null) {
        final userData =
            UserData.fromJson(Map<String, dynamic>.from(userDataMap));
        role = userData.role ?? role;
      }

      final client = _getClient(requireAuth: true);
      debugPrint(
          "Sending POST request to /api/v1/dashboard/$role/orders with body: $body");
      final response = await client.post(
        '/api/v1/dashboard/$role/orders',
        data: body,
      );

      final parsed = CreateOrderResponse.fromJson(response.data);
      final id = parsed.data?.id;

      if (box.containsKey(key)) {
        final map = Map<String, dynamic>.from(box.get(key) as Map);
        map['_meta'] = {
          'syncStatus': 'synced',
          'transactionStatus': 'pending',
          'updatedAt': DateTime.now().toIso8601String(),
          'serverId': id
        };
        await box.put(key, map);

        if (id != null) {
          await submitPaymentTransaction(id, hiveKey: key);
        }
      }
      return true;
    } catch (ex, stackTrace) {
      debugPrint("Error pushing order $key: $ex");
      debugPrint("Stack trace: $stackTrace");
      AppHelpers.recordSyncErrorToCrashlytics(
        error: ex,
        stackTrace: stackTrace,
        context: 'OrderSyncHandler.pushSingleOrder',
      );
      return false;
    }
  }

  /// Submits a payment transaction for a specific order.
  ///
  /// [orderId] is the server-side ID of the order.
  /// [hiveKey] is the optional local storage key for the order.
  Future<bool> submitPaymentTransaction(int orderId, {dynamic hiveKey}) async {
    try {
      debugPrint("Submitting transaction for order $orderId...");
      final ordersBox = await HiveService.openBox(HiveBoxes.orders);
      final transactionsBox = await HiveService.openBox(HiveBoxes.transactions);

      Map? orderEntry;
      dynamic orderKey = hiveKey;

      // 1. Resolve Order Entry
      if (orderKey != null) {
        orderEntry = ordersBox.get(orderKey);
      } else {
        // Find order by serverId
        try {
          final entry = ordersBox.toMap().entries.firstWhere((e) {
            final val = e.value;
            if (val is! Map) return false;
            final meta = val['_meta'] as Map?;
            return meta?['serverId'] == orderId;
          });
          orderKey = entry.key;
          orderEntry = entry.value as Map?;
        } catch (_) {
          // Not found
        }
      }

      if (orderEntry == null || orderKey == null) {
        debugPrint("Order $orderId not found in Hive.");
        return false;
      }

      // 2. Find transaction in transactions box using local order ID (orderKey)
      dynamic transactionKey;
      Map? transactionEntry;
      try {
        final entry = transactionsBox.toMap().entries.firstWhere((e) {
          final val = e.value;
          if (val is! Map) return false;
          return val['order_id'] == orderKey;
        });
        transactionKey = entry.key;
        transactionEntry = Map<String, dynamic>.from(entry.value as Map);
      } catch (_) {
        // Transaction record might not exist yet if it was created via legacy flow
        debugPrint(
            "Transaction record for order $orderKey not found in transactions box.");
      }

      // 3. Get payment ID (prefer transaction record, fallback to order record)
      final paymentId =
          transactionEntry?['payment_id'] ?? orderEntry['payment_id'];
      if (paymentId == null) {
        debugPrint("Payment ID not found for order $orderId.");
        return false;
      }

      final client = _getClient(requireAuth: true);
      final data = {'payment_sys_id': paymentId};

      final response = await client.post(
        '/api/v1/payments/order/$orderId/transactions',
        data: data,
      );

      // Update transaction status to paid
      await client.put(
        '/api/v1/payments/order/$orderId/transactions',
        data: {'status': 'paid'},
      );

      final parsed = TransactionsResponse.fromJson(response.data);
      final transactionServerId = parsed.data?.id;

      // 4. Update transaction record in Hive
      if (transactionKey != null && transactionEntry != null) {
        transactionEntry['server_id'] = transactionServerId;
        transactionEntry['_meta'] = {
          ...(transactionEntry['_meta'] as Map? ?? {}),
          'syncStatus': 'synced',
          'syncedAt': DateTime.now().toIso8601String(),
        };
        await transactionsBox.put(transactionKey, transactionEntry);
        debugPrint(
            "Transaction record updated with server ID: $transactionServerId");
      }

      // 5. Update order record in Hive for legacy compatibility and UI status
      final map = Map<String, dynamic>.from(orderEntry);
      final meta = Map<String, dynamic>.from(map['_meta'] ?? {});
      meta['transactionStatus'] = 'synced';
      meta['transactionServerId'] =
          transactionServerId; // Store server ID here too
      meta['transactionUpdatedAt'] = DateTime.now().toIso8601String();
      map['_meta'] = meta;
      await ordersBox.put(orderKey, map);

      debugPrint("Transaction submitted successfully for order $orderId.");
      return true;
    } catch (e, stackTrace) {
      debugPrint("Error submitting transaction: $e");
      AppHelpers.recordSyncErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'OrderSyncHandler.submitPaymentTransaction',
      );
      return false;
    }
  }

  /// Pushes all pending transactions for synced orders to the server.
  Future<bool> pushTransactions() async {
    try {
      debugPrint("Pushing pending transactions to server...");
      final ordersBox = await HiveService.openBox(HiveBoxes.orders);
      final transactionsBox = await HiveService.openBox(HiveBoxes.transactions);

      // 1. Find all transactions that are not yet synced
      final pendingTransactions = transactionsBox.toMap().entries.where((e) {
        final val = e.value;
        if (val is! Map) return false;
        final meta = val['_meta'] as Map?;
        return meta?['syncStatus'] != 'synced';
      }).toList();

      int processed = 0;
      for (final entry in pendingTransactions) {
        final tx = entry.value as Map;
        final localOrderId = tx['order_id'];

        if (localOrderId == null) continue;

        // 2. Check if the corresponding order is synced
        final orderEntry = ordersBox.get(localOrderId);
        if (orderEntry != null && orderEntry is Map) {
          final orderMeta = orderEntry['_meta'] as Map?;
          final orderServerId = orderMeta?['serverId'];

          if (orderServerId != null) {
            // Order is synced, so we can submit the transaction
            final success = await submitPaymentTransaction(orderServerId,
                hiveKey: localOrderId);
            if (success) processed++;
          }
        }
      }

      if (processed > 0) {
        _progressSink.add(SyncProgress(
            phase: 'push',
            entity: 'transactions',
            processed: processed,
            total: pendingTransactions.length,
            errors: const []));
      }

      debugPrint(
          "Finish push transactions to server. Processed $processed transactions.");
      return true;
    } catch (e, stackTrace) {
      debugPrint("Error pushing transactions: $e");
      AppHelpers.recordSyncErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'OrderSyncHandler.pushTransactions',
      );
      return false;
    }
  }

  /// PUTs updated product list for an existing synced order.
  Future<bool> pushOrderUpdate(dynamic key) async {
    try {
      final box = await HiveService.openBox(HiveBoxes.orders);
      final e = box.get(key);
      if (e == null || e is! Map) return false;

      final map = Map<String, dynamic>.from(e);
      final meta = map['_meta'] as Map?;
      final serverId = meta?['serverId'];
      if (serverId == null) return false;

      final rawBody = Map<String, dynamic>.from((map['body'] ?? {}) as Map);
      final orderBody = OrderBodyData.fromJson(rawBody);
      final role = LocalStorage.getUser()?.role ?? '';
      final client = _getClient(requireAuth: true);

      await client.put(
        '/api/v1/dashboard/$role/orders/$serverId',
        data: orderBody.toJson(),
      );

      map['_meta'] = {
        ...Map<String, dynamic>.from(meta ?? {}),
        'syncStatus': 'synced',
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await box.put(key, map);
      return true;
    } catch (ex, stackTrace) {
      debugPrint('Error pushing order update $key: $ex');
      AppHelpers.recordSyncErrorToCrashlytics(
        error: ex,
        stackTrace: stackTrace,
        context: 'OrderSyncHandler.pushOrderUpdate',
      );
      return false;
    }
  }

  /// Scans orders with syncStatus == 'update_pending' and pushes each.
  Future<bool> pushPendingOrderUpdates() async {
    try {
      final box = await HiveService.openBox(HiveBoxes.orders);
      final pending = box.toMap().entries
          .where((e) => e.value is Map && e.value['_meta']?['syncStatus'] == 'update_pending')
          .toList();

      int processed = 0;
      final errors = <String>[];
      for (final entry in pending) {
        if (await pushOrderUpdate(entry.key)) {
          processed++;
        } else {
          errors.add('update/${entry.key}');
        }
      }
      _progressSink.add(SyncProgress(
        phase: 'push',
        entity: 'order_updates',
        processed: processed,
        total: pending.length,
        errors: errors,
      ));
      return true;
    } catch (e, stackTrace) {
      AppHelpers.recordSyncErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'OrderSyncHandler.pushPendingOrderUpdates',
      );
      return false;
    }
  }

  /// Updates an existing order's status on the backend.
  Future<bool> updateOrderStatus(int serverId, String status) async {
    try {
      final role = LocalStorage.getUser()?.role ?? '';
      final client = _getClient(requireAuth: true);
      await client.post(
        '/api/v1/dashboard/$role/order/$serverId/status',
        data: {'status': status},
      );
      return true;
    } catch (e, stackTrace) {
      AppHelpers.recordSyncErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'OrderSyncHandler.updateOrderStatus',
      );
      return false;
    }
  }

  /// Pushes voided orders to the server.
  Future<bool> pushVoidedOrders() async {
    try {
      debugPrint("Pushing voided orders to server...");
      final box = await HiveService.openBox(HiveBoxes.orders);
      final voidedOrders = box.toMap().entries.where((e) {
        final val = e.value;
        if (val is! Map) return false;
        final isVoided = val['is_voided'] == true;
        final syncVoided = val['sync_voided'] == true;
        final serverId = val['_meta']?['serverId'];
        return isVoided && !syncVoided && serverId != null;
      }).toList();

      int processed = 0;
      for (final entry in voidedOrders) {
        try {
          final val = entry.value as Map;
          final serverId = val['_meta']['serverId'];
          final rawBody = Map<String, dynamic>.from((val['body'] ?? {}) as Map);
          final orderBody = OrderBodyData.fromJson(rawBody);

          // Fetch role from the users list with the userid from body variable
          final usersBox = await HiveService.openBox(HiveBoxes.users);
          final userDataMap = usersBox.get(orderBody.userId);

          String role = LocalStorage.getUser()?.role ?? '';
          int? shopId = LocalStorage.getUser()?.shop?.id;

          if (userDataMap != null) {
            final userData =
                UserData.fromJson(Map<String, dynamic>.from(userDataMap));
            if (userData.role != null) {
              role = userData.role!;
              shopId = userData.shop?.id;
            }
          }

          final client = _getClient(requireAuth: true);
          final data = {
            'status': 'canceled',
            if (role == TrKeys.seller && shopId != null) 'shop_id': shopId,
          };

          final apiUrl = (role == TrKeys.admin || role == TrKeys.seller)
              ? '/api/v1/dashboard/$role/order/$serverId/status'
              : (role == TrKeys.waiter
                  ? '/api/v1/dashboard/$role/order/$serverId/status/update'
                  : role == TrKeys.cook
                      ? '/api/v1/dashboard/$role/orders/$serverId/status/update'
                      : '/api/v1/dashboard/$role/orders/$serverId/status/change');

          debugPrint("Sending POST request to $apiUrl with data: $data");
          await client.post(
            apiUrl,
            data: data,
          );

          // Update sync_voided status in Hive
          final map = Map<String, dynamic>.from(val);
          map['sync_voided'] = true;
          await box.put(entry.key, map);
          processed++;
        } catch (e, stackTrace) {
          debugPrint("Error pushing voided order ${entry.key}: $e");
          AppHelpers.recordSyncErrorToCrashlytics(
            error: e,
            stackTrace: stackTrace,
            context: 'OrderSyncHandler.pushVoidedOrders.item',
          );
        }
      }

      if (processed > 0) {
        _progressSink.add(SyncProgress(
            phase: 'push',
            entity: 'voided_orders',
            processed: processed,
            total: voidedOrders.length,
            errors: const []));
      }

      debugPrint("Finish push voided orders to server.");
      return true;
    } catch (e, stackTrace) {
      debugPrint("Error pushing voided orders: $e");
      AppHelpers.recordSyncErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'OrderSyncHandler.pushVoidedOrders',
      );
      return false;
    }
  }
}
