# Home And Space Dashboard Lazy Loading

## Purpose

This document records the performance-oriented dashboard changes made for:

- `moneko-mobile/lib/features/home/presentation/pages/home_page.dart`
- `moneko-mobile/lib/features/households/presentation/widgets/household_home_content.dart`

It is meant as a technical memory for future engineers and AI agents.

This document is intentionally focused on the **home / space dashboard optimization work only**.
It does not attempt to describe the entire analytics system or unrelated screens.

---

## Goal

The goal of this work was:

- keep the same visible numbers and UX
- avoid reading full transaction history just to render dashboard cards
- make each dashboard widget fetch only the data required for its own date range
- keep `TransactionsPage` as the only ledger-style screen that uses transaction feed pagination

In short:

- **dashboard = bounded card data**
- **transactions page = ledger data**

---

## What Changed

### Before

`home_page.dart` and `household_home_content.dart` depended heavily on broad local data sources:

- personal dashboard cards derived from `analyticsProvider`
- household dashboard cards often derived from large local household datasets
- recent-transaction widgets sorted local in-memory rows
- calendar widgets could depend on more rows than were actually visible

That meant dashboard rendering cost scaled with transaction history.

### After

Dashboard widgets now use dedicated, bounded dashboard data contracts.

For the dashboard surface, the app now separates data into three kinds:

1. **snapshot summary data**
2. **recent activity rows**
3. **calendar-window rows**

Each widget refetches based on **its own configured date range**.

---

## Core Design

### Dashboard-specific contracts

Added dashboard RPCs for the home / space surface:

- `get_dashboard_snapshot_v1`
- `get_dashboard_recent_transactions_v1`
- `get_dashboard_calendar_transactions_v1`
- `get_dashboard_currency_summaries_v1`
- `get_dashboard_user_activity_v1`

These are used only for dashboard rendering concerns.

### Ledger remains separate

`TransactionsPage` still uses the transaction feed contract:

- `get_user_transactions_page_v1`
- `get_user_transactions_summary_v1`

This is intentional.

The dashboard is not a ledger page.

---

## Why This Was The Right Optimization

Other senior engineers would usually make this distinction:

- **home dashboard** needs fast, card-specific, bounded reads
- **ledger / transactions page** needs pagination, deep filtering, export, and browsing semantics

If both use the same public contract, you usually get one of two failures:

1. dashboard over-fetches
2. ledger gets constrained by dashboard simplifications

This change avoids that.

---

## Backend Pieces Added

The dashboard work introduced these RPCs in:

- `moneko-web/supabase/migrations/20260402153000_split_dashboard_snapshot_rpcs.sql`

### `get_dashboard_snapshot_v1`

Used for aggregate card/chart data.

Inputs:

- user id
- household id (nullable)
- currency (nullable)
- start date (nullable)
- end date (nullable)
- interval granularity (nullable)

Returns:

- transaction count
- expense total
- income total
- multiple-currency flag
- category summaries
- period totals

This powers widgets such as:

- spending summary
- spending breakdown chart
- where the money went
- net cashflow calculations

### `get_dashboard_recent_transactions_v1`

Used for the dashboard recent-transactions card.

It returns only the latest bounded rows needed for the card.

### `get_dashboard_calendar_transactions_v1`

Used by the dashboard calendar widget.

It returns only the rows for the currently visible time window.

### `get_dashboard_currency_summaries_v1`

Used by the home header currency modal and related lightweight currency state.

This avoids needing full analytics data just to power currency UI.

### `get_dashboard_user_activity_v1`

Used for lightweight “has user ever logged transactions?” checks in the home onboarding / checklist banner.

This preserves the old checklist semantics without forcing the dashboard to depend on full analytics history.

---

## Mobile Files Added Or Updated

### New state/models

#### `lib/features/home/presentation/state/dashboard_snapshot_models.dart`

Contains dashboard-specific query and response models:

- `DashboardScopeQuery`
- `DashboardRecentTransactionsRequest`
- `DashboardCategorySummary`
- `DashboardSnapshotSummary`

These are dashboard models, not ledger models.

#### `lib/features/home/presentation/state/dashboard_lazy_providers.dart`

Contains the dashboard data service and providers:

- `DashboardDataService`
- `SupabaseDashboardDataService`
- `PreviewDashboardDataService`
- `dashboardSummaryProvider`
- `dashboardRecentTransactionsProvider`
- `dashboardCalendarTransactionsProvider`
- `dashboardRefreshSignalProvider`

Responsibilities:

- call dashboard-specific RPCs
- provide preview-safe behavior
- re-fetch dashboard data when dashboard refresh signal changes

#### `lib/features/home/presentation/state/dashboard_user_context_provider.dart`

Contains lightweight dashboard-only shell data providers:

- `dashboardUserContactProvider`
- `dashboardPersonalBudgetsProvider`
- `dashboardSelectedHomeCurrencyCodeProvider`
- `dashboardHasLoggedTransactionsProvider`
- `dashboardCurrencySummariesProvider`
- `dashboardCurrencyTransactionCountsProvider`

Responsibilities:

- contact / timezone / preferred currency fallback
- personal budgets for dashboard cards
- lightweight currency selector state
- lightweight checklist state

---

