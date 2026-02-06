import 'package:isar/isar.dart';

part 'pending_query.g.dart';

/// Status of a pending offline query
enum PendingQueryStatus {
  pending,
  processing,
  completed,
  failed,
}

@collection
class PendingQuery {
  Id id = Isar.autoIncrement;

  late String query;

  late List<String> attachmentPaths;

  late DateTime createdAt;

  @enumerated
  PendingQueryStatus status = PendingQueryStatus.pending;

  /// Error message if failed
  String? errorMessage;

  PendingQuery();

  factory PendingQuery.create({
    required String query,
    List<String>? attachmentPaths,
  }) {
    return PendingQuery()
      ..query = query
      ..attachmentPaths = attachmentPaths ?? []
      ..createdAt = DateTime.now();
  }
}

/// Repository for pending offline queries
class PendingQueryRepository {
  final Isar _isar;

  PendingQueryRepository(this._isar);

  /// Queue a new query for later processing
  Future<int> queue({
    required String query,
    List<String>? attachmentPaths,
  }) async {
    final pending = PendingQuery.create(
      query: query,
      attachmentPaths: attachmentPaths,
    );

    await _isar.writeTxn(() async {
      await _isar.pendingQuerys.put(pending);
    });

    return pending.id;
  }

  /// Get all pending queries
  Future<List<PendingQuery>> getPending() async {
    return await _isar.pendingQuerys
        .filter()
        .statusEqualTo(PendingQueryStatus.pending)
        .sortByCreatedAt()
        .findAll();
  }

  /// Get count of pending queries
  Future<int> getPendingCount() async {
    return await _isar.pendingQuerys
        .filter()
        .statusEqualTo(PendingQueryStatus.pending)
        .count();
  }

  /// Mark query as processing
  Future<void> markProcessing(int id) async {
    await _isar.writeTxn(() async {
      final query = await _isar.pendingQuerys.get(id);
      if (query != null) {
        query.status = PendingQueryStatus.processing;
        await _isar.pendingQuerys.put(query);
      }
    });
  }

  /// Mark query as completed and remove
  Future<void> markCompleted(int id) async {
    await _isar.writeTxn(() async {
      await _isar.pendingQuerys.delete(id);
    });
  }

  /// Mark query as failed
  Future<void> markFailed(int id, String error) async {
    await _isar.writeTxn(() async {
      final query = await _isar.pendingQuerys.get(id);
      if (query != null) {
        query.status = PendingQueryStatus.failed;
        query.errorMessage = error;
        await _isar.pendingQuerys.put(query);
      }
    });
  }

  /// Clear all completed/failed queries
  Future<void> clearProcessed() async {
    await _isar.writeTxn(() async {
      await _isar.pendingQuerys
          .filter()
          .statusEqualTo(PendingQueryStatus.completed)
          .or()
          .statusEqualTo(PendingQueryStatus.failed)
          .deleteAll();
    });
  }
}
