# Wallet Auto Capture Implementation Plan

## Purpose

This document is the implementation handoff for adding automatic transaction capture to Moneko on both iOS and Android while preserving the existing Siri voice logging flow.

It is written so another coding agent can execute the work with minimal ambiguity.

## Outcome

Implement a new cross-platform "auto capture" capability with:

- iOS: Apple Wallet transaction automation via Shortcuts + App Intents
- Android: user-enabled notification ingestion from recently active apps
- Shared backend: a new Supabase Edge Function named `save-wallet-transaction`
- Shared category behavior: exactly aligned with the category system already used by `analyze-expense`
- Existing Siri voice logging remains untouched

## Key Product Decisions

### Confirmed decisions

- Keep the existing voice-based Siri expense logging flow.
- Add a second iOS flow specifically for Apple Wallet transaction automations.
- Add an Android flow based on notification access.
- Use a single backend function named `save-wallet-transaction`.
- `save-wallet-transaction` must both analyze and save.
- It must preserve the same category behavior as `analyze-expense`, including:
  - built-in categories
  - custom categories
  - hidden categories
  - category remaps
  - category preferences
- Android should use the "recent notification apps only" approach.
- Android app toggles must default to off.
- Users choose the destination space in advance.

### Explicitly rejected approaches

- Do not use `analyze-expense` directly as the primary Wallet ingestion path.
- Do not prompt for destination space during the happy-path capture flow.
- Do not maintain a giant hardcoded global banking-app allowlist as the only Android strategy.
- Do not auto-enable any Android app sources by default.
- Do not modify the current voice Siri flow except where small shared refactors reduce duplication.

## Existing Implementation To Reuse

### Mobile iOS

- Existing Siri transaction orchestration lives in `moneko-mobile/ios/Runner/AppDelegate.swift`.
- Existing voice logging flow starts at `moneko-mobile/ios/Runner/AppDelegate.swift:687`.
- Existing `AppShortcutsProvider` is in `moneko-mobile/ios/Runner/AppDelegate.swift:1866`.
- Existing Flutter/native auth bridge is:
  - `moneko-mobile/lib/core/services/siri_shortcut_auth_service.dart`
  - `moneko-mobile/ios/Runner/AppDelegate.swift:1941`
- Existing app-group-backed configuration sync is:
  - `moneko-mobile/lib/features/home/presentation/services/widget_sync_manager.dart:48`
  - `moneko-mobile/lib/core/services/widget_service.dart:131`

### Web / Supabase

- Existing analysis function:
  - `moneko-web/supabase/functions/analyze-expense/index.ts`
- Existing save functions:
  - `moneko-web/supabase/functions/save-expense/index.ts`
  - `moneko-web/supabase/functions/save-transactions-batch/index.ts`
  - `moneko-web/supabase/functions/save-income/index.ts`
- Existing category system helpers:
  - `moneko-web/supabase/functions/shared/user-categories.ts`
  - `moneko-web/supabase/functions/shared/analyze-core.ts`

## High-Level Architecture

### Shared backend

Create a new function:

- `moneko-web/supabase/functions/save-wallet-transaction/index.ts`

Responsibilities:

- authenticate caller
- validate payload
- normalize transaction input
- load category context exactly like `analyze-expense`
- resolve category using the same user rules
- dedupe
- save the final expense
- learn category preference if save succeeds
- return saved row or duplicate result

### iOS path

- User creates Apple Shortcuts personal automation using Wallet trigger.
- Shortcut runs a new Moneko App Intent action.
- Native iOS code sends structured Wallet data to `save-wallet-transaction`.
- The backend resolves category and saves immediately.

### Android path

- User grants Notification Access.
- Moneko tracks recently active notification source apps.
- User manually enables selected apps.
- Enabled app notifications are parsed locally.
- Structured transaction payloads are sent to `save-wallet-transaction`.
- The backend resolves category and saves immediately.

## Source Of Truth For Category Behavior

This is the most important requirement.

