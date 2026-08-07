import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moneko/core/local_data/local_database_provider.dart';
import 'package:moneko/core/utils/user_timezone.dart';
import 'package:moneko/features/households/presentation/providers/household_providers.dart'
    show supabaseClientProvider;
import 'package:moneko/features/recurring/data/recurring_read_repository.dart';
import 'package:moneko/features/recurring/domain/models/recurring_read_models.dart';
import 'package:moneko/features/recurring/domain/models/recurring_transaction.dart';

final recurringReadRefreshSignalProvider = StateProvider<int>((ref) => 0);

enum RecurringSeriesMutationKind { upsert, remove }

@immutable
class RecurringSeriesOptimisticEntry {
  const RecurringSeriesOptimisticEntry({
    required this.mutationId,
    required this.revision,
    required this.kind,
    required this.recurringId,
    required this.sourceHouseholdId,
    required this.transaction,
    this.currentMonthConfirmedAmountDeltaCents,
    this.isCommitted = false,
  });

  final String mutationId;
  final int revision;
  final RecurringSeriesMutationKind kind;
  final String recurringId;
  final String? sourceHouseholdId;
  final RecurringTransaction? transaction;
  final int? currentMonthConfirmedAmountDeltaCents;
  final bool isCommitted;

  RecurringSeriesOptimisticEntry copyWith({
    RecurringTransaction? transaction,
    int? currentMonthConfirmedAmountDeltaCents,
    bool? isCommitted,
  }) {
    return RecurringSeriesOptimisticEntry(
      mutationId: mutationId,
      revision: revision,
      kind: kind,
      recurringId: transaction?.id ?? recurringId,
      sourceHouseholdId: sourceHouseholdId,
      transaction: transaction ?? this.transaction,
      currentMonthConfirmedAmountDeltaCents:
          currentMonthConfirmedAmountDeltaCents ??
              this.currentMonthConfirmedAmountDeltaCents,
      isCommitted: isCommitted ?? this.isCommitted,
    );
  }
}

@immutable
class RecurringSeriesOptimisticHandle {
  const RecurringSeriesOptimisticHandle({
    required this.recurringId,
    required this.revision,
    required this.previous,
  });

  final String recurringId;
  final int revision;
  final RecurringSeriesOptimisticEntry? previous;
}

