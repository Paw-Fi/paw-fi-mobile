# Local Only Mode Implementation Plan (Moneko Mobile)

This document is the execution handoff for implementing a first-class `Cloud`
and `Local Only` data-mode choice in `moneko-mobile/`.

Plan authority: This document records the product decisions confirmed with the
user. The implementation must also comply with the repository architecture
notes and async mutation contract listed below.

## Required Reading

Before editing code, read these documents in full:

- `../../../../moneko-obsidian-vault/moneko-app-file-relationship-architecture.md`
- `../../../../moneko-obsidian-vault/architecture/app-shell-and-shared-state.md`
- `../../../../moneko-obsidian-vault/architecture/transactions-and-entry-points.md`
- `../../../../moneko-obsidian-vault/architecture/recurring-and-pockets.md`
- `../../../../moneko-obsidian-vault/architecture/wallets-and-insights.md`
- `../../../../moneko-obsidian-vault/architecture/synchronization-and-mutation-reliability.md`
- `../../../../moneko-obsidian-vault/architecture/audited-file-inventory.md`
- `../../../../docs/async-ui-and-optimistic-mutation-contract.md`
- `../../../../docs/multi-currency-behavior-memory.md`
- `../../../../AGENTS.md`
- `../../../AGENTS.md`

Resolve current Flutter, Riverpod, adaptive_platform_ui, local_auth,
flutter_secure_storage, SQLite encryption, and cryptography APIs with Context7
before selecting dependencies or writing implementation code.

## Objective

Add an explicit onboarding choice between:

- `Cloud`: preserve the current Supabase-authenticated, local-first, outbox, and
  delta-sync behavior.
- `Local Only`: create a stable local UUID profile with no Supabase account and
  make the device database the final authority for personal and local-portfolio
  financial data.

Local Only must not be implemented as temporary network-offline state, preview
mode, a permanently failing outbox, or a UI-only feature flag.

Current release acceptance covers the iOS and Android mobile apps. Web and
desktop Local Only implementations are future work; current identity, entity
IDs, cryptography, backup format, and repository boundaries must not preclude
them, but this plan does not require shipping or validating those platforms.

## Confirmed Product Decisions

### Identity and Storage

- A Local Only user has a generated stable local UUID.
- No Supabase Auth user is created for a Local Only profile.
- One Local Only profile is supported per device.
- A Local Only profile can contain multiple local portfolios.
- Local portfolios match the user-facing behavior of current Private Spaces,
  but they are not Supabase households and have no membership model.
- All Local Only financial records and managed attachments are encrypted at
  rest.
- The profile encryption key is protected by device secure storage and
  biometric authentication.
- A recovery key is generated during setup and the user must acknowledge that
  it was saved before onboarding can finish.
- Moneko cannot recover a lost recovery key.
- A complete encrypted backup contains the profile, portfolios, transactions,
  receipts, wallets, transfers, pockets, recurring data, categories, settings,
  and report-relevant metadata.

### Remote Access

- Local Only does not write financial or profile data to Supabase tables,
  Storage, RPCs, or Edge Functions.
- Local Only does not create or drain remote mutation outbox operations.
- Local Only does not run mobile delta synchronization.
- User-scoped Supabase reads are disabled.
- Hosted AI is disabled in Local Only.
- Scenario Planning is disabled in Local Only.
- PDF AI import is disabled in Local Only.
- A narrowly allowlisted public, read-only currency-rate request is permitted.
  It must not contain profile or financial data.
- Cached and bundled currency rates remain available without a network.
- Crashlytics remains enabled as in Cloud mode, but Local Only must route all
  application-supplied reports through a tested redaction boundary. Reports
  must not deliberately attach financial values, merchant/category text,
  recovery material, encryption keys, attachment data/paths, or stable local
  identity. Product privacy copy must disclose that automatic redacted
  technical diagnostics are sent and must not promise that a native crash SDK
  can provide a mathematically absolute zero-metadata guarantee.

### Entitlements

- All on-device Local Only features are free.
- Local Only has no subscription lookup, trial grant, paywall, receipt
  verification, or Plus gate.
- Cloud mode entitlement behavior must remain unchanged.

### Data Behavior

- Core behavior should match Cloud mode unless this plan explicitly excludes a
  remote feature.
- Local Only transaction creation uses a blank manual transaction editor as the
  primary FAB action.
- Structured CSV, TSV, TXT, XLS, and XLSX imports are processed and saved
  locally.
- Receipt images are copied into encrypted app-managed attachment storage.
- Custom categories have full local create, rename, style, hide, and delete
  support.
- A non-deletable local `Spending` wallet is automatically created for every
  currency used by a profile or portfolio.
- Transaction currency must match wallet currency.
- Local wallets support full create, edit, archive, restore, delete, detail,
  history, balance, and same-currency transfer behavior.
- Deleting a wallet makes its ordinary transactions unassigned.
- A wallet referenced by a transfer cannot be deleted until the relevant
  transfers are removed.
- Pockets retain full monthly, template, rollover, category-link,
  uncategorized-assignment, detail, and historical behavior.
- Recurring retains full series, projection, confirm, edit, unconfirm, skip,
  bulk confirmation, and history behavior.
