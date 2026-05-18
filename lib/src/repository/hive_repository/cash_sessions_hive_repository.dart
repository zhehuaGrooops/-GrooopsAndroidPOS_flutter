import 'package:admin_desktop/src/core/di/dependency_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:admin_desktop/src/core/constants/hive_boxes.dart';
import 'package:admin_desktop/src/core/handlers/handlers.dart';
import 'package:admin_desktop/src/core/utils/local_storage.dart';
import 'package:admin_desktop/src/models/models.dart';
import 'package:hive/hive.dart';
import 'package:admin_desktop/src/core/utils/cash_drawer_calculator.dart';

import 'package:admin_desktop/src/core/db/hive_service.dart';

import 'package:admin_desktop/src/repository/cash_sessions_repository.dart';
import 'package:admin_desktop/src/repository/orders_repository.dart';
import 'package:admin_desktop/src/repository/hive_repository/orders_hive_repository.dart';

class CashSessionsHiveRepository extends CashSessionsRepository {
  final OrdersRepository? _ordersRepo;

  CashSessionsHiveRepository({
    OrdersRepository? ordersRepo,
  }) : _ordersRepo = ordersRepo;

  OrdersRepository get ordersRepo => _ordersRepo ?? OrdersHiveRepository();

  Future<Box> _box() => HiveService.openBox(HiveBoxes.cashSessions);

