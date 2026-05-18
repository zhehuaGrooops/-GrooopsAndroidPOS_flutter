import 'package:admin_desktop/src/repository/gallery.dart';
import 'package:admin_desktop/src/repository/impl/notification_repo_impl.dart';
import 'package:admin_desktop/src/repository/impl/table_repository_iml.dart';
import 'package:admin_desktop/src/repository/notification_repository.dart';
import 'package:admin_desktop/src/repository/table_repository.dart';
import 'package:get_it/get_it.dart';
import '../../repository/impl/gallery_repository.dart';
import '../../repository/repository.dart';
import '../../core/constants/app_constants.dart';
import '../../repository/hive_repository/products_hive_repository.dart';
import '../../repository/hive_repository/shops_hive_repository.dart';
import '../../repository/hive_repository/brands_hive_repository.dart';
import '../../repository/hive_repository/categories_hive_repository.dart';
import '../../repository/hive_repository/currencies_hive_repository.dart';
import '../../repository/hive_repository/settings_hive_repository.dart';
import '../../repository/hive_repository/orders_hive_repository.dart';
import '../../repository/hive_repository/users_hive_repository.dart';
import '../../repository/hive_repository/payments_hive_repository.dart';
import '../../repository/hive_repository/table_hive_repository.dart';
import '../../repository/hive_repository/cash_sessions_hive_repository.dart';
import '../handlers/handlers.dart';

final GetIt getIt = GetIt.instance;

void setUpDependencies() {
  getIt.registerLazySingleton<HttpService>(() => HttpService());
  getIt.registerSingleton<PrinterRepository>(PrinterRepositoryImpl());
  getIt.registerSingleton<KitchenPrintersRepository>(
      KitchenPrintersRepositoryImpl());
  if (AppConstants.useHiveRepositories) {
    getIt.registerSingleton<SettingsRepository>(SettingsHiveRepository());
    getIt.registerSingleton<AuthRepository>(AuthRepositoryImpl());
    getIt.registerSingleton<ProductsRepository>(ProductsHiveRepository());
    getIt.registerSingleton<ShopsRepository>(ShopsHiveRepository());
    getIt.registerSingleton<BrandsRepository>(BrandsHiveRepository());
    getIt.registerSingleton<GalleryRepositoryFacade>(GalleryRepository());
    getIt.registerSingleton<CategoriesRepository>(CategoriesHiveRepository());
    getIt.registerSingleton<CurrenciesRepository>(CurrenciesHiveRepository());
    getIt.registerSingleton<PaymentsRepository>(PaymentsHiveRepository());
    getIt.registerSingleton<OrdersRepository>(OrdersHiveRepository());
    getIt.registerSingleton<NotificationRepository>(
        NotificationRepositoryImpl());
    getIt.registerSingleton<UsersRepository>(UsersHiveRepository());
    getIt.registerSingleton<TableRepository>(TableHiveRepository());
    getIt.registerSingleton<CashSessionsRepository>(
        CashSessionsHiveRepository());
  } else {
    getIt.registerSingleton<SettingsRepository>(
        SettingsSettingsRepositoryImpl());
    getIt.registerSingleton<AuthRepository>(AuthRepositoryImpl());
    getIt.registerSingleton<ProductsRepository>(ProductsRepositoryImpl());
    getIt.registerSingleton<ShopsRepository>(ShopsRepositoryImpl());
    getIt.registerSingleton<BrandsRepository>(BrandsRepositoryImpl());
    getIt.registerSingleton<GalleryRepositoryFacade>(GalleryRepository());
    getIt.registerSingleton<CategoriesRepository>(CategoriesRepositoryImpl());
    getIt.registerSingleton<CurrenciesRepository>(CurrenciesRepositoryImpl());
    getIt.registerSingleton<PaymentsRepository>(PaymentsRepositoryImpl());
    getIt.registerSingleton<OrdersRepository>(OrdersRepositoryImpl());
    getIt.registerSingleton<NotificationRepository>(
        NotificationRepositoryImpl());
    getIt.registerSingleton<UsersRepository>(UsersRepositoryImpl());
    getIt.registerSingleton<TableRepository>(TableRepositoryIml());
    getIt.registerSingleton<CashSessionsRepository>(
        CashSessionsRepositoryImpl());
  }
}

HttpService get dioHttp => getIt.get<HttpService>();
SettingsRepository get settingsRepository => getIt.get<SettingsRepository>();
AuthRepository get authRepository => getIt.get<AuthRepository>();
ProductsRepository get productsRepository => getIt.get<ProductsRepository>();
ShopsRepository get shopsRepository => getIt.get<ShopsRepository>();
BrandsRepository get brandsRepository => getIt.get<BrandsRepository>();
GalleryRepositoryFacade get galleryRepository =>
    getIt.get<GalleryRepositoryFacade>();
CategoriesRepository get categoriesRepository =>
    getIt.get<CategoriesRepository>();
CurrenciesRepository get currenciesRepository =>
    getIt.get<CurrenciesRepository>();
PaymentsRepository get paymentsRepository => getIt.get<PaymentsRepository>();
OrdersRepository get ordersRepository => getIt.get<OrdersRepository>();
NotificationRepository get notificationRepository =>
    getIt.get<NotificationRepository>();
UsersRepository get usersRepository => getIt.get<UsersRepository>();
TableRepository get tableRepository => getIt.get<TableRepository>();
CashSessionsRepository get cashSessionsRepository =>
    getIt.get<CashSessionsRepository>();
