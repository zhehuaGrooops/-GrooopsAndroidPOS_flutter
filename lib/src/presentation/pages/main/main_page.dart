// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:admin_desktop/src/core/routes/app_router.dart';
import 'package:admin_desktop/src/presentation/components/custom_clock/custom_clock.dart';
import 'package:admin_desktop/src/presentation/pages/main/riverpod/notifier/main_notifier.dart';
import 'package:admin_desktop/src/presentation/pages/main/riverpod/state/main_state.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/customers/customers_page.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/customers/riverpod/notifier/customer_notifier.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/customers/riverpod/provider/customer_provider.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/kitchen/kitchen_page.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/kitchen/riverpod/kitchen_provider.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/notifications/components/notification_count_container.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/notifications/notification_dialog.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/orders_table/orders/canceled/canceled_orders_provider.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/orders_table/orders/cooking/cooking_orders_provider.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/orders_table/orders/delivered/delivered_orders_provider.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/notifications/riverpod/notification_provider.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/post_page.dart';
import 'package:admin_desktop/src/presentation/pages/main/widgets/tables/tables_page.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:auto_route/auto_route.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_remix/flutter_remix.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:proste_indexed_stack/proste_indexed_stack.dart';
import '../../../../generated/assets.dart';
import '../../../core/constants/constants.dart';
import '../../../core/utils/utils.dart';
import '../../components/components.dart';
import '../../theme/theme.dart';
import 'riverpod/provider/main_provider.dart';
import 'widgets/income/income_page.dart';
import 'widgets/orders_table/orders/accepted/accepted_orders_provider.dart';
import 'widgets/orders_table/orders/new/new_orders_provider.dart';
import 'widgets/orders_table/orders/on_a_way/on_a_way_orders_provider.dart';
import 'widgets/orders_table/orders/ready/ready_orders_provider.dart';
import 'widgets/orders_table/orders_table.dart';
import 'widgets/profile/edit_profile/edit_profile_page.dart';
import 'widgets/right_side/riverpod/right_side_provider.dart';
import 'widgets/tables/riverpod/tables_provider.dart';
import 'widgets/sale_history/sale_history.dart';
import 'widgets/settings/settings_page.dart';
import 'widgets/settings/riverpod/printer_provider.dart';
import 'dart:io' show Platform;
import 'widgets/open_drawer_dialog.dart';
import 'widgets/cash_session/generate_cash_session.dart';
import '../../../core/di/injection.dart';
import '../../../core/sync/sync_service.dart';
import '../../../core/sync/sync_provider.dart';
import '../../../repository/repository.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

@RoutePage()
class MainPage extends ConsumerStatefulWidget {
  const MainPage({super.key});

  @override
  ConsumerState<MainPage> createState() => _MainPageState();
}

