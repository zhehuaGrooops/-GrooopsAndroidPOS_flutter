import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'sync_service.dart';
import 'sync_models.dart';

final syncProgressProvider = StreamProvider<SyncProgress>((ref) {
  return SyncService().progressStream;
});
