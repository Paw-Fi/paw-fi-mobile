# Multi-Currency Implementation Plan (Mobile)

This document describes a robust, step-by-step plan to implement full multi-currency support in the Flutter mobile app, ensuring every view displays amounts with the correct currency symbol, enabling currency-scoped analytics, and providing a currency selector UX. The plan avoids refetching data, leverages existing Riverpod architecture, and covers edge cases and testing for a bug-free rollout.

---

## Goals & Non-Goals

- Goals
  - Display each expense with its own currency symbol.
  - Group data (expenses and budgets) by currency and allow switching the Home page view per currency.
  - Provide a full-screen currency selector showing per-currency summaries.
  - Make budget updates currency-aware.
  - Preserve current data fetching (no extra network calls) using in-memory filtering.

- Non-Goals
  - Performing FX conversions or normalizing multi-currency totals to a single base currency (future enhancement).
  - Backend/schema changes (we will use existing columns).

---

## Current State (Reference)

- Expenses: `features/home/presentation/models/expense_entry.dart` include `currency` (e.g., USD, EUR).
- Budgets: `features/home/presentation/models/daily_budget_entry.dart` include `currency`.
- User: `UserContact.preferredCurrency` used as default/placeholder currency symbol across UI.
- Analytics: `AnalyticsNotifier` loads ALL expenses and budgets (last 365 days) and stores both raw and filtered sets.
- Filtering: date filtering is local (providers); no currency filtering yet.

Problem: UI currently uses preferred currency for display, not each transaction’s currency; Home has no currency scope.

---

## High-Level Design

1) Data remains fetched once; currency filtering and grouping occur in derived providers.
2) Introduce a currency filter (selectedCurrency) in Home filter state.
3) Add derived providers that expose available currencies and per-currency summaries.
4) Update UI to:
   - Add a currency selector button (next to date range selector).
   - Provide a full-screen currency modal with per-currency stats.
   - Ensure all amount displays use appropriate currency symbol.
5) Make budget update flow currency-aware.

---

## Detailed Implementation

### 1) Models

- Create: `lib/features/home/presentation/models/currency_summary.dart`

```dart
class CurrencySummary {
  final String currencyCode; // e.g., USD, EUR
  final double totalExpenses;
  final double totalBudget;
  final int transactionCount;

  const CurrencySummary({
    required this.currencyCode,
    required this.totalExpenses,
    required this.totalBudget,
    required this.transactionCount,
  });

  double get netCashflow => totalBudget - totalExpenses;
  bool get isPositive => netCashflow >= 0;
}
```

- Update exports: `lib/features/home/presentation/models/models.dart`
  - Add: `export 'currency_summary.dart';`

### 2) Filter State & Notifier

- File: `lib/features/home/presentation/state/home_filter_provider.dart`
  - Extend `HomeFilterState` with a currency filter:

```dart
class HomeFilterState {
  final DateRangeFilter dateRangeFilter;
  final DateTime? customStartDate;
  final DateTime? customEndDate;
  final String? selectedCurrency; // null => All currencies

  HomeFilterState({
    this.dateRangeFilter = DateRangeFilter.last30Days,
    this.customStartDate,
    this.customEndDate,
    this.selectedCurrency,
  });

  HomeFilterState copyWith({
    DateRangeFilter? dateRangeFilter,
    DateTime? customStartDate,
    DateTime? customEndDate,
    String? selectedCurrency,
  }) {
    return HomeFilterState(
      dateRangeFilter: dateRangeFilter ?? this.dateRangeFilter,
      customStartDate: customStartDate ?? this.customStartDate,
      customEndDate: customEndDate ?? this.customEndDate,
      selectedCurrency: selectedCurrency ?? this.selectedCurrency,
    );
  }
}

class HomeFilterNotifier extends StateNotifier<HomeFilterState> {
  HomeFilterNotifier() : super(HomeFilterState());

  void setFilter(
    DateRangeFilter filter, {
    DateTime? startDate,
    DateTime? endDate,
    String? selectedCurrency,
  }) {
    state = state.copyWith(
      dateRangeFilter: filter,
      customStartDate: startDate,
      customEndDate: endDate,
      selectedCurrency: selectedCurrency,
    );
  }

  void setSelectedCurrency(String? currency) {
    state = state.copyWith(selectedCurrency: currency);
  }
}
```

