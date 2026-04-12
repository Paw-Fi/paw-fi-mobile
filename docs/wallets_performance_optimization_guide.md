# Wallets Performance Optimization Guide

## Goal

Make `lib/features/wallets/presentation/pages/wallets_page.dart` feel instant while preserving all existing wallet calculations and business behavior.

This guide documents the current optimized approach, the invariants that must never be broken, and the rules future agents should follow when tuning wallets performance.

## Non-Negotiable Invariants

These must remain true after any optimization.

1. Wallet math must not change.
2. If the old code showed `$2000`, the optimized code must still show `$2000` for the same scope/month/data.
3. The wallets landing page must continue to use recurring-aware history and recurring-aware month snapshots.
4. User month boundaries must continue to respect the user's timezone.
5. Wallet page performance work must not silently fall back to weaker or different calculations.

## Current Root Cause Summary

Original critical path before optimization:

1. Wait for auth headers.
2. Fetch wallet list.
3. Build wallet page state.
4. Inside page state, fetch history.
5. Then fetch 3 month snapshots.
6. Only then paint useful UI.

Measured result before optimization:

- `first-useful-paint` was roughly `1073ms`.
- `list-wallets` edge function was roughly `1063ms`.
- wallets page state bootstrap was roughly `937ms`.

Primary issues:

1. Too much work on the first-paint path.
2. Serial history then snapshot work.
3. Full-page gating on multiple async dependencies.
4. Cache invalidation too narrow after transaction mutations.

## Current Architecture

### 1. Cache-first rendering

The wallets page now opens from cached data when available.

Sources:

- session cache for wallet list
- persisted cache for wallet list
- session cache for wallets page state
- persisted cache for wallets page state

This produces fast perceived load.

### 2. Stale-while-revalidate

When persisted cache is used:

1. render immediately from cache
2. refresh live data in background
3. update UI when fresh network data arrives

When session cache is used:

1. render immediately from session cache
2. do not automatically re-fetch on every re-entry in the same app session

This avoids paying the same background refresh cost on every tab visit.

### 3. First-paint bootstrap is reduced

The wallets page state no longer waits for 3 snapshots before first render.

Current bootstrap path:

1. fetch recurring-aware history
2. fetch current selected-month snapshot
3. return initial page state with current month only
4. prefetch older visible months after initial state is ready

This keeps the first frame correct while moving non-critical work out of the critical path.

### 4. Wallets page sections render independently

The page no longer blocks the entire screen on all async branches finishing.

Current behavior:

1. overview can render from cached page state
2. wallet stack can render from cached wallet list
3. bank connections remain non-blocking
4. older month snapshots load behind the first visible frame

### 5. Mutation refresh is broad and deliberate

Wallet-affecting mutations must clear wallet caches for the entire user, not only the currently selected household/currency.

This is critical because:

1. a transaction can affect a different wallet scope from the current view
2. persisted caches may exist for multiple household/currency combinations
3. narrow invalidation can leave Wallets stale until restart

## Files That Matter

### Page layer

- `lib/features/wallets/presentation/pages/wallets_page.dart`

Responsibilities:

1. paint useful content as early as possible
2. avoid blocking the whole page on secondary async dependencies
3. keep `WalletsTrace` instrumentation intact unless replacing with equivalent tracing

### Wallet list provider

- `lib/features/wallets/presentation/providers/wallet_providers.dart`

Responsibilities:

1. provide wallet entities for current scope
2. use session cache first
3. use persisted cache second
4. refresh from network safely
5. reject stale in-flight responses if scope changes mid-request
6. react when auth headers become available

### Wallet page state provider

- `lib/features/wallets/presentation/providers/wallets_lazy_providers.dart`

Responsibilities:

1. provide recurring-aware history and month snapshots
2. bootstrap current month only for first paint
3. prefetch older visible months afterward
4. rebuild when wallet/dashboard refresh signals fire
5. bypass persisted cache during invalidation windows

### Cache store

- `lib/features/wallets/presentation/providers/wallets_cache_store.dart`

Responsibilities:

1. session cache storage
2. persisted cache storage
3. user-wide cache clearing
4. persisted-cache bypass flag used during mutation invalidation

### Home shell prewarm

- `lib/core/navigation/main_shell.dart`

Responsibilities:

1. prewarm only cheap/useful wallet data
2. never trigger heavy wallets page-state prewarm from Home unless explicitly intended
3. never prewarm before wallet auth headers are ready

### Mutation sources that must refresh wallets

- `lib/features/home/presentation/widgets/unified_transaction_sheet.dart`
- `lib/features/recurring/presentation/widgets/add_recurring_sheet.dart`
- `lib/features/home/presentation/state/expense_save_providers.dart`
- `lib/features/home/presentation/state/transaction_edit_notifier.dart`

These flows must keep Wallets correct after:

1. new expense
2. new income
3. edit expense
4. delete expense
5. add recurring expense
6. add recurring income
7. edit recurring transaction
8. delete or skip recurring transaction

## Current Refresh Contract

When a wallet-affecting mutation succeeds, the system must do all of the following:

1. invalidate wallet provider families
2. invalidate wallet page state provider family
3. bump wallet refresh signal
4. clear wallet caches for the entire user
5. temporarily bypass persisted wallet caches while invalidation is in flight

If any one of those is removed, stale wallets can reappear.

## Important Safety Rules

### Rule 1: Never change the data source for balances casually

