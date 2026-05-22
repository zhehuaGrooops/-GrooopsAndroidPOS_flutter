import 'dart:async';

import 'package:admin_desktop/src/core/constants/hive_boxes.dart';
import 'package:admin_desktop/src/core/di/dependency_manager.dart';
import 'package:admin_desktop/src/core/handlers/handlers.dart';
import 'package:admin_desktop/src/models/models.dart';
import 'package:admin_desktop/src/core/utils/utils.dart';
import 'package:admin_desktop/src/repository/hive_repository/users_hive_repository.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';

import '../../models/response/profile_response.dart';
import '../db/hive_service.dart';
import 'sync_models.dart';
import 'order_sync_handler.dart';
import 'payment_sync_handler.dart';
import 'cash_session_sync_handler.dart';
import 'faqs_sync_handler.dart';
import 'product_sync_handler.dart';
import 'categories_sync_handler.dart';
import 'discount_setting_sync_handler.dart';
import 'table_sync_handler.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();

  Timer? _timer;
  bool _isSyncing = false;
  final _progress = StreamController<SyncProgress>.broadcast();
  final _status = StreamController<SyncStatus>.broadcast();
  late OrderSyncHandler _orderSyncHandler;
  late PaymentSyncHandler _paymentSyncHandler;
  late CashSessionSyncHandler _cashSessionSyncHandler;
  late FaqsSyncHandler _faqsSyncHandler;
  late ProductSyncHandler _productSyncHandler;
  late CategoriesSyncHandler _categoriesSyncHandler;
  late DiscountSettingSyncHandler _discountSettingSyncHandler;
  late TableSyncHandler _tableSyncHandler;

  SyncService._internal() {
    _orderSyncHandler = OrderSyncHandler(
      httpService: HttpService(),
      progressSink: _progress.sink,
    );
    _paymentSyncHandler = PaymentSyncHandler(
      httpService: HttpService(),
      progressSink: _progress.sink,
    );
    _cashSessionSyncHandler = CashSessionSyncHandler(
      httpService: HttpService(),
      progressSink: _progress.sink,
    );
    _faqsSyncHandler = FaqsSyncHandler(
      httpService: HttpService(),
      progressSink: _progress.sink,
    );
    _productSyncHandler = ProductSyncHandler(
      httpService: HttpService(),
      progressSink: _progress.sink,
    );
    _categoriesSyncHandler = CategoriesSyncHandler(
      httpService: HttpService(),
      progressSink: _progress.sink,
    );
    _discountSettingSyncHandler = DiscountSettingSyncHandler(
      httpService: HttpService(),
      progressSink: _progress.sink,
    );
    _tableSyncHandler = TableSyncHandler(
      httpService: HttpService(),
      progressSink: _progress.sink,
    );
  }

  factory SyncService() => _instance;

  Stream<SyncProgress> get progressStream => _progress.stream;

  Stream<SyncStatus> get statusStream => _status.stream;

  HttpService? _mockHttpService;

  @visibleForTesting
  set mockHttpService(HttpService service) {
    _mockHttpService = service;
    _orderSyncHandler = OrderSyncHandler(
      httpService: service,
      progressSink: _progress.sink,
    );
    _paymentSyncHandler = PaymentSyncHandler(
      httpService: service,
      progressSink: _progress.sink,
    );
    _cashSessionSyncHandler = CashSessionSyncHandler(
      httpService: service,
      progressSink: _progress.sink,
    );
    _faqsSyncHandler = FaqsSyncHandler(
      httpService: service,
      progressSink: _progress.sink,
    );
    _productSyncHandler = ProductSyncHandler(
      httpService: service,
      progressSink: _progress.sink,
    );
    _categoriesSyncHandler = CategoriesSyncHandler(
      httpService: service,
      progressSink: _progress.sink,
    );
    _discountSettingSyncHandler = DiscountSettingSyncHandler(
      httpService: service,
      progressSink: _progress.sink,
    );
    _tableSyncHandler = TableSyncHandler(
      httpService: service,
      progressSink: _progress.sink,
    );
  }

  Dio _getClient({required bool requireAuth}) {
    return (_mockHttpService ?? HttpService()).client(requireAuth: requireAuth);
  }

  Future<bool> pushOrders() async {
    final ok = await _orderSyncHandler.pushOrders();
    await _orderSyncHandler.pushTransactions();
    return ok;
  }

  Future<bool> pushOrderUpdates() => _orderSyncHandler.pushPendingOrderUpdates();

  Future<bool> pushOrderUpdate(dynamic key) => _orderSyncHandler.pushOrderUpdate(key);

  Future<bool> updateOrderStatusOnBackend(int serverId, String status) =>
      _orderSyncHandler.updateOrderStatus(serverId, status);

  /// Pushes all pending transactions for synced orders to the server.
  Future<bool> pushTransactions() => _orderSyncHandler.pushTransactions();

  /// Pushes a single order to the server.
  Future<bool> pushSingleOrder(dynamic key) =>
      _orderSyncHandler.pushSingleOrder(key);

  /// Pulls payment methods from the server.
  Future<bool> pullPayments() => _paymentSyncHandler.pullPayments();

  /// Submits a payment transaction for an order.
  Future<bool> submitPaymentTransaction(int orderId, {dynamic hiveKey}) =>
      _orderSyncHandler.submitPaymentTransaction(orderId, hiveKey: hiveKey);

  /// Fetches FAQs from the server.
  Future<bool> fetchFaqs() => _faqsSyncHandler.fetchFaqs();

  /// Pushes pending table/section mutations to the server.
  Future<bool> pushTableChanges() => _tableSyncHandler.pushPendingTables();

  Future<bool> _isReachable() async {
    try {
      final dio = _getClient(requireAuth: false);
      await dio.get('/api/v1/rest/languages/active');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> start({Duration interval = const Duration(minutes: 2)}) async {
    if ((LocalStorage.getToken()).isEmpty) return;

    Future<bool> hasNetworkInterface() async {
      try {
        final connectivityResult = await Connectivity().checkConnectivity();
        return connectivityResult.contains(ConnectivityResult.mobile) ||
            connectivityResult.contains(ConnectivityResult.wifi) ||
            connectivityResult.contains(ConnectivityResult.ethernet);
      } catch (e, stackTrace) {
        debugPrint('SyncService.start connectivity check failed: $e');
        AppHelpers.recordSyncErrorToCrashlytics(
          error: e,
          stackTrace: stackTrace,
          context: 'SyncService.start.hasNetworkInterface',
        );
        return false;
      }
    }

    Future<bool> hasInternetConnectivity() async {
      final hasInterface = await hasNetworkInterface();
      if (!hasInterface) return false;
      try {
        return await _isReachable().timeout(const Duration(seconds: 2));
      } catch (e, stackTrace) {
        debugPrint('SyncService.start reachability check failed: $e');
        AppHelpers.recordSyncErrorToCrashlytics(
          error: e,
          stackTrace: stackTrace,
          context: 'SyncService.start.hasInternetConnectivity',
        );
        return false;
      }
    }

    _timer?.cancel();
    final reachable = await hasInternetConnectivity();
    if (reachable) {
      await _runOnce();
    }
    _timer = Timer.periodic(interval, (_) async {
      try {
        final reachable = await hasInternetConnectivity();
        if (reachable) {
          await _runOnce();
        }
      } catch (e, stackTrace) {
        debugPrint('SyncService.start periodic sync failed: $e');
        AppHelpers.recordSyncErrorToCrashlytics(
          error: e,
          stackTrace: stackTrace,
          context: 'SyncService.start.periodic',
        );
      }
    });
  }

  Future<void> startPullPrerequisite(
      {Duration interval = const Duration(minutes: 2)}) async {
    if ((LocalStorage.getToken()).isEmpty) return;
    var connectivityResult = await Connectivity().checkConnectivity();
    if (!(connectivityResult.contains(ConnectivityResult.mobile) ||
        connectivityResult.contains(ConnectivityResult.wifi) ||
        connectivityResult.contains(ConnectivityResult.ethernet))) {
      return;
    }
    final reachable = await _isReachable();
    if (!reachable) return;
    await _runOnceForPrerequisite();
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) async {
      // Connectivity check is preserved in the background sync service to prevent
      // background synchronization tasks from attempting to run without a network connection.
      final ok = await AppConnectivity.connectivity();
      if (!ok) return;
      if (!await _isReachable()) return;
      await _runOnceForPrerequisite();
    });
  }

  Future<void> _runOnceForPrerequisite() async {
    if (_isSyncing) return;
    _isSyncing = true;
    _status.add(SyncStatus(running: true, completed: false, errors: const []));
    try {
      debugPrint("Starting Sync Service to pull data from server...");
      final errors = <String>[];
      final ok1 = await _withRetry(() => _pullCurrencies());
      if (!ok1) errors.add('currencies');
      final ok2 = await _withRetry(() => _pullSettings());
      if (!ok2) errors.add('settings');
      final ok3 = await _withRetry(() => _pullCategories());
      if (!ok3) errors.add('categories');
      final ok4 = await _withRetry(() => _paymentSyncHandler.pullPayments());
      if (!ok4) errors.add('payments');

      _progress.add(SyncProgress(
          phase: 'complete',
          entity: 'all',
          processed: 0,
          total: 0,
          errors: errors));
      _status.add(SyncStatus(running: false, completed: true, errors: errors));

      debugPrint("Finishing Sync Service to pull data from server...");
    } finally {
      _isSyncing = false;
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _runOnce() async {
    if (_isSyncing) return;
    _isSyncing = true;
    _status.add(SyncStatus(running: true, completed: false, errors: const []));
    try {
      debugPrint("Starting Sync Service to pull data from server...");
      final errors = <String>[];
      final ok1 = await _withRetry(() => _pullCurrencies());
      if (!ok1) errors.add('currencies');
      final ok1b = await _withRetry(() => _pullProfileDetails());
      if (!ok1b) errors.add('profile');
      final ok1c = await _withRetry(() => _pullCurrentUserShop());
      if (!ok1c) errors.add('current_user_shop');
      final ok2 = await _withRetry(() => _pullSettings());
      if (!ok2) errors.add('settings');
      final ok3 = await _withRetry(() => _pullCategories());
      if (!ok3) errors.add('categories');
      final ok4 = await _withRetry(() => _pullBrands());
      if (!ok4) errors.add('brands');
      final ok5 = await _withRetry(() => _pullShops());
      if (!ok5) errors.add('shops');
      final ok6 = await _withRetry(() => _pullUsers());
      if (!ok6) errors.add('users');
      final ok6b = await _withRetry(() => _faqsSyncHandler.fetchFaqs());
      if (!ok6b) errors.add('faqs');
      final ok6c = await _withRetry(() => _paymentSyncHandler.pullPayments());
      if (!ok6c) errors.add('payments');
      final okPullSession =
          await _withRetry(() => _cashSessionSyncHandler.pullActiveSession());
      if (!okPullSession) errors.add('pull_session');
      final okOpenSession =
          await _withRetry(() => _cashSessionSyncHandler.pushOpenSessions());
      if (!okOpenSession) errors.add('open_sessions');
      final ok6d = await _withRetry(() => _orderSyncHandler.pushPendingOrderUpdates());
      if (!ok6d) errors.add('order_updates');
      final ok7 = await _withRetry(() => _orderSyncHandler.pushOrders());
      if (!ok7) errors.add('orders');
      final ok7b = await _withRetry(() => _orderSyncHandler.pushVoidedOrders());
      if (!ok7b) errors.add('voided_orders');
      final ok7c = await _withRetry(() => _orderSyncHandler.pushTransactions());
      if (!ok7c) errors.add('transactions');
      final okCloseSession =
          await _withRetry(() => _cashSessionSyncHandler.pushCloseSessions());
      if (!okCloseSession) errors.add('close_sessions');
      final ok8 = await _withRetry(() => _productSyncHandler
          .pullProducts()); // pull products after push orders, as the products data have quantity
      if (!ok8) errors.add('products');
      final ok9 = await _withRetry(
          () => _discountSettingSyncHandler.pullDiscountSettings());
      if (!ok9) errors.add('discount_settings');
      final ok10 = await _withRetry(() => _tableSyncHandler.pushPendingTables());
      if (!ok10) errors.add('table_push');
      final ok11 = await _withRetry(() => _tableSyncHandler.pullTables());
      if (!ok11) errors.add('table_pull');
      _progress.add(SyncProgress(
          phase: 'complete',
          entity: 'all',
          processed: 0,
          total: 0,
          errors: errors));
      _status.add(SyncStatus(running: false, completed: true, errors: errors));

      debugPrint("Finishing Sync Service to pull data from server...");
    } finally {
      _isSyncing = false;
    }
  }

  Future<bool> _pullCurrencies() async {
    try {
      debugPrint("Pulling currency data from server ...");
      // Original API implementation moved from repository: CurrenciesRepositoryImpl.getCurrencies
      final client = HttpService().client(requireAuth: false);
      final response = await client.get('/api/v1/rest/currencies');
      final parsed = CurrenciesResponse.fromJson(response.data);
      final box = await HiveService.openBox(HiveBoxes.currencies);
      await box.clear();
      final list = parsed.data ?? [];
      for (final e in list) {
        await box.put(e.id, e.toJson());
      }
      _progress.add(SyncProgress(
          phase: 'pull',
          entity: 'currencies',
          processed: list.length,
          total: list.length,
          errors: const []));

      debugPrint("Finished pull currency data.");

      return true;
    } catch (e, stackTrace) {
      AppHelpers.recordSyncErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'SyncService._pullCurrencies',
      );
      _progress.add(SyncProgress(
          phase: 'pull',
          entity: 'currencies',
          processed: 0,
          total: 0,
          errors: [e.toString()]));
      return false;
    }
  }

  Future<bool> _pullSettings() async {
    try {
      debugPrint("Pulling settings data from server...");
      // Original API implementation moved from repository: SettingsSettingsRepositoryImpl.getGlobalSettings
      final client = HttpService().client(requireAuth: false);
      final settingsResponse = await client.get('/api/v1/rest/settings');
      final settingsParsed =
          GlobalSettingsResponse.fromJson(settingsResponse.data);
      if (settingsParsed.data != null) {
        await LocalStorage.setSettingsList(settingsParsed.data!);
      }
      final sbox = await HiveService.openBox(HiveBoxes.settings);
      await sbox.clear();
      for (final e in settingsParsed.data ?? []) {
        await sbox.add(e.toJson());
      }
      _progress.add(SyncProgress(
          phase: 'pull',
          entity: 'settings',
          processed: settingsParsed.data?.length ?? 0,
          total: settingsParsed.data?.length ?? 0,
          errors: const []));

      // Original API implementation moved from repository: SettingsSettingsRepositoryImpl.getLanguages
      try {
        final langClient = HttpService().client(requireAuth: false);
        final langResponse =
            await langClient.get('/api/v1/rest/languages/active');
        final langParsed = LanguagesResponse.fromJson(langResponse.data);
        if (LocalStorage.getLanguage() == null ||
            !(langParsed.data
                    ?.map((e) => e.id)
                    .contains(LocalStorage.getLanguage()?.id) ??
                true)) {
          langParsed.data?.forEach((element) {
            if (element.isDefault ?? false) {
              LocalStorage.setLanguageData(element);
              LocalStorage.setLangLtr(element.backward);
            }
          });
        }
        await sbox.put('languages',
            langParsed.data?.map((e) => e.toJson()).toList() ?? []);
      } catch (_) {}

      // Original API implementation moved from repository: SettingsSettingsRepositoryImpl.getTranslations
      try {
        final trClient = HttpService().client(requireAuth: false);
        final trResponse = await trClient.get(
          '/api/v1/rest/translations/paginate',
          queryParameters: {'lang': LocalStorage.getLanguage()?.locale ?? 'en'},
        );
        final trParsed = TranslationsResponse.fromJson(trResponse.data);
        final tbox = await HiveService.openBox(HiveBoxes.translations);
        await tbox.put('translations', trParsed.data ?? {});
      } catch (_) {}

      debugPrint("Finishing pulling settings data from server...");
      return true;
    } catch (e, stackTrace) {
      AppHelpers.recordSyncErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'SyncService._pullSettings',
      );
      _progress.add(SyncProgress(
          phase: 'pull',
          entity: 'settings',
          processed: 0,
          total: 0,
          errors: [e.toString()]));
      return false;
    }
  }

  Future<bool> _pullCategories() => _categoriesSyncHandler.pullCategories();

  Future<bool> _pullBrands() async {
    try {
      debugPrint("Pulling brands data from server...");
      // Original API implementation moved from repository: BrandsRepositoryImpl.searchBrands
      final client = HttpService().client(requireAuth: true);
      final response = await client.get(
        '/api/v1/rest/brands/paginate',
        queryParameters: const {},
      );
      final parsed = BrandsPaginateResponse.fromJson(response.data);
      final box = await HiveService.openBox(HiveBoxes.brands);
      await box.clear();
      for (final e in parsed.data ?? []) {
        await box.put(e.id, e.toJson());
      }
      _progress.add(SyncProgress(
          phase: 'pull',
          entity: 'brands',
          processed: parsed.data?.length ?? 0,
          total: parsed.data?.length ?? 0,
          errors: const []));
      debugPrint("Finished pull brands data from server.");
      return true;
    } catch (e, stackTrace) {
      AppHelpers.recordSyncErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'SyncService._pullBrands',
      );
      _progress.add(SyncProgress(
          phase: 'pull',
          entity: 'brands',
          processed: 0,
          total: 0,
          errors: [e.toString()]));
      return false;
    }
  }

  Future<bool> _pullShops() async {
    try {
      debugPrint("Pulling shops data from server...");
      // Original API implementation moved from repository: ShopsRepositoryImpl.searchShops
      final data = {
        'lang': LocalStorage.getLanguage()?.locale ?? 'en',
        'status': 'approved',
      };
      final client = HttpService().client(requireAuth: true);
      final response = await client.get(
        '/api/v1/dashboard/${LocalStorage.getUser()?.role}/shops/all',
        queryParameters: data,
      );
      final parsed = ShopsPaginateResponse.fromJson(response.data);
      final box = await HiveService.openBox(HiveBoxes.shops);
      await box.clear();
      for (final e in parsed.data ?? []) {
        await box.put(e.id, e.toJson());
      }
      _progress.add(SyncProgress(
          phase: 'pull',
          entity: 'shops',
          processed: parsed.data?.length ?? 0,
          total: parsed.data?.length ?? 0,
          errors: const []));
      debugPrint("Finish pull shops data from server...");
      return true;
    } catch (e, stackTrace) {
      _progress.add(SyncProgress(
          phase: 'pull',
          entity: 'shops',
          processed: 0,
          total: 0,
          errors: [e.toString()]));
      debugPrint("Error pull shops data$e");
      AppHelpers.recordSyncErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'SyncService._pullShops',
      );
      return false;
    }
  }

  Future<bool> _pullCurrentUserShop() async {
    try {
      debugPrint("Pulling current user shop data from server...");
      final client = _getClient(requireAuth: true);
      final response = await client.get(
        '/api/v1/dashboard/${LocalStorage.getUser()?.role}/shops',
        queryParameters: {'lang': LocalStorage.getLanguage()?.locale ?? 'en'},
      );
      final parsed = SingleShopResponse.fromJson(response.data);
      final box = await HiveService.openBox(HiveBoxes.currentUserShop);
      await box.clear();
      if (parsed.data != null) {
        await box.put('current', parsed.data!.toJson());
      }
      _progress.add(SyncProgress(
          phase: 'pull',
          entity: 'current_user_shop',
          processed: parsed.data == null ? 0 : 1,
          total: 1,
          errors: const []));
      debugPrint("Finished pull current user shop data from server.");
      return true;
    } catch (e, stackTrace) {
      _progress.add(SyncProgress(
          phase: 'pull',
          entity: 'current_user_shop',
          processed: 0,
          total: 1,
          errors: [e.toString()]));
      debugPrint("Error pull current user shop data $e");
      AppHelpers.recordSyncErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'SyncService._pullCurrentUserShop',
      );
      return false;
    }
  }

  // Local clone of UsersRepositoryImpl.getUsers for SyncService standalone use.
  Future<ApiResult<List<UserData>>> _getUsers() async {
    try {
      final client = dioHttp.client(requireAuth: true);

      final response = await client.get(
        '/api/v1/dashboard/${LocalStorage.getUser()?.role}/users/all',
      );

      final List<UserData> users = (response.data['data'] as List)
          .map((e) => UserData.fromJson(e))
          .toList();

      return ApiResult.success(data: users);
    } catch (e, stackTrace) {
      debugPrint('==> get users failure: $e');
      AppHelpers.recordSyncErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'SyncService._getUsers',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  Future<bool> _pullUsers() async {
    try {
      debugPrint("Pulling users data from server...");
      final hiveRepository = UsersHiveRepository();
      final users = <UserData>[];
      final result = await _getUsers();
      bool ok = true;
      result.when(
        success: (List<UserData> data) {
          users.addAll(data);
        },
        failure: (error, _) {
          _progress.add(SyncProgress(
              phase: 'pull',
              entity: 'users',
              processed: 0,
              total: 0,
              errors: [error]));
          ok = false;
        },
      );
      if (!ok) {
        return false;
      }
      final storeResult = await hiveRepository.saveUsers(users);
      storeResult.when(
        success: (_) {
          _progress.add(SyncProgress(
              phase: 'pull',
              entity: 'users',
              processed: users.length,
              total: users.length,
              errors: const []));
        },
        failure: (error, _) {
          _progress.add(SyncProgress(
              phase: 'pull',
              entity: 'users',
              processed: 0,
              total: 0,
              errors: [error]));
          ok = false;
        },
      );
      debugPrint("Finished pull users data from server.");
      return ok;
    } catch (e, stackTrace) {
      AppHelpers.recordSyncErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'SyncService._pullUsers',
      );
      _progress.add(SyncProgress(
          phase: 'pull',
          entity: 'users',
          processed: 0,
          total: 0,
          errors: [e.toString()]));
      return false;
    }
  }

  Future<bool> _withRetry(Future<bool> Function() action,
      {int maxAttempts = 3,
      Duration delay = const Duration(seconds: 1)}) async {
    int attempt = 0;
    while (attempt < maxAttempts) {
      final ok = await action();
      if (ok) return true;
      attempt++;
      if (attempt < maxAttempts) {
        final d = Duration(seconds: delay.inSeconds * attempt);
        await Future.delayed(d);
      }
    }
    return false;
  }

  Future<bool> _pullProfileDetails() async {
    try {
      debugPrint("Pulling profile data from server...");
      final client = HttpService().client(requireAuth: true);
      final response = await client.get('/api/v1/dashboard/user/profile/show');
      final parsed = ProfileResponse.fromJson(response.data);
      // Update in-memory user
      LocalStorage.setUser(parsed.data);
      // Persist to hive users box under 'profile' so hive repo can read it
      try {
        final box = await HiveService.openBox(HiveBoxes.users);
        await box.put('profile', parsed.toJson());
      } catch (_) {}

      _progress.add(SyncProgress(
          phase: 'pull',
          entity: 'profile',
          processed: 1,
          total: 1,
          errors: const []));
      debugPrint("Finished pull profile data.");
      return true;
    } catch (e, stackTrace) {
      AppHelpers.recordSyncErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'SyncService._pullProfileDetails',
      );
      _progress.add(SyncProgress(
          phase: 'pull',
          entity: 'profile',
          processed: 0,
          total: 0,
          errors: [e.toString()]));
      return false;
    }
  }
}
