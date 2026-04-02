# Transactions Page Pagination Architecture

## Purpose

This document captures the current architecture and change history for `TransactionsPage` after the performance rework that moved the page away from full-history client-side loading.

It is written as an internal handoff for future engineers and AI agents. The goal is that someone can read only this document and quickly understand:

- why the page was changed
- which files now own which responsibilities
- how mobile and backend cooperate
- what bugs were encountered during rollout
- which assumptions are intentional
- where future changes should be made

## Problem Statement

The original transactions page loaded and processed the full transaction history on the client.

That caused several scaling problems:

- initial screen load got slower as history grew
- filtering, sorting, grouping, and chart aggregation all happened on the UI thread
- the page rebuilt expensive derived data too often
- exporting and deep linking could trigger large data fetches indirectly
- the backend contract effectively forced the frontend to know about the entire history

This was acceptable for small datasets, but not for users with large transaction histories.

## High-Level Solution

The page now uses a split backend contract:

- paginated transaction feed for visible rows
- aggregate summary payload for charts and totals
- single-expense lookup RPC for notification fallback

The frontend keeps a small amount of local derivation for UI-only behavior:

- recurring projections are still generated locally
- month/day grouping is still done locally for the currently loaded page items
- page-local search debounce and selection state remain local to the screen

This gives a more senior, production-style shape:

- backend owns dataset reduction
- frontend owns presentation and local interaction state
- charts are accurate without requiring full-history rows in memory

This pagination architecture is now reused beyond `TransactionsPage`:

- `AccountDetailsPage` now consumes the same feed + summary contract
- `PocketDetailsPage` now consumes paginated feed data for recent transactions

## Files and Responsibilities

### Mobile UI

- `moneko-mobile/lib/features/home/presentation/pages/transactions_page.dart`

  - main transactions screen
  - builds `TransactionsFeedQuery` from current UI filters and account scope
  - reads paginated feed state from Riverpod
  - merges projected recurring entries into locally derived data
  - renders sliver list, charts, filter UI, selection mode, export trigger

- `moneko-mobile/lib/features/home/presentation/widgets/transactions_pie_chart.dart`
  - pie chart widget
  - now supports optional precomputed category summary and total overrides
  - allows backend summary data to drive the chart without needing all rows locally

### Mobile State

- `moneko-mobile/lib/features/home/presentation/state/transactions_feed_provider.dart`

  - page-specific paginated feed state
  - owns feed query model, cursor model, summary model, service abstraction, notifier state
  - calls backend RPCs for summary and page data
  - supports `loadInitial`, `refresh`, `loadMore`, `fetchAllPages`
  - exposes `transactionsFeedRefreshSignalProvider` for external invalidation

- `moneko-mobile/lib/features/home/presentation/utils/transactions_page_derived_data.dart`
  - pure helper layer for client-side derivation
  - filters and groups currently loaded rows plus projected recurring rows
  - creates visible grouped render items for the sliver list

### Mobile Notification Integration

- `moneko-mobile/lib/core/notifications/notification_dispatcher.dart`
  - no longer depends on full analytics payload to find one expense
  - uses `get_user_expense_by_id_v1` as targeted RPC fallback
  - bumps `transactionsFeedRefreshSignalProvider` when a fetched expense is injected into app state

### Backend / Supabase

Important: the SQL for this feature lives in the web repo because that is where Supabase migrations are maintained.

- `moneko-web/supabase/migrations/20260402123000_add_transactions_feed_rpcs.sql`

  - original migration introducing feed/summary/lookup RPCs
  - should be kept correct for clean deploys to new databases

- `moneko-web/supabase/migrations/20260402124500_fix_transactions_feed_type_casts.sql`
  - follow-up migration for already-migrated databases
  - fixes enum-to-text casting bug in SQL

## Backend Contract

### `get_user_transactions_page_v1`

Purpose:

- return only one page of transactions for the current filter set
- return `has_more`
- return `next_cursor`

Used by:

