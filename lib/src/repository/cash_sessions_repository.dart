import '../core/handlers/handlers.dart';

abstract class CashSessionsRepository {
  Future<ApiResult<dynamic>> openCashSession(
      {required Map<String, dynamic> body});
  Future<ApiResult<dynamic>> closeCashSession({
    required int id,
    Map<String, dynamic>? summary,
  });
  Future<ApiResult<dynamic>> activeCashSession();
}