class RecurringSeriesOptimisticNotifier
    extends StateNotifier<Map<String, RecurringSeriesOptimisticEntry>> {
  RecurringSeriesOptimisticNotifier() : super(const {});

  final Map<String, int> _revisions = {};
  final Map<String, RecurringSeriesOptimisticHandle> _handlesByMutation = {};

  RecurringSeriesOptimisticHandle upsert({
    required String mutationId,
    required RecurringTransaction transaction,
    String? sourceHouseholdId,
    int? currentMonthConfirmedAmountDeltaCents,
  }) {
    return _begin(
      mutationId: mutationId,
      recurringId: transaction.id,
      kind: RecurringSeriesMutationKind.upsert,
      sourceHouseholdId: sourceHouseholdId ?? transaction.householdId,
      transaction: transaction,
      currentMonthConfirmedAmountDeltaCents:
          currentMonthConfirmedAmountDeltaCents,
    );
  }

  RecurringSeriesOptimisticHandle remove({
    required String mutationId,
    required String recurringId,
    required String? householdId,
  }) {
    return _begin(
      mutationId: mutationId,
      recurringId: recurringId,
      kind: RecurringSeriesMutationKind.remove,
      sourceHouseholdId: householdId,
      transaction: null,
    );
  }

  bool rollback(RecurringSeriesOptimisticHandle handle) {
    final current = state[handle.recurringId];
    if (current?.revision != handle.revision) return false;
    final next = Map<String, RecurringSeriesOptimisticEntry>.from(state);
    if (handle.previous == null) {
      next.remove(handle.recurringId);
    } else {
      next[handle.recurringId] = handle.previous!;
    }
    state = next;
    return true;
  }

  bool rollbackMutation(String mutationId) {
    final handle = _handlesByMutation[mutationId];
    return handle == null ? false : rollback(handle);
  }

  void commitMutation(String mutationId) {
    final handle = _handlesByMutation[mutationId];
    if (handle != null) commit(handle);
  }

  void commit(
    RecurringSeriesOptimisticHandle handle, {
    RecurringTransaction? canonicalTransaction,
  }) {
    final current = state[handle.recurringId];
    if (current?.revision != handle.revision) return;
    final next = Map<String, RecurringSeriesOptimisticEntry>.from(state);
    if (canonicalTransaction != null &&
        canonicalTransaction.id != handle.recurringId) {
      next.remove(handle.recurringId);
      final canonicalRevision = (_revisions[canonicalTransaction.id] ?? 0) + 1;
      _revisions[canonicalTransaction.id] = canonicalRevision;
      next[canonicalTransaction.id] = RecurringSeriesOptimisticEntry(
        mutationId: current!.mutationId,
        revision: canonicalRevision,
        kind: RecurringSeriesMutationKind.upsert,
        recurringId: canonicalTransaction.id,
        sourceHouseholdId: current.sourceHouseholdId,
        transaction: canonicalTransaction,
        currentMonthConfirmedAmountDeltaCents:
            current.currentMonthConfirmedAmountDeltaCents,
        isCommitted: true,
      );
    } else {
      next[handle.recurringId] = current!.copyWith(
        transaction: canonicalTransaction,
        isCommitted: true,
      );
    }
    state = next;
  }

  void reconcile(
    RecurringReadScope scope,
    List<RecurringSeriesSummary> serverItems,
  ) {
    final serverIds = serverItems.map((item) => item.transaction.id).toSet();
    final next = Map<String, RecurringSeriesOptimisticEntry>.from(state);
    var changed = false;
    for (final entry in state.values) {
      if (!entry.isCommitted || !_affectsScope(entry, scope)) continue;
      final isReconciled = entry.kind == RecurringSeriesMutationKind.remove
          ? !serverIds.contains(entry.recurringId)
          : serverIds.contains(entry.recurringId);
      if (isReconciled) {
        next.remove(entry.recurringId);
        changed = true;
      }
    }
    if (changed) state = next;
  }

  List<RecurringSeriesSummary> apply(
    RecurringReadScope scope,
    List<RecurringSeriesSummary> base,
  ) {
    final byId = <String, RecurringSeriesSummary>{
      for (final item in base) item.transaction.id: item,
    };
    for (final entry in state.values) {
      if (!_affectsScope(entry, scope)) continue;
      final transaction = entry.transaction;
      final previous = transaction == null ? null : byId[transaction.id];
      if (entry.sourceHouseholdId == scope.householdId) {
        byId.remove(entry.recurringId);
      }
      if (entry.kind == RecurringSeriesMutationKind.upsert &&
          transaction != null &&
          transaction.householdId == scope.householdId &&
          scope.normalizedCurrencies.contains(
            transaction.currency.trim().toUpperCase(),
          )) {
        byId[transaction.id] = RecurringSeriesSummary(
          transaction: transaction,
          nextOccurrenceDate: transaction.serverNextOccurrenceDate ??
              previous?.nextOccurrenceDate ??
              transaction.getNextOccurrence(DateTime.now()),
          latestActionableOccurrenceDate:
              entry.currentMonthConfirmedAmountDeltaCents == null
                  ? transaction.serverLatestActionableOccurrenceDate
                  : transaction.serverLatestActionableOccurrenceDate ??
                      previous?.latestActionableOccurrenceDate,
          actionableCount: previous?.actionableCount ?? 0,
          currentMonthConfirmedAmountDeltaCents:
              (previous?.currentMonthConfirmedAmountDeltaCents ?? 0) +
                  (entry.currentMonthConfirmedAmountDeltaCents ?? 0),
        );
      }
    }
    return byId.values.toList(growable: false);
  }

  RecurringSeriesOptimisticHandle _begin({
    required String mutationId,
    required String recurringId,
    required RecurringSeriesMutationKind kind,
    required String? sourceHouseholdId,
    required RecurringTransaction? transaction,
    int? currentMonthConfirmedAmountDeltaCents,
  }) {
    final revision = (_revisions[recurringId] ?? 0) + 1;
    _revisions[recurringId] = revision;
    final previous = state[recurringId];
    state = {
      ...state,
      recurringId: RecurringSeriesOptimisticEntry(
        mutationId: mutationId,
        revision: revision,
        kind: kind,
        recurringId: recurringId,
        sourceHouseholdId: sourceHouseholdId,
        transaction: transaction,
        currentMonthConfirmedAmountDeltaCents:
            currentMonthConfirmedAmountDeltaCents,
      ),
    };
    final handle = RecurringSeriesOptimisticHandle(
      recurringId: recurringId,
      revision: revision,
      previous: previous,
    );
    _handlesByMutation[mutationId] = handle;
    return handle;
  }

  bool _affectsScope(
    RecurringSeriesOptimisticEntry entry,
    RecurringReadScope scope,
  ) {
    return entry.sourceHouseholdId == scope.householdId ||
        entry.transaction?.householdId == scope.householdId;
  }
}

