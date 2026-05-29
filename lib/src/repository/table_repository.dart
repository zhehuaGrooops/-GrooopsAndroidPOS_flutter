import 'package:admin_desktop/src/models/data/table_model.dart';
import 'package:admin_desktop/src/models/response/close_day_response.dart';
import 'package:admin_desktop/src/models/response/table_bookings_response.dart';
import 'package:admin_desktop/src/models/response/table_info_response.dart';
import 'package:admin_desktop/src/models/response/table_statistic_response.dart';
import 'package:admin_desktop/src/models/response/working_day_response.dart';
import '../core/handlers/handlers.dart';
import '../models/data/disable_dates.dart';
import '../models/data/table_data.dart';
import '../models/response/bookings_response.dart';
import '../models/response/shop_section_response.dart';
import '../models/response/table_response.dart';

abstract class TableRepository {
  Future<ApiResult<ShopSection>> createNewSection(
      {required String name, required num area});

  Future<ApiResult<ShopSectionResponse>> getSection({
    int? page,
    String? query,
  });

  Future<ApiResult<dynamic>> createNewTable({required TableModel tableModel});

  Future<ApiResult<TableResponse>> getTables({
    int? page,
    String? query,
    int? shopSectionId,
    String? type,
    DateTime? from,
    DateTime? to,
  });

  Future<ApiResult<TableBookingResponse>> getTableOrders({
    int? page,
    int? id,
    String? type,
    DateTime? from,
    DateTime? to,
  });

  Future<ApiResult<TableInfoResponse>> getTableInfo(int id);

  Future<ApiResult<TableResponse>> deleteSection(int id);

  Future<ApiResult<TableResponse>> deleteTable(int id);

  Future<ApiResult<TableData>> updateTable({
    required int id,
    String? name,
    int? chairCount,
    double? positionX,
    double? positionY,
  });

  Future<ApiResult<List<DisableDates>>> disableDates({
    required DateTime dateTime,
    required int? id,
  });

  Future<ApiResult<BookingsResponse>> getBookings({int? page});

  Future<ApiResult<dynamic>> setBookings({
    int? bookingId,
    int? tableId,
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<ApiResult<WorkingDayResponse>> getWorkingDay();

  Future<ApiResult<CloseDayResponse>> getCloseDay();

  Future<ApiResult<dynamic>> changeOrderStatus(
      {required String status, required int id});

  Future<ApiResult<TableStatisticResponse>> getStatistic({
    DateTime? from,
    DateTime? to,
  });

  Future<ApiResult<ShopSection>> updateSectionMapSize(
      int id, int width, int height);

  Future<ApiResult<ShopSection>> updateSection(
      {required int id, required String name, required num area});
}