### 3) New Derived Providers

- In `home_filter_provider.dart` (same file), add:

```dart
import 'package:moneko/features/home/presentation/models/currency_summary.dart';
import 'package:moneko/features/utils/currency.dart';

// Unique list of currencies present in expenses/budgets (uppercased)
final availableCurrenciesProvider = Provider<List<String>>((ref) {
  final data = ref.watch(analyticsProvider);
  final set = <String>{};
  for (final e in data.allExpenses) {
    final c = e.currency?.toUpperCase();
    if (c != null && c.isNotEmpty) set.add(c);
  }
  for (final b in data.allBudgets) {
    final c = b.currency?.toUpperCase();
    if (c != null && c.isNotEmpty) set.add(c);
  }
  final list = set.toList()..sort();
  return list;
});

// Per-currency summaries for the current date range
final currencySummariesProvider = Provider<List<CurrencySummary>>((ref) {
  final data = ref.watch(analyticsProvider);
  final filter = ref.watch(homeFilterProvider);
  final range = getDateRangeFromFilter(
    filter.dateRangeFilter,
    filter.customStartDate,
    filter.customEndDate,
  );
  final from = range['from']!;
  final to = range['to']!;

  final byCurExpenses = <String, double>{};
  final byCurBudgets = <String, double>{};
  final byCurCount = <String, int>{};

  for (final e in data.allExpenses) {
    final c = (e.currency ?? '').toUpperCase();
    if (c.isEmpty) continue;
    final d = DateTime(e.date.year, e.date.month, e.date.day);
    if (d.isBefore(from) || d.isAfter(to)) continue;
    byCurExpenses[c] = (byCurExpenses[c] ?? 0) + e.amount;
    byCurCount[c] = (byCurCount[c] ?? 0) + 1;
  }

  for (final b in data.allBudgets) {
    final c = (b.currency ?? '').toUpperCase();
    if (c.isEmpty) continue;
    final d = DateTime(b.date.year, b.date.month, b.date.day);
    if (d.isBefore(from) || d.isAfter(to)) continue;
    byCurBudgets[c] = (byCurBudgets[c] ?? 0) + b.amount;
  }

  final codes = {...byCurExpenses.keys, ...byCurBudgets.keys}.toList()..sort();
  return codes
      .map((code) => CurrencySummary(
            currencyCode: code,
            totalExpenses: byCurExpenses[code] ?? 0,
            totalBudget: byCurBudgets[code] ?? 0,
            transactionCount: byCurCount[code] ?? 0,
          ))
      .toList();
});
```

### 4) Update Existing Derived Providers (Date + Currency Filtering)

Keep the date filtering but add currency filtering:

```dart
final homeFilteredExpensesProvider = Provider<List<ExpenseEntry>>((ref) {
  final data = ref.watch(analyticsProvider);
  final filter = ref.watch(homeFilterProvider);
  final range = getDateRangeFromFilter(
    filter.dateRangeFilter,
    filter.customStartDate,
    filter.customEndDate,
  );
  final from = range['from']!;
  final to = range['to']!;
  final sel = filter.selectedCurrency?.toUpperCase();

  return data.allExpenses.where((e) {
    final d = DateTime(e.date.year, e.date.month, e.date.day);
    final dateOk = (d.isAtSameMomentAs(from) || d.isAfter(from)) &&
        (d.isAtSameMomentAs(to) || d.isBefore(to));
    final curOk = sel == null || (e.currency?.toUpperCase() == sel);
    return dateOk && curOk;
  }).toList();
});

final homeFilteredBudgetsProvider = Provider<List<DailyBudgetEntry>>((ref) {
  final data = ref.watch(analyticsProvider);
  final filter = ref.watch(homeFilterProvider);
  final range = getDateRangeFromFilter(
    filter.dateRangeFilter,
    filter.customStartDate,
    filter.customEndDate,
  );
  final from = range['from']!;
  final to = range['to']!;
  final sel = filter.selectedCurrency?.toUpperCase();

  final inRange = data.allBudgets.where((b) {
    final d = DateTime(b.date.year, b.date.month, b.date.day);
    final dateOk = (d.isAtSameMomentAs(from) || d.isAfter(from)) &&
        (d.isAtSameMomentAs(to) || d.isBefore(to));
    final curOk = sel == null || (b.currency?.toUpperCase() == sel);
    return dateOk && curOk;
  }).toList();

  if (inRange.isNotEmpty) return inRange;

  // Fallback: most recent budget before 'from' (matching currency if selected)
  DailyBudgetEntry? mostRecent;
  for (final b in data.allBudgets.reversed) {
    final d = DateTime(b.date.year, b.date.month, b.date.day);
    final curOk = sel == null || (b.currency?.toUpperCase() == sel);
    if (curOk && d.isBefore(from)) { mostRecent = b; break; }
  }
  return mostRecent != null ? [mostRecent] : [];
});
```