`save-wallet-transaction` must preserve the category behavior already used by `analyze-expense`.

### Required shared category behavior

From `moneko-web/supabase/functions/analyze-expense/index.ts` and shared helpers, the new function must reuse:

- `fetchUserCustomCategories`
- `fetchUserHiddenCategories`
- `mergeAllowedCategories`
- `fetchUserCategoryPreferences`
- `fetchUserCategoryRemaps`
- `applyPreferencesToItems`
- `applyCategoryRemap`
- final coercion to the allowed category set

### Required category resolution order

The Wallet flow must preserve this order:

1. Create an initial category guess from the Wallet/notification payload.
2. Apply explicit remap.
3. Apply learned preference only if remap did not lock the category.
4. Apply remap again after preference application.
5. Coerce the category into the user's allowed category set.

This mirrors the logic in `moneko-web/supabase/functions/shared/analyze-core.ts:4625`.

### Why this matters

Without this, Wallet/notification-captured transactions will behave differently from AI-analyzed manual transactions, which will confuse users and weaken trust in the category system.

## Detailed Backend Plan

### New function

Create:

- `moneko-web/supabase/functions/save-wallet-transaction/index.ts`

### Recommended request shape

```json
{
  "captureSource": "ios_wallet_shortcut",
  "userId": "optional-but-validated-against-jwt",
  "householdId": null,
  "isPortfolio": false,
  "idempotencyKey": "sha256-key",
  "clientCreatedAt": "2026-03-11T09:14:22Z",
  "transaction": {
    "merchantName": "Starbucks",
    "rawMerchant": "STARBUCKS 1234",
    "amount": 6.45,
    "currency": "USD",
    "date": "2026-03-11",
    "cardLabel": "Apple Card",
    "network": "Visa",
    "note": "Wallet automation",
    "externalSourceId": "optional-device-event-id",
    "packageName": null,
    "locale": "en-US"
  }
}
```

`captureSource` should allow values like:

- `ios_wallet_shortcut`
- `android_notification_listener`

### Recommended response shape

```json
{
  "success": true,
  "duplicate": false,
  "data": {
    "id": "expense-id",
    "category": "food_and_drink",
    "amount_cents": 645,
    "currency": "USD"
  },
  "meta": {
    "captureSource": "ios_wallet_shortcut",
    "resolvedCategory": "food_and_drink"
  }
}
```

### Authentication requirements

- Require valid Authorization header.
- Resolve caller using the same safe pattern as `analyze-expense`.
- If `userId` is provided in the body, it must match the authenticated caller unless the request is from a trusted internal path.

### Destination scope requirements

Support:

- personal
- household
- portfolio

Behavior should match `save-expense` semantics for household/portfolio handling.

### Dedupe requirements

Implement durable dedupe in `save-wallet-transaction`.

Minimum fingerprint inputs:

- resolved user id
- destination scope
- normalized merchant
- amount
- currency
- date
- optional card label
- optional external source id
- capture source

Behavior:

- if exact duplicate is found, return `success: true` and `duplicate: true`
- do not create a second expense row

### Save path requirements

Use logic equivalent to `save-expense`, not `save-transactions-batch`, because Wallet/notification capture is a single-item path.

The function should:

- normalize amount into cents
- sanitize/coerce category like current save logic
- insert into `expenses`
- support household split behavior if required
- learn category preference after successful save

### Category guess strategy

The initial category guess should be cheap.

Preferred order:

1. deterministic merchant/category map if available
2. description-based heuristic
3. optional lightweight AI fallback only when confidence is low

Do not invoke the full `runAnalyzeExpense` path for normal structured Wallet events unless absolutely necessary.

### Shared helper refactor recommendation

To avoid duplicating category-resolution logic across `analyze-expense` and `save-wallet-transaction`, extract a shared helper if needed.

Recommended shared utility responsibilities:

- load user category context
- resolve final category for a transaction item
- expose one function usable by both `analyze-expense` and `save-wallet-transaction`

Example candidate shared file:

- `moneko-web/supabase/functions/shared/category-resolution.ts`

This is not strictly required, but highly recommended.

## Detailed iOS Plan

### Goal

Add a second App Intent that is specifically designed for Apple Wallet Shortcuts automation.

### Constraints

- Keep the current Siri voice logging flow unchanged.
- Do not ask the user to pick the destination space at runtime.
- Use the existing auth bridge and app-group storage.

### Native files

Primary native file:

- `moneko-mobile/ios/Runner/AppDelegate.swift`

### New App Intent

Add a new intent, for example:

- `LogWalletTransactionIntent`

It should be a separate App Intent from `LogExpenseWithSiriIntent`.

### Suggested Wallet parameters

Use structured parameters instead of freeform text:

- `merchantName: String?`
- `rawMerchant: String?`
- `amount: Double?`
- `currencyCode: String?`
- `transactionDate: String?`
- `cardLabel: String?`
- `externalSourceId: String?`

These fields must be finalized after validating actual Shortcuts Wallet input on a physical iPhone.

### Native runtime flow

1. App Intent is triggered from Shortcuts automation.
2. Read preconfigured Wallet destination from app-group storage.
3. Load auth context using existing Siri auth bridge.
4. Refresh token if expired using the current refresh path.
5. Build native short-window idempotency key.
6. Fail fast if duplicate is detected locally.
7. Call `save-wallet-transaction` with structured payload.
8. Return short dialog text.

### Reuse from current iOS logic

Re-use or extract from the current Siri flow in `AppDelegate.swift`:

- auth loading
- auth refresh
- HTTP request construction
- local idempotency slotting
- error mapping

Recommended refactor:

- extract shared helper methods so the new Wallet intent and current Siri text intent do not duplicate transport/auth code

### Add App Shortcut registration

Update the existing app shortcuts provider in:

- `moneko-mobile/ios/Runner/AppDelegate.swift:1866`

Add the new Wallet action so it appears in Shortcuts.

### Flutter settings changes for iOS

Primary UI file:

- `moneko-mobile/lib/features/profile/presentation/pages/settings_page.dart`

Add a new Wallet Auto Capture section:

- enabled state
- default destination space selector
- status row
- open Shortcuts CTA
- setup instructions

### App-group configuration changes

Reuse existing widget/app-group sync infra:

- `moneko-mobile/lib/core/services/widget_service.dart`
- `moneko-mobile/lib/features/home/presentation/services/widget_sync_manager.dart`

Add Wallet config storage keys such as:

- `wallet_capture_enabled`
- `wallet_default_scope_id`
- `wallet_default_scope_name`
- `wallet_default_is_portfolio`

### iOS onboarding flow

In-app guidance should instruct the user to:

1. Open Shortcuts.
2. Create Personal Automation.
3. Choose Wallet trigger.
4. Select cards to watch.
5. Enable `Run Immediately`.
6. Add Moneko's Wallet action.
7. Map Shortcut Input fields to the App Intent fields.
8. Save automation.

### iOS failure cases

Handle these explicitly:

- missing auth context
- expired session that cannot refresh
- missing destination config
- missing amount/currency/date
- duplicate request
- backend timeout
- household membership no longer valid

### iOS test plan

Must verify on real device:

- Wallet Shortcut Input field availability
- successful save into personal space
- successful save into household space
- duplicate automation retry
- expired auth recovery
- missing/incomplete input handling

## Detailed Android Plan

### Goal

Implement notification-based transaction auto capture using the safest global strategy:

- recent notification apps only
- all apps disabled by default
- user-managed allowlist

### Why this strategy

Because Moneko is global and cannot reliably maintain a perfect bank-app list for 200+ countries.

This approach avoids needing a giant global package registry and lets users choose the apps that matter to them.

### Native Android implementation

Add a `NotificationListenerService`.

Responsibilities:

- observe incoming notifications after user grants Notification Access
- record recent source apps locally
- only parse notifications from enabled package names
- extract structured transaction candidates
- call `save-wallet-transaction`