- Recurring reminders use device-local notifications.
- Monthly reports recompute from current local source data.
- Native home-screen widgets are disabled for Local Only profiles because their
  shared platform storage cannot satisfy the biometric-locked encrypted-at-rest
  guarantee. Existing Local Only widget snapshots and launch actions must be
  cleared or rejected.

### Space and Integration Discoverability

- Shared Space, bank, Plaid, email import, iOS Wallet capture, Android
  notification capture, WhatsApp/social binding, public import review, and
  scenario surfaces remain discoverable as unavailable.
- Unavailable surfaces explain that the feature requires Cloud mode and offer a
  guarded route into the Settings migration flow.
- Deep links, background services, platform channels, native queues, and direct
  routes must enforce the same restriction. Hiding a menu row is insufficient.
- Direct Cloud-only routes, including `/paywall`, `/plan-selection`, AI/widget
  launch links, bank links, and import-review links, show a local Cloud-required
  explanation with a guarded Settings migration action. They must not perform
  subscription, auth, trial, purchase, AI, bank, or import-review lookups first.
- Local portfolio settings keep name, cover, currency/scope preferences,
  switching, and deletion.
- Local portfolio membership, invitations, splitting, settlement, sharing, and
  conversion actions do not exist.

### Mode Migration

- Mode switching is a guarded Settings migration flow, not a simple toggle.
- Cloud to Local always copies the personal scope and all current private
  spaces, converting private spaces into local portfolios.
- Shared households and household records are excluded.
- Bank-linked wallets become manual local wallets and lose provider state.
- Existing custom categories are copied and remain fully editable.
- Cloud receipt files are downloaded into encrypted local attachment storage.
- Copy completion must verify all records and attachments before activating the
  Local Only profile.
- Cloud data remains untouched after copying.
- Local to Cloud uses an all-or-nothing snapshot review after Cloud account
  creation.
- Upload must verify the complete Cloud snapshot before reporting success.
- The separate Local Only copy remains available after successful upload.
- Neither migration runs silently or in the background without explicit review.

### Future Device Synchronization

Cross-device transport is not part of the current implementation.

The schema and identity design must leave room for a future AirDrop-like manual
sync that uses:

- QR-authenticated encrypted local-network transfer.
- Signed encrypted `.moneko` sync bundles transferred through AirDrop, Quick
  Share, LocalSend, USB, or user-owned storage.
- No persistent Moneko storage.
- Globally unique entity IDs.
- Stable per-device IDs and public keys.
- Per-entity revisions or append-only signed change metadata.
- Deterministic merge and explicit conflict behavior.

Do not implement peer-to-peer transport in this project phase. Do not introduce
sequential local entity IDs or server-canonical-ID assumptions that would make
future merging unsafe.

## Non-Goals

- Do not revive Goals.
- Do not add Local Only shared households, members, invitations, splits, or
  settlements.
- Do not implement hosted AI for anonymous/local users.
- Do not implement persistent Moneko ciphertext storage.
- Do not implement cross-device synchronization yet.
- Do not expand current delivery scope to web or desktop applications.
- Do not replace all existing Cloud repositories with a speculative generic
  framework.
- Do not change Cloud product behavior except where a shared abstraction is
  required to preserve existing behavior.

## Architectural Requirements

### First-Class Data Mode

Introduce a persisted data mode with equivalent semantics to:

```dart
enum AppDataMode {
  cloud,
  localOnly,
}
```

Expose one authoritative active identity boundary. Do not let individual
features independently choose between `authProvider.uid` and a local ID.

The active identity must distinguish at least:

- unauthenticated onboarding visitor,
- authenticated Cloud user,
- unlocked Local Only profile,
- locked Local Only profile.

Provider-family keys must use the active identity and complete scope arguments.
No Local Only provider key may use an empty user ID or a prior Cloud user ID.

### Local Scope

Local Only scope must support:

- one profile-level personal scope,
- zero or more local portfolio scopes,
- no household membership or shared scope.

Do not reuse current private household IDs as live local scope identities.
Generate local IDs and maintain migration mappings when copying from Cloud.

### Repository Boundaries

Each active domain must have a mode-aware repository boundary:

- profiles and settings,
- portfolios,
- transactions and attachments,
- categories,
- wallets and transfers,
- pockets,
- recurring templates and occurrences,
- reminders,
- reports and analytics,
- imports,
- currency rates.

Cloud implementations keep their current local-first and Supabase behavior.
Local implementations use only authoritative local storage and local refresh
signals.

Do not rely only on UI checks. Remote clients and dispatchers must reject Local
Only identity at their deepest callable boundary.

### Local Mutation Status

Local Only records are final local records, not queued Cloud mutations.

Either add a distinct local-authoritative origin/status or otherwise model this
explicitly. Do not leave Local Only rows in `local`, `failed`, or eternally
pending outbox states.

Local mutations still require:

- input validation,
- atomic local persistence,
- entity revision ownership,
- immediate provider projection,
- derived cache refresh,
- durable rollback when a local transaction fails,
- tests for overlapping edits.

### Local Database

The current production database is raw `sqlite3` in
`lib/core/local_data/moneko_database.dart`. Do not assume Drift owns its schema
merely because Drift is listed in `pubspec.yaml`.