final recurringSeriesOptimisticProvider = StateNotifierProvider<
    RecurringSeriesOptimisticNotifier,
    Map<String, RecurringSeriesOptimisticEntry>>(
  (ref) => RecurringSeriesOptimisticNotifier(),
);

@immutable
class RecurringOccurrenceOptimisticEntry {
  const RecurringOccurrenceOptimisticEntry({
    required this.mutationId,
    required this.revision,
    required this.recurringId,
    required this.scheduledOccurrenceDate,
    required this.occurrence,
    this.isCommitted = false,
  });

  final String mutationId;
  final int revision;
  final String recurringId;
  final DateTime scheduledOccurrenceDate;
  final RecurringOccurrenceSummary? occurrence;
  final bool isCommitted;

  String get key =>
      '$recurringId|${formatDateOnlyYmd(scheduledOccurrenceDate)}';

  RecurringOccurrenceOptimisticEntry copyWith({bool? isCommitted}) {
    return RecurringOccurrenceOptimisticEntry(
      mutationId: mutationId,
      revision: revision,
      recurringId: recurringId,
      scheduledOccurrenceDate: scheduledOccurrenceDate,
      occurrence: occurrence,
      isCommitted: isCommitted ?? this.isCommitted,
    );
  }
}

@immutable
class RecurringOccurrenceOptimisticHandle {
  const RecurringOccurrenceOptimisticHandle({
    required this.key,
    required this.revision,
    required this.previous,
  });

  final String key;
  final int revision;
  final RecurringOccurrenceOptimisticEntry? previous;
}

