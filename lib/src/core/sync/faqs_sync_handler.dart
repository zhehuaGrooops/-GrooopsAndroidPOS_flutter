import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../db/hive_service.dart';
import '../constants/hive_boxes.dart';
import '../handlers/handlers.dart';
import '../utils/utils.dart';
import 'sync_models.dart';

/// Handler for FAQ synchronization tasks.
class FaqsSyncHandler {
  final HttpService _httpService;
  final StreamSink<SyncProgress> _progressSink;

  FaqsSyncHandler({
    required HttpService httpService,
    required StreamSink<SyncProgress> progressSink,
  })  : _httpService = httpService,
        _progressSink = progressSink;

  /// Gets a Dio client with appropriate authentication.
  Dio _getClient({required bool requireAuth}) {
    return _httpService.client(requireAuth: requireAuth);
  }

  /// Fetches FAQs from the server and saves them to local Hive storage.
  Future<bool> fetchFaqs() async {
    try {
      final client = _getClient(requireAuth: true);
      final response = await client.get('/api/v1/rest/faqs/all');

      final box = await HiveService.openBox(HiveBoxes.faq);
      await box.clear();

      if (response.data is Map && response.data['data'] is List) {
        final List faqs = response.data['data'];
        for (var i = 0; i < faqs.length; i++) {
          final faq = faqs[i];
          if (faq is Map) {
            // Use the FAQ ID as the key, or index if ID is missing
            await box.put(faq['id'] ?? i, faq);
          }
        }

        _progressSink.add(SyncProgress(
            phase: 'pull',
            entity: 'faqs',
            processed: faqs.length,
            total: faqs.length,
            errors: const []));
      }

      return true;
    } catch (e, stackTrace) {
      debugPrint("Error fetching FAQs: $e");
      AppHelpers.recordSyncErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'FaqsSyncHandler.fetchFaqs',
      );
      _progressSink.add(SyncProgress(
          phase: 'pull',
          entity: 'faqs',
          processed: 0,
          total: 0,
          errors: [e.toString()]));
      return false;
    }
  }
}