Wallet cards on the page should continue to prefer the selected month snapshot balances for display:

- `walletBalances[wallet.id] ?? wallet.currentBalanceCents`

This matters because snapshot balances and raw entity balances are not interchangeable for all views.

### Rule 2: Never replace user-month logic with `DateTime.now()`

Always anchor wallet history/snapshot queries to the user's effective timezone month.

If this is broken:

1. recurring items can drift across month boundaries
2. wallet landing page can disagree with details/pockets

### Rule 3: Never assume one cache key is enough

Wallet caches can vary by:

1. user
2. household scope
3. selected currency
4. current month anchor

Mutation invalidation must consider all wallet cache variants for the user.

### Rule 4: Never let old async responses overwrite a new scope

Wallet list fetches can race with scope switching.

Always capture a request key before await, then verify the active scope still matches before writing state/cache.

### Rule 5: Do not prewarm expensive wallet history/snapshot work from Home by default

Cheap prewarm can help.

Heavy prewarm can:

1. waste battery/network
2. fetch the wrong household/currency combinations
3. make Home noisy and unexpectedly expensive

## `WalletsTrace` Events To Keep

These traces are useful and should remain unless replaced with an equivalent system.

### Wallets page

- `WalletsPageOpen`
- `first-useful-paint`

### Wallet list

- `ScopedWalletsProvider`
- `WalletsByHousehold`

### Page state

- `WalletsPageStateBuild`
- `WalletsPageRefresh`
- `WalletsHistoryRpc`
- `WalletsMonthSnapshotRpc`
- `WalletsSnapshotPrefetch`

## How To Interpret The Trace

### Healthy optimized open

Good sign:

- `persisted-cache-hit` or `session-cache-hit`
- `first-useful-paint` under `100ms`

This means the user sees real content immediately.

### If wallet list is the only slow thing left

Pattern:

1. page state cache hits immediately
2. wallet list cache misses or background refreshes
3. `WalletsByHousehold` remains around `1s+`

That means UX is already good, but backend freshness sync is still expensive.

### If Home starts showing wallet history/snapshot logs again

That means shell prewarm became too aggressive again.

Fix by reducing or removing prewarm, or limiting it to wallet-list only.

### If Wallets stays stale after mutation

Check:

1. did wallet mutation call `walletActionsProvider.refreshAccountData()`?
2. did generic save/edit providers also trigger wallet refresh?
3. did user-wide wallet cache clearing run?
4. was persisted cache bypass active during invalidation?

## Performance Strategy For Future Agents

When optimizing further, use this order.

### Phase 1: Preserve the instant feel

Do not regress:

1. cache-first first paint
2. section-level rendering
3. non-blocking bank connections
4. deferred older month prefetch

### Phase 2: Reduce backend freshness cost

Primary next target is the wallet list fetch.

Recommended directions:

1. replace `list-wallets` edge function on critical user paths if possible
2. consider a lightweight metadata-only wallet fetch for the page list
3. keep snapshot balances as the source of displayed balance on Wallets page

Important:

If replacing `list-wallets`, do not accidentally change fields relied on by:

1. wallet details
2. transfer sheet
3. archived wallets page
4. wallet card and wallet balance adjustment flows

### Phase 3: Add freshness policy only if safe

Possible future improvement:

1. TTL-based background refresh for persisted cache
2. skip revalidation if cache is very recent

But do this only if mutation invalidation remains stronger than TTL.

## UX Rules

To match premium apps, performance and UX must work together.

### Do

1. show real cached content immediately
2. keep structure stable while refreshing in background
3. prefer partial content over whole-page skeletons
4. keep wallet stack interactive as soon as data is sufficient
5. make pull-to-refresh truly wait for live network refresh

### Do not

1. return to full-page skeleton after cached content exists
2. block wallet list on bank connection loads
3. block first paint on older month snapshots
4. prewarm every possible wallet scope from Home
5. allow persisted cache to win right after a mutation

## Mutation Checklist

Any future save/edit/delete flow that can affect wallets must verify all of the following.

1. wallet caches for the user are cleared
2. wallet refresh signal is bumped
3. wallets page state provider will rebuild
4. current wallet scope will not keep stale session cache
5. returning to Wallets without app restart shows fresh values

## Verification Checklist

Before claiming a wallet performance change is correct, verify:

1. `flutter analyze` passes for changed files
2. wallet provider tests pass
3. open Wallets from a warm cache and confirm `first-useful-paint` stays fast
4. save a new expense from `unified_transaction_sheet.dart` and confirm Wallets updates without restart
5. save a recurring expense/income from `add_recurring_sheet.dart` and confirm Wallets updates without restart
6. switch personal/household scope and confirm no stale wallet list overwrites the new scope

## Known Good Outcome

After the current optimization:

1. wallet page first useful paint dropped from roughly `1073ms` to roughly `73ms`
2. page state loads from cache immediately
3. live history and snapshot refresh happen in background
4. wallet list can still refresh in background, but it no longer blocks first useful paint

This is the current baseline to preserve or improve.

## If You Need To Debug Again

1. capture `WalletsTrace` on Home without opening Wallets
2. capture `WalletsTrace` when opening Wallets
3. capture `WalletsTrace` after saving an expense/income/recurring transaction
4. verify whether the issue is:
   - slow first paint
   - slow background freshness
   - stale cache after mutation
   - over-aggressive prewarm

Then optimize the specific bottleneck, not the whole system blindly.
