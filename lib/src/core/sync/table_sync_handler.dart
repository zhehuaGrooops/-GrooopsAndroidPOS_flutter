import 'dart:async';

import 'package:admin_desktop/src/core/constants/hive_boxes.dart';
import 'package:admin_desktop/src/core/db/hive_service.dart';
import 'package:admin_desktop/src/core/handlers/handlers.dart';
import 'package:admin_desktop/src/core/utils/utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'sync_models.dart';

class TableSyncHandler {
  final HttpService _httpService;
  final StreamSink<SyncProgress> _progressSink;

  TableSyncHandler({
    required HttpService httpService,
    required StreamSink<SyncProgress> progressSink,
  })  : _httpService = httpService,
        _progressSink = progressSink;

  Dio _getClient({required bool requireAuth}) =>
      _httpService.client(requireAuth: requireAuth);

  /// Pushes all pending table/section mutations to the server.
  Future<bool> pushPendingTables() async {
    try {
      final box = await HiveService.openBox(HiveBoxes.tables);
      final role = LocalStorage.getUser()?.role ?? '';
      final client = _getClient(requireAuth: true);

      final keys = List.from(box.keys);
      int processed = 0;
      final errors = <String>[];

      for (final key in keys) {
        final raw = box.get(key);
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        if (map['_meta']?['syncStatus'] != 'pending') continue;

        final operation = map['_meta']?['operation'] as String?;
        try {
          if (map['type'] == 'table') {
            if (operation == 'create') {
              final body = Map<String, dynamic>.from(map)
                ..remove('_meta')
                ..remove('type');
              final localId = map['id']?.toString() ?? '';
              final res = await client.post(
                '/api/v1/dashboard/$role/tables',
                queryParameters: body,
                options: Options(headers: {'X-Idempotency-Key': localId}),
              );
              final serverId = res.data['data']?['id'];
              await box.delete(key);
              if (serverId != null) {
                final updated = Map<String, dynamic>.from(map);
                updated['id'] = serverId;
                updated['_meta'] = {
                  'syncStatus': 'synced',
                  'updatedAt': DateTime.now().toIso8601String(),
                };
                await box.put('table_$serverId', updated);
              }
            } else if (operation == 'delete') {
              await client.delete(
                '/api/v1/dashboard/$role/tables/delete',
                queryParameters: {'ids[0]': map['id']},
              );
              await box.delete(key);
            } else if (operation == 'update') {
              await client.put(
                '/api/v1/dashboard/$role/tables/${map['id']}',
                data: {
                  if (map['name'] != null) 'name': map['name'],
                  if (map['chair_count'] != null)
                    'chair_count': map['chair_count'],
                  if (map['position_x'] != null)
                    'position_x': map['position_x'],
                  if (map['position_y'] != null)
                    'position_y': map['position_y'],
                },
              );
              map['_meta'] = {
                'syncStatus': 'synced',
                'updatedAt': DateTime.now().toIso8601String(),
              };
              await box.put(key, map);
            }
          } else if (map['type'] == 'section') {
            if (operation == 'create') {
              final body = <String, dynamic>{
                'area': map['area'],
                'images': [],
                'title': {
                  LocalStorage.getLanguage()?.locale ?? 'en':
                      map['translation']?['title'] ?? '',
                },
              };
              final localId = map['id']?.toString() ?? '';
              final res = await client.post(
                '/api/v1/dashboard/$role/shop-sections',
                queryParameters: body,
                options: Options(headers: {'X-Idempotency-Key': localId}),
              );
              final serverId = res.data['data']?['id'];
              await box.delete(key);
              if (serverId != null) {
                final updated = Map<String, dynamic>.from(map);
                updated['id'] = serverId;
                updated['_meta'] = {
                  'syncStatus': 'synced',
                  'updatedAt': DateTime.now().toIso8601String(),
                };
                await box.put('section_$serverId', updated);
              }
            } else if (operation == 'delete') {
              await client.delete(
                '/api/v1/dashboard/$role/shop-sections/delete',
                queryParameters: {'ids[0]': map['id']},
              );
              await box.delete(key);
            } else if (operation == 'update') {
              await client.put(
                '/api/v1/dashboard/$role/shop-sections/${map['id']}',
                data: {
                  'area': map['area'],
                  'title': {
                    LocalStorage.getLanguage()?.locale ?? 'en':
                        map['translation']?['title'] ?? '',
                  },
                },
              );
              map['_meta'] = {
                'syncStatus': 'synced',
                'updatedAt': DateTime.now().toIso8601String(),
              };
              await box.put(key, map);
            } else if (operation == 'update_map_size') {
              await client.patch(
                '/api/v1/dashboard/$role/shop-sections/${map['id']}/map-size',
                data: {
                  'map_width': map['map_width'],
                  'map_height': map['map_height'],
                },
              );
              map['_meta'] = {
                'syncStatus': 'synced',
                'updatedAt': DateTime.now().toIso8601String(),
              };
              await box.put(key, map);
            }
          }
          processed++;
        } catch (e) {
          // Leave as pending — SyncService 2-min timer will retry
          debugPrint('==> TableSyncHandler.$operation failed for $key: $e');
          errors.add('$operation/$key: ${e.toString()}');
        }
      }

      _progressSink.add(SyncProgress(
        phase: 'push',
        entity: 'tables',
        processed: processed,
        total: keys.length,
        errors: errors,
      ));
      return errors.isEmpty;
    } catch (e, stackTrace) {
      AppHelpers.recordSyncErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'TableSyncHandler.pushPendingTables',
      );
      _progressSink.add(SyncProgress(
        phase: 'push',
        entity: 'tables',
        processed: 0,
        total: 0,
        errors: [e.toString()],
      ));
      return false;
    }
  }

  /// Pulls tables and sections from server into Hive, preserving pending local mutations.
  Future<bool> pullTables() async {
    try {
      final client = _getClient(requireAuth: true);
      final role = LocalStorage.getUser()?.role ?? '';
      final lang = LocalStorage.getLanguage()?.locale ?? 'en';
      final box = await HiveService.openBox(HiveBoxes.tables);

      // Pull sections
      final sectionsRes = await client.get(
        '/api/v1/dashboard/$role/shop-sections',
        queryParameters: {'perPage': 100, 'lang': lang},
      );
      final dynamic rawSections = sectionsRes.data['data'];
      final sections = rawSections is List ? rawSections : (rawSections is Map ? rawSections['data'] as List? ?? [] : <dynamic>[]);
      debugPrint('==> pullTables sections raw response: ${sectionsRes.data}');

      // Pull tables
      final tablesRes = await client.get(
        '/api/v1/dashboard/$role/tables',
        queryParameters: {'perPage': 100, 'lang': lang},
      );
      final dynamic rawTables = tablesRes.data['data'];
      final tables = rawTables is List ? rawTables : (rawTables is Map ? rawTables['data'] as List? ?? [] : <dynamic>[]);
      debugPrint('==> pullTables tables raw response: ${tablesRes.data}');
      debugPrint('==> Pulled ${sections.length} sections and ${tables.length} tables from server');
      // Clear all synced entries before writing fresh backend data.
      // Pending entries (offline mutations not yet pushed) are preserved.
      final keysToDelete = box.keys.where((k) {
        final v = box.get(k);
        return v is Map && v['_meta']?['syncStatus'] != 'pending';
      }).toList();
      for (final k in keysToDelete) {
        await box.delete(k);
      }

      for (final s in sections) {
        final map = Map<dynamic, dynamic>.from(s as Map);
        map['type'] = 'section';
        await box.put('section_${map['id']}', map);
      }

      for (final t in tables) {
        final map = Map<dynamic, dynamic>.from(t as Map);
        map['type'] = 'table';
        await box.put('table_${map['id']}', map);
      }

      _progressSink.add(SyncProgress(
        phase: 'pull',
        entity: 'tables',
        processed: sections.length + tables.length,
        total: sections.length + tables.length,
        errors: const [],
      ));
      return true;
    } catch (e, stackTrace) {
      AppHelpers.recordSyncErrorToCrashlytics(
        error: e,
        stackTrace: stackTrace,
        context: 'TableSyncHandler.pullTables',
      );
      _progressSink.add(SyncProgress(
        phase: 'pull',
        entity: 'tables',
        processed: 0,
        total: 0,
        errors: [e.toString()],
      ));
      return false;
    }
  }
}