Before implementation, make an explicit and tested decision between:

- extending the current SQLite layer with an encryption-capable connection, or
- performing a separately planned migration to an encrypted database layer.

Do not mix two authoritative databases.

Normalized local authority is required for at least:

- local profile metadata,
- local portfolios,
- wallet definitions and archive state,
- transfers,
- pocket budgets, envelopes, allocations, links, rollover, and tombstones,
- recurring templates,
- occurrence confirmations, skips, overrides, and history,
- reminder schedules and state,
- custom and hidden category definitions and styles,
- managed attachment metadata and lifecycle,
- migration mappings and checkpoints,
- future device/change metadata.

`local_json_cache` may remain a stale-while-revalidate/cache mechanism, but it
must not be the permanent authority for Local Only entities.

### Cryptography

Use established authenticated encryption. Do not design custom cryptography.

At minimum:

- Generate profile and recovery key material with a cryptographically secure
  random source.
- Use authenticated encryption such as AES-256-GCM or XChaCha20-Poly1305.
- Use a unique random nonce for every encrypted object/version.
- Bind schema version, profile ID, and object type as authenticated associated
  data where appropriate.
- Keep raw keys out of SharedPreferences, logs, Crashlytics, routes, and backup
  metadata.
- Store only wrapped keys in platform secure storage.
- Test tampering, wrong keys, interrupted writes, backup corruption, and key
  rotation/migration behavior.

The recovery key and biometric device wrapping have different purposes. A
biometric reset or secure-storage loss must be recoverable with the recovery
key. Recovery requires the recovery key to rewrap new device credentials; there
is no weaker device-passcode, app-PIN, or Cloud reset fallback. The threat model
must require biometric authorization before unwrapping the profile key, clear
unwrapped key material on lock/background according to a documented short
session policy, and test biometric reset, biometric enrollment changes, secure
storage invalidation, passcode removal, process death, and app restart. Loss of
both device credentials and recovery key must be documented as permanent data
loss.

### Attachments

Do not retain image-picker temporary paths as authoritative receipt storage.

Implement an app-managed encrypted attachment directory with:

- stable attachment IDs,
- atomic copy/encrypt/write,
- content authentication,
- transaction ownership,
- replacement cleanup,
- delete cleanup,
- backup inclusion,
- migration download verification,
- orphan cleanup that cannot delete a still-referenced file.

### Remote Access Policy

Add one central policy used by repositories, services, MainShell, native bridge
code, deep-link handlers, and background jobs.

Local Only must deny:

- Supabase Auth operations except explicit guarded migration to Cloud,
- user table reads and writes,
- Storage uploads and downloads except Cloud-to-Local migration receipt reads,
- user-scoped RPC and Edge Function calls,
- mobile outbox dispatch,
- mobile delta sync,
- FCM registration,
- native Wallet/notification capture credential synchronization,
- pending native capture upload,
- hosted AI and PDF parsing,
- scenario generation/history,
- bank and Plaid operations,
- email import and review operations.

The currency-rate allowlist must be explicit rather than permitting arbitrary
anonymous functions.

## Page and Feature Matrix

The executor must inspect each page and all imported child widgets, sheets,
providers, background callbacks, skeletons, and directly routable actions.

### Core and Navigation

| Surface                                 | Local Only requirement                                                   |
| --------------------------------------- | ------------------------------------------------------------------------ |
| `core/ui/pages/splash_screen.dart`      | Resolve Local Only identity without waiting for Cloud initialization.    |
| `core/ui/pages/error_page.dart`         | Do not turn expected Cloud unavailability into a Local Only fatal error. |
| `core/navigation/main_shell.dart`       | Skip outbox/delta/remote tab refresh; preserve local refresh fan-out.    |
| `core/navigation/main_menu_screen.dart` | Show mode-appropriate entries and unavailable integration affordances.   |
| `core/app/router.dart`                  | Route unlocked Local Only profiles to dashboard without Supabase auth.   |
| Deep links                              | Block Cloud-only targets at the route and deepest mutation boundary.     |

### Onboarding, Auth, and App Lock

| Surface                                  | Local Only requirement                                                                |
| ---------------------------------------- | ------------------------------------------------------------------------------------- |
| `onboarding_flow_page.dart`              | Add explicit animated Cloud/Local Only selection and contextual Q&A before questions. |
| `onboarding_pre_auth_flow_page.dart`     | Persist answers to the selected authority without remote calls.                       |
| `onboarding_save_budget_page.dart`       | Save Local Only budget/profile data locally.                                          |
| `onboarding_account_preparing_page.dart` | Add a local preparation branch; skip account, trial, household, and remote bootstrap. |
| `onboarding_post_auth_flow_page.dart`    | Replace Cloud-only steps with local security/recovery completion where applicable.    |
| `onboarding_preview_page.dart`           | Keep preview isolated from Local Only persisted identity.                             |
| `login_screen.dart`                      | Cloud entry and Local-to-Cloud migration only.                                        |
| `register_screen.dart`                   | Cloud entry and Local-to-Cloud migration only.                                        |
| `auth_callback_screen.dart`              | Cloud only; cannot overwrite a Local Only profile silently.                           |
| `avatar_customizer_screen.dart`          | Store generated avatar and metadata locally.                                          |
| `app_lock_setup_page.dart`               | Free Local Only setup tied to key protection.                                         |
| `app_lock_page.dart`                     | Unlock Local Only key without requiring Cloud auth.                                   |

