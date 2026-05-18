import 'dart:async';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app_widget.dart';
import 'src/core/di/dependency_manager.dart';
import 'src/core/utils/utils.dart';
import 'src/core/db/hive_service.dart';
import 'dart:io' show Platform;

Future<void> main() async {
  if (Platform.isAndroid || Platform.isIOS) {
    await runZonedGuarded(
      () async {
        WidgetsFlutterBinding.ensureInitialized();
        setUpDependencies();
        await Firebase.initializeApp();
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
        await _configureCrashlytics();
        await _bootstrap();
      },
      (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      },
    );
    return;
  }

  WidgetsFlutterBinding.ensureInitialized();
  setUpDependencies();
  await _bootstrap();
}

// Initializes platform-specific services and launches the app.
Future<void> _bootstrap() async {
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    doWhenWindowReady(() {
      // const initialSize = Size(1280, 720);
      const minSize = Size(1024, 576);
      const maxSize = Size(7680, 4320);
      appWindow.maxSize = maxSize;
      appWindow.minSize = minSize;
      // appWindow.size = initialSize; //default size
      appWindow.show();
    });
  }

  await LocalStorage.init();
  await HiveService.init();
  SystemChrome.setPreferredOrientations(
      [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  runApp(const ProviderScope(child: AppWidget()));
}

// Configures Crashlytics capture for Flutter and platform-level errors.
Future<void> _configureCrashlytics() async {
  // This settings will skip debug mode for Crashlytics Data Collection
  await FirebaseCrashlytics.instance
      .setCrashlyticsCollectionEnabled(!kDebugMode);

  FlutterError.onError = (details) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };

  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}
