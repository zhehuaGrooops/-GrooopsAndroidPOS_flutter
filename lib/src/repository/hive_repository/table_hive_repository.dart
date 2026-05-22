import 'package:admin_desktop/src/core/constants/hive_boxes.dart';
import 'package:admin_desktop/src/core/handlers/handlers.dart';
import 'package:admin_desktop/src/core/utils/app_connectivity.dart';
import 'package:admin_desktop/src/models/data/table_data.dart';
import 'package:admin_desktop/src/models/response/table_response.dart';
import 'package:admin_desktop/src/models/response/table_bookings_response.dart';
import 'package:admin_desktop/src/models/response/table_info_response.dart';
import 'package:admin_desktop/src/models/data/table_info_data.dart';
import 'package:admin_desktop/src/models/response/table_statistic_response.dart';
import 'package:admin_desktop/src/models/response/working_day_response.dart';
import 'package:admin_desktop/src/models/response/close_day_response.dart';
import 'package:admin_desktop/src/models/data/table_statistics_data.dart';
import 'package:hive/hive.dart';

import '../../core/db/hive_service.dart';
import '../../core/handlers/api_result.dart';
import '../../core/sync/sync_service.dart';
import '../../models/models.dart';
import '../table_repository.dart';

class TableHiveRepository extends TableRepository {
  Future<Box> _box() => HiveService.openBox(HiveBoxes.tables);