In Local Only, the post-auth onboarding AI expense step must be omitted or
replaced with blank manual transaction/local sample behavior. It must not call
`onboardingPostAuthLogExpenseActionProvider`, `handleAiFreeFormText`, or
`handleAiCameraCapture`.

The mode transition should use keyed `AnimatedSwitcher`, `AnimatedSize`, and
short fade/position/container transitions, normally 150-300 ms. Hidden panels
must not receive taps or accessibility focus. Preserve light and dark themes and
use centralized semantic color tokens.

Local Only onboarding Q&A must disclose:

- where data is stored,
- what encryption and biometrics protect,
- that Moneko cannot recover the recovery key,
- device-loss and uninstall consequences,
- backup responsibility,
- unavailable Cloud features,
- free local entitlement,
- permitted public rate requests,
- future migration behavior,
- future manual device-transfer intent without promising a release date.

### Home, Transactions, and Categories

| Surface                          | Local Only requirement                                                    |
| -------------------------------- | ------------------------------------------------------------------------- |
| `home_page.dart`                 | Full personal/local-portfolio dashboard from local authority.             |
| `dashboard_page.dart`            | Local startup, refresh, totals, and rows.                                 |
| `overview_dashboard_page.dart`   | Remove household-loading dependency in local scopes.                      |
| `transactions_page.dart`         | Full local pagination, filters, search, charts, export, edit, and delete. |
| `category_details_page.dart`     | Local transactions and recurring projections with native row routing.     |
| `currency_rates_page.dart`       | Free public live refresh plus cached/bundled fallback.                    |
| `home_ai_fab.dart`               | Do not invoke AI; present manual transaction creation in Local Only.      |
| `unified_transaction_sheet.dart` | Save locally final ordinary transactions without outbox dispatch.         |
| Transaction detail router        | Preserve ordinary, recurring occurrence, and transfer routing.            |
| Custom category surfaces         | Full authoritative local create/edit/hide/style/delete support.           |
| Receipt surfaces                 | Use encrypted managed attachments, never Supabase Storage.                |

Preserve aggregate-vs-native currency behavior exactly as documented in
`AGENTS.md` and the multi-currency behavior memory.

### Import

| Surface                       | Local Only requirement                                                                                                                                                   |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `import_wizard_page.dart`     | Keep local structured parsing, mapping, validation, review, dedupe, and editing.                                                                                         |
| Structured import save        | Atomically persist selected transactions through the local repository.                                                                                                   |
| PDF import                    | Show unavailable because current parsing uploads to hosted AI.                                                                                                           |
| Wallet creation during import | Use local wallet repository.                                                                                                                                             |
| Scope selection               | Offer personal and local portfolios only.                                                                                                                                |
| `import_review_page.dart`     | Show Cloud-required explanation; do not inspect remote review tokens.                                                                                                    |
| Share intents                 | Validate MIME/type before queueing; structured files enter encrypted local import storage, while images/PDFs show unavailable and native temporary files are cleaned up. |

### Recurring and Reminders

| Surface                            | Local Only requirement                                                                                 |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------ |
| `recurring_transactions_page.dart` | Full local series list and mutations.                                                                  |
| `recurring_history_page.dart`      | Authoritative local occurrence history and pagination.                                                 |
| Recurring create/edit sheet        | Local series create/edit/delete without remote function calls.                                         |
| Occurrence sheets                  | Local confirm/edit/unconfirm/skip and bulk behavior.                                                   |
| `reminder_page.dart`               | Do not preserve hardcoded/placeholder behavior as authority.                                           |
| Reminder scheduling                | Device-local scheduling, cancellation, timezone changes, DST, restart, and denied permission handling. |

### Pockets

| Surface                    | Local Only requirement                                                |
| -------------------------- | --------------------------------------------------------------------- |
| `pockets_page.dart`        | Full authoritative local month state, including first uncached month. |
| `pocket_details_page.dart` | Local detail totals, projections, rows, and editing.                  |
| Pocket edit sheet          | Local create/edit/delete with versioned monthly snapshots.            |
| Templates and rollover     | Preserve current behavior with local records.                         |
| Uncategorized assignment   | Persist category-envelope links locally.                              |

Do not publish a fake zero/empty pocket state while local authority is loading.

### Wallets and Transfers

| Surface                         | Local Only requirement                                                                                                                                                                    |
| ------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `wallets_page.dart`             | Full local wallet entities and aggregate calculations.                                                                                                                                    |
| `wallet_details_page.dart`      | Native-currency local detail, rows, history, and actions.                                                                                                                                 |
| `archived_wallets_page.dart`    | Authoritative local archive list and restore.                                                                                                                                             |
| `wallets_history_page.dart`     | Confirm active reachability before changing; do not expand legacy code unnecessarily.                                                                                                     |
| Wallet create/edit sheet        | Local final create/edit/archive/restore/delete.                                                                                                                                           |
| Transfer sheet                  | Local final same-currency create/edit/delete with two derived feed rows.                                                                                                                  |
| Wallet balance adjustment sheet | If caller reachability is confirmed, persist a local final adjustment with atomic balance/feed/history projection, restart persistence, backup inclusion, and no remote/outbox operation. |
| Wallet deletion                 | Unassign ordinary rows; block while transfers reference the wallet.                                                                                                                       |
| Spending wallets                | Auto-create a non-deletable wallet for every used currency.                                                                                                                               |
| `bank_connections_page.dart`    | Show unavailable and block all provider actions.                                                                                                                                          |
| Plaid walkthrough/review pages  | Show unavailable and block tokens, callbacks, polling, and imports.                                                                                                                       |

