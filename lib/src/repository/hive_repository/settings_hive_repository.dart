import 'package:admin_desktop/src/core/constants/hive_boxes.dart';
import 'package:admin_desktop/src/core/handlers/handlers.dart';
import 'package:admin_desktop/src/models/response/mobile_translations_response.dart';
import 'package:admin_desktop/src/models/response/sale_history_response.dart';
import 'package:admin_desktop/src/models/response/sale_cart_response.dart';
import 'package:admin_desktop/src/models/response/income_cart_response.dart';
import 'package:admin_desktop/src/models/response/income_statistic_response.dart';
import 'package:admin_desktop/src/models/response/income_chart_response.dart';
import 'package:admin_desktop/src/models/data/sale_receipt.dart';
import 'package:admin_desktop/src/models/data/help_data.dart';
import 'package:admin_desktop/src/models/models.dart';
import 'package:admin_desktop/src/repository/impl/settings_repository_impl.dart';

import 'package:hive/hive.dart';

import '../../core/db/hive_service.dart';
import '../../core/di/dependency_manager.dart';
import '../settings_repository.dart';

class SettingsHiveRepository extends SettingsRepository {
  Future<Box> _settings() => HiveService.openBox(HiveBoxes.settings);
  Future<Box> _translations() => HiveService.openBox(HiveBoxes.translations);
  Future<Box> _faqs() => HiveService.openBox(HiveBoxes.faq);
  Future<Box> _terminalBox() => HiveService.openBox(HiveBoxes.terminal);
  Future<Box> _ordersBox() => HiveService.openBox(HiveBoxes.orders);