- `TransactionsFeedService.fetchPage`
- `TransactionsFeedNotifier.loadInitial`
- `TransactionsFeedNotifier.loadMore`

Filter inputs:

- `p_user_id`
- `p_household_id`
- `p_currency`
- `p_category`
- `p_account_id` (optional)
- `p_categories` (optional text[] category set)
- `p_type`
- `p_search_query`
- `p_start_date`
- `p_end_date`
- pagination cursor fields

Ordering:

- `date desc`
- `created_at desc`
- `id desc`

### `get_user_transactions_summary_v1`

Purpose:

- return filter-aware totals without loading the full list into Flutter

Summary payload currently includes:

- total transaction count
- total expense amount
- total income amount
- multi-currency flag
- category summaries
- yearly period totals

Used by:

- `TransactionsFeedService.fetchSummary`
- `TransactionsPage` chart rendering
- `AccountDetailsPage` monthly income/spend/net cards (month-scoped query)

Supports the same optional narrowing filters as page RPC:

- `p_account_id`
- `p_categories`

### `get_user_expense_by_id_v1`

Purpose:

- resolve exactly one expense by id for notification/deep-link recovery

Used by:

- `NotificationDispatcher`

This replaces the previous fallback pattern of pulling a full analytics payload just to find a single transaction.

## Transactions Page Data Flow

### 1. Build filter query

`TransactionsPage` derives `TransactionsFeedQuery` from:

- current authenticated user
- active account / household scope
- selected currency
- selected category
- selected type
- debounced search string
- date range filter converted to start/end dates

### 2. Fetch backend state

`transactionsFeedProvider(feedQuery)` loads:

- summary RPC
- first page RPC

The provider state contains:

- `summary`
- `items`
- `hasMore`
- `nextCursor`
- loading and error flags

### 3. Build local derived UI data

`TransactionsPage` sets:

- `_baseExpenses = feedState.items`

Then it locally adds projected recurring rows through:

- `projectRecurringTransactionsAsExpenseEntries(...)`

Then it derives screen-ready data through:

- `deriveTransactionsPageData(...)`

This gives:

- filtered row list
- grouped month/day structures
- category list for UI filters

### 4. Render charts

Charts are driven by:

- backend summary data
- plus projected recurring rows merged locally through `TransactionsFeedSummary.addingExpenses(...)`

This is important.

The chart is not based only on the currently visible page rows. It is based on the full backend summary for the current filter set, then augmented with projected recurring rows that do not exist in the database feed.

### 5. Render list lazily

The visible transaction list is a `CustomScrollView` + `SliverList`.

The list is lazy in two ways:

- the backend only returns one page of DB rows at a time
- Flutter builds list children lazily through `SliverChildBuilderDelegate`

When scroll reaches near the bottom:

- `_handleScroll()` triggers `_loadMoreTransactions()`
- the notifier requests the next backend page with cursor
- new items are appended to provider state
- local grouping is recalculated against the new in-memory page set

## Reuse in Other Screens

The same backend-paginated feed pattern is now used in two additional detail pages.

### Account details

`account_details_page.dart` now:

- builds a `TransactionsFeedQuery` scoped by account id (`selectedAccountId`)
- uses feed pages for recent transactions list (`GroupedTransactionsList`)
- uses a month-bounded summary query for key insight totals
- supports incremental loading with `loadMore()`

Load-more trigger behavior:

- now auto-loads on scroll-near-bottom (no manual load-more button)

Why:

- removes dependency on `analyticsProvider.allExpenses` full-history in-memory filtering
- keeps account details responsive for large datasets

### Pocket details

`pocket_details_page.dart` now:

- builds a month-scoped `TransactionsFeedQuery` with `selectedCategories`
- uses feed pages for recent transactions list
- supports incremental loading with `loadMore()`

Load-more trigger behavior:

- now auto-loads on scroll-near-bottom (no manual load-more button)

`pocket_details_provider.dart` now also returns `linkedCategories` so the page can construct server-side category filters.

Why:

- avoids building recent list rows from full local query results when paginated RPC can provide them
- keeps pocket recent-activity rendering aligned with the same feed contract

