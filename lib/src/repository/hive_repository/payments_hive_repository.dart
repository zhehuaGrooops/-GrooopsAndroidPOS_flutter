import 'package:admin_desktop/src/core/constants/hive_boxes.dart';
import 'package:admin_desktop/src/core/handlers/handlers.dart';
import 'package:admin_desktop/src/models/models.dart';
import 'package:hive/hive.dart';

import '../../core/db/hive_service.dart';
import '../payments_repository.dart';

class PaymentsHiveRepository extends PaymentsRepository {
  Future<Box> _box() => HiveService.openBox(HiveBoxes.payments);
  Future<Box> _transactionsBox() => HiveService.openBox(HiveBoxes.transactions);

  @override
  Future<ApiResult<PaymentsResponse>> getPayments() async {
    try {
      final box = await _box();
      final list = box.values
          .whereType<Map>()
          .map((e) => PaymentData.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return ApiResult.success(data: PaymentsResponse(data: list));
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<TransactionsResponse>> createTransaction(
      {required int orderId, required int paymentId}) async {
    try {
      final box = await _transactionsBox();

      final cashSessionsBox = await HiveService.openBox(HiveBoxes.cashSessions);
      final activeSession = cashSessionsBox.values.firstWhere(
        (e) => e['closed_at'] == null,
        orElse: () => null,
      );

      final tx = {
        'order_id': orderId,
        'payment_id': paymentId,
        'created_at': DateTime.now().toIso8601String(),
        'cash_session_id': activeSession?['id'],
      };
      await box.add(tx);
      return ApiResult.success(data: TransactionsResponse());
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<List<Map<String, dynamic>>>> getTransactionsBySessionId(
    int sessionId,
  ) async {
    try {
      final box = await _transactionsBox();
      final list = box.values
          .whereType<Map>()
          .where((e) => e['cash_session_id'] == sessionId)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      return ApiResult.success(data: list);
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }
}
