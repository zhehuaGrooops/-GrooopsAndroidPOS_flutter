import 'package:admin_desktop/src/core/constants/constants.dart';
import 'package:admin_desktop/src/core/di/dependency_manager.dart';
import 'package:admin_desktop/src/core/utils/time_service.dart';
import 'package:admin_desktop/src/models/response/close_day_response.dart';
import 'package:admin_desktop/src/models/response/table_info_response.dart';
import 'package:admin_desktop/src/models/response/table_statistic_response.dart';
import 'package:admin_desktop/src/models/response/working_day_response.dart';
import 'package:admin_desktop/src/repository/table_repository.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/handlers/handlers.dart';
import '../../core/utils/utils.dart';
import '../../models/data/table_data.dart';
import '../../models/models.dart';
import '../../models/response/table_bookings_response.dart';
import '../../models/response/table_response.dart';

class TableRepositoryIml extends TableRepository {
  @override
  Future<ApiResult<ShopSection>> createNewSection(
      {required String name, required num area}) async {
    try {
      final client = dioHttp.client(requireAuth: true);
      final response = await client.post(
        '/api/v1/dashboard/${LocalStorage.getUser()?.role}/shop-sections',
        queryParameters: {
          "area": area,
          "images": [],
          "title": {LocalStorage.getLanguage()?.locale ?? 'en': name}
        },
      );
      return ApiResult.success(
          data: ShopSection.fromJson(response.data["data"]));
    } catch (e, stackTrace) {
      debugPrint('==> get createNewSection failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'TableRepositoryIml.createNewSection',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<ShopSectionResponse>> getSection({
    int? page,
    String? query,
  }) async {
    final data = {
      if (page != null) 'page': page,
      'perPage': 50,
      if (query != null) 'search': query,
      'lang': LocalStorage.getLanguage()?.locale ?? 'en',
    };
    try {
      final client = dioHttp.client(requireAuth: true);
      final response = await client.get(
        '/api/v1/dashboard/${LocalStorage.getUser()?.role}/shop-sections',
        queryParameters: data,
      );
      return ApiResult.success(
        data: ShopSectionResponse.fromJson(response.data),
        // data: TableResponse.fromJson(mapData),
      );
    } catch (e, stackTrace) {
      debugPrint('==> get getSection failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'TableRepositoryIml.getSection',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<dynamic>> createNewTable(
      {required TableModel tableModel}) async {
    try {
      final client = dioHttp.client(requireAuth: true);
      await client.post(
        '/api/v1/dashboard/${LocalStorage.getUser()?.role}/tables',
        queryParameters: tableModel.toJson(),
      );
      return const ApiResult.success(data: null);
    } catch (e, stackTrace) {
      debugPrint('==> get createNewTable failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'TableRepositoryIml.createNewTable',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<TableResponse>> getTables({
    int? page,
    int? shopSectionId,
    String? type,
    String? query,
    DateTime? from,
    DateTime? to,
  }) async {
    from ??= from ?? DateTime.now();
    to ??= to ?? DateTime.now();
    to = to.add(const Duration(days: 1));
    final data = {
      if (page != null) 'page': page,
      'perPage': 10,
      'lang': LocalStorage.getLanguage()?.locale ?? 'en',
      if (type != null) 'status': type,
      if (shopSectionId != null) "shop_section_id": shopSectionId,
      if (type != null) "date_from": TimeService.dateFormatYMD(from),
      if (type != null) "date_to": TimeService.dateFormatYMD(to),
      if (query != null) "search": query,
    };
    try {
      final client = dioHttp.client(requireAuth: true);
      final response = await client.get(
        '/api/v1/dashboard/${LocalStorage.getUser()?.role}/tables',
        queryParameters: data,
      );
      return ApiResult.success(
        data: TableResponse.fromJson(response.data),
      );
    } catch (e, stackTrace) {
      debugPrint('==> get getTableInfo failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'TableRepositoryIml.getTables',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<TableBookingResponse>> getTableOrders({
    int? page,
    int? id,
    String? type,
    DateTime? from,
    DateTime? to,
  }) async {
    to = to != null ? to.add(const Duration(days: 1)) : from;

    final data = {
      if (page != null) 'page': page,
      'lang': LocalStorage.getLanguage()?.locale ?? 'en',
      if (type != null) 'status': type,
      if (from != null)
        "start_from":
            from.toString().substring(0, from.toString().indexOf(" ")),
      if (to != null)
        "start_to": to.toString().substring(0, to.toString().indexOf(" ")),
    };
    try {
      final client = dioHttp.client(requireAuth: true);
      final response = await client.get(
        '/api/v1/dashboard/${LocalStorage.getUser()?.role}/user-bookings',
        queryParameters: data,
      );
      return ApiResult.success(
        data: TableBookingResponse.fromJson(response.data),
        // data: TableResponse.fromJson(mapData),
      );
    } catch (e, stackTrace) {
      debugPrint('==> get getTableOrders failure: $e,$stackTrace');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'TableRepositoryIml.getTableOrders',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<TableResponse>> deleteSection(int id) async {
    try {
      final client = dioHttp.client(requireAuth: true);
      final response = await client.delete(
        '/api/v1/dashboard/${LocalStorage.getUser()?.role}/shop-sections/delete',
        queryParameters: {"ids[0]": id},
      );
      return ApiResult.success(
        data: TableResponse.fromJson(response.data),
      );
    } catch (e, stackTrace) {
      debugPrint('==> get deleteSection failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'TableRepositoryIml.deleteSection',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<TableResponse>> deleteTable(int id) async {
    try {
      final client = dioHttp.client(requireAuth: true);
      final response = await client.delete(
        '/api/v1/dashboard/${LocalStorage.getUser()?.role}/tables/delete',
        queryParameters: {"ids[0]": id},
      );
      return ApiResult.success(
        data: TableResponse.fromJson(response.data),
      );
    } catch (e, stackTrace) {
      debugPrint('==> get deleteTable failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'TableRepositoryIml.deleteTable',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<List<DisableDates>>> disableDates({
    required DateTime dateTime,
    required int? id,
  }) async {
    try {
      final client = dioHttp.client(requireAuth: true);
      final response = await client.get(
        '/api/v1/dashboard/${LocalStorage.getUser()?.role}/disable-dates/table/$id',
        queryParameters: {
          'lang': LocalStorage.getLanguage()?.locale ?? 'en',
          "date_from": DateFormat("yyyy-MM-dd").format(dateTime),
        },
      );
      return ApiResult.success(data: disableDatesFromJson(response.data));
    } catch (e, stackTrace) {
      debugPrint('==> get disableDates failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'TableRepositoryIml.disableDates',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<BookingsResponse>> getBookings({int? page}) async {
    try {
      final client = dioHttp.client(requireAuth: true);
      final response = await client.get(
        '/api/v1/dashboard/${LocalStorage.getUser()?.role}/bookings',
        queryParameters: {
          'lang': LocalStorage.getLanguage()?.locale ?? 'en',
          'page': page,
          'perPage': 100
        },
      );
      return ApiResult.success(data: BookingsResponse.fromJson(response.data));
    } catch (e, stackTrace) {
      debugPrint('==> get getBookings failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'TableRepositoryIml.getBookings',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<dynamic>> setBookings({
    int? bookingId,
    int? tableId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final client = dioHttp.client(requireAuth: true);
      await client.post(
        '/api/v1/dashboard/${LocalStorage.getUser()?.role}/user-bookings',
        data: {
          'booking_id': bookingId,
          'end_date': TimeService.dateFormatYMD(endDate ?? DateTime.now()),
          'start_date': TimeService.dateFormatYMD(startDate ?? DateTime.now()),
          "table_id": tableId
        },
      );
      return const ApiResult.success(data: null);
    } catch (e, stackTrace) {
      debugPrint('==> get setBookings failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'TableRepositoryIml.setBookings',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<WorkingDayResponse>> getWorkingDay() async {
    try {
      final client = dioHttp.client(requireAuth: true);
      final response = await client.get(
        '/api/v1/dashboard/${LocalStorage.getUser()?.role}/booking/shop-working-days/${LocalStorage.getUser()?.role == TrKeys.waiter ? LocalStorage.getUser()?.invite?.shopId : LocalStorage.getUser()?.shop?.uuid}',
        queryParameters: {'lang': LocalStorage.getLanguage()?.locale ?? 'en'},
      );
      return ApiResult.success(
          data: WorkingDayResponse.fromJson(response.data));
    } catch (e, stackTrace) {
      debugPrint('==> get getWorkingDay failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'TableRepositoryIml.getWorkingDay',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<CloseDayResponse>> getCloseDay() async {
    try {
      final client = dioHttp.client(requireAuth: true);
      final response = await client.get(
        '/api/v1/dashboard/${LocalStorage.getUser()?.role}/booking/shop-closed-dates/${LocalStorage.getUser()?.role == TrKeys.waiter ? LocalStorage.getUser()?.invite?.shopId : LocalStorage.getUser()?.shop?.uuid}',
        queryParameters: {'lang': LocalStorage.getLanguage()?.locale ?? 'en'},
      );
      return ApiResult.success(data: CloseDayResponse.fromJson(response.data));
    } catch (e, stackTrace) {
      debugPrint('==> getCloseDay failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'TableRepositoryIml.getCloseDay',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<TableInfoResponse>> getTableInfo(int id) async {
    try {
      final client = dioHttp.client(requireAuth: true);
      final response = await client.get(
        '/api/v1/dashboard/${LocalStorage.getUser()?.role}/user-bookings/$id',
        queryParameters: {'lang': LocalStorage.getLanguage()?.locale ?? 'en'},
      );
      return ApiResult.success(data: TableInfoResponse.fromJson(response.data));
    } catch (e, stackTrace) {
      debugPrint('==> getTableInfo failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'TableRepositoryIml.getTableInfo',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult> changeOrderStatus(
      {required String status, required int id}) async {
    try {
      final client = dioHttp.client(requireAuth: true);
      await client.post(
        '/api/v1/dashboard/${LocalStorage.getUser()?.role}/user-booking/status/$id',
        queryParameters: {'status': status},
      );
      return const ApiResult.success(data: null);
    } catch (e, stackTrace) {
      debugPrint('==> changeOrderStatus failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'TableRepositoryIml.changeOrderStatus',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<TableStatisticResponse>> getStatistic({
    DateTime? from,
    DateTime? to,
  }) async {
    from ??= from ?? DateTime.now();
    to ??= to ?? DateTime.now();
    to = to.add(const Duration(days: 1));

    try {
      final client = dioHttp.client(requireAuth: true);
      final response = await client.get(
          '/api/v1/dashboard/${LocalStorage.getUser()?.role}/table/statistic',
          queryParameters: {
            "date_from": TimeService.dateFormatYMD(from),
            "date_to": TimeService.dateFormatYMD(to),
          });
      return ApiResult.success(
          data: TableStatisticResponse.fromJson(response.data));
    } catch (e, stackTrace) {
      debugPrint('==> get statistic failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'TableRepositoryIml.getStatistic',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<TableData>> updateTablePosition(
      int id, double normX, double normY) async {
    try {
      final client = dioHttp.client(requireAuth: true);
      final response = await client.patch(
        '/api/v1/dashboard/${LocalStorage.getUser()?.role}/tables/$id/position',
        data: {'position_x': normX, 'position_y': normY},
      );
      return ApiResult.success(
          data: TableData.fromJson(
              Map<String, dynamic>.from(response.data['data'])));
    } catch (e, stackTrace) {
      debugPrint('==> updateTablePosition failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'TableRepositoryIml.updateTablePosition',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<ShopSection>> updateSectionMapSize(
      int id, int width, int height) async {
    try {
      final client = dioHttp.client(requireAuth: true);
      final response = await client.patch(
        '/api/v1/dashboard/${LocalStorage.getUser()?.role}/shop-sections/$id/map-size',
        data: {'map_width': width, 'map_height': height},
      );
      return ApiResult.success(
          data: ShopSection.fromJson(
              Map<String, dynamic>.from(response.data['data'])));
    } catch (e, stackTrace) {
      debugPrint('==> updateSectionMapSize failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'TableRepositoryIml.updateSectionMapSize',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }
}