class RecurringOccurrenceOptimisticNotifier
    extends StateNotifier<Map<String, RecurringOccurrenceOptimisticEntry>> {
  RecurringOccurrenceOptimisticNotifier() : super(const {});

  final Map<String, int> _revisions = {};
  final Map<String, RecurringOccurrenceOptimisticHandle> _handlesByMutation =
      {};

  RecurringOccurrenceOptimisticHandle upsert({
    required String mutationId,
    required RecurringOccurrenceSummary occurrence,
  }) {
    return _begin(
      mutationId: mutationId,
      recurringId: occurrence.recurringId,
      scheduledOccurrenceDate: occurrence.scheduledOccurrenceDate,
      occurrence: occurrence,
    );
  }

  RecurringOccurrenceOptimisticHandle remove({
    required String mutationId,
    required String recurringId,
    required DateTime scheduledOccurrenceDate,
  }) {
    return _begin(
      mutationId: mutationId,
      recurringId: recurringId,
      scheduledOccurrenceDate: scheduledOccurrenceDate,
      occurrence: null,
    );
  }

  bool rollback(RecurringOccurrenceOptimisticHandle handle) {
    final current = state[handle.key];
    if (current?.revision != handle.revision) return false;
    final next = Map<String, RecurringOccurrenceOptimisticEntry>.from(state);
    if (handle.previous == null) {
      next.remove(handle.key);
    } else {
      next[handle.key] = handle.previous!;
    }
    state = next;
    return true;
  }

  bool rollbackMutation(String mutationId) {
    final handle = _handlesByMutation[mutationId];
    return handle == null ? false : rollback(handle);
  }

  void commitMutation(String mutationId) {
    final handle = _handlesByMutation[mutationId];
    if (handle != null) commit(handle);
  }

  void commit(RecurringOccurrenceOptimisticHandle handle) {
    final current = state[handle.key];
    if (current?.revision != handle.revision) return;
    state = {
      ...state,
      handle.key: current!.copyWith(isCommitted: true),
    };
  }

  void reconcile(
    String recurringId,
    List<RecurringOccurrenceSummary> serverItems,
  ) {
    final serverByDate = <String, RecurringOccurrenceSummary>{
      for (final item in serverItems)
        formatDateOnlyYmd(item.scheduledOccurrenceDate): item,
    };
    final next = Map<String, RecurringOccurrenceOptimisticEntry>.from(state);
    var changed = false;
    for (final entry in state.values) {
      if (!entry.isCommitted || entry.recurringId != recurringId) continue;
      final server =
          serverByDate[formatDateOnlyYmd(entry.scheduledOccurrenceDate)];
      final isReconciled = entry.occurrence == null
          ? server == null || server.status == 'pending'
          : server?.status == entry.occurrence!.status;
      if (isReconciled) {
        next.remove(entry.key);
        changed = true;
      }
    }
    if (changed) state = next;
  }

  List<RecurringOccurrenceSummary> apply(
    String recurringId,
    List<RecurringOccurrenceSummary> base,
  ) {
    final byDate = <String, RecurringOccurrenceSummary>{
      for (final item in base)
        formatDateOnlyYmd(item.scheduledOccurrenceDate): item,
    };
    for (final entry in state.values) {
      if (entry.recurringId != recurringId) continue;
      final dateKey = formatDateOnlyYmd(entry.scheduledOccurrenceDate);
      if (entry.occurrence == null) {
        byDate.remove(dateKey);
      } else {
        byDate[dateKey] = entry.occurrence!;
      }
    }
    return byDate.values.toList(growable: false)
      ..sort((a, b) =>
          b.scheduledOccurrenceDate.compareTo(a.scheduledOccurrenceDate));
  }

  RecurringOccurrenceOptimisticHandle _begin({
    required String mutationId,
    required String recurringId,
    required DateTime scheduledOccurrenceDate,
    required RecurringOccurrenceSummary? occurrence,
  }) {
    final key = '$recurringId|${formatDateOnlyYmd(scheduledOccurrenceDate)}';
    final revision = (_revisions[key] ?? 0) + 1;
    _revisions[key] = revision;
    final previous = state[key];
    state = {
      ...state,
      key: RecurringOccurrenceOptimisticEntry(
        mutationId: mutationId,
        revision: revision,
        recurringId: recurringId,
        scheduledOccurrenceDate: scheduledOccurrenceDate,
        occurrence: occurrence,
      ),
    };
    final handle = RecurringOccurrenceOptimisticHandle(
      key: key,
      revision: revision,
      previous: previous,
    );
    _handlesByMutation[mutationId] = handle;
    return handle;
  }
}

final recurringOccurrenceOptimisticProvider = StateNotifierProvider<
    RecurringOccurrenceOptimisticNotifier,
    Map<String, RecurringOccurrenceOptimisticEntry>>(
  (ref) => RecurringOccurrenceOptimisticNotifier(),
);

final recurringReadRemoteDataSourceProvider =
    Provider<RecurringReadRemoteDataSource>((ref) {
  return SupabaseRecurringReadRemoteDataSource(
    ref.watch(supabaseClientProvider),
  );
});

final recurringReadRepositoryProvider =
    FutureProvider<RecurringReadRepository>((ref) async {
  return RecurringReadRepository(
    database: await ref.watch(localDatabaseProvider.future),
    remote: ref.watch(recurringReadRemoteDataSourceProvider),
  );
});

@immutable
class RecurringSeriesPageQuery {
  const RecurringSeriesPageQuery({
    required this.scope,
    this.pageSize = 50,
  });

