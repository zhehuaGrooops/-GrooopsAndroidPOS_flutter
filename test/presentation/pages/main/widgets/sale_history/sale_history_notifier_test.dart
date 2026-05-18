import 'dart:io';
import 'package:admin_desktop/src/core/constants/hive_boxes.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/sale_history/riverpod/sale_history_notifier.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/sale_history/riverpod/sale_history_state.dart';
import 'package:admin_desktop/src/repository/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hive/hive.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:admin_desktop/src/core/handlers/handlers.dart';
import 'package:admin_desktop/src/models/response/sale_history_response.dart';
import 'package:admin_desktop/src/models/response/sale_cart_response.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockPathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async => Directory.systemTemp.path;
  @override
  Future<String?> getApplicationSupportPath() async =>
      Directory.systemTemp.path;
  @override
  Future<String?> getApplicationDocumentsPath() async =>
      Directory.systemTemp.path;
  @override
  Future<String?> getExternalStoragePath() async => Directory.systemTemp.path;
  @override
  Future<List<String>?> getExternalCachePaths() async =>
      [Directory.systemTemp.path];
  @override
  Future<List<String>?> getExternalStoragePaths(
          {StorageDirectory? type}) async =>
      [Directory.systemTemp.path];
  @override
  Future<String?> getDownloadsPath() async => Directory.systemTemp.path;
}

void main() {
  late MockSettingsRepository mockRepo;
  late SaleHistoryNotifier notifier;
  late Box ordersBox;

  setUpAll(() async {
    PathProviderPlatform.instance = MockPathProvider();
    final tempDir = await Directory.systemTemp.createTemp();
    Hive.init(tempDir.path);
    ordersBox = await Hive.openBox(HiveBoxes.orders);
  });

  setUp(() {
    mockRepo = MockSettingsRepository();

    // Stub default responses
    when(() => mockRepo.getSaleHistory(any(), any())).thenAnswer(
        (_) async => ApiResult.success(data: SaleHistoryResponse(list: [])));
    when(() => mockRepo.getSaleCart())
        .thenAnswer((_) async => ApiResult.success(data: SaleCartResponse()));

    notifier = SaleHistoryNotifier(mockRepo);
  });

  tearDown(() {
    notifier.dispose();
  });

  test('Initial state is correct', () {
    expect(notifier.state, const SaleHistoryState());
  });

  test('fetchSale updates state with sales', () async {
    final sales = [SaleHistoryModel(id: 1, totalPrice: 100)];
    when(() => mockRepo.getSaleHistory(any(), any())).thenAnswer(
        (_) async => ApiResult.success(data: SaleHistoryResponse(list: sales)));

    await notifier.fetchSale();

    expect(notifier.state.listHistory, sales);
    expect(notifier.state.isLoading, false);
  });

  test('Hive listener triggers fetchSale and fetchSaleCart on box change',
      () async {
    // Reset mocks to track calls
    reset(mockRepo);
    when(() => mockRepo.getSaleHistory(any(), any())).thenAnswer(
        (_) async => ApiResult.success(data: SaleHistoryResponse(list: [])));
    when(() => mockRepo.getSaleCart())
        .thenAnswer((_) async => ApiResult.success(data: SaleCartResponse()));

    // Add something to box to trigger watch()
    await ordersBox.put('test_key', 'test_value');

    // Wait for debounce (500ms + some buffer)
    await Future.delayed(const Duration(milliseconds: 700));

    verify(() => mockRepo.getSaleHistory(any(), any()))
        .called(greaterThanOrEqualTo(1));
    verify(() => mockRepo.getSaleCart()).called(greaterThanOrEqualTo(1));
  });

  test('Error handling: fetchSale sets errorMessage on failure', () async {
    when(() => mockRepo.getSaleHistory(any(), any())).thenAnswer(
        (_) async => ApiResult.failure(error: 'Fetch failed', statusCode: 500));

    await notifier.fetchSale();

    expect(notifier.state.errorMessage, isNotNull);
    expect(notifier.state.errorMessage, contains('Fetch failed'));
  });
}
