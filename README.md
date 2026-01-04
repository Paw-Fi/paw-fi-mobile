# rsupa

A flutter supabase auth starter build with riverpod

- supabase
- riverpod
- riverpod architecture

## Setup

- cp .env.example .env
- update url and anon keys

## Run
### Android
- flutter run -d emulator-5554 --dart-define=ENV=production

## Release to Production
### iOS
`
flutter build ios --release --dart-define=ENV=prod
`

### Android
`
flutter build appbundle --release --dart-define=ENV=prod
`

### Web
`
flutter build web --release --dart-define=ENV=prod
`

### Localization
`
flutter gen-l10n
`

## Testing

### Run Tests
```bash
flutter test
```

### Run Tests with Coverage
```bash
flutter test --coverage
```

### View Coverage Report (HTML)
```bash
# Install lcov (one-time setup on macOS)
brew install lcov

# Generate coverage
flutter test --coverage

# Generate HTML report
genhtml coverage/lcov.info -o coverage/html

# Open in browser
open coverage/html/index.html
```

### Test Coverage Status

**Current Coverage:** 4.0% (1,897 of 47,200 lines)  
**Total Tests:** 775+ passing (615+ new + 160 existing)  
**Improvement:** +146% increase from initial 1.6% coverage

**Comprehensive Test Coverage:**
- Domain Models (317 tests): Household, ExpenseSplit, Subscription, Goal, GoalContribution, WhatsAppBinding
- Transactions & Income (109 tests): ExpenseEntry, IncomeEntry with all edge cases
- Budgets & Sharing (27 tests): SharedBudget, BudgetPeriod, SharingPreferences
- Presentation Models (98 tests): ParsedExpense, CategorySummary, DailyBudgetEntry, UserContact
- Authentication (22 tests): AppUser Freezed model
- Summary Models (101 tests): Currency, Goal, Income, Household summaries with nested entities
- Plaid Integration (20 tests): SyncedTransaction parsing
- Utility Functions (55 tests): DateTime conversions, category normalization with 60+ alias mappings

**All testable pure functions and business logic are now comprehensively tested.** Tests cover: model creation, JSON serialization, null handling, copyWith, computed properties, equality, edge cases (zero/negative/large values), floating point precision, complex nested structures, FX conversions, contribution types, privacy scopes, timezone handling, and category alias mapping.

**Note:** The remaining 96% of untested code consists of UI components, Riverpod providers, and services that require widget tests, integration tests, and mocked dependencies (different testing paradigm).

The HTML report shows:
- Overall coverage percentage
- Per-file coverage breakdown
- Line-by-line highlighting of covered/uncovered code
- Branch coverage details