### Insights and Reports

| Surface                         | Local Only requirement                             |
| ------------------------------- | -------------------------------------------------- |
| `insights_page.dart`            | Local analytics and report sources only.           |
| `monthly_report_page.dart`      | Dynamically recompute from current local sources.  |
| Monthly report detail/drilldown | Preserve ordinary and recurring row routing.       |
| Scenario Planning               | Show unavailable and never send financial context. |
| Scenario history                | Do not read or write remote history in Local Only. |

### Profiles, Settings, and Integrations

| Surface                                  | Local Only requirement                                                                                                                  |
| ---------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| `settings_page.dart`                     | Local profile, avatar, currency, timezone, financial month, theme, backup, lock, migration, and deletion.                               |
| `financial_month_settings_page.dart`     | Persist per local profile.                                                                                                              |
| `ios_wallet_capture_page.dart`           | Show unavailable; revoke/omit credentials and queue drain.                                                                              |
| `android_notification_capture_page.dart` | Show unavailable; disable listener configuration and queue drain.                                                                       |
| `email_import_settings_page.dart`        | Show unavailable; no remote settings calls.                                                                                             |
| Subscription/paywall pages               | Direct routes show the Cloud-required explanation without subscription lookup, trial grant, receipt verification, purchase, or restore. |
| App version checks                       | May remain if they transmit no profile/financial payload.                                                                               |

Local profile lifecycle actions are:

- lock,
- encrypted backup/export/import,
- portfolio switch,
- guarded migration to Cloud,
- irreversible local profile deletion.

Do not present Cloud logout as Local Only profile lifecycle.

### Shared Spaces

All Shared Space surfaces remain discoverable but unavailable in Local Only:

- `household_onboarding_page.dart`
- `create_space_page.dart` for shared-space creation
- `invite_members_page.dart`
- `household_join_page.dart`
- `household_invitation_handler_page.dart`
- `household_invites_page.dart`
- `household_members_page.dart`
- shared portions of `household_settings_page.dart`
- `household_expenses_page.dart`
- `daily_financial_details_page.dart`
- `household_member_details_page.dart`
- `create_budget_page.dart`
- `budget_detail_page.dart`
- `split_builder_page.dart`
- `settlement_history_page.dart`
- `settlement_calculation_breakdown_page.dart`
- invitation, split, settlement, member, and shared-dashboard child widgets

Local portfolios may reuse visual components where safe, but must not invoke
household providers, membership logic, split logic, or Supabase repositories.

### Legacy and Abandoned Surfaces

- Goals is abandoned and must remain excluded.
- Do not expand legacy Income pages; active income uses ordinary transactions.
- Confirm route/caller reachability before modifying `wallets_history_page.dart`,
  `reminder_page.dart`, demo screens, or superseded transaction sheets.
- If a legacy surface is unreachable, record that fact and leave it untouched
  unless its background provider can still leak remote access.

## Execution Phases

Each phase uses strict TDD. Do not begin the next phase until the current phase
meets its acceptance criteria and the user approves continuation when required
by the execution workflow.

## Phase 0: Baseline and Remote-Call Inventory

Tasks:

- Run the complete existing Flutter test suite and project analyzer.
- Record exact pre-existing failures/findings.
- Build a route-to-provider-to-repository inventory for every page above.
- Inventory all Supabase Auth/table/RPC/Function/Storage calls.
- Inventory all FCM, Plaid, native capture, share-intent, deep-link, background,
  widget, and app-resume entry points.
- Map all provider-family keys that currently depend on `authProvider.uid`.
- Map current SQLite tables, migration code, cache namespaces, and outbox paths.
- Record the encrypted SQLite connection decision in the phase handoff or this
  plan unless the user explicitly approves another documentation file.
- Review every proposed encryption/storage dependency for license compatibility,
  active maintenance, known vulnerabilities, native implementation quality, and
  iOS/Android/web/desktop support limitations.

Acceptance criteria:

- Every reachable remote operation has an owner and planned Local Only policy.
- Every active page has a local, Cloud-only unavailable, or untouched-legacy
  classification.
- Baseline tests and analyzer results are recorded accurately.
- Encryption approach works on iOS and Android and does not preclude desktop.
- Dependency license and security review results are recorded before adoption.

## Phase 1: Mode, Identity, Router, and Remote Denial

Tests first:

- Persist and restore Cloud/Local Only mode.
- Generate and retain stable local UUID.
- Route an incomplete or locked Local Only profile only to onboarding/setup or
  unlock state without auth.
- Keep onboarding visitors distinct from Local Only profiles.
- Keep Cloud router behavior unchanged.
- Force Local Only shared scope to personal/local portfolio only.
- Deny every non-allowlisted remote operation for Local Only identity.
- Skip outbox drain and delta pull in MainShell.