  final RecurringReadScope scope;
  final int pageSize;

  @override
  bool operator ==(Object other) =>
      other is RecurringSeriesPageQuery &&
      scope == other.scope &&
      pageSize == other.pageSize;

  @override
  int get hashCode => Object.hash(scope, pageSize);
}

@immutable
class RecurringSeriesListState {
  const RecurringSeriesListState({
    required this.items,
    required this.hasMore,
    required this.nextCursor,
    this.isRefreshing = false,
    this.isLoadingMore = false,
  });

  final List<RecurringSeriesSummary> items;
  final bool hasMore;
  final RecurringSeriesCursor? nextCursor;
  final bool isRefreshing;
  final bool isLoadingMore;

  factory RecurringSeriesListState.fromPage(RecurringSeriesPage page) {
    return RecurringSeriesListState(
      items: page.items,
      hasMore: page.hasMore,
      nextCursor: page.nextCursor,
    );
  }

  RecurringSeriesListState copyWith({
    List<RecurringSeriesSummary>? items,
    bool? hasMore,
    RecurringSeriesCursor? nextCursor,
    bool clearNextCursor = false,
    bool? isRefreshing,
    bool? isLoadingMore,
  }) {
    return RecurringSeriesListState(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: clearNextCursor ? null : nextCursor ?? this.nextCursor,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

final recurringSeriesPageProvider = AsyncNotifierProvider.family<
    RecurringSeriesPageNotifier,
    RecurringSeriesListState,
    RecurringSeriesPageQuery>(RecurringSeriesPageNotifier.new);

class RecurringSeriesPageNotifier extends FamilyAsyncNotifier<
    RecurringSeriesListState, RecurringSeriesPageQuery> {
  late RecurringSeriesPageQuery _query;

  Future<RecurringReadRepository> get _repository =>
      ref.read(recurringReadRepositoryProvider.future);

  @override
  Future<RecurringSeriesListState> build(RecurringSeriesPageQuery arg) async {
    _query = arg;
    ref.watch(recurringReadRefreshSignalProvider);
    ref.watch(recurringSeriesOptimisticProvider);
    final repository = await _repository;
    final cached = await repository.readCachedSeriesPage(
      scope: arg.scope,
      limit: arg.pageSize,
    );
    if (cached != null) {
      _scheduleRefresh();
      return _withOptimisticOverlay(cached);
    }
    final page = await repository.fetchSeriesPage(
      scope: arg.scope,
      limit: arg.pageSize,
    );
    ref
        .read(recurringSeriesOptimisticProvider.notifier)
        .reconcile(arg.scope, page.items);
    return _withOptimisticOverlay(page);
  }

  Future<void> refresh() async {
    final previous = state.valueOrNull;
    if (previous != null) {
      state = AsyncData(previous.copyWith(isRefreshing: true));
    }
    try {
      final page = await (await _repository).fetchSeriesPage(
        scope: _query.scope,
        limit: _query.pageSize,
      );
      ref
          .read(recurringSeriesOptimisticProvider.notifier)
          .reconcile(_query.scope, page.items);
      state = AsyncData(_withOptimisticOverlay(page));
    } catch (error, stackTrace) {
      if (previous != null) {
        state = AsyncData(previous.copyWith(isRefreshing: false));
      } else {
        state = AsyncError(error, stackTrace);
      }
    }
  }

  Future<void> loadMore() async {
    final previous = state.valueOrNull;
    if (previous == null ||
        !previous.hasMore ||
        previous.nextCursor == null ||
        previous.isLoadingMore) {
      return;
    }
    state = AsyncData(previous.copyWith(isLoadingMore: true));
    try {
      final page = await (await _repository).fetchSeriesPage(
        scope: _query.scope,
        cursor: previous.nextCursor,
        limit: _query.pageSize,
      );
      final byId = <String, RecurringSeriesSummary>{
        for (final item in previous.items) item.transaction.id: item,
        for (final item in page.items) item.transaction.id: item,
      };
      state = AsyncData(RecurringSeriesListState(
        items: byId.values.toList(growable: false),
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
      ));
    } catch (_) {
      state = AsyncData(previous.copyWith(isLoadingMore: false));
    }
  }

  void _scheduleRefresh() {
    unawaited(Future<void>(() async {
      await refresh();
    }));
  }

  RecurringSeriesListState _withOptimisticOverlay(
    RecurringSeriesPage page,
  ) {
    return RecurringSeriesListState(
      items: ref
          .read(recurringSeriesOptimisticProvider.notifier)
          .apply(_query.scope, page.items),
      hasMore: page.hasMore,
      nextCursor: page.nextCursor,
    );
  }
}

final recurringActionableBadgeProvider = AsyncNotifierProvider.family<
    RecurringActionableBadgeNotifier,
    bool,
    RecurringReadScope>(RecurringActionableBadgeNotifier.new);

class RecurringActionableBadgeNotifier
    extends FamilyAsyncNotifier<bool, RecurringReadScope> {
  late RecurringReadScope _scope;

  Future<RecurringReadRepository> get _repository =>
      ref.read(recurringReadRepositoryProvider.future);

  @override
  Future<bool> build(RecurringReadScope arg) async {
    _scope = arg;
    ref.watch(recurringReadRefreshSignalProvider);
    ref.watch(recurringSeriesOptimisticProvider);
    final repository = await _repository;
    final cached = await repository.readCachedBadge(arg);
    if (cached != null) {
      _scheduleRefresh();
      return _withOptimisticSeries(cached, repository);
    }
    final fetched = await repository.fetchBadge(arg);
    return _withOptimisticSeries(fetched, repository);
  }

  Future<void> refresh() async {
    final previous = state.valueOrNull;
    try {
      final repository = await _repository;
      final fetched = await repository.fetchBadge(_scope);
      state = AsyncData(await _withOptimisticSeries(fetched, repository));
    } catch (error, stackTrace) {
      state = previous == null
          ? AsyncError(error, stackTrace)
          : AsyncData(previous);
    }
  }

  void _scheduleRefresh() {
    unawaited(Future<void>(() async {
      await refresh();
    }));
  }

  Future<bool> _withOptimisticSeries(
    bool fallback,
    RecurringReadRepository repository,
  ) async {
    final cachedPage = await repository.readCachedSeriesPage(scope: _scope);
    if (cachedPage == null || cachedPage.hasMore) return fallback;
    final overlaid = ref
        .read(recurringSeriesOptimisticProvider.notifier)
        .apply(_scope, cachedPage.items);
    return overlaid.any((summary) => summary.hasActionableOccurrence);
  }
}

@immutable
class RecurringSeriesDetailQuery {
  const RecurringSeriesDetailQuery({
    required this.userId,
    required this.recurringId,
  });

  final String userId;
  final String recurringId;

  @override
  bool operator ==(Object other) =>
      other is RecurringSeriesDetailQuery &&
      userId == other.userId &&
      recurringId == other.recurringId;

  @override
  int get hashCode => Object.hash(userId, recurringId);
}

final recurringSeriesDetailProvider = AsyncNotifierProvider.family<
    RecurringSeriesDetailNotifier,
    RecurringTransaction,
    RecurringSeriesDetailQuery>(RecurringSeriesDetailNotifier.new);

class RecurringSeriesDetailNotifier extends FamilyAsyncNotifier<
    RecurringTransaction, RecurringSeriesDetailQuery> {
  late RecurringSeriesDetailQuery _query;

  Future<RecurringReadRepository> get _repository =>
      ref.read(recurringReadRepositoryProvider.future);

  @override
  Future<RecurringTransaction> build(RecurringSeriesDetailQuery arg) async {
    _query = arg;
    ref.watch(recurringReadRefreshSignalProvider);
    final repository = await _repository;
    final cached = await repository.readCachedSeriesDetail(
      userId: arg.userId,
      recurringId: arg.recurringId,
    );
    if (cached != null) {
      _scheduleRefresh();
      return cached;
    }
    return repository.fetchSeriesDetail(
      userId: arg.userId,
      recurringId: arg.recurringId,
    );
  }

  Future<void> refresh() async {
    final previous = state.valueOrNull;
    try {
      state = AsyncData(await (await _repository).fetchSeriesDetail(
        userId: _query.userId,
        recurringId: _query.recurringId,
      ));
    } catch (error, stackTrace) {
      state = previous == null
          ? AsyncError(error, stackTrace)
          : AsyncData(previous);
    }
  }

  void _scheduleRefresh() {
    unawaited(Future<void>(() async => refresh()));
  }
}

@immutable
class RecurringOccurrenceHistoryQuery {
  const RecurringOccurrenceHistoryQuery({
    required this.userId,
    required this.recurringId,
    this.pageSize = 30,
  });

  final String userId;
  final String recurringId;
  final int pageSize;

  @override
  bool operator ==(Object other) =>
      other is RecurringOccurrenceHistoryQuery &&
      userId == other.userId &&
      recurringId == other.recurringId &&
      pageSize == other.pageSize;

  @override
  int get hashCode => Object.hash(userId, recurringId, pageSize);
}

@immutable
class RecurringOccurrenceHistoryState {
  const RecurringOccurrenceHistoryState({
    required this.items,
    required this.hasMore,
    required this.nextCursor,
    this.isRefreshing = false,
    this.isLoadingMore = false,
  });

  final List<RecurringOccurrenceSummary> items;
  final bool hasMore;
  final DateTime? nextCursor;
  final bool isRefreshing;
  final bool isLoadingMore;

  factory RecurringOccurrenceHistoryState.fromPage(
    RecurringOccurrencePage page,
  ) {
    return RecurringOccurrenceHistoryState(
      items: page.items,
      hasMore: page.hasMore,
      nextCursor: page.nextCursor,
    );
  }

  RecurringOccurrenceHistoryState copyWith({
    List<RecurringOccurrenceSummary>? items,
    bool? hasMore,
    DateTime? nextCursor,
    bool clearNextCursor = false,
    bool? isRefreshing,
    bool? isLoadingMore,
  }) {
    return RecurringOccurrenceHistoryState(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: clearNextCursor ? null : nextCursor ?? this.nextCursor,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

final recurringOccurrenceHistoryProvider = AsyncNotifierProvider.family<
    RecurringOccurrenceHistoryNotifier,
    RecurringOccurrenceHistoryState,
    RecurringOccurrenceHistoryQuery>(RecurringOccurrenceHistoryNotifier.new);

class RecurringOccurrenceHistoryNotifier extends FamilyAsyncNotifier<
    RecurringOccurrenceHistoryState, RecurringOccurrenceHistoryQuery> {
  late RecurringOccurrenceHistoryQuery _query;

  Future<RecurringReadRepository> get _repository =>
      ref.read(recurringReadRepositoryProvider.future);

  @override
  Future<RecurringOccurrenceHistoryState> build(
    RecurringOccurrenceHistoryQuery arg,
  ) async {
    _query = arg;
    ref.watch(recurringReadRefreshSignalProvider);
    ref.watch(recurringOccurrenceOptimisticProvider);
    final repository = await _repository;
    final cached = await repository.readCachedOccurrencePage(
      userId: arg.userId,
      recurringId: arg.recurringId,
      limit: arg.pageSize,
    );
    if (cached != null) {
      _scheduleRefresh();
      return _withOptimisticOverlay(cached);
    }
    final page = await repository.fetchOccurrencePage(
      userId: arg.userId,
      recurringId: arg.recurringId,
      limit: arg.pageSize,
    );
    ref
        .read(recurringOccurrenceOptimisticProvider.notifier)
        .reconcile(arg.recurringId, page.items);
    return _withOptimisticOverlay(page);
  }

  Future<void> refresh() async {
    final previous = state.valueOrNull;
    if (previous != null) {
      state = AsyncData(previous.copyWith(isRefreshing: true));
    }
    try {
      final page = await (await _repository).fetchOccurrencePage(
        userId: _query.userId,
        recurringId: _query.recurringId,
        limit: _query.pageSize,
      );
      ref
          .read(recurringOccurrenceOptimisticProvider.notifier)
          .reconcile(_query.recurringId, page.items);
      state = AsyncData(_withOptimisticOverlay(page));
    } catch (error, stackTrace) {
      state = previous == null
          ? AsyncError(error, stackTrace)
          : AsyncData(previous.copyWith(isRefreshing: false));
    }
  }

  Future<void> loadMore() async {
    final previous = state.valueOrNull;
    if (previous == null ||
        !previous.hasMore ||
        previous.nextCursor == null ||
        previous.isLoadingMore) {
      return;
    }
    state = AsyncData(previous.copyWith(isLoadingMore: true));
    try {
      final page = await (await _repository).fetchOccurrencePage(
        userId: _query.userId,
        recurringId: _query.recurringId,
        beforeScheduledDate: previous.nextCursor,
        limit: _query.pageSize,
      );
      final byId = <String, RecurringOccurrenceSummary>{
        for (final item in previous.items) item.id: item,
        for (final item in page.items) item.id: item,
      };
      state = AsyncData(RecurringOccurrenceHistoryState(
        items: byId.values.toList(growable: false)
          ..sort((a, b) =>
              b.scheduledOccurrenceDate.compareTo(a.scheduledOccurrenceDate)),
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
      ));
    } catch (_) {
      state = AsyncData(previous.copyWith(isLoadingMore: false));
    }
  }

  void _scheduleRefresh() {
    unawaited(Future<void>(() async => refresh()));
  }

  RecurringOccurrenceHistoryState _withOptimisticOverlay(
    RecurringOccurrencePage page,
  ) {
    return RecurringOccurrenceHistoryState(
      items: ref
          .read(recurringOccurrenceOptimisticProvider.notifier)
          .apply(_query.recurringId, page.items),
      hasMore: page.hasMore,
      nextCursor: page.nextCursor,
    );
  }
}

@immutable
class RecurringOccurrenceDetailQuery {
  const RecurringOccurrenceDetailQuery({
    required this.userId,
    required this.occurrenceId,
  });

  final String userId;
  final String occurrenceId;

  @override
  bool operator ==(Object other) =>
      other is RecurringOccurrenceDetailQuery &&
      userId == other.userId &&
      occurrenceId == other.occurrenceId;

  @override
  int get hashCode => Object.hash(userId, occurrenceId);
}

final recurringOccurrenceDetailProvider = AsyncNotifierProvider.family<
    RecurringOccurrenceDetailNotifier,
    RecurringOccurrenceDetail,
    RecurringOccurrenceDetailQuery>(RecurringOccurrenceDetailNotifier.new);

class RecurringOccurrenceDetailNotifier extends FamilyAsyncNotifier<
    RecurringOccurrenceDetail, RecurringOccurrenceDetailQuery> {
  late RecurringOccurrenceDetailQuery _query;

  Future<RecurringReadRepository> get _repository =>
      ref.read(recurringReadRepositoryProvider.future);

  @override
  Future<RecurringOccurrenceDetail> build(
    RecurringOccurrenceDetailQuery arg,
  ) async {
    _query = arg;
    ref.watch(recurringReadRefreshSignalProvider);
    final repository = await _repository;
    final cached = await repository.readCachedOccurrenceDetail(
      userId: arg.userId,
      occurrenceId: arg.occurrenceId,
    );
    if (cached != null) {
      _scheduleRefresh();
      return cached;
    }
    return repository.fetchOccurrenceDetail(
      userId: arg.userId,
      occurrenceId: arg.occurrenceId,
    );
  }

  Future<void> refresh() async {
    final previous = state.valueOrNull;
    try {
      state = AsyncData(await (await _repository).fetchOccurrenceDetail(
        userId: _query.userId,
        occurrenceId: _query.occurrenceId,
      ));
    } catch (error, stackTrace) {
      state = previous == null
          ? AsyncError(error, stackTrace)
          : AsyncData(previous);
    }
  }

  void _scheduleRefresh() {
    unawaited(Future<void>(() async => refresh()));
  }
}