### Shared lazy-load component

To keep pagination UX consistent and avoid copy-pasted scroll logic, lazy-loading is centralized in:

- `lib/shared/widgets/auto_paginated_scroll.dart`

Shared pieces:

- `AutoPaginatedScroll`
  - single near-bottom trigger policy (`extentAfter <= 600`)
  - guards duplicate fetches (`isLoading`, `isLoadingMore`, `hasMore`)
- `PaginatedLoadMoreIndicator`
  - consistent inline loading spinner for non-sliver content
- `PaginatedLoadMoreSliverIndicator`
  - consistent loading spinner for sliver-based lists

Used by:

- `TransactionsPage`
- `AccountDetailsPage`
- `PocketDetailsPage`

## Why Recurring Transactions Are Still Local

Recurring projections are not ordinary persisted transaction rows.

They are created from recurring rules and projected into the visible period.

That means the screen has two data sources:

- persisted feed rows from backend RPCs
- projected recurring entries created locally

This is why the page still performs local merging and local grouping.

The current architecture intentionally keeps recurring projection local because:

- it avoids changing the backend contract further during this optimization pass
- the recurring rows are view-model style data, not canonical persisted transaction rows
- the page can still keep chart correctness by adding projected rows to summary data locally

## Export Behavior

Export should not export only the currently loaded page.

Current behavior:

- `TransactionsPage._exportTransactions(...)` calls `fetchAllPages(query)`
- this walks the paginated RPC until no more rows remain
- projected recurring expenses for the current screen state are merged in locally
- export uses the same scope context as the current page

Important bug that was fixed:

- export originally re-filtered with personal scope even when the page was showing household/portfolio data
- this could silently drop scoped rows from exports
- export now preserves the actual `householdScopeProvider` values

## Refresh and External Invalidation

### In-page refresh

Pull-to-refresh calls:

- `transactionsFeedProvider(feedQuery).notifier.refresh()`

### After local mutations

The page explicitly refreshes the active feed after:

- bulk delete
- single delete
- editing an existing transaction after the transaction sheet closes

### Notification-driven invalidation

`NotificationDispatcher` may fetch a transaction directly and inject it into app state.

To ensure the paginated feed notices this:

- dispatcher increments `transactionsFeedRefreshSignalProvider`
- `transactionsFeedProvider` watches that signal
- provider gets recreated and reloads current query state

This prevents the transactions page from going stale when a notification path inserts or updates visible transaction data indirectly.

## Known Production Issue Encountered

### Symptom

Transactions page showed the generic error state:

- "Failed to load group transactions"

### Root cause

Supabase RPC failed with:

- `function lower(transaction_type) does not exist`

The `expenses.type` column is an enum, not a text column.

The original SQL used expressions like:

```sql
lower(coalesce(e.type, 'expense'))
```

Postgres does not allow `lower()` on the enum type directly.

### Correct fix

Cast enum values to text before calling `lower()`:

```sql
lower(coalesce(e.type::text, 'expense'))
```

and

```sql
lower(coalesce(type::text, 'expense'))
```

### Migration handling

Two actions were required:

1. fix the original migration so fresh databases deploy cleanly
2. add a follow-up migration so already-deployed databases are corrected safely

That is why both SQL files must remain in sync conceptually.

## Temporary Debugging That Was Added and Removed

During rollout, temporary diagnostics were added to `transactions_feed_provider.dart` to print RPC names and params and log full query context on failure.

These diagnostics were intentionally removed after the enum-cast issue was confirmed and fixed.

The durable state that remains is:

- normal provider error propagation through `TransactionsFeedState.error`
- normal page-level generic error rendering

No temporary debug logging should remain in the feed provider after cleanup.

## Current Tradeoffs

### Accepted tradeoffs

- recurring projections remain local instead of moving into SQL
- month/day grouping is still done client-side for currently loaded rows
- summary period totals are currently yearly only because that is what the page charts use today

### Why these are acceptable