Implementation:

- Add data-mode and active-identity providers.
- Add centralized remote-access policy.
- Update router and app initialization.
- Update provider-family identity boundaries.
- Add deepest-boundary guards to sync/background services.
- Add a test transport/client that fails immediately on every non-allowlisted
  Local Only network request, and reuse it in all later phases.

Acceptance criteria:

- Phase 1 does not expose the dashboard or allow financial writes until
  encryption, recovery acknowledgement, and local profile bootstrap complete.
- No Local Only route requires a Supabase session.
- No Local Only startup path calls user-scoped remote services.
- Cloud behavior and tests remain green.

## Phase 2: Encryption, Recovery, Backup, and App Lock

Tests first:

- Generate, wrap, unlock, and recover profile key.
- Biometric/device-key loss can recover with the recovery key.
- Wrong recovery key fails without data alteration.
- Encrypted database cannot be read as plaintext.
- Encrypted attachment tampering is detected.
- Backup round trip restores all fixture domains and attachments.
- Backup manifest validation rejects missing domains, version mismatches,
  incorrect record counts, attachment digest mismatches, and incomplete files.
- Interrupted backup/import does not replace a valid profile.
- Application-supplied Crashlytics reports omit financial fixtures, merchant or
  category text, stable local identity, attachment metadata, and key material.
- Crashlytics user identifiers, custom keys, breadcrumbs/logs, router errors,
  initialization errors, deep-link errors, Flutter errors, and native crash
  configuration are audited for Local Only.

Implementation:

- Add encrypted local database opening/migration.
- Add profile key and recovery-key lifecycle.
- Integrate Local Only app lock.
- Add encrypted backup container and atomic restore.
- Define a versioned backup manifest before restore implementation. It must list
  every included domain, schema/format versions, per-domain record counts,
  attachment IDs and cryptographic digests, encryption/KDF parameters that are
  safe to disclose, and whole-container integrity metadata without exposing
  keys or financial values.
- Add Crashlytics redaction boundary.

Acceptance criteria:

- Recovery setup is mandatory before onboarding completion.
- No raw key enters preferences, logs, routes, or analytics.
- Complete backup and restore succeeds after app restart.
- Product privacy copy accurately discloses automatic redacted technical
  diagnostics and does not make an absolute native-SDK metadata claim.

## Phase 3: Onboarding and Local Profile Bootstrap

Tests first:

- Mode chooser has no default selection.
- Switching cards animates, updates Q&A, and preserves accessibility.
- Cloud selection follows current onboarding behavior.
- Local selection never saves heard-about/profile/budget data remotely.
- Local setup creates profile, initial portfolio scope, settings, recovery state,
  and initial Spending wallet atomically.
- Retry/restart resumes setup without duplicate entities.

Implementation:

- Add animated chooser to `onboarding_flow_page.dart` before questions.
- Add translated Cloud/Local Only labels and Q&A to `translations.json`; fill
  English only and leave other languages empty.
- Add local profile/security branch through onboarding pages.
- Remove subscription/trial/notification-account assumptions from local branch.

Acceptance criteria:

- Local onboarding completes without network or Supabase initialization.
- After encryption, recovery acknowledgement, and atomic bootstrap complete,
  the Local Only dashboard starts with Supabase unavailable.
- Cloud onboarding remains behaviorally unchanged.
- Transitions meet the 150-300 ms motion contract and work in light/dark mode.

## Phase 4: Transactions, Categories, Attachments, and Import

Tests first:

- Manual create/edit/delete is atomic, locally final, and immediately visible.
- Overlapping edits are latest-write-wins.
- Restart preserves all mutations with no outbox operation.
- New currencies create same-currency Spending wallets.
- Custom category CRUD/style/hide behavior persists locally.
- Receipt add/replace/delete manages encrypted files correctly.
- Structured import deduplicates and commits atomically.
- PDF/image AI paths are unavailable and make no request.
- Home, Transactions, Category Details, exports, and drilldowns refresh.

Implementation:

- Add Local Only transaction/category/attachment repositories.
- Add blank manual entry action in Local Only.
- Add local structured import completion path.
- Preserve native-row and aggregate-conversion contracts.

Acceptance criteria:

- No transaction/category/receipt/import Local Only mutation creates outbox data.
- Every transaction entry point displays the same locally committed result.
- Managed receipts survive restart and backup round trip.

## Phase 5: Local Portfolios and Shared-Space Boundaries

Tests first:

- Create/edit/delete/switch local portfolios.
- Portfolio provider keys and records remain isolated.
- Personal and portfolio dashboards use correct scope.
- Shared routes show unavailable and perform no remote operation.
- Deep links cannot bypass the restriction.

Implementation:

- Add normalized local portfolio authority.
- Reuse safe Private Space visual components without household data logic.
- Add Cloud-required unavailable surfaces and guarded migration action.

Acceptance criteria:

- Local portfolios have no household/member/split records.
- Shared providers are not initialized for Local Only scopes.

## Phase 6: Wallets and Transfers

Tests first:

