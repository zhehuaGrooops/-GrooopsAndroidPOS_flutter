import 'dart:convert';

import 'package:admin_desktop/src/core/constants/constants.dart';
import 'package:admin_desktop/src/core/di/dependency_manager.dart';
import 'package:admin_desktop/src/models/response/income_chart_response.dart';
import 'package:admin_desktop/src/models/response/income_statistic_response.dart';
import 'package:admin_desktop/src/models/response/mobile_translations_response.dart';
import 'package:admin_desktop/src/models/response/sale_cart_response.dart';
import 'package:flutter/material.dart';

import '../../core/handlers/handlers.dart';
import '../../core/utils/utils.dart';
import '../../models/data/help_data.dart';
import '../../models/models.dart';
import '../../models/response/income_cart_response.dart';
import '../../models/response/sale_history_response.dart';
import '../repository.dart';
import 'package:admin_desktop/src/models/data/sale_receipt.dart';

class SettingsSettingsRepositoryImpl extends SettingsRepository {
  @override
  Future<ApiResult<GlobalSettingsResponse>> getGlobalSettings() async {
    try {
      final client = dioHttp.client(requireAuth: false);
      final response = await client.get('/api/v1/rest/settings');
      debugPrint('==> get global settings response: $response');
      return ApiResult.success(
        data: GlobalSettingsResponse.fromJson(response.data),
      );
    } catch (e, stackTrace) {
      debugPrint('==> get settings failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'SettingsSettingsRepositoryImpl.getGlobalSettings',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<MobileTranslationsResponse>> getMobileTranslations(
      {String? lang}) async {
    final data = {'lang': lang ?? LocalStorage.getLanguage()?.locale ?? 'en'};
    try {
      final dioHttp = HttpService();
      final client = dioHttp.client(requireAuth: false);
      final response = await client.get(
        '/api/v1/rest/translations/paginate',
        queryParameters: data,
      );
      await LocalStorage.setTranslations(
          MobileTranslationsResponse.fromJson(response.data).data);
      return ApiResult.success(
          data: MobileTranslationsResponse.fromJson(response.data));
    } catch (e, stackTrace) {
      debugPrint('==> get translations failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'SettingsSettingsRepositoryImpl.getMobileTranslations',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<TranslationsResponse>> getTranslations() async {
    final data = {'lang': LocalStorage.getLanguage()?.locale ?? 'en'};
    try {
      final client = dioHttp.client(requireAuth: false);
      final response = await client.get(
        '/api/v1/rest/translations/paginate',
        queryParameters: data,
      );
      return ApiResult.success(
        data: TranslationsResponse.fromJson(response.data),
      );
    } catch (e, stackTrace) {
      debugPrint('==> get translations failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'SettingsSettingsRepositoryImpl.getTranslations',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<SaleHistoryResponse>> getSaleHistory(
      int type, int page) async {
    final data = {
      'type': type == 0
          ? "deliveryman"
          : type == 1
              ? "today"
              : "history",
      "perPage": 10,
      "page": page,
      "sort": "desc",
      "column": "created_at"
    };
    try {
      final client = dioHttp.client(requireAuth: true);
      final response = await client.get(
        '/api/v1/dashboard/${LocalStorage.getUser()?.role}/sales-history',
        queryParameters: data,
      );
      return ApiResult.success(
        data: SaleHistoryResponse.fromJson(response.data),
      );
    } catch (e, stackTrace) {
      debugPrint('==> get sale history failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'SettingsSettingsRepositoryImpl.getSaleHistory',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<SaleReceipt?>> getSaleReceipt(String saleId) async {
    try {
      return ApiResult.success(data: null);
    } catch (e, stackTrace) {
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'SettingsSettingsRepositoryImpl.getSaleReceipt',
      );
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<SaleCartResponse>> getSaleCart() async {
    try {
      final client = dioHttp.client(requireAuth: true);
      final response = await client.get(
        '/api/v1/dashboard/${LocalStorage.getUser()?.role}/sales-cards',
      );
      return ApiResult.success(
        data: SaleCartResponse.fromJson(response.data),
      );
    } catch (e, stackTrace) {
      debugPrint('==> get sale cart failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'SettingsSettingsRepositoryImpl.getSaleCart',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<IncomeStatisticResponse>> getIncomeStatistic(
      {required String type,
      required DateTime? from,
      required DateTime? to}) async {
    try {
      final data = {
        "type": type,
        "date_from": from.toString().substring(0, from.toString().indexOf(" ")),
        "date_to": to.toString().substring(0, to.toString().indexOf(" "))
      };
      final client = dioHttp.client(requireAuth: true);
      final response = await client.get(
          '/api/v1/dashboard/${LocalStorage.getUser()?.role}/sales-statistic',
          queryParameters: data);
      return ApiResult.success(
        data: IncomeStatisticResponse.fromJson(response.data),
      );
    } catch (e, stackTrace) {
      debugPrint('==> get sale statistic failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'SettingsSettingsRepositoryImpl.getIncomeStatistic',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<IncomeCartResponse>> getIncomeCart(
      {required String type,
      required DateTime? from,
      required DateTime? to}) async {
    try {
      final data = {
        "type": type,
        "date_from": from.toString().substring(0, from.toString().indexOf(" ")),
        "date_to": to.toString().substring(0, to.toString().indexOf(" "))
      };
      final client = dioHttp.client(requireAuth: true);
      final response = await client.get(
          '/api/v1/dashboard/${LocalStorage.getUser()?.role}/sales-main-cards',
          queryParameters: data);
      return ApiResult.success(
        data: IncomeCartResponse.fromJson(response.data),
      );
    } catch (e, stackTrace) {
      debugPrint('==> get sale cart failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'SettingsSettingsRepositoryImpl.getIncomeCart',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<List<IncomeChartResponse>>> getIncomeChart(
      {required String type,
      required DateTime? from,
      required DateTime? to}) async {
    try {
      final data = {
        "type": type == TrKeys.week ? TrKeys.month : type,
        "date_from": from.toString().substring(0, from.toString().indexOf(" ")),
        "date_to": to.toString().substring(0, to.toString().indexOf(" "))
      };
      final client = dioHttp.client(requireAuth: true);
      final response = await client.get(
          '/api/v1/dashboard/${LocalStorage.getUser()?.role}/sales-chart',
          queryParameters: data);
      return ApiResult.success(
        data: incomeChartResponseFromJson(jsonEncode(response.data)),
      );
    } catch (e, stackTrace) {
      debugPrint('==> get sale cart failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'SettingsSettingsRepositoryImpl.getIncomeChart',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<LanguagesResponse>> getLanguages() async {
    try {
      final client = HttpService().client(requireAuth: false);
      final response = await client.get('/api/v1/rest/languages/active');
      if (LocalStorage.getLanguage() == null ||
          !(LanguagesResponse.fromJson(response.data)
                  .data
                  ?.map((e) => e.id)
                  .contains(LocalStorage.getLanguage()?.id) ??
              true)) {
        LanguagesResponse.fromJson(response.data).data?.forEach((element) {
          if (element.isDefault ?? false) {
            LocalStorage.setLanguageData(element);
            LocalStorage.setLangLtr(element.backward);
          }
        });
      }
      return ApiResult.success(
        data: LanguagesResponse.fromJson(response.data),
      );
    } catch (e, stackTrace) {
      debugPrint('==> get languages failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'SettingsSettingsRepositoryImpl.getLanguages',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<HelpModel>> getFaq() async {
    try {
      final client = dioHttp.client(requireAuth: true);
      final response = await client.get('/api/v1/rest/faqs/paginate');
      return ApiResult.success(
        data: HelpModel.fromJson(response.data),
      );
    } catch (e, stackTrace) {
      debugPrint('==> get faq failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'SettingsSettingsRepositoryImpl.getFaq',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<String>> getTerminalID() async {
    try {
      final client = dioHttp.client(requireAuth: true);
      final body = {"prefix": "T"};
      final response = await client
          .post('/api/v1/rest/running-number/terminal/increment', data: body);
      int? runningNumber;
      if (response.data is Map && response.data['data'] != null) {
        final d = response.data['data'];
        if (d is Map && d['number'] != null) {
          runningNumber = int.tryParse(d['number'].toString());
        } else if (d is int) {
          runningNumber = d;
        } else if (d is String) {
          runningNumber = int.tryParse(d);
        }
      } else if (response.data is Map && response.data['number'] != null) {
        runningNumber = int.tryParse(response.data['number'].toString());
      }
      final result =
          'T${runningNumber != null ? runningNumber.toString().padLeft(2, '0') : ''}';
      return ApiResult.success(data: result);
    } catch (e, stackTrace) {
      debugPrint('==> register terminal failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'SettingsSettingsRepositoryImpl.getTerminalID',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  @override
  Future<ApiResult<String?>> generateTransactionID(String prefix) async {
    try {
      final client = dioHttp.client(requireAuth: true);
      final body = {"prefix": prefix};
      final response = await client.post(
          '/api/v1/rest/running-number/transaction/increment',
          data: body);
      int? runningNumber;
      if (response.data is Map && response.data['data'] != null) {
        final d = response.data['data'];
        if (d is Map && d['number'] != null) {
          runningNumber = int.tryParse(d['number'].toString());
        } else if (d is int) {
          runningNumber = d;
        } else if (d is String) {
          runningNumber = int.tryParse(d);
        }
      } else if (response.data is Map && response.data['number'] != null) {
        runningNumber = int.tryParse(response.data['number'].toString());
      }
      final result = runningNumber != null
          ? '$prefix-${runningNumber.toString().padLeft(9, '0')}'
          : null;
      return ApiResult.success(data: result);
    } catch (e, stackTrace) {
      debugPrint('==> generate transaction id failure: $e');
      AppHelpers.recordErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'SettingsSettingsRepositoryImpl.generateTransactionID',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }
}