- the biggest performance issue was full-history row loading and full-history client aggregation
- that problem is solved without forcing an invasive recurring/backend rewrite
- the current architecture is a substantial improvement with limited blast radius

## Constraints and Assumptions

These are important for future changes.

### 1. `TransactionsFeedQuery` equality matters

The Riverpod family key is based on normalized query values.

If query normalization changes, provider recreation behavior will change too.

### 2. Summary and page must stay filter-aligned

If any filter is added or changed in one RPC, the other RPC must be updated the same way.

Otherwise:

- chart totals will no longer match the list

This now also applies to optional account/category-set filters:

- if `p_account_id` / `p_categories` logic diverges between page and summary RPCs, detail page cards and list rows will drift

### 3. Export path must stay scope-aligned

Export uses all backend pages plus local recurring projection.

Any future changes to page scope logic must be mirrored in export logic.

### 4. Notification refresh is signal-based, not direct mutation of page provider state

This is intentional.

The page provider is page-query-specific, so the dispatcher should not try to mutate provider state directly.

## Future Work

These are reasonable next steps if more performance work is needed.

### Near-term

- add widget/integration coverage for the transactions page using the paginated provider
- add export tests for multi-page results with recurring projections
- improve error UI copy to distinguish feed failure from genuinely empty state
- add widget coverage for account/pocket details pagination (`loadMore`, month summary totals, empty/error states)

### Medium-term

- move more chart aggregation server-side if chart requirements expand beyond current summary payload
- add backend support for more chart bucket granularities if needed
- consider a dedicated repository abstraction instead of calling the service/provider directly from the page

### Longer-term

- unify transaction mutation flows so analytics and paginated feed share a more explicit domain-level invalidation model
- consider whether recurring projections should eventually have a backend-backed summary path

## Quick Troubleshooting Guide

If the page breaks again, inspect in this order.

### Page loads error state

Check:

- `transactions_feed_provider.dart`
- the latest Supabase migration state in `moneko-web/supabase/migrations`
- RPC execution in Supabase logs

Most likely causes:

- RPC function signature mismatch
- SQL type issue
- auth / household membership check failure
- filter mismatch between mobile params and SQL assumptions

### Chart totals do not match list filters

Check:

- `TransactionsFeedQuery`
- both SQL RPC filter clauses
- `TransactionsFeedSummary.addingExpenses(...)`
- local recurring projection range/filtering

### Export differs from visible screen scope

Check:

- `_exportTransactions(...)`
- `householdScopeProvider`
- `fetchAllPages(query)`

### Notification deep-link opens stale transaction state

Check:

- `NotificationDispatcher._injectIntoCache(...)`
- `transactionsFeedRefreshSignalProvider`

## File Index

### Most important mobile files

- `lib/features/home/presentation/pages/transactions_page.dart`
- `lib/features/home/presentation/state/transactions_feed_provider.dart`
- `lib/features/home/presentation/utils/transactions_page_derived_data.dart`
- `lib/features/home/presentation/widgets/transactions_pie_chart.dart`
- `lib/core/notifications/notification_dispatcher.dart`
- `lib/features/accounts/presentation/pages/account_details_page.dart`
- `lib/features/pockets/presentation/pages/pocket_details_page.dart`
- `lib/features/pockets/presentation/state/pocket_details_provider.dart`
- `lib/shared/widgets/auto_paginated_scroll.dart`

### Most important backend files

- `../moneko-web/supabase/migrations/20260402123000_add_transactions_feed_rpcs.sql`
- `../moneko-web/supabase/migrations/20260402124500_fix_transactions_feed_type_casts.sql`
- `../moneko-web/supabase/migrations/20260402140000_add_transactions_feed_account_and_categories_filters.sql`

## Summary

The transactions page is no longer a full-history frontend analytics screen.

It is now a hybrid architecture:

- backend-paginated DB feed
- backend summary for charts
- local recurring projection
- local grouping and presentation

That is the main mental model to preserve.

If future work starts drifting back toward "load everything and compute on device," treat that as architectural regression unless there is a very specific reason.
