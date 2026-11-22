import 'package:moneko/core/local_data/moneko_database.dart';
import 'package:uuid/uuid.dart';

enum ResetStatus { prepared, pending, completed, failed }

class ResetJob {
  const ResetJob(this.id, this.status, [this.message]);

  final String id;
  final ResetStatus status;
  final String? message;

  factory ResetJob.parse(Object? value, {bool local = false}) {
    if (value case {'id': final String id, 'status': final String status}
        when Uuid.isValidUUID(fromString: id)) {
      final state = ResetStatus.values.byName(status);
      if (local || state != ResetStatus.prepared) {
        return ResetJob(id, state, (value as Map)['message'] as String?);
      }
    }
    throw const FormatException('Invalid financial reset job');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'status': status.name,
        if (message != null) 'message': message,
      };
}

class FinancialReset {
  FinancialReset({
    required this.rpc,
    required this.database,
    this.timeout = const Duration(seconds: 10),
  });

  final Future<Object?> Function(String, Map<String, dynamic>) rpc;
  final Future<MonekoDatabase> Function() database;
  final Duration timeout;
  final _busy = <String>{};

  Future<ResetJob?> saved(String userId) async {
    final raw = (await database().timeout(timeout)).resetJob(userId);
    return raw == null ? null : ResetJob.parse(raw, local: true);
  }

  Future<void> prepare(String userId, bool Function() isCurrent) async {
    final db = await database().timeout(timeout);
    if (!isCurrent() || userId.isEmpty || db.activeResetOwner != null) {
      throw StateError('Reset unavailable');
    }
    db.saveResetJob(
        userId, ResetJob(const Uuid().v4(), ResetStatus.prepared).toJson());
  }

  Future<ResetJob?> run({
    required String userId,
    required bool Function() isCurrent,
    required Future<void> Function(void Function() guard) cleanup,
  }) async {
    if (userId.isEmpty || !_busy.add(userId)) {
      throw StateError('Reset unavailable');
    }
    var active = true;
    void guard() {
      if (!active || !isCurrent()) throw StateError('Reset interrupted');
    }

    late MonekoDatabase db;
    Future<ResetJob?> fetch(String id, {bool enqueue = false}) async {
      guard();
      final raw = await rpc(
        enqueue ? 'request_financial_data_reset' : 'get_financial_data_reset',
        {'p_request_id': id, 'p_expected_user_id': userId},
      ).timeout(timeout);
      if (!enqueue && raw == null) return null;
      final reply = ResetJob.parse(raw);
      if (!enqueue && reply.id != id) {
        throw const FormatException('Wrong reset ID');
      }
      // Even if Settings closed, record the authoritative ID/status for its
      // original owner before attempting any more RPCs or device cleanup.
      db.saveResetJob(userId, reply.toJson());
      return reply;
    }

    try {
      db = await database().timeout(timeout);
      guard();
      final raw = db.resetJob(userId);
      if (raw == null) return null;
      var job = ResetJob.parse(raw, local: true);
      if (job.status == ResetStatus.failed) return job;
      await db.waitForOutboxIdle().timeout(timeout);
      guard();
      if (job.status == ResetStatus.prepared) {
        // The app may have stopped on either side of the initial dispatch.
        job = await fetch(job.id) ?? (await fetch(job.id, enqueue: true))!;
      } else if (job.status == ResetStatus.pending) {
        job = await fetch(job.id) ??
            (throw StateError('Reset status unavailable'));
      }
      guard();
      if (job.status == ResetStatus.completed) {
        await cleanup(guard);
        guard();
        db.removeResetJob(userId);
      }
      return job;
    } finally {
      active = false;
      _busy.remove(userId);
    }
  }
}