### Android source app list strategy

Do not build the list from all installed apps.

Instead:

1. User grants Notification Access.
2. Moneko begins recording apps that actually post notifications.
3. Moneko shows those apps in settings under recent apps.
4. Every app toggle defaults to off.
5. User manually enables the apps Moneko should process.

### Android data model

Store locally:

- `notification_capture_enabled`
- `enabled_notification_packages`
- `recent_notification_packages`
- `last_seen_at_by_package`
- default destination scope config

Each recent app record should contain:

- package name
- app label
- icon if convenient
- last seen timestamp
- enabled boolean

### Android notification flow

1. Notification arrives.
2. Record its package name in recent apps registry.
3. If package is not enabled, ignore for parsing.
4. If package is enabled, run parser.
5. If parser confidence is sufficient and required fields exist, call backend.
6. Otherwise ignore or flag as incomplete, depending on chosen UX.

### Parsing strategy

Support a pluggable parser pipeline.

Suggested layers:

- source-specific parser for known high-signal apps
- generic parser fallback for unknown apps

Parse for:

- merchant text
- amount
- currency
- timestamp/date
- package name
- optional card/account/source hints

### Android parser rules

- normalize currency symbol to ISO code
- normalize decimal separators
- normalize merchant casing and whitespace
- reject ambiguous notifications
- avoid false positives over aggressive saving

### Android permission UX

Before requesting Notification Access, show an in-app disclosure explaining:

- why Moneko needs notification access
- that access is granted at OS level to Moneko
- that Moneko only processes apps the user explicitly enables
- that all apps start off disabled
- that users can revoke access anytime

### Android settings UI

Add an Android-only section in settings:

- Notification Access status
- Open system settings CTA
- destination space selector
- recent notification apps list
- all toggles default off
- enabled apps summary

Recommended sections:

- `Enabled apps`
- `Recent notification apps`
- `Privacy & how it works`

### Android failure cases

Handle these explicitly:

- notification access not granted
- notification access revoked
- source app not enabled
- grouped/reposted duplicate notifications
- redacted notifications with missing content
- locale parsing failures
- backend timeout or save failure
- app sends generic non-transaction notifications

### Android test plan

Must verify on real devices:

- recent app discovery works
- all toggles default to off
- only enabled packages are parsed
- duplicate notifications are not double-saved
- parser handles common currency formats
- unsupported notifications are ignored
- save goes to correct destination scope

## Flutter App Changes

### Settings page

Primary file:

- `moneko-mobile/lib/features/profile/presentation/pages/settings_page.dart`

Add a dedicated cross-platform Auto Capture section with platform-specific content.

#### iOS content

- Wallet setup status
- destination selector
- open Shortcuts
- setup guide

#### Android content

- Notification Access status
- enable feature toggle
- destination selector
- recent apps toggle list
- disclosure text

### Services / storage

Add or extend services to store:

- default destination scope for auto capture
- platform-specific feature settings
- Android enabled package allowlist

If a new Flutter service is introduced, keep it small and focused.

## API / Data Contracts

### Destination scope contract

The mobile clients should send:

- `householdId`
- `isPortfolio`

Behavior:

- if `householdId == null`, save as personal
- if `householdId != null` and `isPortfolio == false`, save/share as household transaction
- if `householdId != null` and `isPortfolio == true`, save in portfolio/private scoped space

### Transaction minimum save contract

Both platforms should only call save when these are present:

- positive amount
- valid currency
- valid date or safely derived date
- merchant or description text

If any of these are missing, do not save.

## Observability

Add lightweight telemetry for both platforms and backend.

Track at minimum:

- capture invoked
- capture source platform
- duplicate blocked locally
- duplicate blocked server-side
- save succeeded
- save failed
- parse failed
- missing required fields
- destination missing
- auth missing/expired

Do not log raw sensitive transaction text beyond what is necessary for secure debugging.

## Rollout Plan

### Phase 1

Backend only:

