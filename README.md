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



## Background file imports

The import wizard offers automatic background import and the existing editable review wizard. Supabase Storage accepts the source into the private `file-imports` bucket. PostgreSQL schedules a Dart worker that uses the same parser, mapping, recurrence and deduplication code as Mobile. The worker calls the existing PDF analyzer and transaction batch writer. It uses service credentials and can finish after the uploading device disconnects.

Deploy the `20261120120000_file_import_jobs.sql` and `20261122120000_harden_file_import_jobs.sql` migrations in order, and the `analyze-expense`, `save-transactions-batch`, `file-import-maintenance`, `households-send-push-notification` and `households-process-notifications` functions from the Web repository. The migration uses the project's existing Vault, pg_cron and pg_net extensions. Build the worker from the Mobile repository root with the supplied upload allowlist.

```sh
gcloud builds submit . --ignore-file=server/file_import/build.ignore \
  --config=server/file_import/cloudbuild.yaml --substitutions="_IMAGE=$IMPORT_WORKER_IMAGE"
gcloud run deploy file-import-worker --image="$IMPORT_WORKER_IMAGE" \
  --region="$IMPORT_WORKER_REGION" --allow-unauthenticated --concurrency=1 \
  --min-instances=0 --max-instances=2 --cpu=2 --memory=2Gi --timeout=900 \
  --set-env-vars="SUPABASE_URL=$PROJECT_SUPABASE_URL" \
  --set-secrets="FILE_IMPORT_WORKER_SECRET=file-import-worker-secret:latest,SUPABASE_SERVICE_ROLE_KEY=supabase-service-role-jwt:latest,INTERNAL_SERVICE_SECRET=internal-service-secret:latest"
```

Use the project's JWT-format service role key for the existing Edge gateway and the same internal secret as the Edge Functions. Store the deployed HTTPS service origin under `file_import_worker_url` in Supabase Vault. Store the worker's dedicated bearer secret under `file_import_worker_secret`. The worker authenticates each cron request with that secret. Release the mobile build once both Vault entries and the service are ready. When upgrading an active installation, pause the import cron and let existing worker requests finish, apply the forward migration, deploy the Edge Functions and worker together, and re-enable the cron. Queued jobs retain their identity.

Background uploads accept files up to 50 MiB, with the existing 20 MiB PDF limit. Files larger than 6 MiB use resumable Storage uploads. Reselecting the same file restores the last confirmed byte offset. PDFs flagged as incomplete or requiring review stop before writing transactions. The scheduler recovers an upload whose acknowledgement was lost and expires unfinished uploads after one day. Up to two jobs can run concurrently, with one active worker per user. The worker saves groups of 50 transactions and checkpoints the immutable plan and source-row identities. A failed job can retain its plan for seven days for an idempotent retry. Successful jobs release their private files after one hour. Import history remains visible after cleanup.

For a local recovery test, compile `server/file_import/worker.dart` using the Mobile package configuration. In the adjacent Web checkout, run `node --test tests/file-import-jobs-postgres.test.mjs` with `FILE_IMPORT_TEST_WORKER` set to the absolute executable path. The test runs the compiled worker and the real Deno batch writer. It exits the uploader, restarts the worker after a lost write acknowledgement, and checks 20,000 ledger rows, their total, and transition events in an isolated PostgreSQL fixture. Storage, the PostgREST HTTP layer, and external notification providers use local substitutes.

The database validates the current worker lease on each financial insert and records a receipt in the same transaction. Receipts survive edits, moves, and user deletion until job file cleanup. Per-device push acknowledgements protect retries after partial delivery. Once an email has spent 23 hours in the retry window, its outbox row records `delivery_uncertain_at` for reconciliation against provider logs. Import status remains authoritative when an external delivery acknowledgement is unavailable.
