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
      final box = await HiveService.openBox(HiveBoxes.orders);
      // Use entry.key (actual Hive key) not e['id'] from the map value.
      // e['id'] may differ in runtime type from the stored Hive key, causing
      // defaultKeyComparator to throw a type cast error in box.get().
      final pendingEntries = box.toMap().entries.where((entry) {
        final val = entry.value;
        return val is Map && val['_meta']?['syncStatus'] == 'pending';
      }).toList();

      int processed = 0;
      List<String> errors = [];
      for (final entry in pendingEntries) {
        final key = entry.key;

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
          total: pendingEntries.length,
          errors: errors));

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
  ///
  /// Table orders (tableId != null) → POST /orders/init (idempotent, returns
  /// existing new order when duplicate request arrives).
  /// Normal orders → POST /orders (original flow, unchanged).
  Future<bool> pushSingleOrder(dynamic key) async {
    try {
      final box = await HiveService.openBox(HiveBoxes.orders);
      final e = box.get(key);
      if (e == null || e is! Map) return false;

      final rawBody = Map<String, dynamic>.from((e['body'] ?? {}) as Map);
      final orderBody = OrderBodyData.fromJson(rawBody);
      final body = orderBody.toJson();

      final isTableOrder = orderBody.tableId != null;

      // Fetch role from the users list with the userid from body variable.
      // DO NOT use usersBox.get(orderBody.userId) — the users box has mixed
      // key types (int user IDs, String 'profile', String uuids).
      // Hive's defaultKeyComparator throws _TypeError when comparing int vs
      // String during skip-list traversal. Iterate values instead.
      final usersBox = await HiveService.openBox(HiveBoxes.users);
      Map? userDataMap;
      for (final raw in usersBox.values) {
        if (raw is Map && raw['id'] == orderBody.userId) {
          userDataMap = raw;
          break;
        }
      }
      String role = LocalStorage.getUser()?.role ?? '';
      if (userDataMap != null) {
        final userData =
            UserData.fromJson(Map<String, dynamic>.from(userDataMap));
        role = userData.role ?? role;
      }

      final client = _getClient(requireAuth: true);

      // Table orders use /orders/init. Normal orders use /orders.
      final url = isTableOrder
          ? '/api/v1/dashboard/$role/orders/init'
          : '/api/v1/dashboard/$role/orders';

      final response = await client.post(
        url,
        data: body,
        options: Options(headers: {'X-Idempotency-Key': key.toString()}),
      );

      final parsed = CreateOrderResponse.fromJson(response.data);
      final id = parsed.data?.id;

      if (id == null) {
        // Backend accepted the request but returned no order ID.
        // All downstream operations (reorder/cancel/cashout) require serverId.
        // Check backend response structure — POS expects { "data": { "id": <int> } }.
        debugPrint(
          "pushSingleOrder $key: backend returned null id. "
          "Full response: ${response.data}",
        );
      }

      if (box.containsKey(key)) {
        final map = Map<String, dynamic>.from(box.get(key) as Map);
        map['_meta'] = {
          'syncStatus': 'synced',
          'transactionStatus': 'pending',
          'updatedAt': DateTime.now().toIso8601String(),
          'serverId': id
        };
        await box.put(key, map);

        // For table orders: parse response for server-assigned order_detail IDs.
        // Stored per product for future DELETE /orders/{serverId}/items/{detailId}.
        if (isTableOrder && id != null) {
          await _storeDetailIdsFromResponse(response.data, key, box);
        }

        // Normal orders only: submit payment transaction immediately after sync.
        // Table orders settle payment via POST /orders/{serverId}/cashout instead.
        if (id != null && !isTableOrder) {
          await submitPaymentTransaction(id, hiveKey: key);
        }
      }
      return true;
    } catch (ex, stackTrace) {
      // Log the full HTTP response body so backend validation errors are visible.
      final responseBody = (ex is DioException) ? ex.response?.data : null;
      debugPrint(
        "pushSingleOrder $key FAILED — error: $ex"
        "${responseBody != null ? '\nBackend response: $responseBody' : ''}",
      );
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
  /// Used for **normal (non-table) orders only**.
  ///
  /// [orderId] is the server-side ID of the order.
  /// [hiveKey] is the optional local storage key for the order.
  Future<bool> submitPaymentTransaction(int orderId, {dynamic hiveKey}) async {
    try {
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

      // 6. Mark order as delivered — payment submitted = order completed.
      //    updateOrderStatus has its own try/catch; failure is non-fatal.
      await updateOrderStatus(orderId, 'delivered');

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
  ///
  /// Table orders → POST /orders/{serverId}/cashout (reads payment data from Hive body).
  /// Normal orders → legacy /payments/order/{id}/transactions endpoint.
  Future<bool> pushTransactions() async {
    try {
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
            // Detect table order by tableId in order body.
            final rawBody = orderEntry['body'];
            final orderBody = rawBody != null
                ? OrderBodyData.fromJson(
                    Map<String, dynamic>.from(rawBody as Map))
                : null;
            final isTableOrder = orderBody?.tableId != null;

            if (isTableOrder) {
              // Table orders: use POST /orders/{serverId}/cashout.
              // Payment data was stored in order body by finalizeOrderPayment.
              final paymentId =
                  tx['payment_id'] ?? orderEntry['payment_id'];
              if (paymentId == null) continue;

              final success = await cashoutTableOrder(
                serverId: orderServerId,
                hiveKey: localOrderId,
                paymentId: paymentId,
                paidAmount: orderBody?.paidAmount ?? 0,
                refundAmount: orderBody?.refundAmount ?? 0,
                billDiscountAmount: orderBody?.billDiscountAmount,
                billDiscountType: orderBody?.billDiscountType,
                billDiscountPercent: orderBody?.billDiscountPercent,
              );
              if (success) processed++;
            } else {
              // Normal orders: legacy transaction endpoint.
              final success = await submitPaymentTransaction(orderServerId,
                  hiveKey: localOrderId);
              if (success) processed++;
            }
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

  /// Syncs reorder additions for table orders via POST /orders/{serverId}/reorder.
  /// Sends only the NEW items stored in _meta.pendingProducts, not the full list.
  ///
  /// Normal orders fall through to the legacy PUT endpoint (safety path — should
  /// not occur in normal flow since normal orders don't use update_pending).
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

      final isTableOrder = orderBody.tableId != null;

      if (isTableOrder) {
        // Table orders: POST /orders/{serverId}/reorder with only new items.
        // pendingProducts accumulates new items added since the last successful sync.
        final pendingRaw = meta?['pendingProducts'] as List?;
        if (pendingRaw == null || pendingRaw.isEmpty) {
          // Nothing new to add — just mark synced.
          final updatedMeta = Map<String, dynamic>.from(meta ?? {});
          updatedMeta['syncStatus'] = 'synced';
          map['_meta'] = updatedMeta;
          await box.put(key, map);
          return true;
        }

        final response = await client.post(
          '/api/v1/dashboard/$role/orders/$serverId/reorder',
          data: {'products': pendingRaw},
        );

        // Parse response to store serverDetailIds for newly added items.
        await _storeDetailIdsFromResponse(response.data, key, box);

        // Reload map after _storeDetailIdsFromResponse may have updated it.
        final refreshed = Map<String, dynamic>.from(box.get(key) as Map);
        final updatedMeta = Map<String, dynamic>.from(refreshed['_meta'] ?? {});
        updatedMeta['syncStatus'] = 'synced';
        updatedMeta.remove('pendingProducts');
        updatedMeta['updatedAt'] = DateTime.now().toIso8601String();
        refreshed['_meta'] = updatedMeta;
        await box.put(key, refreshed);
        return true;
      } else {
        // Normal orders: keep legacy PUT (safety — update_pending should not occur).
        await client.put(
          '/api/v1/dashboard/$role/orders/$serverId',
          data: orderBody.toJson(),
        );
        final updatedMeta = Map<String, dynamic>.from(meta ?? {});
        updatedMeta['syncStatus'] = 'synced';
        updatedMeta['updatedAt'] = DateTime.now().toIso8601String();
        map['_meta'] = updatedMeta;
        await box.put(key, map);
        return true;
      }
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
  /// Used for normal orders. Table orders use POST /orders/{serverId}/cashout.
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
  ///
  /// Table orders → POST /orders/{serverId}/cancel (restores stock atomically).
  /// Normal orders → role-based status endpoint (existing behavior unchanged).
  Future<bool> pushVoidedOrders() async {
    try {
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
          final isTableOrder = orderBody.tableId != null;

          final client = _getClient(requireAuth: true);

          if (isTableOrder) {
            // Table orders: POST /orders/{serverId}/cancel
            // Backend handles stock restoration and status=canceled atomically.
            final role = LocalStorage.getUser()?.role ?? '';
            await client.post(
              '/api/v1/dashboard/$role/orders/$serverId/cancel',
            );
          } else {
            // Normal orders: existing role-based status endpoint (unchanged).
            final usersBox = await HiveService.openBox(HiveBoxes.users);
            Map? userDataMap;
            for (final raw in usersBox.values) {
              if (raw is Map && raw['id'] == orderBody.userId) {
                userDataMap = raw;
                break;
              }
            }

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

            await client.post(apiUrl, data: data);
          }

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

  // ───────────────────────────── Table-specific endpoints ─────────────────────

  /// Completes payment for a table order: POST /orders/{serverId}/cashout.
  /// Atomic on server: recalculates totals, creates transaction, sets delivered.
  Future<bool> cashoutTableOrder({
    required int serverId,
    dynamic hiveKey,
    required int paymentId,
    required num paidAmount,
    required num refundAmount,
    num? billDiscountAmount,
    String? billDiscountType,
    num? billDiscountPercent,
  }) async {
    try {
      final role = LocalStorage.getUser()?.role ?? '';
      final client = _getClient(requireAuth: true);

      await client.post(
        '/api/v1/dashboard/$role/orders/$serverId/cashout',
        data: {
          'payment_id': paymentId,
          'paid_amount': paidAmount,
          'refund_amount': refundAmount,
          if (billDiscountAmount != null && billDiscountAmount > 0)
            'bill_discount_amount': billDiscountAmount,
          if (billDiscountType != null) 'bill_discount_type': billDiscountType,
          if (billDiscountPercent != null)
            'bill_discount_percent': billDiscountPercent,
        },
      );

      // Update Hive meta to reflect completed cashout.
      if (hiveKey != null) {
        final box = await HiveService.openBox(HiveBoxes.orders);
        final entry = box.get(hiveKey);
        if (entry is Map) {
          final map = Map<String, dynamic>.from(entry);
          final meta = Map<String, dynamic>.from(map['_meta'] ?? {});
          meta['syncStatus'] = 'synced';
          meta['transactionStatus'] = 'synced';
          meta['updatedAt'] = DateTime.now().toIso8601String();
          map['_meta'] = meta;
          await box.put(hiveKey, map);
        }
      }
      return true;
    } catch (e, stackTrace) {
      AppHelpers.recordSyncErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'OrderSyncHandler.cashoutTableOrder',
      );
      return false;
    }
  }

  /// Removes a single item from an open table order.
  /// DELETE /orders/{serverId}/items/{orderDetailId}
  /// Backend restores stock for the removed item and its addons.
  Future<bool> cancelTableOrderItem({
    required int serverId,
    required int orderDetailId,
  }) async {
    try {
      final role = LocalStorage.getUser()?.role ?? '';
      final client = _getClient(requireAuth: true);
      await client.delete(
        '/api/v1/dashboard/$role/orders/$serverId/items/$orderDetailId',
      );
      return true;
    } catch (e, stackTrace) {
      AppHelpers.recordSyncErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'OrderSyncHandler.cancelTableOrderItem',
      );
      return false;
    }
  }

  /// Processes item-level cancels queued while offline.
  /// Reads _meta.pendingCancelDetailIds from each Hive order and calls DELETE /items/{id}.
  Future<bool> pushPendingCancels() async {
    try {
      final box = await HiveService.openBox(HiveBoxes.orders);
      int processed = 0;

      for (final entry in box.toMap().entries) {
        final val = entry.value;
        if (val is! Map) continue;
        final meta = val['_meta'] as Map?;
        final serverId = meta?['serverId'] as int?;
        final pendingCancels = meta?['pendingCancelDetailIds'] as List?;
        if (serverId == null || pendingCancels == null || pendingCancels.isEmpty) {
          continue;
        }

        final role = LocalStorage.getUser()?.role ?? '';
        final client = _getClient(requireAuth: true);
        final remaining = List<dynamic>.from(pendingCancels);

        for (final detailId in List<dynamic>.from(pendingCancels)) {
          try {
            await client.delete(
              '/api/v1/dashboard/$role/orders/$serverId/items/$detailId',
            );
            remaining.remove(detailId);
            processed++;
          } catch (_) {
            // Keep in list — retry on next tick.
          }
        }

        final map = Map<String, dynamic>.from(val);
        final updatedMeta = Map<String, dynamic>.from(meta!);
        if (remaining.isEmpty) {
          updatedMeta.remove('pendingCancelDetailIds');
        } else {
          updatedMeta['pendingCancelDetailIds'] = remaining;
        }
        map['_meta'] = updatedMeta;
        await box.put(entry.key, map);
      }

      if (processed > 0) {
        _progressSink.add(SyncProgress(
          phase: 'push',
          entity: 'pending_cancels',
          processed: processed,
          total: processed,
          errors: const [],
        ));
      }
      return true;
    } catch (e, stackTrace) {
      AppHelpers.recordSyncErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'OrderSyncHandler.pushPendingCancels',
      );
      return false;
    }
  }

  // ───────────────────────────── Private helpers ───────────────────────────────

  /// Parses the server response for a table order init/reorder and stores
  /// server-assigned order_detail IDs in each EnhancedProductOrder in Hive.
  ///
  /// Tries common response field names for the details array:
  /// `details`, `order_details`, `items`.
  /// Best-effort — failures are logged and silently ignored.
  Future<void> _storeDetailIdsFromResponse(
    dynamic responseData,
    dynamic hiveKey,
    dynamic box,
  ) async {
    try {
      final data = responseData['data'] as Map?;
      if (data == null) return;

      // Try common field names for the order details array.
      List? detailsList;
      for (final field in ['details', 'order_details', 'items']) {
        final candidate = data[field];
        if (candidate is List && candidate.isNotEmpty) {
          detailsList = candidate;
          break;
        }
      }
      if (detailsList == null) return;

      // Build stock_id → server order_detail_id map.
      final detailIdByStockId = <int, int>{};
      for (final d in detailsList) {
        if (d is Map) {
          // stock_id may be nested under 'stock' or directly present.
          final stockId = (d['stock_id'] ?? d['stock']?['id']) as int?;
          final detailId = d['id'] as int?;
          if (stockId != null && detailId != null) {
            detailIdByStockId[stockId] = detailId;
          }
        }
      }
      if (detailIdByStockId.isEmpty) return;

      // Update each EnhancedProductOrder in Hive with its server detail ID.
      if (!(box as dynamic).containsKey(hiveKey)) return;
      final current = Map<String, dynamic>.from(box.get(hiveKey) as Map);
      final bodyMap = current['body'];
      if (bodyMap is! Map) return;
      final bodyMutable = Map<String, dynamic>.from(bodyMap);
      final enhancedRaw = bodyMutable['enhanced_products'];
      if (enhancedRaw is! List) return;

      bodyMutable['enhanced_products'] = enhancedRaw.map((p) {
        if (p is! Map) return p;
        final pm = Map<String, dynamic>.from(p);
        final stockId = pm['stock_id'] as int?;
        if (stockId != null && detailIdByStockId.containsKey(stockId)) {
          pm['server_detail_id'] = detailIdByStockId[stockId];
        }
        return pm;
      }).toList();

      current['body'] = bodyMutable;
      await box.put(hiveKey, current);
    } catch (e) {
      // Non-fatal — detail ID storage is best-effort.
      debugPrint('_storeDetailIdsFromResponse: $e');
    }
  }
}