### 5) Budget Update Flow (Currency-Aware)

- Home page currently calls `set-budget` edge function with `{ userId, amount, phone?, currency? }`.
- Update payload to set `currency` to the selected currency if not null, else fallback to `contact.preferredCurrency` if present.
- Update local state after success:
  - Replace `setBudgetAmount(double amount)` with a currency-specific method in `AnalyticsNotifier`:

```dart
// In AnalyticsNotifier
void setBudgetAmountForCurrency(String currencyCode, double amount) {
  final code = currencyCode.toUpperCase();
  final newCents = (amount * 100).round();
  if (newCents <= 0) return;

  final current = state.budgets.where((b) => (b.currency ?? '').toUpperCase() == code).toList();
  if (current.isEmpty) {
    final contactId = state.contact?.id;
    if (contactId == null || contactId.isEmpty) return;
    final newEntry = DailyBudgetEntry(
      id: 'local-budget-${DateTime.now().millisecondsSinceEpoch}',
      contactId: contactId,
      date: DateTime.now(),
      amountCents: newCents,
      currency: code,
    );
    state = state.copyWith(budgets: [...state.budgets, newEntry]);
    return;
  }

  final totalCurrentCents = current.fold<int>(0, (s, b) => s + b.amountCents);
  List<DailyBudgetEntry> updated = List.of(state.budgets);

  if (totalCurrentCents <= 0) {
    final per = (newCents / current.length).round();
    updated = updated.map((b) =>
      (b.currency?.toUpperCase() == code) ? b.copyWith(amountCents: per) : b
    ).toList();
  } else {
    final ratio = newCents / totalCurrentCents;
    updated = updated.map((b) =>
      (b.currency?.toUpperCase() == code)
          ? b.copyWith(amountCents: (b.amountCents * ratio).round())
          : b
    ).toList();
    final diff = newCents - updated
        .where((b) => (b.currency?.toUpperCase() == code))
        .fold<int>(0, (s, b) => s + b.amountCents);
    if (diff != 0) {
      for (int i = updated.length - 1; i >= 0; i--) {
        final b = updated[i];
        if ((b.currency?.toUpperCase() == code)) {
          updated[i] = b.copyWith(amountCents: b.amountCents + diff);
          break;
        }
      }
    }
  }

  state = state.copyWith(budgets: updated);
}
```

- Keep the existing `setBudgetAmount` temporarily, but prefer the currency-specific method from Home page when a currency is selected.

### 6) Currency Selector Modal (UI)

- Create: `lib/features/home/presentation/widgets/currency_selector_modal.dart`
  - Full-screen modal (Scaffold) with safe area and AppBar.
  - Top-left close (X) button.
  - Scrollable list of cards:
    - "All Currencies" card:
      - Budget: sum of budgets in range across all currencies (see caveat below).
      - Spent: sum of expenses across all currencies.
      - Net: Budget − Spent (label as "Mixed" to avoid misleading symbol).
      - Transaction count: total across all currencies.
    - Per-currency cards from `currencySummariesProvider`:
      - Placeholder avatar (Circular avatar with the 3-letter code).
      - Budget, Spent, Net with currency symbol.
      - Transaction count.
  - On tap:
    - For "All Currencies": `ref.read(homeFilterProvider.notifier).setSelectedCurrency(null);`
    - For a specific currency: `setSelectedCurrency(currencyCode)`
    - Pop the modal.