class _MainPageState extends ConsumerState<MainPage>
    with SingleTickerProviderStateMixin {
  final user = LocalStorage.getUser();
  bool _isCashSessionOpen = false;
  bool _isDrawerActive = false;
  bool _isInitialSyncing = false;
  bool _isManuallySyncing = false;

  late List<IndexedStackChild> list;
  late List<IndexedStackChild> listWaiter;

  void _initLists() {
    final settings = LocalStorage.getSettingsList();
    bool hideCustomer = false;
    bool hideTable = false;
    bool hideOrderFlow = false;

    for (var element in settings) {
      if (element.key == 'hide_customer') {
        hideCustomer = element.value == '1' || element.value == 'true';
      } else if (element.key == 'hide_table') {
        hideTable = element.value == '1' || element.value == 'true';
      } else if (element.key == 'hide_order_flow') {
        hideOrderFlow = element.value == '1' || element.value == 'true';
      }
    }

    list = [
      IndexedStackChild(child: const PostPage(), preload: true),
      IndexedStackChild(
        child:
            hideOrderFlow ? const SizedBox.shrink() : const OrdersTablesPage(),
      ),
      IndexedStackChild(
        child: hideCustomer ? const SizedBox.shrink() : const CustomersPage(),
      ),
      IndexedStackChild(
        child: hideTable ? const SizedBox.shrink() : const TablesPage(),
      ),
      IndexedStackChild(child: const SaleHistory()),
      IndexedStackChild(child: const InComePage()),
      IndexedStackChild(child: const ProfilePage()),
      IndexedStackChild(child: const SettingsPage()),
    ];

    listWaiter = [
      IndexedStackChild(child: const PostPage(), preload: true),
      IndexedStackChild(
        child:
            hideOrderFlow ? const SizedBox.shrink() : const OrdersTablesPage(),
      ),
      IndexedStackChild(
        child: hideTable ? const SizedBox.shrink() : const TablesPage(),
      ),
      IndexedStackChild(child: const ProfilePage()),
      IndexedStackChild(child: const SettingsPage()),
    ];
  }

  late List<IndexedStackChild> listKitchen = [
    IndexedStackChild(child: const KitchenPage(), preload: true),
    IndexedStackChild(child: const ProfilePage()),
    IndexedStackChild(child: const SettingsPage()),
  ];

  Timer? timer;
  Timer? _notificationTimer;
  int time = 0;
  final player = AudioPlayer();

  notification() async {
    await FirebaseMessaging.instance.requestPermission(
      sound: true,
      alert: true,
      badge: false,
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      if (AppConstants.playMusicOnOrderStatusChange) {
        player.play(AssetSource("audio/notification.wav"));
      }
      if (!mounted) return;
      AppHelpers.showSnackBar(
        context,
        "${AppHelpers.getTranslation(TrKeys.id)} #${message.notification?.title} ${message.notification?.body}",
      );
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    _notificationTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    _initLists();
    super.initState();
    if (Platform.isAndroid || Platform.isIOS) {
      FirebaseMessaging.instance.requestPermission(
        sound: true,
        alert: true,
        badge: false,
      );
    }
    notification();
    // initialize cash session state from local storage
    final session = LocalStorage.getCashSession();
    if (session != null && session.isNotEmpty) {
      _isCashSessionOpen = true;
    }
    _isInitialSyncing = true;
    Future.microtask(() async {
      await SyncService().start();
      if (!mounted) return;
      _initLists();
      setState(() {
        _isInitialSyncing = false;
      });
      _runInitialLoads();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isInitialSyncing) return;
      _runInitialLoads();
      ref.read(printerProvider.notifier).init();

      if (mounted) {
        _notificationTimer = Timer.periodic(
          AppConstants.refreshTime,
          (s) {
            if (!mounted) return;
            ref.read(notificationProvider.notifier).fetchCount(context);
          },
        );
      }
    });
  }

  void _runInitialLoads() {
    if (user?.role == TrKeys.seller) {
      ref.read(mainProvider.notifier)
        ..refreshProducts(
          context: context,
        )
        ..fetchCategories(
          context: context,
          checkYourNetwork: () {
            AppHelpers.showSnackBar(
              context,
              AppHelpers.getTranslation(TrKeys.checkYourNetworkConnection),
            );
          },
        )
        ..fetchUserDetail()
        ..changeIndex(0);
      ref.read(rightSideProvider.notifier).fetchUsers(
        checkYourNetwork: () {
          AppHelpers.showSnackBar(
            context,
            AppHelpers.getTranslation(TrKeys.checkYourNetworkConnection),
          );
        },
      );
    } else if (user?.role == TrKeys.cooker) {
      ref.read(mainProvider.notifier)
        ..fetchUserDetail()
        ..changeIndex(0);
    } else {
      ref.read(mainProvider.notifier)
        ..refreshProducts(
          context: context,
        )
        ..fetchCategories(
          context: context,
          checkYourNetwork: () {
            AppHelpers.showSnackBar(
              context,
              AppHelpers.getTranslation(TrKeys.checkYourNetworkConnection),
            );
          },
        )
        ..fetchUserDetail()
        ..changeIndex(0);
    }
  }

  Future playMusic() async {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      await player.play(AssetSource("audio/notification.wav"));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (AppConstants.keepPlayingOnNewOrder) {
      ref.listen(newOrdersProvider, (previous, next) async {
        if (next.orders.isEmpty) {
          await player.stop();
          timer?.cancel();
        }
        if (time != 0 && next.orders.isNotEmpty) {
          await playMusic();
        }
        time++;
      });
    }
    ref.listen<int>(
      mainProvider.select((s) => s.selectIndex),
      (previous, current) {
        if (current == 0 && previous != null && previous != 0) {
          ref.read(mainProvider.notifier).refreshProducts(context: context);
        }
      },
    );
    final state = ref.watch(mainProvider);
    final pages = (user?.role == TrKeys.seller || user?.role == TrKeys.admin)
        ? list
        : user?.role == TrKeys.cooker
            ? listKitchen
            : listWaiter;
    final safeIndex = state.selectIndex >= pages.length ? 0 : state.selectIndex;
    final customerNotifier = ref.read(customerProvider.notifier);
    final notifier = ref.read(mainProvider.notifier);

    return SafeArea(
      child: KeyboardDismisser(
        child: Stack(
          children: [
            Scaffold(
              resizeToAvoidBottomInset: false,
              appBar: customAppBar(notifier, customerNotifier),
              backgroundColor: AppStyle.mainBack,
              body: Row(
                children: [
                  (user?.role == TrKeys.seller || user?.role == TrKeys.admin)
                      ? bottomLeftNavigationBar(state)
                      : user?.role == TrKeys.cooker
                          ? bottomLeftNavigationBarKitchen(state)
                          : bottomLeftNavigationBarWaiter(state),
                  Expanded(
                    child: ProsteIndexedStack(
                      index: safeIndex,
                      children: pages,
                    ),
                  ),
                ],
              ),
            ),
            if (_isInitialSyncing)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.4),
                  alignment: Alignment.center,
                  child: Container(
                    padding: EdgeInsets.all(24.r),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    width: 360.r,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 48.r,
                          width: 48.r,
                          child: const CircularProgressIndicator(),
                        ),
                        16.verticalSpace,
                        Text(
                          'Syncing data...',
                          style: GoogleFonts.inter(
                              fontSize: 16.sp,
                              color: AppStyle.black,
                              fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                        8.verticalSpace,
                        Builder(
                          builder: (context) {
                            final progress = ref.watch(syncProgressProvider);
                            if (progress.hasValue) {
                              final p = progress.value!;
                              final msg =
                                  '${p.phase} ${p.entity} (${p.processed}/${p.total})';
                              return Text(
                                msg,
                                style: GoogleFonts.inter(
                                    fontSize: 14.sp,
                                    color: AppStyle.black,
                                    fontWeight: FontWeight.w400),
                                textAlign: TextAlign.center,
                              );
                            }
                            if (progress.hasError) {
                              return Text(
                                AppHelpers.getTranslation(
                                    TrKeys.somethingWentWrongWithTheServer),
                                style: GoogleFonts.inter(
                                    fontSize: 14.sp,
                                    color: Colors.red,
                                    fontWeight: FontWeight.w400),
                                textAlign: TextAlign.center,
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  AppBar customAppBar(
      MainNotifier notifier, CustomerNotifier customerNotifier) {
    return AppBar(
      backgroundColor: AppStyle.white,
      automaticallyImplyLeading: false,
      elevation: 0.5,
      title: IntrinsicHeight(
        child: Row(
          children: [
            12.horizontalSpace,
            Text(
              AppHelpers.getAppName() ?? "",
              style: GoogleFonts.inter(
                  color: AppStyle.black, fontWeight: FontWeight.bold),
            ),
            16.horizontalSpace,
            const VerticalDivider(),
            30.horizontalSpace,
            Expanded(
              child: Row(
                children: [
                  Icon(
                    FlutterRemix.search_2_line,
                    size: 20.r,
                    color: AppStyle.black,
                  ),
                  17.horizontalSpace,
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      onChanged: (value) {
                        if (user?.role == TrKeys.seller) {
                          ref.watch(mainProvider).selectIndex == 2
                              ? customerNotifier.searchUsers(
                                  context, value.trim())
                              : notifier.setProductsQuery(
                                  context,
                                  value.trim(),
                                  pricingTier:
                                      ref.read(selectedPricingTierProvider),
                                  tierPrices:
                                      ref.read(rightSideProvider).tierPrices,
                                );
                          if (ref.watch(mainProvider).selectIndex == 1) {
                            ref
                                .read(newOrdersProvider.notifier)
                                .setOrdersQuery(context, value.trim());
                            ref
                                .read(acceptedOrdersProvider.notifier)
                                .setOrdersQuery(context, value.trim());
                            ref
                                .read(readyOrdersProvider.notifier)
                                .setOrdersQuery(context, value.trim());
                            ref
                                .read(onAWayOrdersProvider.notifier)
                                .setOrdersQuery(context, value.trim());
                            ref
                                .read(deliveredOrdersProvider.notifier)
                                .setOrdersQuery(context, value.trim());
                            ref
                                .read(canceledOrdersProvider.notifier)
                                .setOrdersQuery(context, value.trim());
                          }
                        } else if (user?.role == TrKeys.cooker) {
                          ref
                              .read(kitchenProvider.notifier)
                              .setOrdersQuery(context, value.trim());
                        } else {
                          if (ref.watch(mainProvider).selectIndex == 1) {
                            ref
                                .read(newOrdersProvider.notifier)
                                .setOrdersQuery(context, value.trim());
                            ref
                                .read(acceptedOrdersProvider.notifier)
                                .setOrdersQuery(context, value.trim());
                            ref
                                .read(readyOrdersProvider.notifier)
                                .setOrdersQuery(context, value.trim());
                            ref
                                .read(onAWayOrdersProvider.notifier)
                                .setOrdersQuery(context, value.trim());
                            ref
                                .read(deliveredOrdersProvider.notifier)
                                .setOrdersQuery(context, value.trim());
                            ref
                                .read(canceledOrdersProvider.notifier)
                                .setOrdersQuery(context, value.trim());
                          }
                          notifier.setProductsQuery(
                            context,
                            value.trim(),
                            pricingTier: ref.read(selectedPricingTierProvider),
                            tierPrices: ref.read(rightSideProvider).tierPrices,
                          );
                        }
                      },
                      cursorColor: AppStyle.black,
                      cursorWidth: 1.r,
                      decoration: InputDecoration.collapsed(
                        hintText: ref.watch(mainProvider).selectIndex == 1
                            ? AppHelpers.getTranslation(TrKeys.searchOrders)
                            : ref.watch(mainProvider).selectIndex == 2 &&
                                    user?.role != TrKeys.waiter
                                ? AppHelpers.getTranslation(
                                    TrKeys.searchCustomers)
                                : AppHelpers.getTranslation(
                                    TrKeys.searchProducts),
                        hintStyle: GoogleFonts.inter(
                          fontWeight: FontWeight.w500,
                          fontSize: 18.sp,
                          color: AppStyle.searchHint.withOpacity(0.3),
                          letterSpacing: -14 * 0.02,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const VerticalDivider(),
            SizedBox(width: 120.w, child: const CustomClock()),
            const VerticalDivider(),
            IconButton(
                onPressed: () async {
                  context.pushRoute(const HelpRoute());
                  // await launch(
                  //   "${SecretVars.webUrl}/help",
                  //   forceSafariVC: true,
                  //   forceWebView: true,
                  //   enableJavaScript: true,
                  // );
                },
                icon: const Icon(
                  FlutterRemix.question_line,
                  color: AppStyle.black,
                )),
            // IconButton(
            //     onPressed: () {},
            //     icon: const Icon(
            //       FlutterRemix.settings_5_line,
            //       color: AppColors.black,
            //     )),
            _isManuallySyncing
                ? Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.r),
                    child: SizedBox(
                      width: 20.r,
                      height: 20.r,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppStyle.black,
                      ),
                    ),
                  )
                : IconButton(
                    tooltip: 'Sync now',
                    onPressed: () async {
                      setState(() => _isManuallySyncing = true);
                      try {
                        await SyncService().runManualSync();
                        if (!mounted) return;
                        _runInitialLoads();
                      } finally {
                        if (mounted) {
                          setState(() => _isManuallySyncing = false);
                        }
                      }
                    },
                    icon: const Icon(
                      FlutterRemix.refresh_line,
                      color: AppStyle.black,
                    ),
                  ),
            IconButton(
                onPressed: () {
                  showDialog(
                      context: context,
                      builder: (_) => const Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Dialog(child: NotificationDialog()),
                            ],
                          ));
                },
                icon: const Icon(
                  FlutterRemix.notification_2_line,
                  color: AppStyle.black,
                )),
            NotificationCountsContainer(
                count:
                    '${ref.watch(notificationProvider).countOfNotifications?.notification ?? 0}')
          ],
        ),
      ),
    );
  }

  Container bottomLeftNavigationBar(MainState state) {
    final settings = LocalStorage.getSettingsList();
    bool hideCustomer = false;
    bool hideTable = false;
    bool hideOrderFlow = false;

    for (var element in settings) {
      if (element.key == 'hide_customer') {
        hideCustomer = element.value == '1' || element.value == 'true';
      } else if (element.key == 'hide_table') {
        hideTable = element.value == '1' || element.value == 'true';
      } else if (element.key == 'hide_order_flow') {
        hideOrderFlow = element.value == '1' || element.value == 'true';
      }
    }

    return Container(
      height: double.infinity,
      width: 90.w,
      color: AppStyle.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          24.verticalSpace,
          Container(
            decoration: BoxDecoration(
                color: state.selectIndex == 0
                    ? AppStyle.primary
                    : AppStyle.transparent,
                borderRadius: BorderRadius.circular(10.r)),
            child: IconButton(
                onPressed: () {
                  ref.read(mainProvider.notifier).changeIndex(0);
                },
                icon: Icon(
                  state.selectIndex == 0
                      ? FlutterRemix.home_smile_fill
                      : FlutterRemix.home_smile_line,
                  color:
                      state.selectIndex == 0 ? AppStyle.white : AppStyle.icon,
                )),
          ),
          28.verticalSpace,
          if (!hideOrderFlow) ...[
            Container(
              decoration: BoxDecoration(
                  color: state.selectIndex == 1
                      ? AppStyle.primary
                      : AppStyle.transparent,
                  borderRadius: BorderRadius.circular(10.r)),
              child: IconButton(
                  onPressed: () {
                    ref.read(mainProvider.notifier).changeIndex(1);
                  },
                  icon: Icon(
                    state.selectIndex == 1
                        ? FlutterRemix.shopping_bag_fill
                        : FlutterRemix.shopping_bag_line,
                    color:
                        state.selectIndex == 1 ? AppStyle.white : AppStyle.icon,
                  )),
            ),
            28.verticalSpace,
          ],
          if (!hideCustomer) ...[
            Container(
              decoration: BoxDecoration(
                  color: state.selectIndex == 2
                      ? AppStyle.primary
                      : AppStyle.transparent,
                  borderRadius: BorderRadius.circular(10.r)),
              child: IconButton(
                  onPressed: () {
                    ref.read(mainProvider.notifier).changeIndex(2);
                  },
                  icon: Icon(
                    state.selectIndex == 2
                        ? FlutterRemix.user_3_fill
                        : FlutterRemix.user_3_line,
                    color:
                        state.selectIndex == 2 ? AppStyle.white : AppStyle.icon,
                  )),
            ),
            28.verticalSpace,
          ],
          if (!hideTable) ...[
            Container(
              decoration: BoxDecoration(
                  color: state.selectIndex == 3
                      ? AppStyle.primary
                      : AppStyle.transparent,
                  borderRadius: BorderRadius.circular(10.r)),
              child: IconButton(
                onPressed: () {
                  final cashoutId = LocalStorage.getCashoutTableId();
                  if (cashoutId != null) {
                    LocalStorage.setCashoutTableId(null);
                    ref.read(mainProvider.notifier).setPriceDate(null);
                    ref.read(tablesProvider.notifier).exitTableOrdering();
                    ref.read(rightSideProvider.notifier).clearCalculate();
                  }
                  ref.read(mainProvider.notifier).changeIndex(3);
                },
                icon: SvgPicture.asset(
                  state.selectIndex == 3
                      ? Assets.svgSelectTable
                      : Assets.svgTable,
                ),
              ),
            ),
            28.verticalSpace,
          ],
          Container(
            decoration: BoxDecoration(
                color: state.selectIndex == 4
                    ? AppStyle.primary
                    : AppStyle.transparent,
                borderRadius: BorderRadius.circular(10.r)),
            child: IconButton(
                onPressed: () {
                  ref.read(mainProvider.notifier).changeIndex(4);
                },
                icon: Icon(
                  state.selectIndex == 4
                      ? FlutterRemix.money_dollar_circle_fill
                      : FlutterRemix.money_dollar_circle_line,
                  color:
                      state.selectIndex == 4 ? AppStyle.white : AppStyle.icon,
                )),
          ),
          28.verticalSpace,
          Container(
            decoration: BoxDecoration(
                color: state.selectIndex == 5
                    ? AppStyle.primary
                    : AppStyle.transparent,
                borderRadius: BorderRadius.circular(10.r)),
            child: IconButton(
                onPressed: () {
                  ref.read(mainProvider.notifier).changeIndex(5);
                },
                icon: Icon(
                  state.selectIndex == 5
                      ? FlutterRemix.pie_chart_fill
                      : FlutterRemix.pie_chart_line,
                  color:
                      state.selectIndex == 5 ? AppStyle.white : AppStyle.icon,
                )),
          ),
          28.verticalSpace,
          Container(
            decoration: BoxDecoration(
                color: state.selectIndex == 7
                    ? AppStyle.primary
                    : AppStyle.transparent,
                borderRadius: BorderRadius.circular(10.r)),
            child: IconButton(
                onPressed: () {
                  ref.read(mainProvider.notifier).changeIndex(7);
                },
                icon: Icon(
                  state.selectIndex == 7
                      ? FlutterRemix.settings_5_fill
                      : FlutterRemix.settings_5_line,
                  color:
                      state.selectIndex == 7 ? AppStyle.white : AppStyle.icon,
                )),
          ),
          const Spacer(),
          // Open cash drawer button — use saved/default printer configuration
          if (user?.role == TrKeys.seller)
            Container(
              decoration: BoxDecoration(
                color:
                    _isDrawerActive ? AppStyle.primary : AppStyle.transparent,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: IconButton(
                  onPressed: () async {
                    setState(() {
                      _isDrawerActive = true;
                    });
                    await OpenDrawerDialog.openDrawer(context);
                    if (mounted) {
                      setState(() {
                        _isDrawerActive = false;
                      });
                    }
                  },
                  icon: const Icon(
                    Icons.point_of_sale,
                    color: AppStyle.icon,
                  )),
            ),
          24.verticalSpace,
          InkWell(
            onTap: () {
              ref.read(mainProvider.notifier).changeIndex(6);
            },
            child: Container(
              decoration: BoxDecoration(
                  border: Border.all(
                    color: state.selectIndex == 6
                        ? AppStyle.primary
                        : AppStyle.transparent,
                  ),
                  borderRadius: BorderRadius.circular(20.r)),
              child: CommonImage(
                  width: 40,
                  height: 40,
                  radius: 20,
                  imageUrl: LocalStorage.getUser()?.img ?? ""),
            ),
          ),
          24.verticalSpace,
          // Cash session open/close icon — calls API and toggles on success
          if (user?.role == TrKeys.seller)
            Container(
              decoration: BoxDecoration(
                color: _isCashSessionOpen
                    ? AppStyle.primary
                    : AppStyle.transparent,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: IconButton(
                  onPressed: () async {
                    try {
                      if (!_isCashSessionOpen) {
                        final user = LocalStorage.getUser();
                        final shopId = user?.shop?.id ?? user?.invite?.shopId;
                        final body = {
                          'user_id': user?.id ?? 0,
                          'shop_id': shopId ?? 0,
                        };
                        final result = await inject<CashSessionsRepository>()
                            .openCashSession(body: body);
                        await result.when(
                          success: (data) async {
                            // store session and update UI on success
                            await LocalStorage.setCashSession(data ?? {});
                            if (mounted) {
                              setState(() {
                                _isCashSessionOpen = true;
                              });
                              AppHelpers.showSnackBar(
                                  context, 'New Shift Started');
                            }
                          },
                          failure: (error, statusCode) {
                            AppHelpers.showSnackBar(context, error.toString());
                          },
                        );
                      } else {
                        // attempt to close session on server using stored session id
                        final session = LocalStorage.getCashSession();
                        int? sessionId;
                        if (session != null) {
                          if (session['id'] is int) {
                            sessionId = session['id'] as int;
                          } else if (session['id'] is String) {
                            sessionId = int.tryParse(session['id'] as String);
                          } else if (session['data'] is Map &&
                              session['data']['id'] != null) {
                            final v = session['data']['id'];
                            if (v is int) sessionId = v;
                            if (v is String) sessionId = int.tryParse(v);
                          } else if (session['cash_session'] is Map &&
                              session['cash_session']['id'] != null) {
                            final v = session['cash_session']['id'];
                            if (v is int) sessionId = v;
                            if (v is String) sessionId = int.tryParse(v);
                          }
                        }

                        if (sessionId == null) {
                          // fallback: clear locally if we can't determine id
                          await LocalStorage.setCashSession({});
                          if (mounted) {
                            setState(() {
                              _isCashSessionOpen = false;
                            });
                            AppHelpers.showSnackBar(context,
                                'No active shift found, cleared locally');
                          }
                        } else {
                          final result = await inject<CashSessionsRepository>()
                              .closeCashSession(id: sessionId);
                          await result.when(
                            success: (data) async {
                              // extract session data from response
                              final Map<String, dynamic> sessionPayload =
                                  (data is Map && data['data'] != null)
                                      ? Map<String, dynamic>.from(data['data'])
                                      : (data is Map
                                          ? Map<String, dynamic>.from(data)
                                          : {});
                              if (mounted) {
                                // show preview dialog with server-provided session report
                                try {
                                  AppHelpers.showSnackBar(
                                      context, 'Preparing shift preview...');
                                  await showDialog<void>(
                                    context: context,
                                    builder: (context) {
                                      return LayoutBuilder(
                                          builder: (context, constraints) {
                                        return SimpleDialog(
                                          title: SizedBox(
                                            height: constraints.maxHeight * 0.7,
                                            width: 450.r,
                                            child: GenerateCashSessionPage(
                                                sessionData: sessionPayload),
                                          ),
                                        );
                                      });
                                    },
                                  );
                                } catch (e) {
                                  debugPrint(
                                      '==> showDialog failed for cash session preview: $e');
                                  // fallback: open full screen page so user still sees report
                                  if (mounted) {
                                    await Navigator.of(context)
                                        .push(MaterialPageRoute(
                                      builder: (_) => Scaffold(
                                        appBar: AppBar(
                                            title: const Text(
                                                'Cash Session Preview')),
                                        body: GenerateCashSessionPage(
                                            sessionData: sessionPayload),
                                      ),
                                    ));
                                  }
                                }
                              }
                              // clear local session regardless after preview
                              await LocalStorage.setCashSession({});
                              if (mounted) {
                                setState(() {
                                  _isCashSessionOpen = false;
                                });
                                AppHelpers.showSnackBar(
                                    context, 'Shift closed');
                              }
                            },
                            failure: (error, statusCode) {
                              if (mounted) {
                                AppHelpers.showSnackBar(
                                    context, error.toString());
                              }
                            },
                          );
                        }
                      }
                    } catch (e) {
                      debugPrint('==> open shift error: $e');
                      if (mounted) {
                        AppHelpers.showSnackBar(
                            context, 'Failed to open shift');
                      }
                    }
                  },
                  icon: Icon(
                    _isCashSessionOpen
                        ? Icons.door_front_door
                        : FlutterRemix.door_open_fill,
                    color: AppStyle.icon,
                  )),
            ),
          Consumer(
            builder: (context, ref, _) {
              final connectivityAsync = ref.watch(connectivityProvider);

              return connectivityAsync.when(
                data: (results) {
                  final hasNetwork = results.any((r) =>
                      r == ConnectivityResult.mobile ||
                      r == ConnectivityResult.wifi ||
                      r == ConnectivityResult.ethernet);

                  if (!hasNetwork) {
                    return const SizedBox.shrink();
                  }

                  return Column(
                    children: [
                      12.verticalSpace,
                      IconButton(
                        onPressed: () {
                          context.replaceRoute(const LoginRoute());
                          ref.read(newOrdersProvider.notifier).stopTimer();
                          ref.read(acceptedOrdersProvider.notifier).stopTimer();
                          ref.read(cookingOrdersProvider.notifier).stopTimer();
                          ref.read(readyOrdersProvider.notifier).stopTimer();
                          ref.read(onAWayOrdersProvider.notifier).stopTimer();
                          ref
                              .read(deliveredOrdersProvider.notifier)
                              .stopTimer();
                          ref.read(canceledOrdersProvider.notifier).stopTimer();
                          SyncService().stop();
                          LocalStorage.clearStore();
                        },
                        icon: const Icon(
                          FlutterRemix.logout_circle_line,
                          color: AppStyle.icon,
                        ),
                      ),
                      32.verticalSpace,
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              );
            },
          ),
        ],
      ),
    );
  }

  Container bottomLeftNavigationBarKitchen(MainState state) {
    return Container(
      height: double.infinity,
      width: 90.w,
      color: AppStyle.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          28.verticalSpace,
          Container(
            decoration: BoxDecoration(
                color: state.selectIndex == 0
                    ? AppStyle.primary
                    : AppStyle.transparent,
                borderRadius: BorderRadius.circular(10.r)),
            child: IconButton(
              onPressed: () {
                ref.read(mainProvider.notifier).changeIndex(0);
              },
              icon: SvgPicture.asset(
                state.selectIndex == 0
                    ? Assets.svgSelectKitchen
                    : Assets.svgKitchen,
              ),
            ),
          ),
          28.verticalSpace,
          Container(
            decoration: BoxDecoration(
                color: state.selectIndex == 2
                    ? AppStyle.primary
                    : AppStyle.transparent,
                borderRadius: BorderRadius.circular(10.r)),
            child: IconButton(
                onPressed: () {
                  ref.read(mainProvider.notifier).changeIndex(2);
                },
                icon: Icon(
                  state.selectIndex == 2
                      ? FlutterRemix.settings_5_fill
                      : FlutterRemix.settings_5_line,
                  color:
                      state.selectIndex == 2 ? AppStyle.white : AppStyle.icon,
                )),
          ),
          const Spacer(),
          InkWell(
            onTap: () {
              ref.read(mainProvider.notifier).changeIndex(1);
            },
            child: Container(
              decoration: BoxDecoration(
                  border: Border.all(
                    color: state.selectIndex == 1
                        ? AppStyle.primary
                        : AppStyle.transparent,
                  ),
                  borderRadius: BorderRadius.circular(20.r)),
              child: CommonImage(
                  width: 40,
                  height: 40,
                  radius: 20,
                  imageUrl: LocalStorage.getUser()?.img ?? ""),
            ),
          ),
          24.verticalSpace,
          IconButton(
              onPressed: () {
                // Clear any visible snackbars before logging out
                try {
                  ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
                } catch (_) {}

                context.replaceRoute(const LoginRoute());
                ref.read(kitchenProvider.notifier).stopTimer();
                ref.read(mainProvider.notifier).resetForLogout();
                SyncService().stop();
                LocalStorage.clearStore();
              },
              icon: const Icon(
                FlutterRemix.logout_circle_line,
                color: AppStyle.icon,
              )),
          32.verticalSpace
        ],
      ),
    );
  }

  Container bottomLeftNavigationBarWaiter(MainState state) {
    final settings = LocalStorage.getSettingsList();
    bool hideTable = false;
    bool hideOrderFlow = false;

    for (var element in settings) {
      if (element.key == 'hide_table') {
        hideTable = element.value == '1' || element.value == 'true';
      } else if (element.key == 'hide_order_flow') {
        hideOrderFlow = element.value == '1' || element.value == 'true';
      }
    }

    return Container(
      height: double.infinity,
      width: 90.w,
      color: AppStyle.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          24.verticalSpace,
          Container(
            decoration: BoxDecoration(
                color: state.selectIndex == 0
                    ? AppStyle.primary
                    : AppStyle.transparent,
                borderRadius: BorderRadius.circular(10.r)),
            child: IconButton(
                onPressed: () {
                  ref.read(mainProvider.notifier).changeIndex(0);
                },
                icon: Icon(
                  state.selectIndex == 0
                      ? FlutterRemix.home_smile_fill
                      : FlutterRemix.home_smile_line,
                  color:
                      state.selectIndex == 0 ? AppStyle.white : AppStyle.icon,
                )),
          ),
          28.verticalSpace,
          if (!hideOrderFlow) ...[
            Container(
              decoration: BoxDecoration(
                  color: state.selectIndex == 1
                      ? AppStyle.primary
                      : AppStyle.transparent,
                  borderRadius: BorderRadius.circular(10.r)),
              child: IconButton(
                  onPressed: () {
                    ref.read(mainProvider.notifier).changeIndex(1);
                  },
                  icon: Icon(
                    state.selectIndex == 1
                        ? FlutterRemix.shopping_bag_fill
                        : FlutterRemix.shopping_bag_line,
                    color:
                        state.selectIndex == 1 ? AppStyle.white : AppStyle.icon,
                  )),
            ),
            28.verticalSpace,
          ],
          if (!hideTable) ...[
            Container(
              decoration: BoxDecoration(
                  color: state.selectIndex == 2
                      ? AppStyle.primary
                      : AppStyle.transparent,
                  borderRadius: BorderRadius.circular(10.r)),
              child: IconButton(
                onPressed: () {
                  final cashoutId = LocalStorage.getCashoutTableId();
                  if (cashoutId != null) {
                    LocalStorage.setCashoutTableId(null);
                    ref.read(mainProvider.notifier).setPriceDate(null);
                    ref.read(tablesProvider.notifier).exitTableOrdering();
                    ref.read(rightSideProvider.notifier).clearCalculate();
                  }
                  ref.read(mainProvider.notifier).changeIndex(2);
                },
                icon: SvgPicture.asset(
                  state.selectIndex == 2
                      ? Assets.svgSelectTable
                      : Assets.svgTable,
                ),
              ),
            ),
            28.verticalSpace,
          ],
          Container(
            decoration: BoxDecoration(
                color: state.selectIndex == 4
                    ? AppStyle.primary
                    : AppStyle.transparent,
                borderRadius: BorderRadius.circular(10.r)),
            child: IconButton(
                onPressed: () {
                  ref.read(mainProvider.notifier).changeIndex(4);
                },
                icon: Icon(
                  state.selectIndex == 4
                      ? FlutterRemix.settings_5_fill
                      : FlutterRemix.settings_5_line,
                  color:
                      state.selectIndex == 4 ? AppStyle.white : AppStyle.icon,
                )),
          ),
          const Spacer(),
          // Open cash drawer button — use saved/default printer configuration
          Container(
            decoration: BoxDecoration(
              color: _isDrawerActive ? AppStyle.primary : AppStyle.transparent,
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: IconButton(
                onPressed: () async {
                  setState(() {
                    _isDrawerActive = true;
                  });
                  await OpenDrawerDialog.openDrawer(context);
                  if (mounted) {
                    setState(() {
                      _isDrawerActive = false;
                    });
                  }
                },
                icon: const Icon(
                  Icons.point_of_sale,
                  color: AppStyle.icon,
                )),
          ),
          24.verticalSpace,
          InkWell(
            onTap: () {
              ref.read(mainProvider.notifier).changeIndex(3);
            },
            child: Container(
              decoration: BoxDecoration(
                  border: Border.all(
                    color: state.selectIndex == 3
                        ? AppStyle.primary
                        : AppStyle.transparent,
                  ),
                  borderRadius: BorderRadius.circular(20.r)),
              child: CommonImage(
                  width: 40,
                  height: 40,
                  radius: 20,
                  imageUrl: LocalStorage.getUser()?.img ?? ""),
            ),
          ),
          24.verticalSpace,
          // Cash session open/close icon — calls API and toggles on success
          Container(
            decoration: BoxDecoration(
              color:
                  _isCashSessionOpen ? AppStyle.primary : AppStyle.transparent,
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: IconButton(
                onPressed: () async {
                  final repository = inject<CashSessionsRepository>();
                  try {
                    if (!_isCashSessionOpen) {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Start Shift'),
                          content: const Text(
                              'Are you sure you want to start a new shift?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Confirm'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        final user = LocalStorage.getUser();
                        final shopId = user?.shop?.id ?? user?.invite?.shopId;
                        final body = {
                          'user_id': user?.id ?? 0,
                          'shop_id': shopId ?? 0,
                        };

                        final result =
                            await repository.openCashSession(body: body);

                        await result.when(
                          success: (data) async {
                            // store session and update UI on success
                            await LocalStorage.setCashSession(data ?? {});
                            if (mounted) {
                              setState(() {
                                _isCashSessionOpen = true;
                              });
                              AppHelpers.showSnackBar(
                                  context, 'New Shift Started');
                            }
                          },
                          failure: (error, statusCode) {
                            if (mounted) {
                              AppHelpers.showSnackBar(context, error);
                            }
                          },
                        );
                      }
                    } else {
                      // confirm close shift
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Close Shift'),
                          content: const Text(
                              'Are you sure you want to close the current shift?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Confirm'),
                            ),
                          ],
                        ),
                      );
                      if (confirm != true) return;
                      // attempt to close session on server using stored session id
                      final session = LocalStorage.getCashSession();
                      int? sessionId;
                      if (session != null) {
                        if (session['id'] is int) {
                          sessionId = session['id'] as int;
                        } else if (session['id'] is String) {
                          sessionId = int.tryParse(session['id'] as String);
                        } else if (session['data'] is Map &&
                            session['data']['id'] != null) {
                          final v = session['data']['id'];
                          if (v is int) sessionId = v;
                          if (v is String) sessionId = int.tryParse(v);
                        } else if (session['cash_session'] is Map &&
                            session['cash_session']['id'] != null) {
                          final v = session['cash_session']['id'];
                          if (v is int) sessionId = v;
                          if (v is String) sessionId = int.tryParse(v);
                        }
                      }

                      if (sessionId == null) {
                        // fallback: clear locally if we can't determine id
                        await LocalStorage.setCashSession({});
                        if (mounted) {
                          setState(() {
                            _isCashSessionOpen = false;
                          });
                          AppHelpers.showSnackBar(context,
                              'No active shift found, cleared locally');
                        }
                      } else {
                        final result =
                            await repository.closeCashSession(id: sessionId);

                        await result.when(
                          success: (data) async {
                            // extract session data from response
                            final Map<String, dynamic> sessionPayload =
                                (data is Map && data['data'] != null)
                                    ? Map<String, dynamic>.from(data['data'])
                                    : (data is Map
                                        ? Map<String, dynamic>.from(data)
                                        : {});

                            if (mounted) {
                              await showDialog<void>(
                                context: context,
                                builder: (context) {
                                  return LayoutBuilder(
                                      builder: (context, constraints) {
                                    return SimpleDialog(
                                      title: SizedBox(
                                        height: constraints.maxHeight * 0.7,
                                        width: 450.r,
                                        child: GenerateCashSessionPage(
                                            sessionData: sessionPayload),
                                      ),
                                    );
                                  });
                                },
                              );
                            }
                            // clear local session regardless after preview
                            await LocalStorage.setCashSession({});
                            if (mounted) {
                              setState(() {
                                _isCashSessionOpen = false;
                              });
                              AppHelpers.showSnackBar(context, 'Shift closed');
                            }
                          },
                          failure: (error, statusCode) {
                            if (mounted) {
                              AppHelpers.showSnackBar(context, error);
                            }
                          },
                        );
                      }
                    }
                  } catch (e) {
                    debugPrint('==> cash session error: $e');
                    if (mounted) {
                      AppHelpers.showSnackBar(
                          context, 'Failed to process shift operation');
                    }
                  }
                },
                icon: Icon(
                  _isCashSessionOpen
                      ? Icons.door_front_door
                      : FlutterRemix.door_open_fill,
                  color: AppStyle.icon,
                )),
          ),
          12.verticalSpace,
          IconButton(
              onPressed: () {
                context.replaceRoute(const LoginRoute());
                ref.read(newOrdersProvider.notifier).stopTimer();
                ref.read(acceptedOrdersProvider.notifier).stopTimer();
                ref.read(cookingOrdersProvider.notifier).stopTimer();
                ref.read(readyOrdersProvider.notifier).stopTimer();
                ref.read(onAWayOrdersProvider.notifier).stopTimer();
                ref.read(deliveredOrdersProvider.notifier).stopTimer();
                ref.read(canceledOrdersProvider.notifier).stopTimer();
                ref.read(mainProvider.notifier).resetForLogout();
                SyncService().stop();
                LocalStorage.clearStore();
              },
              icon: const Icon(
                FlutterRemix.logout_circle_line,
                color: AppStyle.icon,
              )),
          32.verticalSpace
        ],
      ),
    );
  }
}