  @override
  Future<ApiResult<GlobalSettingsResponse>> getGlobalSettings() async {
    try {
      final box = await _settings();
      final list = box.values
          .whereType<Map>()
          .map((e) => SettingsData.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return ApiResult.success(data: GlobalSettingsResponse(data: list));
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<TranslationsResponse>> getTranslations() async {
    try {
      final box = await _translations();
      final map = box.get('translations') as Map?;
      final data =
          map != null ? Map<String, dynamic>.from(map) : <String, dynamic>{};
      return ApiResult.success(data: TranslationsResponse(data: data));
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<MobileTranslationsResponse>> getMobileTranslations(
      {String? lang}) async {
    try {
      final box = await _translations();
      final key = 'mobile_translations_${lang ?? 'en'}';
      final map = box.get(key) as Map?;
      final data =
          map != null ? Map<String, dynamic>.from(map) : <String, dynamic>{};
      return ApiResult.success(data: MobileTranslationsResponse(data: data));
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<SaleHistoryResponse>> getSaleHistory(
    int type,
    int page,
  ) async {
    try {
      final ordersBox = await HiveService.openBox(HiveBoxes.orders);
      final List<SaleHistoryModel> result = [];

      for (final raw in ordersBox.values) {
        if (raw is! Map) continue;

        final map = _normalizeMap(raw);

        final createdAt = DateTime.tryParse(
          map['_meta']?['updatedAt'] ?? '',
        )?.toLocal();

        if (createdAt == null) continue;

        final todayStart = DateTime.now().toLocal();
        final startOfToday =
            DateTime(todayStart.year, todayStart.month, todayStart.day);

        if (type == 1 && createdAt.isBefore(startOfToday)) continue;

        UserData? user;
        final snapshot = map['user_snapshot'];

        if (snapshot is Map) {
          try {
            user = UserData.fromJson(
              Map<String, dynamic>.from(snapshot),
            );
          } catch (_) {}
        }

        final selectedPayment = map['body']?['bag_data']?['selected_payment'];

        final List<Transaction> transactions = selectedPayment is Map
            ? <Transaction>[
                Transaction(
                  paymentSystem: PaymentSystem(
                    id: selectedPayment['id'],
                    tag: selectedPayment['tag'],
                  ),
                ),
              ]
            : <Transaction>[];

        result.add(
          SaleHistoryModel(
            id: map['_meta']?['serverId'] ?? map['id'],
            userId: user?.id,
            user: user,
            totalPrice: map['total_price'] ?? 0,
            note: map['note'],
            createdAt: createdAt,
            isVoided: map['is_voided'] == true,
            transactions: transactions,
          ),
        );
      }

      result.sort(
        (a, b) =>
            (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
      );

      return ApiResult.success(
        data: SaleHistoryResponse(list: result),
      );
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  Map<String, dynamic> _normalizeMap(Map raw) {
    return raw.map(
      (key, value) => MapEntry(
        key.toString(),
        value is Map
            ? _normalizeMap(value)
            : value is List
                ? value.map((e) => e is Map ? _normalizeMap(e) : e).toList()
                : value,
      ),
    );
  }

  @override
  Future<ApiResult<SaleReceipt?>> getSaleReceipt(String saleId) async {
    try {
      final box = await _ordersBox();

      if (box.isEmpty) {
        return const ApiResult.success(data: null);
      }

      OrderBodyData? found;

      for (final raw in box.values) {
        if (raw is! Map) continue;
        final Map<String, dynamic> map = _normalizeMap(raw);
        final orderHive = OrderHiveModel.fromJson(map);
        if (orderHive.id != null && orderHive.id.toString() == saleId) {
          // base json
          found = orderHive.body;

          // prepare calculationData and groupedByCategory from enhanced products if available
          final List<Map<String, dynamic>> calculationData = [];
          final Map<String, dynamic> groupedByCategory = {};

          final body = orderHive.body;
          final products = body?.enhancedProducts ?? [];

          num originalSubtotal = 0;
          num totalItemLevelDiscount = 0;
          num totalServiceCharge = 0;
          num totalTax = 0;

          for (final p in products) {
            final int qty = p.quantity;
            final num orig = p.originalPrice;
            final num itemDiscount = p.itemDiscountAmount;
            final num serviceCharge = p.serviceChargeAmount;
            final num tax = p.taxAmount;

            // accumulate totals (multiply by quantity)
            originalSubtotal += (orig * qty);
            totalItemLevelDiscount += (itemDiscount * qty);
            totalServiceCharge += (serviceCharge * qty);
            totalTax += (tax * qty);

            // build calculation entry (matches order_calculate structure)
            calculationData.add({
              'stockId': p.stockId,
              'itemDiscountAmount': itemDiscount * qty,
              'itemDiscountType': p.itemDiscountType,
              'itemDiscountPercent': p.itemDiscountPercent,
              'serviceChargeAmount': serviceCharge * qty,
              'serviceChargeType':
                  (p.serviceChargeType ?? '').toString().toLowerCase(),
              'serviceChargePercent': p.serviceChargePercent ?? 0,
              'taxAmount': tax * qty,
              'taxPercent': p.taxPercent ?? 0,
            });

            // group by category name
            final catName = (p.categoryName ?? 'Others').toString();
            if (!groupedByCategory.containsKey(catName)) {
              groupedByCategory[catName] = {
                'products': [],
                'category_data': {
                  'translation': {'title': catName},
                  // supply minimal service_types info if percent present
                  'service_types': [
                    {
                      'name': body?.deliveryType ?? '',
                      'service_charge': p.serviceChargePercent ?? 0,
                      'sst_tax': p.taxPercent ?? 0,
                    }
                  ]
                }
              };
            }
            groupedByCategory[catName]['products'].add(p.toJson());
          }

          // delivery and coupon from body
          final num deliveryFee = body?.deliveryFee ?? 0;
          final num couponPrice = 0; // coupon stored differently; default 0

          final num subtotalAfterItemDiscount =
              originalSubtotal - totalItemLevelDiscount;
          final num subtotalWithTaxesAndFees = subtotalAfterItemDiscount +
              totalServiceCharge +
              totalTax +
              deliveryFee;

          // bill discount (prefer explicit amount)
          num billDiscountValue = body?.billDiscountAmount ?? 0;
          if ((billDiscountValue == 0) && (body?.billDiscountPercent != null)) {
            billDiscountValue = subtotalWithTaxesAndFees *
                ((body!.billDiscountPercent ?? 0) / 100);
          }

          final num finalTotal =
              (subtotalWithTaxesAndFees - billDiscountValue - couponPrice)
                  .clamp(0, double.infinity);
          final num rounding = (finalTotal * 20).round() / 20 - finalTotal;
          final num displayedTotal = finalTotal + rounding;

          // attach calculated values to returned map
          found?.toJson()['calculationData'] = calculationData;
          found?.toJson()['groupedByCategory'] = groupedByCategory;
          found?.toJson()['calculatedTotal'] = displayedTotal;

          break;
        }
      }
      if (found == null) return ApiResult.success(data: null);
      final saleReceipt = SaleReceipt.fromMap(found.toJson());
      return ApiResult.success(data: saleReceipt);
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<SaleCartResponse>> getSaleCart() async {
    try {
      final box = await _settings();
      final map = box.get('sale_cart') as Map?;
      final data = map != null
          ? SaleCartResponse.fromJson(Map<String, dynamic>.from(map))
          : SaleCartResponse();
      return ApiResult.success(data: data);
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<IncomeCartResponse>> getIncomeCart(
      {required String type,
      required DateTime? from,
      required DateTime? to}) async {
    try {
      final repo = SettingsSettingsRepositoryImpl();
      final result = await repo.getIncomeCart(type: type, from: from, to: to);
      // final box = await _settings();`
      // final key = 'income_cart_$type';
      // final map = box.get(key) as Map?;
      // final data = map != null ? IncomeCartResponse.fromJson(Map<String, dynamic>.from(map)) : IncomeCartResponse();
      // return ApiResult.success(data: data);

      return result;
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<IncomeStatisticResponse>> getIncomeStatistic(
      {required String type,
      required DateTime? from,
      required DateTime? to}) async {
    try {
      final repo = SettingsSettingsRepositoryImpl();
      final result =
          await repo.getIncomeStatistic(type: type, from: from, to: to);
      // final box = await _settings();
      // final key = 'income_stat_$type';
      // final map = box.get(key) as Map?;
      // final data = map != null ? IncomeStatisticResponse.fromJson(Map<String, dynamic>.from(map)) : IncomeStatisticResponse();
      // return ApiResult.success(data: data);

      return result;
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<List<IncomeChartResponse>>> getIncomeChart(
      {required String type,
      required DateTime? from,
      required DateTime? to}) async {
    try {
      final repo = SettingsSettingsRepositoryImpl();
      final result = await repo.getIncomeChart(type: type, from: from, to: to);
      // final box = await _settings();
      // final key = 'income_chart_$type';
      // final list = (box.get(key) as List?)?.whereType<Map>().toList() ?? <Map>[];
      // final data = list.map((e) => IncomeChartResponse.fromJson(Map<String, dynamic>.from(e))).toList();
      // return ApiResult.success(data: data);

      return result;
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<LanguagesResponse>> getLanguages() async {
    try {
      final box = await _settings();
      final list =
          (box.get('languages') as List?)?.whereType<Map>().toList() ?? <Map>[];
      final data = list
          .map((e) => LanguageData.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return ApiResult.success(data: LanguagesResponse(data: data));
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<HelpModel>> getFaq() async {
    try {
      final box = await _faqs();
      final list = box.values
          .whereType<Map>()
          .map((e) => Datum.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return ApiResult.success(data: HelpModel(data: list));
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<String?>> getTerminalID() async {
    try {
      final box = await _terminalBox();
      String? terminalId = box.get('terminal_id') as String?;
      if (terminalId == null) {
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
        terminalId =
            'T${runningNumber != null ? runningNumber.toString().padLeft(2, '0') : ''}';
        if (terminalId.isNotEmpty) {
          await box.put('terminal_id', terminalId);
        }
      }
      return ApiResult.success(data: terminalId);
    } catch (e) {
      return ApiResult.failure(error: e.toString());
    }
  }

  @override
  Future<ApiResult<String?>> generateTransactionID(String prefix) {
    return SettingsSettingsRepositoryImpl().generateTransactionID(prefix);
  }
}
