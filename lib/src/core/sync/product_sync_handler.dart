import 'dart:async';
import 'package:admin_desktop/src/core/handlers/handlers.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../models/models.dart';
import '../db/hive_service.dart';
import '../constants/hive_boxes.dart';
import '../constants/constants.dart';
import '../utils/utils.dart';
import 'sync_models.dart';

/// Handler for product synchronization tasks.
class ProductSyncHandler {
  final HttpService _httpService;
  final StreamSink<SyncProgress> _progressSink;

  ProductSyncHandler({
    required HttpService httpService,
    required StreamSink<SyncProgress> progressSink,
  })  : _httpService = httpService,
        _progressSink = progressSink;

  /// Gets a Dio client with appropriate authentication.
  Dio _getClient({required bool requireAuth}) {
    return _httpService.client(requireAuth: requireAuth);
  }

  /// Pulls products data from the server and updates local Hive storage.
  Future<bool> pullProducts() async {
    try {
      final box = await HiveService.openBox(HiveBoxes.products);
      await box.clear();
      // Non-paginated endpoint now returns all products under `data`
      final data = {
        'lang': LocalStorage.getLanguage()?.locale ?? 'en',
        "status": "published",
        "addon_status": "published",
        if (LocalStorage.getUser()?.role == TrKeys.waiter ||
            LocalStorage.getUser()?.role == TrKeys.admin)
          'shop_id': (LocalStorage.getUser()?.role == TrKeys.waiter)
              ? LocalStorage.getUser()?.invite?.shopId
              : LocalStorage.getUser()?.shop?.id,
      };
      final client = _getClient(requireAuth: true);
      final response = await client.get(
        LocalStorage.getUser()?.role == TrKeys.waiter
            ? '/api/v1/rest/products/all'
            : '/api/v1/dashboard/${LocalStorage.getUser()?.role}/products/all',
        queryParameters: data,
      );
      final parsed = ProductsPaginateResponse.fromJson(response.data);
      final items = parsed.data ?? [];
      int processed = 0;

      // We'll collect unique pricing tiers from products to populate the pricingTiers box
      // Using lowercase title as key to prevent duplicates with the same name (e.g. "Member" and "member")
      final Map<String, Map<String, dynamic>> collectedTiers = {};

      for (final e in items) {
        final key = e.id ?? e.uuid ?? '$processed';
        final productJson = e.toJson();
        await box.put(key, productJson);

        // Collect pricing tiers if present
        if (e.productPricingTiers != null) {
          for (final tier in e.productPricingTiers!) {
            final tierTitle = tier.title?.trim();
            if (tierTitle != null && tierTitle.isNotEmpty) {
              final String lowerTitle = tierTitle.toLowerCase();
              if (!collectedTiers.containsKey(lowerTitle)) {
                collectedTiers[lowerTitle] = {
                  'id': tier.id,
                  'pricing_tier_name': tierTitle,
                  'price': tier.price,
                };
              }
            }
          }
        }

        // Precache image
        if (e.img != null && e.img!.isNotEmpty) {
          try {
            // Fire and forget - don't await to avoid slowing down sync
            DefaultCacheManager().downloadFile(e.img!);
          } catch (err, stackTrace) {
            debugPrint('Failed to precache image for product ${e.id}: $err');
            AppHelpers.recordSyncErrorToCrashlytics(
              error: err,
              stackTrace: stackTrace,
              context: 'ProductSyncHandler.pullProducts.precacheImage',
            );
          }
        }
        processed++;
      }

      // Populate pricingTiers box from collected tiers
      final tbox = await HiveService.openBox(HiveBoxes.pricingTiers);
      await tbox.clear();
      if (collectedTiers.isNotEmpty) {
        for (final tierMap in collectedTiers.values) {
          // Use ID as key in Hive for efficient lookup, but uniqueness was handled by title above
          await tbox.put(tierMap['id'], tierMap);
        }
      }

      _progressSink.add(SyncProgress(
          phase: 'pull',
          entity: 'products',
          processed: processed,
          total: processed,
          errors: const []));

    } catch (e, stackTrace) {
      AppHelpers.recordSyncErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'ProductSyncHandler.pullProducts',
      );
      _progressSink.add(SyncProgress(
          phase: 'pull',
          entity: 'products',
          processed: 0,
          total: 0,
          errors: [e.toString()]));
      return false;
    }

    return true;
  }
}
