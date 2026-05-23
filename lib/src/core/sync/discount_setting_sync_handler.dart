import 'dart:async';
import 'package:admin_desktop/src/models/response/discount_setting_response.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../handlers/handlers.dart';
import '../db/hive_service.dart';
import '../constants/hive_boxes.dart';
import '../utils/utils.dart';
import 'sync_models.dart';

class DiscountSettingSyncHandler {
  final HttpService _httpService;
  final StreamSink<SyncProgress> _progressSink;

  DiscountSettingSyncHandler({
    required HttpService httpService,
    required StreamSink<SyncProgress> progressSink,
  })  : _httpService = httpService,
        _progressSink = progressSink;

  Dio _getClient({required bool requireAuth}) {
    return _httpService.client(requireAuth: requireAuth);
  }

  Future<bool> pullDiscountSettings() async {
    try {
      final box = await HiveService.openBox(HiveBoxes.discountSettings);

      // We'll try to fetch all discount settings by setting a large perPage
      final data = {
        'lang': LocalStorage.getLanguage()?.locale ?? 'en',
      };

      final client = _getClient(requireAuth: true);
      final response = await client.get(
        '/api/v1/rest/discount-settings/all',
        queryParameters: data,
      );

      final parsed = DiscountSettingResponse.fromJson(response.data);
      final discountSettings = parsed.data ?? [];

      // Identify pending items to preserve
      final pendingKeys = <dynamic>{};
      for (final key in box.keys) {
        final value = box.get(key);
        if (value is Map && value['_meta']?['syncStatus'] == 'pending') {
          pendingKeys.add(key);
        }
      }

      // Collect keys to remove (items not in server response and not pending)
      final serverIds = discountSettings.map((e) => e.id).toSet();
      final keysToRemove = <dynamic>[];

      for (final key in box.keys) {
        if (!pendingKeys.contains(key) && !serverIds.contains(key)) {
          keysToRemove.add(key);
        }
      }

      // Remove obsolete items
      if (keysToRemove.isNotEmpty) {
        await box.deleteAll(keysToRemove);
      }

      // Update/Add server items
      for (final e in discountSettings) {
        if (e.id != null) {
          await box.put(e.id, e.toJson());
        }
      }

      _progressSink.add(SyncProgress(
          phase: 'pull',
          entity: 'discountSettings',
          processed: discountSettings.length,
          total: discountSettings.length,
          errors: const []));

      return true;
    } catch (e, stackTrace) {
      debugPrint("Error pulling discount settings: $e");
      AppHelpers.recordSyncErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'DiscountSettingSyncHandler.pullDiscountSettings',
      );
      _progressSink.add(SyncProgress(
          phase: 'pull',
          entity: 'discountSettings',
          processed: 0,
          total: 0,
          errors: [e.toString()]));
      return false;
    }
  }
}
