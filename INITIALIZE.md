# Moneko Mobile Initialize Notes

This file captures the verified app data-flow for future AI agents. Keep it factual and update it when local-first, sync, or provider flows change.

## Core Architecture

- Flutter app entrypoint: `lib/main.dart` with Riverpod providers.
- Local-first data layer: `lib/core/local_data/moneko_database.dart`.
- Local database stores cached transactions, optimistic transaction rows, monthly summaries, and mutation outbox rows.
- Outbox dispatcher: `lib/core/sync/mobile_outbox_sync_provider.dart`.
- Main shell sync orchestration: `lib/core/navigation/main_shell.dart`.
- Remote backend: Supabase Edge Functions, RPCs, and tables through feature repositories/providers.

## Transaction Write Flow

- AI transaction entrypoint: `lib/features/home/presentation/widgets/home_ai_fab.dart`.
- `_persistAiTransactions` writes each parsed transaction to SQLite first with `writeOptimisticTransaction`.
- Local optimistic transactions use `sync_status = local` and enqueue an outbox mutation with the target function and request body.
- Receipt upload failures no longer prevent transaction queueing; the transaction is persisted without a receipt image if upload fails.
- After local write, `_persistAiTransactions` bumps `transactionsFeedRefreshSignalProvider` and `dashboardRefreshSignalProvider`, then invalidates `pocketsProvider`.
- If the backend succeeds, the optimistic local row is replaced with the saved server row and marked synced.
- If the backend fails with a retryable/offline error, the local row and outbox mutation remain queued for background retry.
- If the backend fails with a non-retryable error, the optimistic row is rolled back.

## Sync And Reconciliation

- `mobile_outbox_sync_provider.dart` drains queued mutations and dispatches transaction, wallet, pockets, recurring, and household mutations.
- Synced transaction mutations require a saved transaction payload before local optimistic rows are marked synced.
- Synced transaction mutations reconcile optimistic IDs with server IDs and update local rows to `sync_status = synced`.
- Remote delta pulls preserve `sync_status = local` transaction rows and do not delete pending local rows.
- `SyncCoordinator` retries failed mutations with backoff, eventually cancels poison mutations, and continues draining later queued mutations.
- `MainShell` triggers silent resync on auth/session readiness, app resume, and tab switches.
- Silent resync drains the outbox, pulls mobile deltas, and refreshes active/deferred tab data without blocking cached UI.
- Main shell delta pulls bump transaction/dashboard refresh signals when remote changes are applied.

## Home Propagation

- Home dashboard widgets watch `dashboardCalendarTransactionsProvider`, `dashboardRecentTransactionsProvider`, and `dashboardLocalOverlayTransactionsProvider`.
- Dashboard providers read via `transactionsFeedServiceProvider`, which is local-first when SQLite is available.
- Personal dashboard overlays also merge optimistic analytics/provider state so newly queued transactions render immediately.
- Dashboard caches are invalidated by `dashboardRefreshSignalProvider` and explicit cache invalidation providers.
- Transaction deletes from `unified_transaction_sheet.dart` route through `TransactionEditNotifier.deleteExpensesOptimistically` instead of calling Supabase directly.

## Household Propagation

- Household home content uses the same dashboard provider family with a household-scoped `DashboardScopeQuery`.
- Household cards in `household_dashboard_lazy_widgets.dart` merge `dashboardLocalOverlayTransactionsProvider` into calendar/recent base data.
- Household split-aware widgets also watch `householdSplitsProvider` and optimistic split providers.
- AI saves call `attachOptimisticSplitsForSavedExpenses` after server success so split-aware household cards update when split rows are available.
- Household provider caches use persisted stale-while-revalidate behavior and should not self-invalidate from inside their own provider body.

## Pockets Propagation

- `PocketsPage` watches `pocketsProvider(currentScopeParams)`.
- `pockets_providers.dart` registers global listeners for `transactionsFeedRefreshSignalProvider` and `dashboardRefreshSignalProvider`.
- On transaction/dashboard refresh, pockets in-memory and persisted caches are invalidated or bypassed for the active user.
- Pockets month state is then recomputed from backend/RPC data plus local-first transaction state and recurring projections.
- Pockets budget/envelope saves are optimistically persisted and queued through the local outbox with `save_pockets_month`.
- Pockets save enqueue failures now fail visibly instead of pretending changes were durably queued.

## Wallets Propagation

- `WalletsPage` reads `walletsPageStateProvider`, `walletsHistoryProvider`, and `walletsMonthSnapshotProvider` through wallet lazy providers.
- Wallet page state now bypasses stale session/persisted page caches after wallet, dashboard, or transaction refresh signals.
- Successful wallet RPC responses are overlaid with local `sync_status = local` transaction rows before being returned.
- Pending local wallet rows update month income/spend totals, net worth, and matching wallet balances by transaction `account_id`/`walletId` when possible.
- If a pending transaction lacks `account_id`/`walletId` and there is exactly one wallet balance in the snapshot, it is applied to that wallet; otherwise only aggregate net worth/totals are adjusted.
- Wallet mutations themselves are queued through the outbox with `invoke_function` and persisted optimistic wallet cache entries.
- Wallet enqueue failures now fail visibly instead of pretending changes were durably queued.

## Cache Rules

- Prefer local SQLite and provider/session caches for immediate rendering.
- Use stale-while-revalidate instead of clearing visible UI during refresh.
- Bump refresh signals after local writes so mounted tabs update through Riverpod.
- When adding a cache, define the invalidation signal it listens to before shipping it.
- Do not return persisted caches after a local mutation if they can hide a queued local row.

## Future-Agent Checklist

- For new transaction-affecting features, write to SQLite and outbox before calling Supabase.
- Bump `transactionsFeedRefreshSignalProvider` and `dashboardRefreshSignalProvider` after local writes.
- Invalidate or bypass feature caches that derive from transactions.
- Keep UI widgets reading providers; do not call Supabase directly from widgets.
- Do not add a remote-only dashboard, pockets, or wallet summary path unless it overlays pending local rows.
- Run `dart format` on touched Dart files and `flutter analyze` before claiming completion.
