import 'dart:async';
import 'package:dio/dio.dart';
import '../constants/hive_boxes.dart';
import '../db/hive_service.dart';
import '../handlers/handlers.dart';
import '../utils/utils.dart';
import 'package:flutter/foundation.dart';
import 'sync_models.dart';

class CashSessionSyncHandler {
  final HttpService httpService;
  final StreamSink<SyncProgress> progressSink;

  CashSessionSyncHandler({
    required this.httpService,
    required this.progressSink,
  });

  Future<bool> pullActiveSession() async {
    try {
      final client = httpService.client(requireAuth: true);
      final role = LocalStorage.getUser()?.role ?? 'seller';

      final response = await client.get(
        '/api/v1/dashboard/$role/cash-sessions/active',
      );

      final dynamic responseData = response.data;
      final data = (responseData is Map) ? responseData['data'] : null;
      if (data != null) {
        final box = await HiveService.openBox(HiveBoxes.cashSessions);

        // We need to map server data to local format if they differ.
        // Assuming they are similar enough or we store raw server data.
        // Key is 'id'.
        final serverId = data['id'];
        final localId =
            data['id']; // We can use server ID as local ID for pulled sessions?
        // Or if we use timestamp as ID for local, we have a mismatch.
        // Strategy: Use server ID if available. When creating local, we use timestamp.
        // If we pull, we use server ID.

        final session = Map<String, dynamic>.from(data);
        session['_meta'] = {
          'server_id': serverId,
          'syncStatus': 'fully_synced',
        };

        // Check if we already have it
        if (!box.containsKey(localId)) {
          await box.put(localId, session);
        } else {
          // Update if needed
          final local = box.get(localId);
          if (local != null) {
            final localMeta = local['_meta'] ?? {};
            if (localMeta['syncStatus'] == 'fully_synced') {
              // Update with latest server data
              await box.put(localId, session);
            }
          }
        }
      }
      return true;
    } catch (e, stackTrace) {
      debugPrint('Error in pullActiveSession: $e');
      // If 404, it means no active session, which is fine.
      if (e is DioException && e.response?.statusCode == 404) {
        return true;
      }
      AppHelpers.recordSyncErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'CashSessionSyncHandler.pullActiveSession',
      );
      return true;
    }
  }

  Future<bool> pushOpenSessions() async {
    try {
      final box = await HiveService.openBox(HiveBoxes.cashSessions);
      final sessions = box.values.toList();
      sessions.sort(
          (a, b) => (a['opened_at'] ?? '').compareTo(b['opened_at'] ?? ''));

      for (final session in sessions) {
        final map = Map<String, dynamic>.from(session as Map);
        final meta = Map<String, dynamic>.from(map['_meta'] ?? {});

        if (meta['syncStatus'] == 'synced' ||
            meta['syncStatus'] == 'fully_synced') {
          continue;
        }

        final client = httpService.client(requireAuth: true);
        final role = LocalStorage.getUser()?.role ?? 'seller';

        int? serverId = meta['server_id'];
        final localId = map['id'];

        if (serverId == null) {
          try {
            debugPrint('Syncing open session: $localId');
            final response = await client.post(
              '/api/v1/dashboard/$role/cash-sessions/open',
              data: {
                'amount': map['opening_balance'],
                'user_id': map['user_id'],
              },
            );

            final dynamic responseData = response.data;
            final data = (responseData is Map) ? responseData['data'] : null;
            serverId = data != null ? data['id'] : null;

            meta['server_id'] = serverId;
            meta['syncStatus'] = 'synced';
            map['_meta'] = meta;

            await box.put(localId, map);

            // Update transactions with new cash_session_id?
            // Ideally we should update transactions here if they rely on cash_session_id.
            // But let's assume OrderSyncHandler handles transactions logic or backend infers it.
            // If backend infers from active session, then we just need to have it OPEN.

            debugPrint('Synced open session: $localId -> $serverId');
          } catch (e, stackTrace) {
            debugPrint('Failed to sync open session: $e');
            AppHelpers.recordSyncErrorToCrashlytics(
              error: e,
              stackTrace: stackTrace,
              context: 'CashSessionSyncHandler.pushOpenSessions.item',
            );
            continue;
          }
        }
      }
      return true;
    } catch (e, stackTrace) {
      debugPrint('Error in pushOpenSessions: $e');
      AppHelpers.recordSyncErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'CashSessionSyncHandler.pushOpenSessions',
      );
      return false;
    }
  }

  Future<bool> pushCloseSessions() async {
    try {
      final box = await HiveService.openBox(HiveBoxes.cashSessions);
      final sessions = box.values.toList();
      sessions.sort(
          (a, b) => (a['opened_at'] ?? '').compareTo(b['opened_at'] ?? ''));

      for (final session in sessions) {
        final map = Map<String, dynamic>.from(session as Map);
        final meta = Map<String, dynamic>.from(map['_meta'] ?? {});

        // We process only if it's open_synced (meaning it was opened on server)
        // OR if it was already on server (server_id exists) and we just need to close it.
        if (meta['syncStatus'] == 'fully_synced') continue;
        if (map['closed_at'] == null) continue; // Not closed locally yet

        final client = httpService.client(requireAuth: true);
        final role = LocalStorage.getUser()?.role ?? 'seller';

        final serverId =
            meta['server_id']; // Should exist if we ran pushOpenSessions
        final localId = map['id'];

        if (serverId != null) {
          try {
            debugPrint('Syncing close session: $serverId');
            await client.post(
              '/api/v1/dashboard/$role/cash-sessions/$serverId/close',
              data: {
                'closed_at': map['closed_at'],
                'transactions_summary': map['transactions_summary'],
              },
            );

            meta['syncStatus'] = 'fully_synced';
            map['_meta'] = meta;
            await box.put(localId, map);
            debugPrint('Synced close session: $serverId');
          } catch (e, stackTrace) {
            debugPrint('Failed to sync close session: $e');
            AppHelpers.recordSyncErrorToCrashlytics(
              error: e,
              stackTrace: stackTrace,
              context: 'CashSessionSyncHandler.pushCloseSessions.item',
            );
          }
        }
      }
      return true;
    } catch (e, stackTrace) {
      debugPrint('Error in pushCloseSessions: $e');
      AppHelpers.recordSyncErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'CashSessionSyncHandler.pushCloseSessions',
      );
      return false;
    }
  }
}