## Home Page Changes

Main file:

- `lib/features/home/presentation/pages/home_page.dart`

### What changed in `home_page.dart`

The page was changed so that normal dashboard rendering no longer needs full-history transaction analytics.

It now uses:

- dashboard contact provider for timezone / preferred currency fallback
- dashboard personal budgets provider for net-cashflow-related card inputs
- dashboard lazy widget wrappers for card-specific fetching

### Important result

`home_page.dart` is now much less sensitive to the total number of transactions in the user’s history.

---

## Household / Space Dashboard Changes

Main file:

- `lib/features/households/presentation/widgets/household_home_content.dart`

### What changed

The space dashboard now routes widgets through lazy dashboard wrappers rather than relying on larger local datasets for normal dashboard rendering.

This keeps each widget aligned to its own configured date range.

---

## Widget-Level Strategy

This is the most important rule future agents must preserve.

Each dashboard widget can have its own date range configured via **Edit Widgets** in:

- `moneko-mobile/lib/features/home/presentation/widgets/home_header_sliver.dart`

Therefore each widget must fetch only the data required for **that widget’s own range**.

### Personal dashboard widgets

#### Spending Summary

Uses snapshot aggregate data for the widget’s current range.

#### Net Cashflow

Uses:

- current-period dashboard snapshot
- previous-period dashboard snapshot
- dashboard budget data

#### Financial Calendar

Uses only visible-range rows from `get_dashboard_calendar_transactions_v1`.

#### Recent Transactions

Uses only latest bounded rows from `get_dashboard_recent_transactions_v1`.

#### Spending Breakdown / Where The Money Went

Use dashboard snapshot category summaries for the widget’s range.

### Household / space dashboard widgets

The same principle applies.

Each household widget is driven by its own configured date range and uses bounded summary/recent/calendar data instead of broad history reads.

---

## Why Existing Card Widgets Were Reused

We intentionally preserved the current UI behavior by adapting the data underneath rather than rewriting every widget from scratch.

That means the optimization was mostly done through:

- new providers
- new RPCs
- new wrapper widgets
- synthetic derived entries where needed

This was the safest way to improve performance without changing what users see.

---

## Refresh / Invalidation Model

The dashboard work introduced a lightweight invalidation model:

- `dashboardRefreshSignalProvider`

This is bumped after relevant dashboard-affecting actions so dashboard widgets refetch without each widget being manually mutated.

Examples include:

- transaction save flows
- delete flows
- dashboard pull-to-refresh
- some header-triggered refresh paths

---

## Preview Mode

Preview mode is supported through:

- `PreviewDashboardDataService`

This avoids forcing preview to depend on deployed dashboard RPCs.

---

## What This Work Did Not Finish

This optimization work intentionally focused on the home / space dashboard surface.

It did **not** fully remove all legacy analytics loading from the app.

The key remaining item is:

- `analyticsProvider.notifier.loadData(userId)` still runs during app initialization

That should **not** be removed yet unless all remaining non-dashboard consumers are migrated.

At the moment, the safe statement is:

- the **dashboard render path** is optimized and mostly decoupled
- the **app-wide analytics preload** still exists for legacy consumers outside the dashboard

---

## Safe Future Direction

If another agent continues this work, the next step is **not** to rewrite the dashboard again.

The next step is to audit all remaining non-dashboard consumers of `analyticsProvider` and migrate them one by one.

Only after that is complete can app initialization safely stop calling:

- `analyticsProvider.notifier.loadData(userId)`

---

## Guidance For Other Apps

If another AI agent wants to apply this same optimization pattern in a different app, preserve these principles:

1. dashboard is not a ledger
2. each widget fetches only what its own range requires
3. recent-activity cards use bounded rows, not full history
4. calendar widgets use visible-window rows only
5. aggregate cards use summary contracts, not full row scans
6. preserve existing UI behavior by adapting data underneath first
7. remove app-wide preload only after all downstream consumers are migrated

---

## Most Important Files

### Mobile

- `lib/features/home/presentation/pages/home_page.dart`
- `lib/features/households/presentation/widgets/household_home_content.dart`
- `lib/features/home/presentation/state/dashboard_snapshot_models.dart`
- `lib/features/home/presentation/state/dashboard_lazy_providers.dart`
- `lib/features/home/presentation/state/dashboard_user_context_provider.dart`
- `lib/features/home/presentation/widgets/dashboard_lazy_widgets.dart`
- `lib/features/households/presentation/widgets/household_dashboard_lazy_widgets.dart`
- `lib/features/households/presentation/widgets/financial_calendar_widget.dart`
- `lib/features/home/presentation/widgets/home_header_sliver.dart`
- `lib/features/home/presentation/widgets/currency_selector_modal.dart`
- `lib/features/home/presentation/widgets/connect_social_banner.dart`

### Backend

- `moneko-web/supabase/migrations/20260402153000_split_dashboard_snapshot_rpcs.sql`

---

## Final Mental Model

Keep this mental model:

- `home_page.dart` and `household_home_content.dart` should render from bounded dashboard data
- each widget’s own range drives its own fetch
- `TransactionsPage` remains the ledger screen
- performance improvements should happen by reducing dashboard read scope, not by reintroducing full-history local derivation
