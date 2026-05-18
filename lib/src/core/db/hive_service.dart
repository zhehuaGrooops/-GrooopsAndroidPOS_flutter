import 'package:hive_flutter/hive_flutter.dart';

class HiveService {
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    try {
      await Hive.initFlutter();
    } catch (_) {
      Hive.init('.');
    }
    _initialized = true;
  }

  static Future<Box> openBox(String name) async {
    if (!_initialized) {
      await init();
    }
    if (Hive.isBoxOpen(name)) {
      return Hive.box(name);
    }
    return await Hive.openBox(name);
  }

  static Future<LazyBox> openLazyBox(String name) async {
    if (!_initialized) {
      await init();
    }
    return await Hive.openLazyBox(name);
  }

  static Box? tryGetBox(String name) {
    if (Hive.isBoxOpen(name)) {
      return Hive.box(name);
    }
    return null;
  }
}