- Wallet create/edit/archive/restore/delete persists locally.
- Per-currency Spending wallets are automatic and non-deletable.
- Transaction and wallet currencies must match.
- Same-currency transfer create/edit/delete updates both feed sides and balances.
- Wallet deletion unassigns ordinary transactions.
- Wallet deletion is blocked while transfers reference it.
- Reachable wallet balance adjustment create/edit/delete behavior updates the
  wallet header, feed, and history immediately, survives restart/backup, and
  creates no auth-header, Supabase, or outbox work.
- Wallet overview, detail, history, and archived pages update immediately.
- Bank and Plaid routes make no provider calls.

Implementation:

- Add normalized local wallet and transfer repositories.
- Use permanent globally unique local IDs.
- Preserve two-row transfer rendering while keeping one authoritative transfer.
- Add unavailable bank/Plaid handling at UI and service boundaries.

Acceptance criteria:

- Full manual-wallet parity works after restart.
- No Local Only wallet action depends on auth headers or canonical server IDs.

## Phase 7: Recurring and Local Notifications

Tests first:

- Series create/edit/delete and projection.
- Occurrence confirm/edit/unconfirm/skip and bulk confirmation.
- Occurrence history after restart without cached remote pages.
- Projection suppression against materialized actual rows.
- Reminder schedule/update/cancel across timezone and DST changes.
- Denied notification permission preserves recurrence data.
- All dependent dashboard, pocket, wallet, and report surfaces refresh.

Implementation:

- Add normalized recurring template and occurrence ledger authority.
- Add device-local reminder scheduler and reconciliation.
- Preserve existing transaction-detail routing and occurrence identity.

Acceptance criteria:

- Recurring behavior does not depend on `local_json_cache` completeness.
- Reminder delivery is local and no FCM token is registered.

## Phase 8: Pockets

Tests first:

- First uncached month does not publish fake zero/empty data while loading.
- Pocket create/edit/delete and sibling rebalance.
- Templates, links, rollover, uncategorized assignment, and historical months.
- Personal and local-portfolio scopes.
- Multiple currencies and recurring-inclusion setting.
- Concurrent monthly mutations remain latest-write-wins.
- Restart and backup restore preserve exact month state.

Implementation:

- Add normalized local budgets, envelopes, allocations, links, rollover, and
  tombstones.
- Keep current pocket cards native and aggregate headers converted.

Acceptance criteria:

- Full Pocket parity works without RPC/table access.
- Pending local transaction and recurring overlays cannot be hidden by caches.

## Phase 9: Insights, Reports, Rates, Exports, and Widget Boundaries

Tests first:

- Dashboard and reports derive only from local authority.
- Reports recompute after historical edits.
- Report drilldowns route native rows correctly.
- Public rate request contains no profile/financial payload.
- Rate failure uses cached/bundled values.
- Scenario Planning is unavailable.
- Complete export uses local data and attachments as specified.
- Home-screen widgets show a Cloud-required explanation or no Local Only data,
  clear any prior Local Only snapshot, and cannot launch AI text/camera actions.
- `moneko://text`, `moneko://camera`, widget text/camera actions, and equivalent
  deep links are rejected before AI/provider initialization.

Implementation:

- Add Local Only analytics/report repository paths.
- Add explicit rate-service allowlist.
- Remove subscription gates from Local Only rate/report surfaces.
- Disable Local Only widget snapshot writes and clear platform widget storage
  when entering Local Only, locking/deleting the profile, or detecting a stale
  Local Only snapshot.
- Guard `core/app/app.dart`, `core/services/deep_link_service.dart`,
  `features/home/presentation/state/widget_launch_provider.dart`,
  `core/navigation/main_shell.dart`, iOS `MonekoWidget`, and Android widget
  receivers/providers against Local Only AI/configuration launch actions.

Acceptance criteria:

- No insight/report cold load requires household or Supabase data.
- Report values preserve all currency behavior rules.
- No Local Only financial total or profile identity is written to Android
  widget storage or the iOS App Group.

## Phase 10: Cloud-to-Local Migration

Tests first:

- Copy personal scope and all private spaces.
- Exclude shared households and split/settlement records.
- Map remote IDs to globally unique local IDs without collisions.
- Convert bank wallets to manual wallets and remove provider state.
- Preserve custom categories and full editability.
- Download, encrypt, and verify all receipts.
- Interrupted migration resumes or rolls back safely.
- Verification failure does not activate partial Local Only data.
- Cloud source data remains unchanged.

Implementation:

- Add checkpointed snapshot reader and local importer.
- Show exact counts, attachment progress, exclusions, failures, and final
  verification.
- Activate Local Only only after atomic finalization.

Acceptance criteria:

- Source-to-destination count and integrity checks pass.
- No shared or provider credentials exist in the local result.
- Reopening Cloud mode shows the unchanged source account.

## Phase 11: Local-to-Cloud Migration

Tests first:

- Require explicit Cloud account creation/authentication.
- Present an all-or-nothing snapshot summary.
- Preserve currencies, wallet bindings, recurrence identities, pockets,
  portfolios, categories, and attachments.
- Retry idempotently without duplicate server entities.
- Verify complete remote snapshot before success.
- Failed verification retains Cloud rollback/recovery path and untouched local
  source.
- Successful migration retains the separate Local Only profile.

Implementation:

- Add guarded Settings migration flow.
- Add deterministic ID mapping and idempotency metadata.
- Add complete snapshot upload and verification.

Acceptance criteria:

- No silent or partial migration is reported as successful.
- Local data remains readable after Cloud activation.

## Phase 12: Hardening and Whole-Product Regression

Tasks:

- Re-audit every route, page, sheet, provider, service, app-resume handler,
  native bridge, deep link, share intent, notification handler, widget action,
  and background callback.
- Confirm the Phase 1 test transport/client still fails the suite if any Local
  Only path performs a non-allowlisted remote request.
- Verify all initial loading, cached refresh, empty, error, and mutation states.
- Verify no Cloud feature was over-gated or behaviorally changed.
- Update the architecture index and affected supporting architecture notes to
  describe the implemented mode, authority, and data flows.
- Format touched Dart files.
- Analyze every touched file and then run the project-wide analyzer.
- Run targeted tests during development and the complete Flutter suite at the
  end.
- Run Android unit tests for capture parsing/configuration/queue cleanup and
  audit manifests, receivers, services, workers, and widget providers.
- Audit and test, where practical, iOS Wallet capture, share extension, widget
  extension, App Group/Keychain storage, pending queues, and URL handling.
- Run Android and iOS build checks where the environment permits; report exact
  platform checks that cannot run.

Acceptance criteria:

- Every Local Only remote boundary is denied except the explicit rates request.
- All targeted tests pass.
- The complete Flutter test suite passes, or exact unrelated pre-existing
  failures are reported with evidence.
- Touched-file analysis is clean.
- Project-wide analyzer regressions are zero.
- Architecture notes match the implementation.

## Mandatory Test Matrix

For each local repository/domain, cover:

- initial creation,
- cached/restarted read,
- create,
- edit,
- delete,
- overlapping edits,
- local persistence failure and atomic rollback,
- scope isolation,
- currency isolation,
- backup/restore,
- migration mapping where applicable,
- proof that no remote/outbox operation occurs.

For Cloud mode, retain or add regression coverage for:

- Supabase auth routing,
- current onboarding,
- outbox and delta ordering,
- retryable pending mutations,
- terminal rollback,
- subscription and Plus gating,
- household and integration routes.

## Security Review Gates

Run a dedicated security review before completing Phases 2, 10, and 11.

The review must cover:

- key generation, wrapping, storage, rotation, and recovery,
- nonce uniqueness and authenticated encryption,
- backup tampering and rollback attacks,
- biometric invalidation,
- attachment path traversal and orphan cleanup,
- migration authorization and idempotency,
- logs and Crashlytics redaction,
- native platform storage and queues,
- widget/App Group storage clearing and Local Only denial,
- deep-link and route bypasses,
- public currency-rate endpoint abuse and payload minimization.

Critical or high-severity findings must be fixed before continuing.

## Documentation Updates During Implementation

When behavior is implemented, update:

- `moneko-obsidian-vault/moneko-app-file-relationship-architecture.md`
- the relevant notes under `moneko-obsidian-vault/architecture/`
- `docs/async-ui-and-optimistic-mutation-contract.md` only if the authoritative
  contract itself needs an approved change
- `AGENTS.md` only for durable product behavior future agents must preserve

Do not create one note per symbol or duplicate this plan into architecture
documentation. Keep the existing linked architecture structure.

## Executor Handoff Rules

- Use this plan with the `technical-implementation` and `tdd-workflow` skills.
- Use Sequential Thinking before each implementation phase.
- Use Context7 before adopting or changing library APIs.
- Write failing tests before production code.
- Prefer the smallest correct change inside each phase.
- Do not attempt all phases in one unreviewed patch.
- Do not modify unrelated user changes in the worktree.
- Do not add backward compatibility without a concrete persisted-data need.
- Stop and ask the user if a behavior is not resolved by this document.
- Do not infer shared-space, migration conflict, or data-loss behavior.
- Run a code-review agent after each implementation phase and address critical
  and high findings.
- Report exact test/analyzer results; never claim whole-product health from
  targeted tests alone.

## Final Completion Criteria

- A user can choose Cloud or Local Only explicitly during onboarding.
- A Local Only user can complete setup and use every confirmed local feature
  without a Supabase account or user-scoped remote call.
- Local profile data and attachments are encrypted and recoverable only with
  device access or the user-held recovery key.
- Local portfolios provide current Private Space financial behavior without
  household storage or collaboration semantics.
- Transactions, categories, imports, wallets, transfers, balance adjustments,
  pockets, recurring, reminders, reports, rates, settings, and backup satisfy
  the confirmed behavior; Local Only home-screen widgets remain disabled.
- Cloud-only surfaces are discoverable but cannot be bypassed.
- Cloud-to-Local and Local-to-Cloud migrations are explicit, verified, and
  non-destructive to their source.
- Cloud mode behavior remains unchanged.
- No Local Only financial records are sent to Supabase, Storage, Edge Functions,
  native upload queues, or widget storage. Application-supplied logs and
  Crashlytics context pass the tested redaction boundary, and product copy
  accurately discloses automatic redacted technical diagnostics.
- Full formatting, analysis, security review, targeted tests, and complete test
  suite verification are reported accurately.
