import 'dart:io' show Platform;

import 'package:admin_desktop/src/core/utils/utils.dart';
import 'package:admin_desktop/src/presentation/components/components.dart';
import 'package:admin_desktop/src/presentation/theme/theme/theme.dart';
import 'package:admin_desktop/src/repository/repository.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_isolate/flutter_isolate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'core/di/dependency_manager.dart';
import 'core/routes/app_router.dart';
import 'presentation/theme/theme.dart';

@pragma('vm:entry-point')
Future<int> getOtherTranslation(int arg) async {
  final settingsRepository = SettingsSettingsRepositoryImpl();
  final res = await settingsRepository.getLanguages();
  res.when(
      success: (l) {
        l.data?.forEach((e) async {
          final translations =
              await settingsRepository.getMobileTranslations(lang: e.locale);
          translations.when(
              success: (d) {
                LocalStorage.setOtherTranslations(
                    translations: d.data, key: e.id.toString());
              },
              failure: (f, s) => null);
        });
      },
      failure: (f, s) => null);
  return 0;
}

class AppWidget extends StatefulWidget {
  const AppWidget({super.key});

  @override
  State<AppWidget> createState() => _AppWidgetState();
}

class _AppWidgetState extends State<AppWidget> {
  Future<Future<FlutterIsolate>> isolate() async {
    return FlutterIsolate.spawn(getOtherTranslation, 0);
  }

  @override
  void initState() {
    if (LocalStorage.getTranslations().isNotEmpty) {
      fetchSettingNoAwait();
    }
    isolate();
    super.initState();
  }

  Future fetchSetting() async {
    final connect = await Connectivity().checkConnectivity();
    if (connect.contains(ConnectivityResult.wifi) ||
        connect.contains(ConnectivityResult.ethernet) ||
        connect.contains(ConnectivityResult.mobile)) {
      settingsRepository.getGlobalSettings();
      await settingsRepository.getLanguages();
      await settingsRepository.getTranslations();
    }
  }

  Future fetchSettingNoAwait() async {
    settingsRepository.getGlobalSettings();
    settingsRepository.getLanguages();
    settingsRepository.getTranslations();
  }

  final appRouter = AppRouter();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: Future.wait({
          AppTheme.create,
          if (LocalStorage.getTranslations().isEmpty) fetchSetting(),
        }),
        builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
          if (snapshot.hasData) {
            final AppTheme theme = snapshot.data?[0];
            return ScreenUtilInit(
              designSize: const Size(1194, 900),
              builder: (context, child) {
                return ChangeNotifierProvider(
                  create: (BuildContext context) => theme,
                  child: MaterialApp.router(
                    theme: ThemeData(useMaterial3: false),
                    scrollBehavior: CustomScrollBehavior(),
                    debugShowCheckedModeBanner: false,
                    routerDelegate: appRouter.delegate(
                      navigatorObservers: () {
                        if (Platform.isAndroid || Platform.isIOS) {
                          return <NavigatorObserver>[
                            FirebaseAnalyticsObserver(
                              analytics: FirebaseAnalytics.instance,
                            ),
                          ];
                        }
                        return const <NavigatorObserver>[];
                      },
                    ),
                    routeInformationParser: appRouter.defaultRouteParser(),
                    locale: Locale(LocalStorage.getLanguage()?.locale ?? 'en'),
                    color: AppStyle.white,
                    builder: (context, child) => ScrollConfiguration(
                      behavior: MyBehavior(),
                      child: child ?? const SizedBox.shrink(),
                    ),
                  ),
                );
              },
            );
          } else {
            return const SizedBox.shrink();
          }
        });
  }
}

class MyBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}