  @override
  Future<ApiResult<ShopSection>> createNewSection(
      {required String name, required num area}) async {
    try {
      final box = await _box();
      final localId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final map = {
        'type': 'section',
        'id': localId,
        'area': area.toString(),
        'translation': {'title': name}
      };
      await box.put('section_$localId', map);
      return ApiResult.success(data: ShopSection.fromJson(map));
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<ShopSectionResponse>> getSection(
      {int? page, String? query}) async {
    try {
      final box = await _box();
      final list = box.values
          .whereType<Map>()
          .where((e) => e['type'] == 'section')
          .map((e) => ShopSection.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return ApiResult.success(data: ShopSectionResponse(data: list));
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<dynamic>> createNewTable(
      {required TableModel tableModel}) async {
    try {
      final box = await _box();
      final localId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final map = <String, dynamic>{
        'type': 'table',
        'id': localId,
        ...tableModel.toJson(),
        '_meta': {
          'syncStatus': 'pending',
          'operation': 'create',
          'updatedAt': DateTime.now().toIso8601String(),
        },
      };
      await box.put('table_$localId', map);
      if (await AppConnectivity.connectivity()) {
        await SyncService().pushTableChanges();
      }
      return const ApiResult.success(data: null);
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<TableResponse>> getTables(
      {int? page,
      String? query,
      int? shopSectionId,
      String? type,
      DateTime? from,
      DateTime? to}) async {
    try {
      final box = await _box();
      final list = box.values
          .whereType<Map>()
          .where((e) => e['type'] == 'table')
          .where((e) => e['_meta']?['operation'] != 'delete')
          .map((e) => TableData.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return ApiResult.success(
          data: TableResponse(
              timestamp: DateTime.now().toIso8601String(),
              status: true,
              message: '',
              data: list));
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<TableBookingResponse>> getTableOrders(
      {int? page, int? id, String? type, DateTime? from, DateTime? to}) async {
    try {
      return ApiResult.success(data: TableBookingResponse(data: []));
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<TableInfoResponse>> getTableInfo(int id) async {
    try {
      final now = DateTime.now();
      final info = TableInfoData(
          id: id,
          bookingId: 0,
          userId: 0,
          tableId: id,
          startDate: now,
          endDate: now,
          status: 'unknown');
      return ApiResult.success(
          data: TableInfoResponse(
              timestamp: now, status: true, message: '', data: info));
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<TableResponse>> deleteSection(int id) async {
    try {
      final box = await _box();
      await box.delete(id);
      return ApiResult.success(
          data: TableResponse(
              timestamp: DateTime.now().toIso8601String(),
              status: true,
              message: '',
              data: []));
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<TableResponse>> deleteTable(int id) async {
    try {
      final box = await _box();
      final key = 'table_$id';
      final existing = box.get(key);
      if (existing is Map) {
        final map = Map<String, dynamic>.from(existing);
        map['_meta'] = {
          'syncStatus': 'pending',
          'operation': 'delete',
          'updatedAt': DateTime.now().toIso8601String(),
        };
        await box.put(key, map);
      }
      if (await AppConnectivity.connectivity()) {
        await SyncService().pushTableChanges();
      }
      return ApiResult.success(
          data: TableResponse(
              timestamp: DateTime.now().toIso8601String(),
              status: true,
              message: '',
              data: []));
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<List<DisableDates>>> disableDates(
      {required DateTime dateTime, required int? id}) async {
    try {
      return ApiResult.success(data: <DisableDates>[]);
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<BookingsResponse>> getBookings({int? page}) async {
    try {
      return ApiResult.success(data: BookingsResponse(data: null));
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<dynamic>> setBookings(
      {int? bookingId,
      int? tableId,
      DateTime? startDate,
      DateTime? endDate}) async {
    try {
      final box = await _box();
      await box.add({
        'type': 'booking',
        'bookingId': bookingId,
        'tableId': tableId,
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate?.toIso8601String()
      });
      return const ApiResult.success(data: null);
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<WorkingDayResponse>> getWorkingDay() async {
    try {
      final now = DateTime.now();
      final wd = WorkingDayData(
          dates: [], shop: Shop(id: 0, createdAt: now, updatedAt: now));
      return ApiResult.success(
          data: WorkingDayResponse(
              timestamp: now, status: true, message: '', data: wd));
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<CloseDayResponse>> getCloseDay() async {
    try {
      return ApiResult.success(
          data: CloseDayResponse(data: Data(bookingShopClosedDate: [])));
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<TableData>> updateTablePosition(
      int id, double normX, double normY) async {
    try {
      final box = await _box();
      final key = 'table_$id';
      final raw = box.get(key);
      final map = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{'type': 'table', 'id': id};
      map['position_x'] = normX;
      map['position_y'] = normY;
      map['_meta'] = {
        'syncStatus': 'pending',
        'operation': 'update_position',
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await box.put(key, map);
      if (await AppConnectivity.connectivity()) {
        await SyncService().pushTableChanges();
      }
      return ApiResult.success(data: TableData.fromJson(map));
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<ShopSection>> updateSectionMapSize(
      int id, int width, int height) async {
    try {
      final box = await _box();
      final key = 'section_$id';
      final raw = box.get(key);
      final map = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{'type': 'section', 'id': id};
      map['map_width'] = width;
      map['map_height'] = height;
      map['_meta'] = {
        'syncStatus': 'pending',
        'operation': 'update_map_size',
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await box.put(key, map);
      if (await AppConnectivity.connectivity()) {
        await SyncService().pushTableChanges();
      }
      return ApiResult.success(data: ShopSection.fromJson(map));
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<dynamic>> changeOrderStatus(
      {required String status, required int id}) async {
    try {
      final box = await _box();
      final map = Map<String, dynamic>.from((box.get(id) as Map?) ?? {});
      map['order_status'] = status;
      await box.put(id, map);
      return const ApiResult.success(data: null);
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<TableStatisticResponse>> getStatistic(
      {DateTime? from, DateTime? to}) async {
    try {
      final now = DateTime.now();
      final stat = TableStatisticData(
        available: 0,
        booked: 0,
        occupied: 0,
        availableIds: [],
        bookedIds: [],
        occupiedIds: [],
        allBooked: [],
        allOccupied: [],
      );
      return ApiResult.success(
          data: TableStatisticResponse(
              timestamp: now, status: true, message: '', data: stat));
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }
}