Skeleton:

```dart
Future<void> showCurrencySelectorModal(BuildContext context, WidgetRef ref) async {
  await Navigator.of(context).push(
    MaterialPageRoute(fullscreenDialog: true, builder: (_) {
      final summaries = ref.watch(currencySummariesProvider);
      final color = Theme.of(context).colorScheme;
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Select Currency'),
          backgroundColor: color.card,
          elevation: 0,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AllCurrenciesCard(onTap: () {
              ref.read(homeFilterProvider.notifier).setSelectedCurrency(null);
              Navigator.pop(context);
            }),
            const SizedBox(height: 12),
            ...summaries.map((s) => CurrencyCard(summary: s, onTap: () {
              ref.read(homeFilterProvider.notifier).setSelectedCurrency(s.currencyCode);
              Navigator.pop(context);
            })),
          ],
        ),
      );
    }),
  );
}
```

- Export: add `export 'currency_selector_modal.dart';` to `lib/features/home/presentation/widgets/widgets.dart`.

### 7) Home Page Integration

- File: `lib/features/home/presentation/pages/home_page.dart`
  - Add a currency button next to "Personal" label (left side); tapping opens the modal.
  - Button displays:
    - When selectedCurrency != null: e.g., "USD ▼"
    - When null: "All ▼"
  - After selection, all cards and charts react via providers.

Example snippet:

```dart
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Row(children: [
      Text('Personal', ...),
      const SizedBox(width: 12),
      GestureDetector(
        onTap: () => showCurrencySelectorModal(context, ref),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.muted,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Text(filterState.selectedCurrency ?? 'All', ...),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down),
          ]),
        ),
      ),
    ]),
    GestureDetector(onTap: _showDateRangeFilter, child: Row([...]))
  ],
)
```

### 8) Display Correct Symbols Everywhere

- Use `resolveCurrencySymbol(expense.currency)` for per-transaction amounts (e.g., in Transactions list and detail sheet).
- For aggregate cards when a specific currency is selected:
  - Use `resolveCurrencySymbol(selectedCurrency)`.
- For "All Currencies":
  - Prefer either:
    1) Show amounts without a symbol and annotate with "🌐"; or
    2) Show per-currency chips/lines inside the card(s).
  - Do NOT show a single currency symbol when multiple currencies are mixed.

Minimal guidance:

```dart
final selected = ref.watch(homeFilterProvider).selectedCurrency;
final symbol = selected != null ? resolveCurrencySymbol(selected) : '';
// When selected == null, annotate labels with "🌐" as needed.
```

### 9) Budget Update Sheet (Currency-Aware Prefix + Payload)

- In Home page budget sheet:
  - Prefix the input with the selected currency symbol when `selectedCurrency != null`, otherwise fallback to `getCurrencySymbol(contact)`.
  - In payload to `set-budget`:
    - Set `payload['currency'] = selectedCurrency ?? contact?.preferredCurrency` (if not null/empty).
  - After success:
    - Call `setBudgetAmountForCurrency(selectedCurrency ?? (contact?.preferredCurrency ?? ''))` if a currency is determined, else just refresh.

---

## Edge Cases & Behaviors

1) Unknown/Null Currency Codes
   - Treat as unknown: use default symbol `$` or show code as text if available.
   - Normalize codes to uppercase (`USD`, `EUR`, `GBP`, etc.).

2) "All Currencies" Aggregation
   - Aggregated totals are not mathematically precise without FX; label as "Mixed".
   - Optionally, inside the modal show per-currency totals and avoid showing a single mixed total in the main cards.

3) No Budget for a Currency
   - Show Budget: 0, Net = −Spent; allow the normal empty state and keep UI consistent.

4) Fallback Budget Selection
   - If no budget entries exist in range, use the most recent budget before range (matching selected currency) as a fallback (already supported by provider update above).

5) Date + Currency Filter Composition
   - Ensure filter composition is AND: entries must match date range AND selected currency when set.

6) Transactions & Detail Sheet
   - Always render with the transaction’s own currency symbol.

7) Performance
   - All providers are derived from in-memory data. Data volume is limited to last 365 days, so filtering and grouping are fast.

