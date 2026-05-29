import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/models.dart';
import '../constants/constants.dart';

abstract class LocalStorage {
  static SharedPreferences? _preferences;

  LocalStorage._();

  static Future<void> init() async {
    _preferences = await SharedPreferences.getInstance();
  }

  static Future<void> setOtherTranslations(
      {required Map<String, dynamic>? translations,
      required String key}) async {
    SharedPreferences? local = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(translations);
    await local.setString(key, encoded);
  }

  static Future<void> setSystemLanguage(LanguageData? lang) async {
    if (_preferences != null) {
      final String langString = jsonEncode(lang?.toJson());
      await _preferences!.setString(AppConstants.keySystemLanguage, langString);
    }
  }

  static LanguageData? getSystemLanguage() {
    final lang = _preferences?.getString(AppConstants.keySystemLanguage);
    if (lang == null) {
      return null;
    }
    final map = jsonDecode(lang);
    if (map == null) {
      return null;
    }
    return LanguageData.fromJson(map);
  }

  static Future<Map<String, dynamic>> getOtherTranslations(
      {required String key}) async {
    SharedPreferences? local = await SharedPreferences.getInstance();

    final String encoded = local.getString(key) ?? '';
    if (encoded.isEmpty) {
      return {};
    }
    final Map<String, dynamic> decoded = jsonDecode(encoded);
    return decoded;
  }

  static LanguageData? getLanguage() {
    final lang = _preferences?.getString(AppConstants.keyLanguageData);
    if (lang == null) {
      return null;
    }
    final map = jsonDecode(lang);
    if (map == null) {
      return null;
    }
    return LanguageData.fromJson(map);
  }

  static Future<void> setLanguageData(LanguageData? langData) async {
    final String lang = jsonEncode(langData?.toJson());
    setLangLtr(langData?.backward);
    await _preferences?.setString(AppConstants.keyLanguageData, lang);
  }

  static Future<void> setToken(String? token) async {
    if (_preferences != null) {
      await _preferences!.setString(AppConstants.keyToken, token ?? '');
    }
  }

  static bool getLangLtr() =>
      !(_preferences?.getBool(AppConstants.keyLangLtr) ?? true);

  static Future<void> setLangLtr(bool? backward) async {
    if (_preferences != null) {
      await _preferences?.setBool(AppConstants.keyLangLtr, backward ?? false);
    }
  }

  static String getToken() =>
      _preferences?.getString(AppConstants.keyToken) ?? '';

  static void deleteToken() => _preferences?.remove(AppConstants.keyToken);

  static setPinCode(String pinCode) async {
    if (_preferences != null) {
      await _preferences!.setString(AppConstants.pinCode, pinCode);
    }
  }

  static String getPinCode() =>
      _preferences?.getString(AppConstants.pinCode) ?? '';

  static void deletePinCode() => _preferences?.remove(AppConstants.pinCode);

  static Future<void> setSettingsList(List<SettingsData> settings) async {
    if (_preferences != null) {
      final List<String> strings =
          settings.map((setting) => jsonEncode(setting.toJson())).toList();
      await _preferences!
          .setStringList(AppConstants.keyGlobalSettings, strings);
    }
  }

  static List<SettingsData> getSettingsList() {
    final List<String> settings =
        _preferences?.getStringList(AppConstants.keyGlobalSettings) ?? [];
    final List<SettingsData> settingsList = settings
        .map(
          (setting) => SettingsData.fromJson(jsonDecode(setting)),
        )
        .toList();
    return settingsList;
  }

  static void deleteSettingsList() =>
      _preferences?.remove(AppConstants.keyGlobalSettings);

  static Future<void> setActiveLocale(String? locale) async {
    if (_preferences != null) {
      await _preferences!.setString(AppConstants.keyActiveLocale, locale ?? '');
    }
  }

  // String getActiveLocale() =>
  //     _preferences?.getString(AppConstants.keyActiveLocale) ?? 'en';

  static void deleteActiveLocale() =>
      _preferences?.remove(AppConstants.keyActiveLocale);

  static Future<void> setTranslations(
      Map<String, dynamic>? translations) async {
    if (_preferences != null) {
      final String encoded = jsonEncode(translations);
      await _preferences!.setString(AppConstants.keyTranslations, encoded);
    }
  }

  static Map<String, dynamic> getTranslations() {
    final String encoded =
        _preferences?.getString(AppConstants.keyTranslations) ?? '';
    if (encoded.isEmpty) {
      return {};
    }
    final Map<String, dynamic> decoded = jsonDecode(encoded);
    return decoded;
  }

  static void deleteTranslations() =>
      _preferences?.remove(AppConstants.keyTranslations);

  static Future<void> setSelectedCurrency(CurrencyData currency) async {
    if (_preferences != null) {
      final String currencyString = jsonEncode(currency.toJson());
      await _preferences!
          .setString(AppConstants.keySelectedCurrency, currencyString);
    }
  }

