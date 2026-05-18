class SyncStatus {
  final bool running;
  final bool completed;
  final List<String> errors;

  SyncStatus({
    required this.running,
    required this.completed,
    required this.errors,
  });
}

class SyncProgress {
  final String phase;
  final String entity;
  final int processed;
  final int total;
  final List<String> errors;

  SyncProgress({
    required this.phase,
    required this.entity,
    required this.processed,
    required this.total,
    required this.errors,
  });
}