  @override
  Future<ApiResult<dynamic>> openCashSession(
      {required Map<String, dynamic> body}) async {
    try {
      final box = await _box();

      // Check locally for active session
      final active = box.values.firstWhere(
        (e) => e['closed_at'] == null,
        orElse: () => null,
      );

      if (active != null) {
        return ApiResult.success(data: {'data': active});
      }

      // Create locally with pending status
      final int id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final user = LocalStorage.getUser();
      final localSession = {
        'id': id,
        'uuid': '$id',
        'opened_at': DateTime.now().toIso8601String(),
        'closed_at': null,
        'opening_balance': body['amount'] ?? 0,
        'user_id': user?.id,
        'state': 'open',
        'transactions_summary': {},
        '_meta': {'syncStatus': 'pending'},
      };
      await box.put(id, localSession);
      return ApiResult.success(data: {'data': localSession});
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<dynamic>> activeCashSession() async {
    try {
      final box = await _box();

      // Try local only
      final active = box.values.firstWhere(
        (e) => e['closed_at'] == null,
        orElse: () => null,
      );

      if (active != null) {
        return ApiResult.success(data: {'data': active});
      }

      return const ApiResult.success(data: null);
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<dynamic>> closeCashSession({
    required int id,
    Map<String, dynamic>? summary,
  }) async {
    try {
      final box = await _box();
      final sessionMap = box.get(id);

      if (sessionMap == null) {
        return const ApiResult.failure(error: 'Session not found');
      }

      // Calculate Summary Locally
      final summaryResult = await _calculateSessionSummary(id);

      return await summaryResult.when(
        success: (summary) async {
          final closedSession = Map<String, dynamic>.from(sessionMap);
          closedSession['closed_at'] = DateTime.now().toIso8601String();
          closedSession['state'] = 'closed';
          closedSession['transactions_summary'] = summary;
          closedSession['revenue_amount'] =
              summary['revenue_summary']?['total'] ?? 0.0;
          closedSession['_meta'] = {'syncStatus': 'close_pending'};

          await box.put(id, closedSession);
          return ApiResult.success(data: {'data': closedSession});
        },
        failure: (error, _) async {
          return ApiResult.failure(error: 'Failed to close session: $error');
        },
      );
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @visibleForTesting
  Future<Map<String, dynamic>> calculateSessionSummaryForTest(
      int sessionId) async {
    final result = await _calculateSessionSummary(sessionId);
    return result.when(
      success: (data) => data,
      failure: (error, _) => {},
    );
  }

  /// Calculates the summary for a given cash session.
  ///
  /// Performs the following:
  /// 1. Retrieves all transactions associated with the session ID.
  /// 2. Fetches corresponding order details from the Hive database.
  /// 3. Aggregates today's closed sessions for comparison.
  /// 4. Computes the summary using [CashDrawerCalculator].
  ///
  /// Returns an [ApiResult] containing the session summary map.
  Future<ApiResult<Map<String, dynamic>>> _calculateSessionSummary(
      int sessionId) async {
    try {
      final cashSessionsBox = await _box();
      debugPrint('==> Calculating summary for session: $sessionId');

      // 1. Get transactions for this session using paymentsRepository
      final transactionsResult =
          await paymentsRepository.getTransactionsBySessionId(sessionId);

      final List<Map<String, dynamic>> transactions = [];
      transactionsResult.when(
        success: (data) {
          transactions.addAll(data);
          debugPrint(
              '==> Found ${data.length} transactions for session $sessionId');
        },
        failure: (error, _) {
          debugPrint('==> Summary calculation warning: $error');
        },
      );

      // 2. Get orders involved using OrdersHiveRepository for consistent data pipeline
      final Set<int> orderIds =
          transactions.map((tx) => tx['order_id'] as int).toSet();

      final ordersResult = await _fetchOrdersFromHive(orderIds);
      final List<OrderHiveModel> orders = [];
      ordersResult.when(
        success: (data) {
          orders.addAll(data);
          debugPrint(
              '==> Fetched ${data.length} orders for summary calculation');
          for (var o in data) {
            debugPrint('  -> Order ID: ${o.id}, Total: ${o.totalPrice}');
          }
        },
        failure: (error, _) {
          debugPrint('==> Summary calculation warning: $error');
        },
      );

      // 3. Get all sessions for today
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      final List<Map<String, dynamic>> allSessionsToday = cashSessionsBox.values
          .where((s) => s is Map && s['closed_at'] != null)
          .map((s) => Map<String, dynamic>.from(s))
          .where((s) {
        final closedAt = DateTime.parse(s['closed_at']);
        return closedAt.isAfter(todayStart) && closedAt.isBefore(todayEnd);
      }).toList();

      // 4. Get current session and user
      final sessionData = cashSessionsBox.get(sessionId);
      if (sessionData == null) {
        return ApiResult.failure(error: 'Session $sessionId not found');
      }
      final currentSession = Map<String, dynamic>.from(sessionData);
      final currentUser = LocalStorage.getUser();
      final userMap = currentUser != null
          ? {
              'id': currentUser.id,
              'firstname': currentUser.firstname,
              'lastname': currentUser.lastname,
            }
          : null;

      // 5. Use Calculator
      final summary = await CashDrawerCalculator.computeSessionSummary(
        orders: orders,
        transactions: transactions,
        session: currentSession,
        allSessionsToday: allSessionsToday,
        currentUser: userMap,
      );

      return ApiResult.success(data: summary);
    } catch (e) {
      return ApiResult.failure(
        error: 'Failed to calculate session summary for session $sessionId: $e',
      );
    }
  }

  /// Retrieves order details from Hive for a set of order IDs.
  ///
  /// This follows the pattern in [OrdersHiveRepository.fetchOrderById] for
  /// consistent error handling and data retrieval.
  Future<ApiResult<List<OrderHiveModel>>> _fetchOrdersFromHive(
      Set<int> orderIds) async {
    try {
      final List<OrderHiveModel> orders = [];
      for (final id in orderIds) {
        // Utilizing fetchOrderById from OrdersHiveRepository for consistent pattern
        final result = await ordersRepo.fetchOrderById(id);
        result.when(
          success: (orderModel) {
            orders.add(orderModel);
          },
          failure: (error, _) {
            debugPrint(
                '==> Failed to fetch order $id from local database: $error');
          },
        );
      }
      return ApiResult.success(data: orders);
    } catch (e) {
      return ApiResult.failure(
        error: 'Hive database access failed during batch order fetch: $e',
      );
    }
  }
}