  static CurrencyData getSelectedCurrency() {
    final String? currencyString =
        _preferences?.getString(AppConstants.keySelectedCurrency);
    if (currencyString == null || currencyString.isEmpty) {
      return CurrencyData();
    }
    final map = jsonDecode(currencyString);
    return CurrencyData.fromJson(map);
  }

  static void deleteSelectedCurrency() =>
      _preferences?.remove(AppConstants.keySelectedCurrency);

  static Future<void> setBags(List<BagData> bags) async {
    if (_preferences != null) {
      final List<String> strings =
          bags.map((bag) => jsonEncode(bag.toJson())).toList();
      await _preferences!.setStringList(AppConstants.keyBags, strings);
    }
  }

  static List<BagData> getBags() {
    final List<String> bags =
        _preferences?.getStringList(AppConstants.keyBags) ?? [];
    final List<BagData> localBags = bags
        .map(
          (bag) => BagData.fromJson(jsonDecode(bag)),
        )
        .toList(growable: true);
    return localBags;
  }

  static void deleteCartProducts() =>
      _preferences?.remove(AppConstants.keyBags);

  static Future<void> setUser(UserData? user) async {
    if (_preferences != null) {
      final String userString = user != null ? jsonEncode(user.toJson()) : '';
      await _preferences!.setString(AppConstants.keyUser, userString);
    }
  }

  static UserData? getUser() {
    final savedString = _preferences?.getString(AppConstants.keyUser);
    if (savedString == null || savedString.isEmpty) {
      return null;
    }
    final map = jsonDecode(savedString);
    if (map == null) {
      return null;
    }
    return UserData.fromJson(map);
  }

  static void deleteUser() => _preferences?.remove(AppConstants.keyUser);

  static void clearStore() {
    deletePinCode();
    deleteToken();
    deleteUser();
    deleteCartProducts();
    deleteSettingsList();
  }

  static Future<void> setCashSession(Map<String, dynamic> session) async {
    if (_preferences != null) {
      await _preferences!.setString('cash_session', jsonEncode(session));
    }
  }

  static Map<String, dynamic>? getCashSession() {
    final encoded = _preferences?.getString('cash_session') ?? '';
    if (encoded.isEmpty) return null;
    return jsonDecode(encoded) as Map<String, dynamic>?;
  }

  static Future<void> setQueueState(int counter, String date) async {
    if (_preferences != null) {
      await _preferences!.setInt(AppConstants.keyQueueCounter, counter);
      await _preferences!.setString(AppConstants.keyQueueDate, date);
    }
  }

  static Map<String, dynamic> getQueueState() {
    final int counter = _preferences?.getInt(AppConstants.keyQueueCounter) ?? 0;
    final String date =
        _preferences?.getString(AppConstants.keyQueueDate) ?? '';
    return {'counter': counter, 'date': date};
  }

  // ── Per-table pending order items (local hold before cashout) ─────────────

  static List<Map<String, dynamic>> getTableItems(int tableId) {
    final raw = _preferences?.getString('table_items_$tableId');
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static List<Map<String, dynamic>> getAllActiveTableItems() {
    final keys = _preferences?.getKeys() ?? <String>{};
    final result = <Map<String, dynamic>>[];
    for (final key in keys) {
      if (key.startsWith('table_items_')) {
        final raw = _preferences?.getString(key);
        if (raw != null && raw.isNotEmpty) {
          try {
            result.addAll((jsonDecode(raw) as List)
                .map((e) => Map<String, dynamic>.from(e as Map)));
          } catch (_) {}
        }
      }
    }
    return result;
  }

  static Future<void> setTableItems(
      int tableId, List<Map<String, dynamic>> items) async {
    await _preferences?.setString('table_items_$tableId', jsonEncode(items));
  }

  static Future<void> clearTableItems(int tableId) async {
    await _preferences?.remove('table_items_$tableId');
  }

  static int? getCashoutTableId() {
    final v = _preferences?.getInt('cashout_table_id');
    return (v == null || v == -1) ? null : v;
  }

  static Future<void> setCashoutTableId(int? tableId) async {
    await _preferences?.setInt('cashout_table_id', tableId ?? -1);
  }

  static int? getActiveOrderingTableId() {
    final v = _preferences?.getInt('active_ordering_table_id');
    return (v == null || v == -1) ? null : v;
  }

  static Future<void> setActiveOrderingTableId(int? tableId) async {
    await _preferences?.setInt('active_ordering_table_id', tableId ?? -1);
  }

  static Future<void> setUseOrderHooks(bool v) async =>
      await _preferences?.setBool(AppConstants.keyUseOrderHooks, v);

  static bool getUseOrderHooks() =>
      _preferences?.getBool(AppConstants.keyUseOrderHooks) ?? false;

  static Map<String, dynamic>? getSelectedCurrencyJson() {
    final raw = _preferences?.getString(AppConstants.keySelectedCurrency);
    if (raw == null || raw.isEmpty) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }
}
