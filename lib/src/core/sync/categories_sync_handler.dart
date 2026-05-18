import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../models/models.dart';
import '../constants/constants.dart';
import '../constants/hive_boxes.dart';
import '../db/hive_service.dart';
import '../handlers/handlers.dart';
import '../utils/utils.dart';
import 'sync_models.dart';

/// Handler for Categories synchronization tasks.
class CategoriesSyncHandler {
  final HttpService _httpService;
  final StreamSink<SyncProgress> _progressSink;

  CategoriesSyncHandler({
    required HttpService httpService,
    required StreamSink<SyncProgress> progressSink,
  })  : _httpService = httpService,
        _progressSink = progressSink;

  /// Gets a Dio client with appropriate authentication.
  Dio _getClient({required bool requireAuth}) {
    return _httpService.client(requireAuth: requireAuth);
  }

  /// Pulls categories data from the server and stores it in Hive.
  Future<bool> pullCategories() async {
    try {
      debugPrint("Pulling categories data from server...");

      // Clear the box first or at the end?
      // Usually better to clear before writing new data if we are doing a full sync.
      // But if fetch fails, we lose data.
      // However, other handlers clear it first (PaymentSyncHandler inside success callback).
      // I'll fetch first, then clear and write.

      final List<CategoryData> allCategories = [];
      int page = 1;
      bool hasMore = true;
      int totalItems = 0;
      final int perPage = 100;

      while (hasMore) {
        final result = await fetchCategories(page: page, perPage: perPage);

        // We need to handle the result.
        // Since fetchCategories returns ApiResult, we have to unpack it.
        // But doing this in a loop with functional result type is a bit tricky if we want to break on failure.

        bool success = false;

        await result.when(
          success: (response) async {
            final List<CategoryData> items = response.data ?? [];
            allCategories.addAll(items);

            final meta = response.meta;
            if (meta != null && meta.total != null) {
              totalItems = meta.total!;
              final int totalPages = (totalItems / perPage).ceil();
              if (page >= totalPages) {
                hasMore = false;
              }
            } else {
              // If no meta, assume no more pages if items < perPage
              if (items.length < perPage) {
                hasMore = false;
              }
            }
            success = true;
          },
          failure: (error, statusCode) {
            debugPrint("Failed to fetch categories page $page: $error");
            // Stop fetching on error
            hasMore = false;
            // We might want to throw or return false here to abort the whole sync
            throw Exception(error);
          },
        );

        if (!success) {
          // Error occurred and was caught in failure block (rethrown)
          // Or handle it here if not rethrown
          return false;
        }

        page++;
      }

      // Save to Hive
      final box = await HiveService.openBox(HiveBoxes.categories);
      await box.clear();

      for (final category in allCategories) {
        if (category.id != null) {
          await box.put(category.id, category.toJson());
        }
      }

      reportProgress(
          processed: allCategories.length,
          total: totalItems > 0 ? totalItems : allCategories.length);
      debugPrint(
          "Finished pulling categories data. Processed ${allCategories.length} items.");
      return true;
    } catch (e, stackTrace) {
      debugPrint("Unexpected error during categories sync: $e");
      AppHelpers.recordSyncErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'CategoriesSyncHandler.pullCategories',
      );
      reportProgress(processed: 0, total: 0, errors: [e.toString()]);
      return false;
    }
  }

  /// Fetches categories data from the API.
  Future<ApiResult<CategoriesPaginateResponse>> fetchCategories(
      {required int page, int perPage = 100}) async {
    try {
      final client = _getClient(requireAuth: true);

      final data = {
        'lang': LocalStorage.getLanguage()?.locale ?? 'en',
        'perPage': perPage,
        'page': page,
        'type': 'main',
        "has_products": 1,
        "p_shop_id": LocalStorage.getUser()?.role == TrKeys.waiter
            ? LocalStorage.getUser()?.invite?.shopId ?? 0
            : LocalStorage.getUser()?.shop?.id ?? 0
      };

      final response = await client.get(
        '/api/v1/rest/categories/paginate',
        queryParameters: data,
      );

      return ApiResult.success(
        data: CategoriesPaginateResponse.fromJson(response.data),
      );
    } catch (e, stackTrace) {
      debugPrint('==> get categories failure: $e');
      AppHelpers.recordSyncErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'CategoriesSyncHandler.fetchCategories',
      );
      return ApiResult.failure(error: AppHelpers.errorHandler(e));
    }
  }

  /// Reports progress to the sync stream.
  void reportProgress({
    required int processed,
    required int total,
    List<String> errors = const [],
  }) {
    _progressSink.add(SyncProgress(
      phase: 'pull',
      entity: 'categories',
      processed: processed,
      total: total,
      errors: errors,
    ));
  }
}