---

## Testing Strategy

Unit (Providers)
- availableCurrenciesProvider returns normalized, sorted unique codes.
- currencySummariesProvider groups budgets/expenses correctly for a range.
- homeFilteredExpensesProvider/date+currency filter correctness.
- homeFilteredBudgetsProvider fallback selection per currency.

Widget
- Currency selector modal: opens, lists All + currencies, tapping sets filter and closes.
- Home cards/charts update when currency is changed.
- Budget sheet shows correct prefix and sends correct payload currency when selected.
- Transactions list rows show correct symbols per expense; detail sheet also correct.

Integration
- Login → data loads → Home shows default (All or preferred currency based on UX decision).
- Switching currencies and date ranges together produces expected filtered views.
- Error surfaces do not crash UI (e.g., unknown currency, empty lists).

---

## Rollout & Migration

- No DB migrations required.
- Feature can be rolled out behind a simple feature flag if desired (e.g., via env var) by conditionally rendering the currency button and modal; not necessary for MVP.
- Backward compatibility: when `selectedCurrency == null`, app behaves close to current behavior but with better annotation for mixed totals.

---

## Developer Checklist (Step-by-Step)

1) Models
   - [ ] Add `currency_summary.dart` and export in `models.dart`.

2) Providers
   - [ ] Extend `HomeFilterState` with `selectedCurrency` and methods in `HomeFilterNotifier`.
   - [ ] Add `availableCurrenciesProvider` and `currencySummariesProvider`.
   - [ ] Update `homeFilteredExpensesProvider` and `homeFilteredBudgetsProvider` to include currency filtering + fallback.

3) UI
   - [ ] Create `currency_selector_modal.dart`; export in `widgets.dart`.
   - [ ] Add currency button to Home header; wire to modal.
   - [ ] Update labels: when All → annotate as Mixed, avoid single-symbol totals.

4) Budget Flow
   - [ ] Prefix budget input with selected currency symbol if present.
   - [ ] Include currency in `set-budget` payload.
   - [ ] Add `setBudgetAmountForCurrency` to `AnalyticsNotifier`; use it on success.

5) Symbols
   - [ ] Use `resolveCurrencySymbol(expense.currency)` in per-transaction UI.
   - [ ] Use `resolveCurrencySymbol(selectedCurrency)` in aggregate cards when selected.

6) QA
   - [ ] Execute unit, widget, and manual tests from Testing Strategy.

---

## UX Notes & Accessibility

- Currency cards: include clear labels (Budget, Spent, Net, Transactions), ensure sufficient contrast (green/red net indicators).
- Modal: top-left close is easy to reach; also allow Android back to dismiss.
- Large tap targets (min 44x44) for currency cards.
- Localize labels (future), keep ISO codes and symbols as-is.

---

## Future Enhancements (Optional)

- Base currency mode: convert all currencies via cached rates for accurate aggregation.
- Per-currency budget editor in the modal (set budget per currency directly).
- Persist last-selected currency (e.g., SharedPreferences) to restore on next app launch.

---

## Acceptance Criteria

- Each transaction amount is shown with its own currency symbol across lists and detail views.
- Home can switch between “All” and specific currencies via a modal; UI reacts immediately.
- Date and currency filters compose correctly.
- Budget update uses the correct currency and updates UI accordingly.
- No crashes or UI regressions when data is empty or currencies are unknown.

---

## Appendix: Helper Guidance

- Symbol resolution:
  - Use `resolveCurrencySymbol(String? currencyCode)` (already in `features/utils/currency.dart`).
  - For selected currency code → `resolveCurrencySymbol(selectedCurrency)`.
  - For All → render without symbol or annotate Mixed.

- API payload example for `set-budget`:
```json
{
  "userId": "<uid>",
  "amount": 123.45,
  "currency": "USD",
  "phone": "+15551231234" // optional if WhatsApp-linked
}
```

- Error handling:
  - Wrap network calls in try/catch; show toasts; never block UI permanently.
  - Providers should avoid throwing; prefer empty results and visible error messages in UI.

---

This plan is designed to be implemented incrementally, with minimal risk, and comprehensive test coverage to ensure a bug-free multi-currency experience.