- implement `save-wallet-transaction`
- category reuse complete
- durable dedupe complete
- tests complete

### Phase 2

iOS only:

- add Wallet App Intent
- add settings setup UI
- real-device Wallet mapping validation
- limited internal testing

### Phase 3

Android only:

- add notification listener
- add recent apps registry
- add settings toggle UI
- real-device parser validation

### Phase 4

Staged rollout:

- internal testers
- small beta cohort
- monitor duplicate rate, save success rate, false positives, category correctness

## Implementation Checklist

### Shared backend checklist

- [ ] Create `moneko-web/supabase/functions/save-wallet-transaction/index.ts`
- [ ] Reuse authenticated caller resolution pattern from `analyze-expense`
- [ ] Load custom categories
- [ ] Load hidden categories
- [ ] Merge allowed categories
- [ ] Load category preferences
- [ ] Load category remaps
- [ ] Implement category resolution in the same order as `analyze-expense`
- [ ] Implement deterministic initial category guess
- [ ] Add optional low-cost AI fallback only when needed
- [ ] Implement durable dedupe
- [ ] Save with semantics equivalent to `save-expense`
- [ ] Learn category preference after successful save
- [ ] Return duplicate result without double-saving
- [ ] Add unit/integration tests

### iOS checklist

- [ ] Add `LogWalletTransactionIntent` to `moneko-mobile/ios/Runner/AppDelegate.swift`
- [ ] Add Wallet App Shortcut registration
- [ ] Reuse/extract shared auth + transport helpers from current Siri flow
- [ ] Add native local idempotency for Wallet flow
- [ ] Add app-group keys for Wallet destination config
- [ ] Extend Flutter settings UI for Wallet setup
- [ ] Add destination selector
- [ ] Add Shortcuts setup guide CTA
- [ ] Validate actual Wallet Shortcut Input fields on a physical iPhone
- [ ] Verify personal-space save
- [ ] Verify household-space save
- [ ] Verify duplicate handling
- [ ] Verify expired auth recovery

### Android checklist

- [ ] Add `NotificationListenerService`
- [ ] Add Notification Access onboarding/disclosure flow
- [ ] Add recent notification app registry
- [ ] Add enabled package allowlist storage
- [ ] Ensure all discovered apps are off by default
- [ ] Add settings UI for recent apps toggle list
- [ ] Add destination selector
- [ ] Implement local notification parsing pipeline
- [ ] Implement duplicate prevention for reposted/grouped notifications
- [ ] Only send enabled app notifications to backend
- [ ] Verify ignore-path for non-enabled packages
- [ ] Verify parse success on real-world notification samples
- [ ] Verify missing/ambiguous notifications are not auto-saved

### Cross-platform checklist

- [ ] Keep existing Siri voice logging unchanged
- [ ] Use the same backend `save-wallet-transaction` from both platforms
- [ ] Ensure users configure destination space in advance
- [ ] Add telemetry
- [ ] Add error-state UX copy
- [ ] Validate privacy implications and disclosures

## Validation Requirements Before Marking Complete

Do not mark this feature complete until all of the following are true:

- iOS Wallet automation works on a physical iPhone
- Android notification capture works on physical Android device(s)
- Category outcomes match the existing `analyze-expense` category rules
- No duplicate expenses are created in common retry scenarios
- Existing Siri voice logging remains functional
- Both platforms save into the correct configured destination space

## Important Notes For The Implementer

- Preserve backward compatibility for the current Siri flow.
- Do not introduce hardcoded category logic that bypasses shared user category helpers.
- Do not auto-enable Android app sources.
- Favor small focused helpers over growing `AppDelegate.swift` further without structure.
- Real-device validation is mandatory for both platform capture paths.

## Recommended First Execution Order

1. Implement `save-wallet-transaction` with category reuse and dedupe.
2. Add iOS Wallet App Intent and config UI.
3. Validate iOS on device.
4. Add Android notification listener and recent-app allowlist flow.
5. Validate Android on device.
6. Add telemetry and polish.
