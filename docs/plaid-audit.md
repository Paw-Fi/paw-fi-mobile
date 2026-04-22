Findings
- Critical: plaid-webhook calls mergePlaidSyncStatusMetadata(...) without importing it, so the repo version of the webhook handler is broken at compile/runtime (moneko-web/supabase/functions/plaid-webhook/index.ts:1-5,148).
- Critical: plaid-exchange-public-token exchanges the public_token before several failure/return paths, but does not compensate with /item/remove, so it can create orphaned, still-billable Plaid Items (moneko-web/supabase/functions/plaid-exchange-public-token/index.ts:181-223,245-257,319-347,410-425).
- Critical: transaction webhooks are logged but explicitly do not enqueue sync jobs, so the app is not following Plaid’s recommended sync lifecycle for Transactions freshness (moneko-web/supabase/functions/plaid-webhook/index.ts:205-212).
- Critical: the /transactions/sync loop does not handle Plaid’s TRANSACTIONS_SYNC_MUTATION_DURING_PAGINATION restart requirement, which risks missed or duplicated updates during long paginated syncs (moneko-web/supabase/functions/plaid-sync-transactions/index.ts:499-580).
- High: update mode is only partially implemented. The app handles ITEM_LOGIN_REQUIRED and PENDING_EXPIRATION, but not PENDING_DISCONNECT, LOGIN_REPAIRED, or NEW_ACCOUNTS_AVAILABLE (plaid-webhook/index.ts:25-29,160-203; grep found no handlers for the missing webhooks).
- High: the main mobile “Connect Bank” entrypoint is still hard-disabled with an immediate comingSoon return, so the initial Link flow is not fully available from the main wallet UI (moneko-mobile/lib/features/wallets/presentation/pages/wallets_page.dart:590-612).
- High: offboarding is incomplete. /item/remove exists, but user account deletion does not call it before local cascade delete, and there is no mobile disconnect UI (moneko-web/supabase/migrations/20260421130000_fix_account_deletion_system_wallet_cleanup.sql:83-113; moneko-mobile grep found no Plaid disconnect flow).
- High: duplicate-item prevention is weaker than Plaid recommends. The app mostly checks by institution and idempotency, not by account-level metadata before exchange, and there is no duplicate-specific UX (plaid-create-link-token/index.ts:89-115; plaid_link_service.dart:32-40; plaid_sync_walkthrough_page.dart:170-185).
- Medium: operational logging is incomplete for Plaid support. request_id and link_session_id are not consistently captured, while some logs contain financial PII such as merchant names, amounts, and dates (shared/plaid-client.ts:84-109,263-299; plaid_link_service.dart:32-57; plaid-sync-transactions/index.ts:750-775).
- Medium: the mobile manual refresh button calls plaid-sync-transactions directly instead of the dedicated Plaid refresh path, so it bypasses /transactions/refresh (plaid-item-control/index.ts:166-245; wallets_page.dart:725-732).
- Medium: test coverage is helper-only. I found no end-to-end or function-level tests for plaid-webhook, plaid-exchange-public-token, plaid-item-control, plaid-maintenance, or the processor path (moneko-web/supabase/functions/_tests/*plaid*; no Plaid tests under moneko-web/supabase/tests).
Checklist
Item	Status	Notes
Initial Link flow	Partially implemented	Backend exists, walkthrough exists, main mobile entrypoint is disabled
Item creation and account linking	Partially implemented	Exchange/upsert/account fetch works; linked wallet creation is a second-step review flow
1. Transactions core workflow	Partially implemented	Uses /transactions/sync and cursors, but webhook-driven sync is disabled and pagination edge handling is incomplete
2. Activate update mode entrypoint	Partially implemented	Handles ITEM_LOGIN_REQUIRED and PENDING_EXPIRATION; missing PENDING_DISCONNECT
3. Messaging and UI for update mode	Partially implemented	Reconnect CTA exists, but messaging is generic and not clearly update-mode specific
4. Dismiss prompts after update mode / LOGIN_REPAIRED	Partially implemented	Successful reconnect clears backend relink state, but LOGIN_REPAIRED is unhandled and UI refresh is brittle
5. Prompt for new accounts in update mode	Missing	No NEW_ACCOUNTS_AVAILABLE handling and no account_selection_enabled update-mode flow
6. /item/remove and offboarding	Partially implemented	Manual remove and some subscription cleanup exist; user deletion and local data cleanup are incomplete
7. Duplicate Items	Partially implemented	Institution-level heuristics only; no strong pre-exchange duplicate prevention or UX
8. Logging	Partially implemented	Some audit tables exist, but key Plaid identifiers are missing and some logs are too sensitive
Detail
1. Transactions core workflow: Partially implemented  
The backend creates Plaid link tokens, exchanges public_token, stores the Item and accounts, and uses /transactions/sync with a saved cursor (plaid-create-link-token/index.ts:197-204, plaid-exchange-public-token/index.ts:181-347, plaid-sync-transactions/index.ts:473-597). That aligns with Plaid’s core Transactions pattern. It does not satisfy production readiness because transaction webhooks do not enqueue sync (plaid-webhook/index.ts:205-212), the webhook file itself currently references a missing import (plaid-webhook/index.ts:148), and the sync loop does not handle mutation-during-pagination restart semantics. Risk: stale data, dropped updates, and broken webhook processing.
2. Activate entrypoint for update mode: Partially implemented  
The system marks connections as needs_reauth for ITEM_LOGIN_REQUIRED from both sync errors and ITEM webhooks (plaid-sync-transactions/index.ts:627-652, plaid-webhook/index.ts:160-203). PENDING_EXPIRATION is also treated as a reconnect signal because it is in REAUTH_EVENT_CODES (plaid-webhook/index.ts:25-29). The missing piece is PENDING_DISCONNECT, which Plaid explicitly recommends treating as an update-mode trigger. Risk: US/CA Items can lapse without surfacing the reconnect UX in time.
3. Messaging and UI for update mode: Partially implemented  
There is a reconnect CTA in the wallet screen and a reconnect picker (wallets_page.dart:541-584). The walkthrough can be launched in reconnect mode by passing connectionId (plaid_sync_walkthrough_page.dart:131-146). The UX is still generic: the walkthrough copy is new-link onboarding copy, not “your bank needs repair / consent is expiring / add new accounts” copy (plaid_sync_walkthrough_page.dart:285-315). Risk: users may not understand why they are re-entering Link or what outcome to expect.
4. Dismiss prompts after update mode or LOGIN_REPAIRED: Partially implemented  
A successful reconnect clears relink_state and restores healthy status in the backend (plaid-exchange-public-token/index.ts:297-317, plaid-sync-transactions/index.ts:583-597). That is good. It still misses Plaid’s full recommendation because LOGIN_REPAIRED is not handled at all, and the review flow does not directly invalidate bankConnectionsProvider on completion (plaid_sync_review_page.dart:664-682; compare manual sync, which does invalidate it in wallets_page.dart:772). Risk: stale reconnect banners and no automatic prompt dismissal if the user repairs the Item elsewhere.
5. Prompt for new accounts in update mode: Missing  
I found no backend or UI handling for NEW_ACCOUNTS_AVAILABLE, and no use of account_selection_enabled in Link token creation (shared/plaid-client.ts:137-166; grep found no NEW_ACCOUNTS_AVAILABLE or account_selection_enabled). The review screen can display multiple accounts returned by the current flow and auto-create wallets for unlinked ones (bank_sync_review_session.dart:19-29,68-105; plaid_sync_review_page.dart:153-204), but that is not Plaid’s recommended “prompt user to update existing Item to share new accounts” flow. Risk: new accounts never appear until the user accidentally reconnects, and even then the app lacks explicit consent/add-skip UX.
6. /item/remove and offboarding: Partially implemented  
The code has a proper /item/remove wrapper and a remove_item control path (shared/plaid-client.ts:294-299, plaid-item-control/index.ts:121-151, shared/plaid-remove.ts:10-69). Lifecycle cleanup also runs for inactive subscriptions and scheduled removal (plaid-maintenance/index.ts:177-285, stripe-webhook/index.ts:209-259). Gaps remain:
delete_user_account() deletes local user data but does not call Plaid first (20260421130000_fix_account_deletion_system_wallet_cleanup.sql:83-113).
The mobile app has no visible disconnect/unlink bank flow.
Local cleanup leaves bank_accounts, bank_transaction_raw, and imported provider payloads in place unless other cascades happen.  
Risk: unnecessary Plaid billing, incomplete user offboarding, and excessive retained bank data.
7. Duplicate Items: Partially implemented  
There is some protection: plaid-create-link-token looks for an existing active Plaid connection by institution ID and switches to update/reconnect mode if it finds one (plaid-create-link-token/index.ts:89-115). Exchange idempotency and DB uniqueness also reduce duplicate inserts (plaid-exchange-public-token/index.ts:125-179; unique indexes on provider transaction IDs in SQL). This falls short of Plaid’s duplicate-item guidance because the client only captures institutionId and institutionName from Link success, not account metadata or link_session_id (plaid_link_service.dart:32-40), and there is no duplicate-specific UI. duplicate_group_key exists in schema but appears unused (20260410_plaid_production_hardening.sql:129-135). Risk: users can still create multiple billable Items for the same institution, then see confusing duplicate accounts or imports.
8. Logging: Partially implemented  
The app has some good operational primitives: webhook events are stored in bank_webhook_events and sync attempts in bank_sync_audit (20260120_bank_sync_resilience.sql:97-139, plaid-sync-transactions/index.ts:347-365). It does not meet Plaid’s recommended troubleshooting standard because:
request_id is not consistently surfaced or stored, even though the Plaid client types expose it for some endpoints (shared/plaid-client.ts:263-299).
link_session_id is not captured from mobile Link callbacks (plaid_link_service.dart:32-57).
Logging is inconsistent on item_id and account_id.
Some logs include merchant names, dates, amounts, and account IDs (plaid-sync-transactions/index.ts:750-775).  
Risk: harder support escalation with Plaid, while simultaneously storing more financial PII than necessary.
Missing Pieces
- Missing webhook handling: PENDING_DISCONNECT, LOGIN_REPAIRED, NEW_ACCOUNTS_AVAILABLE.
- Missing update-mode request shaping: no account_selection_enabled, no explicit update-mode config beyond passing access_token.
- Missing sync behavior: transaction webhooks do not enqueue jobs.
- Missing cleanup logic: no Plaid offboarding in delete_user_account().
- Missing UI: active “Connect Bank” entrypoint, disconnect bank flow, duplicate-item warning flow, new-account update prompt flow.
- Missing observability: link_session_id, consistent request_id, and webhook idempotency usage.
- Missing tests: end-to-end Plaid function tests and webhook lifecycle tests.
Privacy, Retention, Cost
- Cost: orphaned Items can be created if exchange succeeds and later persistence fails (plaid-exchange-public-token/index.ts:181-223,245-257,410-425).
- Cost: user deletion can remove local rows without calling /item/remove, which can leave billing active remotely (20260421130000_fix_account_deletion_system_wallet_cleanup.sql:83-113).
- Privacy: raw provider payloads are stored on bank_accounts, expenses, and bank_transaction_raw (20260115_salt_edge_integration.sql:137,225-226; 20260119_bank_provider_normalization.sql:179-187; shared/bank-sync.ts:389-408).
- Privacy: retention cleanup only deletes old webhook events and sync audit rows, not raw transaction staging or expense payloads (plaid-maintenance/index.ts:288-317).
- Privacy: debug logs include transaction content in sandbox or when explicitly enabled (plaid-sync-transactions/index.ts:729-775).
Prioritized Remediation
Critical
1. Fix plaid-webhook import breakage and add a deployment test for the function.
2. Add compensating /item/remove cleanup after any post-exchange failure in plaid-exchange-public-token.
3. Enqueue deduped sync jobs from Plaid transaction webhooks and use webhook idempotency keys.
4. Handle TRANSACTIONS_SYNC_MUTATION_DURING_PAGINATION by restarting from the original cursor.
5. Call /item/remove during full user account deletion before local cascade delete.
High
1. Add explicit handlers for PENDING_DISCONNECT, LOGIN_REPAIRED, and NEW_ACCOUNTS_AVAILABLE.
2. Implement real update-mode token options, including account_selection_enabled for new-account consent flows.
3. Re-enable a real mobile “Connect Bank” entrypoint or remove the dead UI until launch-ready.
4. Route manual refresh UI through plaid-item-control so it uses /transactions/refresh.
5. Add a real disconnect/unlink bank UI and finish local cleanup policy for bank accounts and retained provider payloads.
6. Capture and persist link_session_id, request_id, item_id, and account_id for support/debugging.
Medium
1. Strengthen duplicate detection using account-level Link metadata before token exchange.
2. Add tailored reconnect/new-account messaging instead of generic onboarding copy in the walkthrough.
3. Invalidate bankConnectionsProvider after reconnect review completion so prompt dismissal is immediate.
4. Add integration tests for webhook state transitions, orphan cleanup, refresh flow, and duplicate handling.
5. Reduce financial PII in logs and document retention windows by table.
Low
1. Either implement duplicate_group_key or remove it.
2. Make Plaid redirect/package config environment-driven instead of hardcoded in shared/plaid-client.ts:32-33.
Suggested Event Flows
1. ITEM_LOGIN_REQUIRED / PENDING_EXPIRATION / PENDING_DISCONNECT
Set relink_state, show reconnect banner, create update-mode link_token with existing access_token, run Link, exchange token, clear prompt, enqueue sync.
2. LOGIN_REPAIRED
Clear reconnect prompt state immediately, invalidate cached bank-connection data, enqueue a sync.
3. NEW_ACCOUNTS_AVAILABLE
Persist a “new accounts available” prompt state, create update-mode token with account selection enabled, let the user choose accounts, then show an add/skip review instead of auto-linking all returned accounts.
4. Exchange failure after successful Plaid item creation
If any DB write, account fetch, or queue step fails after /item/public_token/exchange, call /item/remove before returning failure.