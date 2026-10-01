# Moneko Mobile Performance Audit

Date: 2026-10-01. Scope: the Flutter app, its startup/read ownership, local-first hydration, mutation propagation, provider lifecycle, scrolling, images, and rendering architecture.

## Outcome and evidence limits

The first pass implemented four focused optimization areas: transaction-feed hydration, unused feed diagnostics, shared transaction-row dependencies, and recurring-group rendering. Existing financial formulas, native/aggregate currency rules, routes, mutation ownership, outbox payloads, retry/rollback, bank authority, and visual tokens were retained. No dependency, schema, backend, or generated localization changes were made.

This is a source and deterministic regression audit. It is **not a device frame-time certification**. No representative signed-in profile-mode session, DevTools UI/raster timeline, production request trace, or large real-account SQLite benchmark was recorded. The reported work reductions are verified by source and test counters, not inferred milliseconds. Remaining candidates are explicitly separated from implemented findings.

The initial checkout contained wallet implementation/test changes belonging to other work. Those were left intact; the checkout subsequently incorporated wallet commit `694e4564` (`fix(wallets): refresh safely and update transfer balances`). This audit does not claim authorship of that wallet work. The final diff identifies this audit's changes independently.

Framework: Flutter 3.35.7, Dart 3.9.2, installed Riverpod/hooks_riverpod 2.6.1. Flutter, Riverpod, and adaptive_platform_ui documentation were reviewed through Context7. Architecture index, relevant supporting notes, async/optimistic contract, currency rules, README, and pubspec were reviewed before implementation. CodeGraph supplied structural context; focused source reads covered omitted/truncated Dart bodies and edited files. Serena and feedback MCPs were unavailable, so normal file tools and Flutter commands were used.

## Second pass: code-only investigation of R01–R09

The latest user instruction is **“focus on the code, dont run any flutter command or run the app.”** No further Flutter command, app launch, device profile, test execution, or analyzer run was performed after that instruction. Bare Dart formatting was used for source formatting/parsing only; it is not compilation or behavioral validation. Final bare-Dart formatting completed successfully across 13 touched Dart files (exit 0, analytics suppressed). An earlier formatter invocation completed edits but exited on a sandbox-denied telemetry timestamp write; this was a tooling issue, not a test result.

The first-pass improvements remain intact. This pass adds opt-in tracing, exact-scope/revision request sharing, stale refresh publication guards, all-items database-readiness handling, and removal of discarded wallet projection work. Financial formulas, authority flags, native/aggregate currency handling, pending/outbox writes, retries, rollbacks, occurrence hydration, bank-sync authority, navigation destinations, and visual design remain unchanged in the code diff. **The final second-pass checkout has not been tested or analyzed.** Status “Confirmed and Fixed” below means the source-proven redundant path has an implemented fix; it does not certify the unexecuted final changes for production.

| Finding | Second-pass status | Evidence / remaining boundary |
| --- | --- | --- |
| R01 | Confirmed and Fixed | Controlled overlapping cached-feed case: 3 reconciliation page calls before, 1 after initial sharing fix. Later stale-response/revision refinements have unexecuted regression sources. |
| R02 | Confirmed and Fixed | Full downstream phase fan-out now shares an equal captured identity. Per-user transaction sync stays serialized; newer revisions queue rather than being suppressed. Runtime downstream RPC frequency and cold-wallet initialization-plus-refresh remain unmeasured. |
| R03 | Confirmed but intentionally not changed | Partial financial-summary barrier retained because persisted monthly summaries are derived from potentially partial rows. The separate database-opening/all-items false-empty gap is fixed in source, with unexecuted regressions. |
| R04 | Confirmed and Fixed | Discarded recurring projection generation removed. Concurrent identical legacy inputs share work; different dates/revisions and sequential reads remain distinct. Wallet regressions are unexecuted. |
| R05 | Not reproduced / not meaningful | Repeated full Transactions derivation for unchanged inputs is already avoided by its existing content/filter cache. Signature scans and other derivations have no measured CPU/rebuild hotspot; no new memoization was added. |
| R06 | Confirmed but intentionally not changed | Unbounded eager report/drilldown content is source-confirmed. No permitted large-data layout/gesture measurement supports a further layout conversion. |
| R07 | Requires physical-device measurement | Intrinsic layout exists, but no UI/layout frame cost was recorded. |
| R08 | Requires physical-device measurement | No raster/blur/compositing trace supports altering glass, animation, shadows, clipping or chart appearance. |
| R09 | Requires physical-device measurement | Synchronous SQLite/select/transform paths are instrumented; duration and hidden-tab frequency remain unmeasured. No DB isolation/write-order rewrite. |

### Concrete evidence and its limits

- Before the latest restriction, `transactions_feed_hydration_test.dart` reproduced the overlapping-background/two-foreground case with **Expected: 1; Actual: 3** page requests (`/private/tmp/moneko-performance-r01-before.log`). After the initial coordinator fix, hydration and existing feed tests reported **32 passed** (`/private/tmp/moneko-performance-r01-after.log`). The cached overlap then had **1 page + 2 summary calls**. The summaries still serve reconciliation validation and final visible summary with pending overlays; they were intentionally retained.
- Those 32 tests preceded the final generation/error guards, all-items readiness bridge, full shell coordinator, and wallet sharing implementation. They are **not the final checkout's test result**.
- Added **25 unexecuted regression cases** across five new test files and two additional hydration cases. They cover exact-key sharing, no completed-result cache, failure cleanup, reentrant registration, changed scope/revision, complete phase sharing, canceled owner handoff, serialized newer sync revisions, late stale responses/errors, mutation follow-up, background-failure indicator release, opening/failed/empty database handling, obsolete opening readers, wallet current/historical ranges, and committed wallet-input revisions. Additional local-service regressions retain the optimistic EUR 40 row through overlapping remote reconciliations.
- Source-proven removal: **one projection generation/mapping/deduplication pipeline per reached legacy wallet load → zero**. The awaited recurring and occurrence-resolution reads remain. Expected concurrent same-scope/current-end-date input loads: **2 → 1**; this is an unexecuted regression expectation, not an observed device/network count.
- No new quantitative claim is made for SQLite latency, derived CPU time, consumer rebuilds, constructed report rows, navigation/startup milliseconds, UI frames, or raster frames. The earlier recurring-row/consumer evidence belongs to the first pass below.
- A physical iPhone was discovered before the restriction; no app was launched on it. Its availability does not establish profile evidence.
- The task-scoped `git diff --check` passes. A separate concurrent `pubspec.yaml` version bump was left untouched; the workspace-wide check flags its pre-existing trailing-space style on the changed version line. No configuration change was made by this pass.

### Tracing contract

`lib/core/monitoring/performance_trace.dart` enables diagnostics only when `MONEKO_PERFORMANCE_TRACE` is requested in a non-release build (or a test sink is installed). It uses lazy identity callbacks, structured request/start/end events, `TimelineTask`, and elapsed microseconds. Release tracing is disabled. Raw search text is replaced by a process-local diagnostic fingerprint; auth headers/tokens are used only as conservative in-memory key identity and are never logged. Fingerprints are not deduplication keys.

Feed identity includes user, household, normalized currency set, category/categories, wallet/unassigned policy, type, date range, summary interval, page size, service generation, committed database revision, and optimistic edit generation. Actual request sharing uses the complete query object, not a reduced log fingerprint. Reasons distinguish provider initialization, background reconciliation, explicit refresh, mutation refresh, revision follow-up, shell startup and foreground resume. Unattributed existing consumers remain `provider-read`; no claim is made that every backend client in the app is instrumented.

Shell request/phase traces include active tab, scope/currency/cycle and refresh generations. Wallet traces distinguish history, month snapshot, FX-provider read, legacy input request/execution, actual filtering and pending-local reads. SQLite traces distinguish page, row transform, count, and the **eight legitimate summary SQL statements** (totals, category/year/period, currency category/year/period/type), including pending/synced read policy and cursor identity. Eight summary selects are not automatically eight duplicate logical requests. Async spans include waiting time; only synchronous select/filter/row-transform spans measure their bounded synchronous work.

No trace result cache, TTL, new financial snapshot authority, extra DB query, or whole-page invalidation was introduced for diagnostics. The monotonic database revision increments at the existing transaction-change notification boundary. It is process-local coordination metadata, independent of persisted financial authority.

## Classification

| Severity | Interpretation |
| --- | --- |
| Critical | Demonstrated widespread correctness/performance failure; none established in this audit. |
| High | Proven unnecessary work or hydration barrier on an important path, or a high-impact candidate explicitly awaiting profiling. |
| Medium | Proven avoidable reactive/DB work, or a meaningful scoped candidate. |
| Low | Small or bounded work that does not justify changing behavior without measurement. |
| Already Correct / No Change Needed | Existing architecture satisfies the inspected requirement; not a promise about all runtime scenarios. |

## Implemented findings

### P01 — High: a complete cached feed waited for a remote summary

- **Area/files/providers:** Transactions and all consumers of `transactionsFeedProvider`; `lib/features/home/presentation/state/transactions_feed_provider.dart`, `LocalFirstTransactionsFeedService`, `TransactionsFeedNotifier`.
- **Previous behavior/evidence:** Initial load awaited `Future.wait(fetchSummary, fetchPage)`. A complete local page returned immediately, but online `fetchSummary` still awaited the backend. The notifier could not publish either result until both completed. The existing subsequent background reconciliation performed another remote page/summary pass.
- **Root cause:** Local page and remote summary shared one initial publication barrier. Already correct: the database had exact scoped completeness markers, local page/summary readers, pending-write authority, and background refresh guards; these were reused.
- **Change:** Added optional `fetchCachedSnapshot`. The local service returns a page plus summary only for the exact complete query; the notifier publishes it before starting its existing background reconciliation. Complete empty snapshots also count as usable. Partial caches keep the original remote-summary path.
- **Risk/boundary:** Do not fabricate full totals from partial rows. Query identity remains user, household, selected currency set, category/categories, wallet, type, search, dates, and summary interval. Existing completeness-marker maintenance remains authoritative. No new time-based cache was added. SQLite reads must still complete before local content appears.
- **Expected benefit:** Backend latency no longer gates complete-cache hydration. In the controlled one-page cached case, startup has **one remote page and two remote summaries**, rather than the three summary calls reachable in the previous initial-load-plus-reconciliation path. The two retained summaries serve reconciliation validation and the final visible summary with current pending overlays.
- **Verification:** Delayed backend tests prove local EUR 20 is published before backend EUR 30, no subsequent loading state during background reconciliation, canonical EUR 30 persists in SQLite, and a new notifier reads it. Tests cover complete empty, absent/partial cache, offline cache, failure retention, optimistic edit during reconciliation, and explicit refresh while a response is pending. Existing feed tests cover pagination/tail preservation, remote deletion, recurring-template exclusion, and local merges. This proves notifier state and persistence; it is not a screenshot or frame trace of every consuming page.

### P02 — Medium: opening SQLite briefly looked like a successfully empty feed

- **Area/files/providers:** Same feed provider factory and notifier.
- **Previous behavior/evidence:** `transactionsFeedServiceProvider` returned `EmptyTransactionsFeedService` while `localDatabaseProvider` was loading. Calling its successful empty methods could set `hasLoadedInitial = true` before the database resolved, allowing consumers to interpret startup as genuine zero/empty data.
- **Root cause:** An unresolved dependency and a valid empty response used the same service contract. Already correct: provider service replacement and generation checks existed.
- **Change:** Database opening now has `OpeningDatabaseTransactionsFeedService`. The notifier remains initially unresolved, then hydrates when the real service arrives. An explicit `EmptyTransactionsFeedService` retains its original successful-empty contract, including existing test overrides and subclasses.
- **Risk/boundary:** With no loaded snapshot, a skeleton until SQLite opens is correct. The first pass did not make all complete-dataset FutureProviders wait on this sentinel; the second-pass all-items bridge below now addresses that separate path, with final validation pending. A database failure still uses the original remote fallback.
- **Expected benefit:** Avoid a false empty/zero publication and its following content replacement during normal database opening.
- **Verification:** Opening-service-to-ready-service test, valid-empty-service test, and existing category-details navigation test pass. An intermediate full run exposed a test-contract timeout; separating the opening sentinel fixed it without changing the existing test or routing.

### P03 — Medium: disabled feed diagnostics still performed DB and list work

- **Area/files/providers:** `LocalFirstTransactionsFeedService.fetchPage`, `fetchAllPages`, and `fetchSummary`.
- **Previous behavior/evidence:** `_homeSpendTrace(String _) {}` was a no-op, but interpolated arguments still evaluated row folds, amount formatting, query formatting, and pending-row checks. `fetchPage` and `fetchAllPages` each ran `_hasPendingLocalRows` solely to construct a discarded diagnostic message.
- **Root cause:** Removing a logging body did not remove evaluation of its arguments. Already correct: functional pending-create and pending-update/delete checks in `fetchSummary` controlled financial authority.
- **Change:** Removed no-op trace calls and their formatting-only helpers. Removed the two call-site pending counts used only by tracing. Retained functional summary/pending checks and all reconciliation counts.
- **Risk:** Low; no returned value or branch depended on the removed diagnostics. Operationally these traces were already silent.
- **Expected benefit:** One fewer SQLite count per affected page/all-pages service invocation, plus no logging-only O(n) folds/formatting. No measured DB latency claim.
- **Verification:** Source data-dependency inspection and existing feed/database/local mutation tests in the full suite; touched-file analyzer clean.

### P04 — Medium: transaction rows reacted to inputs they did not render

- **Area/files/providers:** `lib/shared/widgets/transaction_list_tile.dart`, `homeFilterProvider`, `customCategoryStyleOverridesNotifier`.
- **Previous behavior/evidence:** Internally derived currency flags selected an allocated normalized currency list even though rendering needed only `length > 1`. Every row also mounted a private-category `ValueListenableBuilder`, including shared rows explicitly configured to ignore private styles.
- **Root cause:** Selected dependency identity was broader than the rendered value; an irrelevant listener remained active. Already correct: row-native amount/currency, explicit caller-supplied flags, shared style isolation, theme and locale handling.
- **Change:** Select only the flag-visibility boolean. Bypass the private-style listener when `useCustomCategoryStyleOverrides` is false; reuse the unchanged content builder. Personal rows retain the listener.
- **Risk/boundary:** Parent rows still rebuild when their actual input changes; changing a selected currency set can legitimately rebuild the containing page. This does not promise zero Flutter builds or prevent parent updates.
- **Expected benefit:** No row-content rebuild from same-visibility currency selections or irrelevant private category style changes in shared rows.
- **Verification:** Widget identity tests prove shared rows do not reconstruct title output on private-style changes, personal rows still do, and single-to-single/multiple-to-multiple flag selections do not reconstruct output. Crossing the visibility boundary updates the flag. Existing grouped-row currency, accessibility/text-scaling, and swipe-delete tests pass.

### P05 — High: recurring groups eagerly built every row and registered each read on the page

- **Area/files/providers:** `lib/features/recurring/pages/recurring_transactions_page.dart`; new `lib/features/recurring/presentation/widgets/recurring_series_group_sliver.dart`; `recurringOccurrenceMaterializedProvider`.
- **Previous behavior/evidence:** Each unbounded date group was a `SliverToBoxAdapter` containing a decorated `Column` of every `RecurringTransactionCard`. The page's helper watched materialization for each actionable row. Off-screen rows therefore incurred construction/layout and occurrence reads; an individual read could notify the page consumer.
- **Root cause:** A scrolling group was one eager box, with per-row dependencies owned by the page. Already correct: group order, summary source, confirmation authority, pagination, materialization keys, and unknown-result CTA suppression.
- **Change:** Preserve group decoration/insets and use `DecoratedSliver` plus `SliverChildBuilderDelegate`. Each viewport-built row owns its exact materialization family. Stable transaction keys and index lookup preserve row identity; callbacks use the existing detail/delete paths.
- **Risk/boundary:** Sliver extent estimation differs from eager layout internally. Light/dark geometry and large text are tested, but raster screenshots/native-platform gestures still require device verification. Provider retention policy was not changed: materialization families already visited can remain retained.
- **Expected benefit/evidence:** A 150-series widget test constructs **fewer than 20 cards and fewer than 20 materialization lookups** initially instead of the previous eager 150-row structure. A completed lookup updates its row without reconstructing another mounted card. No frame-time percentage is claimed.
- **Verification:** Five widget tests cover initial laziness, scrolling to row 149, actual tap and swipe/delete interaction, unknown/materialized action suppression, isolated row updates, and matching old/new row rectangles in both themes at text scale 2. Existing recurring controllers and mutation tests run in the complete suite.

## Dataset ownership and already-correct architecture

Scopes and purpose matter: a page-sized row request, full-range summary, recurring occurrence ledger, and household settlement request are not automatically duplicates.

| Area / affected files or providers | Current behavior and evidence | Root/ownership and status | Recommendation, risk, expected benefit, verification |
| --- | --- | --- | --- |
| App initialization: `core/app/app_initialization_provider_v2.dart`, `core/services/init_cache_manager.dart` | Persisted account metadata appears before `initialize_app_v2` reconciles. Metadata is separate from financial SQLite state. | Initialization provider owns metadata; **Already Correct** for inspected cached path. | Leave unchanged. Combining metadata and financial queries could hide scope differences. Source review; no startup device latency recorded. |
| Foreground sync: `core/navigation/main_shell.dart`, `core/sync/mobile_outbox_sync_provider.dart` | `_mobileSyncInFlightByUser` coalesces concurrent outbox/category-remap/delta work per user. Lifecycle guards stop stale continuations. | Shell orchestrates; dispatcher owns durable replay; **Already Correct** for this phase. | Retain guards and replay. Removing sync triggers would risk missed reconciliation; later shell refresh phases are a separate candidate below. Source and existing lifecycle/outbox tests. |
| Main tabs: `MainShell`, visited-tab set, `IndexedStack` | Only visited/active tab roots are built; visited roots stay in keyed elements and existing repaint boundaries. Tab navigation is not preceded by an awaited backend request. Actual fifth root is `BrowsePage`. | Shell owns navigation; **Already Correct** for lazy visitation/state retention. | Preserve mounting/navigation. No blanket keep-alive/provider removal. Source review; existing navigation tests run, no physical-device repeated-tab trace. |
| Dashboard: `features/home/presentation/providers/dashboard_lazy_providers.dart`, Home widgets | Scoped cache generations, local transaction revisions, optimistic rows/tombstones, and cached/previous values participate in reads. Personal calendar hydration intentionally relies on canonical delta reconciliation. Household cached calendar can reconcile in background. | Dashboard query coordinator owns read freshness; shell delta owns canonical writes; **Already Correct** for inspected boundaries. | Do not replace it with a parallel remote-only calendar or drop recurrence suppression. Existing dashboard projection, aggregation, local override and currency tests run. No blanket page-level select split added. |
| Transactions/details: `transactions_page.dart`, `shared/widgets/grouped_transactions_list.dart`, `category_details_page.dart`, wallet/pocket/household detail lists | Main transaction lists use builder slivers and stable row IDs. Feed refresh retains rows and `hasLoadedInitial`; existing consumers distinguish first load from refresh. Pagination preserves the visible tail. | Scoped feed notifier owns page reads; full-range providers serve totals/charts separately; **Already Correct** list architecture, with P01–P04 improvements. | Preserve complete-summary and page-query distinction. Tests cover grouped native rows, converted headers, paging and details. |
| Pockets: `pockets_providers.dart`, `pockets_page.dart`, `pocket_details_provider.dart` | Exact month/scope/currency keys, persisted snapshots, optimistic monthly overlays, and generation checks exist. `_scheduleSilentReload` coalesces paired refresh signals before loading. Previously loaded content survives refresh. | Pockets notifier owns month reconciliation; mutation sheet/outbox owns durable save; **Already Correct** for inspected ownership. | Retain RPC-only spend, local overlay, recurring inclusion and cycle rules. Existing pocket cache/fallback/optimistic/currency/rollback tests run; two unrelated copy tests fail below. |
| Wallets: `wallet_providers.dart`, `wallets_lazy_providers.dart`, `wallets_page.dart`, `wallet_details_page.dart` | Scoped session/persisted snapshots, pending effects and provider-authoritative zero balances are preserved. Current positive cache-bypass requests trigger refresh; clearing a consumed bypass does not recreate the notifier/ref. | Scoped wallet list/page notifiers own reads; existing wallet actions own optimistic effects; **Already Correct** inspected lifecycle protections. | Leave recent wallet fixes intact; no additional invalidation listeners were added. Existing wallet tests run. This audit does not attribute concurrent wallet changes to itself. |
| Recurring reads: `recurring_lazy_providers.dart`, `recurring_providers.dart` | Scoped read models, recurrence overlays, confirmed actual suppression, and background refresh already exist. Confirmation remains checked at the deepest controller. | Recurring read/mutation providers; **Already Correct**, aside from P05 eager row rendering. | Keep forecast/actual separation and all confirmation guards. Existing create/edit/delete/occurrence and offline replay tests run. |
| Reports: `features/insights/presentation/state/monthly_report_provider.dart`, `monthly_report_page.dart` | Cached snapshot is published first; background source loading uses generation checks. Manual refresh preserves the previous snapshot and an `isRefreshing` signal. | Monthly report notifier owns report reconciliation; **Already Correct** cached state lifecycle. | Preserve paid-date, financial-cycle, FX and recurring ledger semantics. Rendering candidates below need measurements, not blanket memoization. Source and existing report tests. |
| Household/shared state: `household_providers.dart`, household dashboard lazy widgets | Scope-specific persisted caches, request deduplicators, generation keys and optimistic split overlays exist. Backend splits remain authoritative. | Household providers own scoped reads; existing command/outbox paths own mutation; **Already Correct** inspected shared cache/read boundaries. | Never substitute inferred split or personal-state data to reduce reads. Existing household splits, members, settlement and currency tests run. |
| Mutation propagation: Home AI, unified transaction sheet, income/recurring/pockets/wallet command providers, outbox | Deterministic saves publish local rows/effects and required signals before remote completion. Retryable work stays queued; terminal rollback is revision-owned. Refresh observers are necessary across dependent surfaces. | One durable mutation owner plus read-side refresh consumers; **Already Correct** fundamental contract. | No signal or invalidation was removed merely because another provider observes it. Existing create/edit/delete, transfer, batch merchant/category, occurrence, retry and rollback tests run. |
| Merchant images: `shared/widgets/merchant_logo.dart` | CachedNetworkImage uses URL cache identity and bounded 72px decode width; Logo.dev requests bounded output. Trusted provider URL → canonical domain → structured-name logo → category fallback stays intact. | Existing image cache and merchant identity contract; **Already Correct** inspected caching/sizing. | No alternate cache, extra fade, identity change or blanket clipping removal. Source and merchant/logo tests; no real-scroll image-cache hit trace. |
| Notifications/auth: device registration service, auth provider and router | Shared device registration coalesces initialization by user/authority and rejects stale generations. External auth/billing/bank operations retain authoritative pending/completion behavior. | Dedicated lifecycle services; **Already Correct** inspected ownership. | Do not make navigation appear faster by bypassing entitlement/session/Plus checks. Existing lifecycle/gating tests run. |

## Remaining findings and intentionally deferred changes

These are actionable audit results, not implemented performance fixes. Severity denotes potential impact or source-proven work, not a measured device slowdown.

### R01 — Medium: foreground and background feed refresh overlapped

- **Status:** Confirmed and Fixed; implemented source, final refinements unexecuted.
- **Area/files/providers:** `transactions_feed_provider.dart`, `TransactionsFeedNotifier`, `LocalFirstTransactionsFeedService`; shared `in_flight_requests.dart`; database transaction revision metadata.
- **Previous behavior/evidence:** Background-only protection did not include explicit refresh. One delayed cached startup plus two foreground callers issued 3 same-scope page reconciliations. The failing-before/passing-after logs are recorded above.
- **Root cause/change:** Both foreground and background now enter one notifier operation keyed by service generation, database revision and mounted edit generation. The local service also shares exact query/revision reconciliation for independent callers. Completed/failed work is removed. A new revision remains a new request. Current-response guards prevent an older response or error from publishing over a newer edit/refresh; an edit during a lone request gets a follow-up. A newer silent failure releases an inherited refresh indicator while retaining content.
- **Already correct/preserved:** Full financial query keys, durable pending-write authority, retained visible rows, pagination/tail merges, remote deletion handling and authorization behavior. Two semantically different summary reads remain.
- **Risk/benefit:** Medium lifecycle/concurrency risk until final regression execution. Verified initial overlap reduction is 3 → 1 pages; no suppression of changed generations is intended. No claim of removing every startup producer or full-history read.
- **Verification:** Initial 32 focused tests passed before later refinements. Additional generation, failure, service sharing and durable optimistic-edit regression sources added but not run. No production request trace.

### R02 — Medium: lower sync sharing did not own downstream shell phases

- **Status:** Confirmed and Fixed for full-phase fan-out; cold-wallet read pair intentionally retained.
- **Area/files/providers:** `main_shell.dart`, `foreground_reconciler.dart`, sync/settlement/FX/active/deferred phases and `_refreshWalletsMainShellData`.
- **Previous behavior/evidence:** Callers joining the same lower sync future each resumed their own downstream phases. This control-flow fan-out is source-confirmed; downstream providers may independently absorb some reads, so it is not an observed count of duplicate backend requests.
- **Root cause/change:** Container-owned coordination covers the complete phase sequence with user, tab, full filter/scope/wallet cycle, database instance/revision, auth-header instance and refresh generations. Different scopes/revisions cannot join stale work. The lower outbox/category/delta sequence retains **per-user serialization**: a newer revision waits then executes its own reconciliation. A surviving caller retries phases skipped by a canceled owner. Phase order, deferred delay/spacing and guards stay intact.
- **Already correct/preserved:** Existing outbox/delta authority, foreground navigation policy, legitimate scoped warming and active/deferred refreshes. No time-based suppression or completed-result cache.
- **Intentionally unchanged:** Shell still refreshes the wallet list, awaits page initialization and then refreshes its page. A cold initialization may already read current data, but bypass flags, persisted snapshots, pending overlays and initialization completeness require runtime evidence before skipping the explicit refresh. Warming keys and family keys were not casually merged.
- **Risk/benefit:** Medium/high lifecycle risk until execution; expected one downstream phase chain per equal overlapping identity. No final measured RPC/DB count or navigation timing.
- **Verification:** Added source regressions for complete phase counts, scope/revision separation, cancellation handoff, sequential refreshes, inactive owners, failures, and serialized revision follow-up. Unexecuted. Read-side tracing added for actual future counts.

### R03 — Medium: partial rows do not prove a complete financial summary

- **Status:** Confirmed but intentionally not changed for partial-summary hydration; all-items opening subfinding fixed in source.
- **Area/files/providers:** Feed completeness markers, `fetchSummary`, `transactionsFeedAllItemsProvider`, new `transactionsFeedReadyServiceProvider`, database `_rebuildSummary`/`monthly_summaries` and full-range consumers.
- **Current behavior/evidence/root:** Exact complete-cache snapshots hydrate immediately. `_rebuildSummary` computes monthly persisted totals from `local_transactions`; a partial row cache therefore yields a partial persisted monthly summary too. It lacks independent complete remote-summary/revision authority and does not cover arbitrary category/wallet/search/date-cycle keys. Reusing it as a complete total would fabricate financial certainty.
- **Change to separate opening gap:** All-items readers wait for the ready service rather than accepting the opening sentinel's empty methods. Dependencies are captured before awaiting, with disposal cancellation before the actual read so obsolete opening generations cannot trigger duplicate work. An opened empty offline DB stays legitimately empty; DB-open error retains remote fallback.
- **Already correct/preserved:** Complete empty snapshots are usable; partial totals remain unresolved through the existing summary path. No new schema, summary authority, zero fallback or change to pending overlays.
- **Risk/benefit:** Partial-summary redesign has high financial/stale-authority risk and is deferred. Ready-service change should prevent false empty publications and obsolete reads; final validation pending.
- **Verification:** Existing negative partial-cache regression remains. New unexecuted tests cover populated offline opening, open failure, true empty DB, and repeated refresh signals while opening. No claim of instant full financial summaries for arbitrary partial caches.

### R04 — Medium: wallet legacy inputs and discarded projection work

- **Status:** Confirmed and Fixed; source-proven discarded work removed, sharing regressions unexecuted.
- **Area/files/providers:** `wallets_lazy_providers.dart`, `LocalWalletsLegacyDataLoader`, history/current-month snapshot, scoped actual/recurring/occurrence loaders, pending-local and FX reads.
- **Previous behavior/evidence:** Each legacy load generated projected expenses, mapped source account bindings and deduplicated them, then used the result only for a trace count and returned actual materialized transactions. This was a pure discarded result. Concurrent history/current snapshot paths could independently load identical wallet/actual/recurring/occurrence inputs.
- **Change:** Removed only that projection pipeline/private helper and unused import. Retained the awaited occurrence resolution and recurring reads. Share concurrent input loads only when full scope, inclusive end date, database instance/revision, auth, household scope, all relevant refresh generations, network state, feed service and wallet-list snapshot match. Different historical ranges, changed inputs and later reads execute separately.
- **Already correct/preserved:** Wallet/provider-zero authority, transfers, actual balances, current/historical cycle calculations and pending effect keys. Shared returned input lists are consumed without mutation. FX still resolves through the existing provider; latest pending rows and active create IDs are still read after input loading, because absorbing those into an older snapshot could miss a mutation.
- **Risk/benefit:** Low risk for pure discarded output; medium for concurrent sharing until tests run. One unused projection pipeline eliminated per reached load. Expected identical overlapping input loads 2 → 1, not yet measured.
- **Verification:** Full data-dependency source review; new unexecuted tests for history/current sharing, distinct historical end dates, no completed-result cache and committed DB revisions. Existing wallet lifecycle/authority tests were preserved, not rerun. Trace spans cover history/month/FX/inputs/filter/pending work.

### R05 — Medium candidate: build-time derivation is partly already memoized

- **Status:** Not reproduced / not meaningful for the claim of full Transactions derivation on every unrelated build; other hotspots unmeasured.
- **Area/files/providers:** `transactions_page.dart`, `transactions_page_derived_data.dart`, category and household detail derivations, wallet sorting and chart adapters.
- **Source evidence:** `_resolveDerivedData` already checks `_TransactionsDerivedCacheKey` before filtering/grouping. Its key contains base/projected content signatures plus search/category/type/currencies/date filter/custom range, household/account scope, day anchor and financial-cycle start day. Unchanged inputs return cached derived data. This was left intact.
- **Remaining uncertainty:** Signature scans still visit rows; some other consumers filter/convert/group in build, and wallet histories run per-cycle snapshot math. No permitted large-dataset CPU/rebuild measurement ranks their actual cost. Broad provider watches alone do not prove whole-page financial recomputation.
- **Already correct/recommendation:** Preserve currency inclusion, native rows versus aggregate conversion, FX, occurrence and scope reactivity. Measure before moving another derived result or adding caching. Do not use list length/month as freshness authority.
- **Risk/benefit/verification:** An incomplete key risks stale money. No new cache/provider split or speculative `.select()` expansion; source/CodeGraph review and existing derivation regressions preserved. Actual CPU and rebuild counts unmeasured. Wallet actual-filter instrumentation can support later measurements.

### R06 — Medium: eager report/day/grid paths remain

- **Status:** Confirmed but intentionally not changed.
- **Area/files:** Report sections/transaction drilldowns/archive in `monthly_report_page.dart`, `daily_financial_details_page.dart`, `pockets_grid_section.dart`, merchant/import lists.
- **Current behavior/evidence/root:** Report drilldowns eagerly construct their row collection inside a decorated card and outer scroll; archives use shrink-wrapped list content; daily details nest a shrink-wrapped list; reorderable pocket grids compute their full extent. These are source-confirmed eager paths, without an actual large-account layout/frame benchmark.
- **Already correct:** Main transaction/category/member lists, recurring history and settlement breakdown have lazy builders. Bounded forms/cards are not established hotspots. First-pass lazy recurring groups remain untouched.
- **Recommendation/risk:** Profile representative cardinalities before a focused sliver conversion. Preserve grouped card backgrounds, reorder/drag semantics, text scaling, accessibility and report scope. Source-only layout rewrites would add unverified gesture/geometry risk under the current no-run constraint.
- **Expected benefit/verification:** Potential lower row construction/layout on large drilldowns; no measured constructed-row or frame reduction in this pass. Focused source inspection; no further scroll layout change.

### R07 — Low/Medium: intrinsic measurements need UI/layout evidence

- **Status:** Requires physical-device measurement.
- **Area/files:** Recurring-history timeline, Browse tool cards and selected paywall/Plus cards.
- **Current behavior/evidence/root:** IntrinsicHeight requests extra intrinsic measurements in some paths, but those children are often bounded and the timeline is already lazy. No measured frame-budget violation was recorded.
- **Already correct/recommendation:** Preserve intended alignment, timeline geometry and large-text behavior. Inspect UI/layout samples before substituting constraints or custom layout.
- **Risk/benefit/verification:** Possible fewer layout passes only if hot; visual/alignment risk without geometry tests. Source inventory only; unchanged.

### R08 — Medium candidate: GPU/glass cause remains unproven

- **Status:** Requires physical-device measurement.
- **Area/files:** Persistent native/adaptive tab glass, recurring summary blur, Home AI/camera overlays, lock/subscription surfaces, pocket liquid animation and charts.
- **Current behavior/evidence/root:** Blur, shadows, clips, gradients and animations exist. Many belong to modal states; their cost depends on clipped area, platform compositor and background damage. Their presence alone does not explain the perceived scrolling lag.
- **Already correct/recommendation:** Preserve visual tokens, existing boundaries and animations. Record UI versus raster durations, layer/paint work and scrolling under persistent glass before changing a demonstrated region.
- **Risk/benefit/verification:** Unmeasured appearance degradation is not justified. No blur removal, extra blanket RepaintBoundary, changed animation/clip/shadow, or logo-resolution reduction. No new GPU/frame evidence; device app execution prohibited.

### R09 — Medium candidate: synchronous SQLite and hidden-tab work

- **Status:** Requires physical-device measurement.
- **Area/files/providers:** `moneko_database.dart`, feed summary/page/count readers, full-history transforms, retained shell tabs and provider listeners.
- **Source evidence/root:** sqlite3 selects are synchronous inside async-shaped methods. One feed summary legitimately runs eight differently scoped/grouped SQL selects. Committed changes rebuild local monthly summaries, and retained visited tabs may react to shared signals while hidden. No duration or hidden-tab read-frequency was recorded.
- **Change:** Added lazy, opt-in synchronous select/row-transform spans with full scope/revision/cursor/pending policy and distinct summary statement names. Request sharing in R01/R04 can reduce duplicate upstream reads; existing pending checks and all write ordering remain.
- **Already correct/recommendation:** Keep durable persistence, completeness, mutation transactions, navigation state and financial authority. Use actual duration/frequency evidence before narrower summary queries, broader DB read coalescing, hidden-tab subscription changes or isolates.
- **Risk/benefit/verification:** DB execution/mutation ordering rewrite has high correctness risk; intentionally deferred. No claim of measured DB speedup or UI-thread stall elimination. No isolate/schema/index/write-order change.

### R10 — Low: legacy/auxiliary routes do not justify a general rewrite

- **Area/files:** Legacy overview/dashboard/income pages, onboarding/auth/profile/import/subscription/reminder/avatar screens; abandoned Goals sources.
- **Current behavior/evidence/root:** File inventory includes historical page classes, finite forms, tool/settings cards, external-operation workflows, and demo screens. Existence in `lib/` does not prove a main navigation route. Income's legacy list retains previous AsyncValue during refresh and uses a builder, but its initial loader directly invokes `list-income` rather than the shared SQLite feed.
- **Already correct:** Main-shell fifth tab is Browse; externally authoritative actions await the necessary result/entitlement. Goals is abandoned and absent from the inspected shell/router/Browse references.
- **Recommendation:** Confirm route reachability and profile frequently used auxiliary screens before replacing their architecture. Keep entitlement, authentication and externally authoritative completion checks. Do not revive Goals.
- **Risk/benefit/verification:** High scope/behavior risk for changing unused or external-operation flows; benefit unknown without usage evidence. Main route/source inspection and whole-lib pattern inventory. Left unchanged.

## Mutation and refresh preservation

The optimization changes are read/render-only. No mutation payload, account binding, mutation ID/revision, local status, rollback snapshot, retry threshold, recurrence calculation, exchange-rate calculation, split, transfer clock, provider-authority flag, navigation destination, or shared refresh signal changed.

| Workflow inspected | Authority preserved / verification boundary |
| --- | --- |
| Expense create/edit/delete; AI/manual input | Existing SQLite-first row/outbox owner and local refresh publication preserved. Feed tests plus full suite exercise optimistic merges, tombstones and replay; cached background edit regression specifically prevents backend EUR 30 from overwriting pending EUR 40. |
| Merchant/category batch edits | Batch payload membership and per-transaction canonical identities preserved; no diagnostic query used to decide visibility was removed. Existing batch/local cache tests run. |
| Wallet create/edit/archive/delete and transfers | Existing wallet effects, scoped/native-currency endpoints and provider-authoritative balances preserved. Wallet mutation/authority implementation is unchanged. The second pass changes legacy read coordination and discarded work only; first-pass existing wallet tests ran, final second-pass wallet regressions did not. |
| Recurring create/edit/delete/confirm/unconfirm/skip | Existing series/occurrence controllers, revisioned overlays, confirmation eligibility and downstream publication preserved. P05 changes row construction and consumer ownership only. Unknown materialization still hides confirmation. |
| Pocket/budget modifications | Existing monthly optimistic snapshot, revision checks, persisted cache and save_pockets_month queue preserved. No money or rollover calculations changed. |
| Shared household/settlements | Existing split/member/scoped caches and backend settlement authority preserved. No inferred split or household authority substitution. |
| Bank sync and lifecycle delta | Existing drainer/delta canonical writes and provider flag semantics preserved. No backend deployment or bank-provider runtime verification performed. |
| Pull-to-refresh/background refresh | Existing loaded rows remain present during refresh. New tests retain local EUR 20 while responses are held pending. R01 now shares same-generation refresh work. The initial overlap regression passed before final stale-response refinements; final regressions remain unexecuted. |

No claim is made that all localized mutations now cause only leaf builds across the entire app. P04 and P05 demonstrate specific reduced dependencies; broader page derivation and refresh fan-out still warrant profiling.

## First-pass verification results (historical; not final second-pass validation)

| Check | Final result |
| --- | --- |
| Pre-change full Flutter suite | **2,354 passed, 4 failed**; `/private/tmp/moneko-performance-baseline-tests.log`. |
| Final focused source/widget regressions and existing feed/navigation/grouping/scaling tests | **50 passed, 0 failed**; `/private/tmp/moneko-performance-focused-final.log`. Includes 20 new tests across three files. |
| Final complete Flutter suite (`flutter test --reporter expanded`) | **2,374 passed, 4 failed**; the same four baseline assertions below. `/private/tmp/moneko-performance-final-tests.log`. |
| Every touched Dart source/test (`flutter analyze` with seven explicit paths) | **No issues found** after the final refinement; `/private/tmp/moneko-performance-touched-analyze.log`. |
| Project-wide `flutter analyze` | **32 issues: 8 warnings, 24 infos, 0 errors**, all in untouched files listed below. `/private/tmp/moneko-performance-final-analyze.log`. |
| Dart format | Final `dart format --output none --set-exit-if-changed` check: **7 files, 0 changes**, exit 0. |
| Whitespace/diff check | `git diff --check` passes for the mobile implementation. |

An intermediate complete run had one additional category-navigation timeout, caused by conflating an explicitly empty test service with an opening database. The final implementation separates those states; the existing navigation test passed in both the focused and final complete runs. It was not ignored, relabeled as pre-existing, or removed.

The four remaining failures were already present in the pre-change full run. Their source/test assertions were not edited by this audit:

1. `test/features/insights/presentation/pages/browse_page_test.dart` — `BrowsePage renders original categorized cards without description`, line 37:
   ```text
   Expected: exactly one matching candidate
   Actual: _TextWidgetFinder:<Found 0 widgets with text "Financial health": []>
   ```
2. `test/features/pockets/presentation/state/monthly_intro_insights_test.dart` — `evaluateMonthlyIntroInsights Scenario 1: Rollover carry-over has top priority`, line 60:
   ```text
   Expected: 'You're starting September with €230 extra'
   Actual: 'You're starting €230 with September extra'
   ```
3. Same file — `evaluateMonthlyIntroInsights Scenario 2: Pocket overspent adjustment when rollover is zero`, line 116:
   ```text
   Expected: contains 'Dining ran €74 above plan last month'
   Actual: 'September ran Dining above plan last month. We can adjust €74 around how you actually spend.'
   ```
4. `test/features/recurring/presentation/widgets/add_recurring_sheet_test.dart` — `Displays floating recurring icon badge on top of category/merchant icon`, line 1670:
   ```text
   Expected: exactly one matching candidate
   Actual: _IconWidgetFinder:<Found 0 widgets with icon "IconData(U+F00F7)": []>
   ```

These are copy/icon expectations on unchanged implementations. They are not claimed resolved or presumed safe to rewrite. The complete suite is **not green**.

Project-wide analyzer output (all referenced files are outside this audit's code diff):

```text
info • The 'if' statement could be replaced by a null-aware assignment • lib/core/app/fallback_localizations.dart:55:3 • prefer_conditional_assignment
info • The 'if' statement could be replaced by a null-aware assignment • lib/core/app/locale_provider.dart:32:3 • prefer_conditional_assignment
info • Don't use 'BuildContext's across async gaps • lib/features/app_version/presentation/widgets/force_update_dialog.dart:38:7 • use_build_context_synchronously
info • Don't use 'BuildContext's across async gaps • lib/features/app_version/presentation/widgets/force_update_dialog.dart:39:14 • use_build_context_synchronously
info • Don't use 'BuildContext's across async gaps • lib/features/app_version/presentation/widgets/force_update_dialog.dart:40:31 • use_build_context_synchronously
info • Don't use 'BuildContext's across async gaps • lib/features/app_version/presentation/widgets/force_update_dialog.dart:41:21 • use_build_context_synchronously
warning • The receiver can't be null, so the null-aware operator '?.' is unnecessary • lib/features/auth/presentation/widgets/google_login_button.dart:71:45 • invalid_null_aware_operator
info • Don't use 'BuildContext's across async gaps • lib/features/avatar/presentation/pages/avatar_customizer_screen.dart:389:14 • use_build_context_synchronously
info • Don't use 'BuildContext's across async gaps • lib/features/avatar/presentation/pages/avatar_customizer_screen.dart:390:14 • use_build_context_synchronously
info • Don't use 'BuildContext's across async gaps • lib/features/home/presentation/widgets/currency_selector_modal.dart:62:21 • use_build_context_synchronously
info • Don't use 'BuildContext's across async gaps • lib/features/home/presentation/widgets/currency_selector_modal.dart:67:21 • use_build_context_synchronously
info • Don't use 'BuildContext's across async gaps • lib/features/home/presentation/widgets/currency_selector_modal.dart:72:28 • use_build_context_synchronously
info • Don't use 'BuildContext's across async gaps • lib/features/home/presentation/widgets/currency_selector_modal.dart:109:60 • use_build_context_synchronously
info • Don't use 'BuildContext's across async gaps • lib/features/home/presentation/widgets/currency_selector_modal.dart:307:62 • use_build_context_synchronously
info • Don't use 'BuildContext's across async gaps • lib/features/home/presentation/widgets/home_ai_fab.dart:2328:29 • use_build_context_synchronously
info • Don't use 'BuildContext's across async gaps • lib/features/home/presentation/widgets/home_ai_fab.dart:2362:11 • use_build_context_synchronously
info • Don't use 'BuildContext's across async gaps • lib/features/home/presentation/widgets/home_ai_fab.dart:2379:31 • use_build_context_synchronously
warning • A value for optional parameter 'onTap' isn't ever given • lib/features/home/presentation/widgets/text_input_drawer.dart:844:10 • unused_element_parameter
info • Use 'const' with the constructor to improve performance • lib/features/households/presentation/utils/household_creation_utils.dart:79:28 • prefer_const_constructors
info • Use 'const' with the constructor to improve performance • lib/features/households/presentation/widgets/household_member_spending_card.dart:342:15 • prefer_const_constructors
info • Use 'const' with the constructor to improve performance • lib/features/households/presentation/widgets/household_member_spending_card.dart:479:15 • prefer_const_constructors
info • Use 'const' with the constructor to improve performance • lib/features/import_review/presentation/pages/import_review_page.dart:697:15 • prefer_const_constructors
info • Use 'const' literals as arguments to constructors of '@immutable' classes • lib/features/import_review/presentation/pages/import_review_page.dart:698:27 • prefer_const_literals_to_create_immutables
warning • Unused import: 'package:moneko/core/l10n/l10n.dart' • lib/features/insights/domain/monthly_financial_report.dart:4:8 • unused_import
warning • The value of the local variable 'forecastEnabled' isn't used • lib/features/pockets/presentation/widgets/envelope_mode_settings_modal.dart:19:11 • unused_local_variable
warning • Unused import: 'package:moneko/shared/widgets/modal_sheet_handle.dart' • lib/features/profile/presentation/widgets/category_customization_sheet.dart:13:8 • unused_import
info • Don't use 'BuildContext's across async gaps • lib/features/profile/presentation/widgets/category_customization_sheet.dart:556:52 • use_build_context_synchronously
info • Statements in an if should be enclosed in a block • lib/features/recurring/presentation/providers/recurring_providers.dart:2538:7 • curly_braces_in_flow_control_structures
info • Statements in an if should be enclosed in a block • lib/features/recurring/presentation/providers/recurring_providers.dart:2542:42 • curly_braces_in_flow_control_structures
warning • The value of the local variable 'secondaryTextColor' isn't used • lib/features/recurring/presentation/widgets/add_recurring_sheet.dart:1765:11 • unused_local_variable
warning • The value of the local variable 'hasResolvableMerchantLogo' isn't used • lib/features/recurring/presentation/widgets/add_recurring_sheet.dart:1770:11 • unused_local_variable
warning • The value of the local variable 'isIncomeMode' isn't used • lib/features/recurring/presentation/widgets/add_recurring_sheet.dart:1778:11 • unused_local_variable
```

Tests establish delayed-backend notifier transitions, SQLite canonical persistence, offline-cache behavior, optimistic edit authority, failure retention, explicit-refresh visibility, row dependency changes, lazy rendering, geometry and interactions. Existing full-suite tests cover the unchanged mutation/replay/navigation domains. They do not replace an authenticated device test of startup, repeated tabs, every rollback workflow, or Android/iOS/web rendering.

## Profile-mode follow-up

Use a representative populated account/cache on a physical device and a release-like profile build. A simulator/debug/widget-test timing is not sufficient to certify scrolling. Available devices were enumerated, but no authenticated device session was launched or mutated for this audit.

1. Record startup with populated/empty cache, offline startup, background EUR 20 → EUR 30 reconciliation, and account/scope/currency switches. Capture timestamps for SQLite ready, first usable content, and remote settlement; distinguish complete and partial caches.
2. Count requests by user/household/currency/cycle/query/revision through initialization, mount, delta, foreground refresh, and deferred refresh. Measure the current R01/R02 coordinators, retained cold-wallet read pair, and any remaining producers before further deduplication.
3. Record long transactions/recurring/report/household/pocket scrolling. Inspect **UI thread** build/layout/Dart samples separately from **raster thread** paint/compositing/image/blur samples. Use the device refresh-rate budget (approximately 16.7ms at 60Hz or 8.3ms at 120Hz).
4. Exercise create/edit/delete/rollback, transfers, recurring confirmation, budget changes, bank delta, pull refresh and overlapping mutation/refresh. Record affected consumers and unexpected request fan-out; verify no loaded content becomes skeleton and no newer local edit loses authority.
5. Compare cold/visited tab navigation and hidden-tab network/listener work. Check large text, both themes, accessibility, iOS/Android/web, and actual native glass gestures/appearance.

Reference principles: [Flutter performance best practices](https://docs.flutter.dev/perf/best-practices), [profile-mode performance debugging](https://docs.flutter.dev/perf/ui-performance). Framework documentation review informs the method; it does not substitute for measurements.

## Confidence

The second-pass source fixes are reviewable, but final tests/analyzer/device measurements remain unperformed under the latest instruction. No production-readiness claim is made for the new coordinators/readiness bridge. Remaining scrolling/navigation causes are not identified by frame traces.

First-pass confidence: high confidence in the narrow work reductions covered by tests and unchanged authority boundaries. Moderate confidence in visual/gesture equivalence of the new recurring sliver based on geometry and interaction tests. No claim of proven whole-app smoothness, complete startup request elimination, zero page builds, or cross-platform frame-budget compliance without the profile follow-up above.

## Coverage inventory

The main shell and important dataset/mutation paths received the focused architectural review described above. The entire `lib/` tree was pattern-screened for eager scroll construction, shrink-wrapping, intrinsic layout, blur and expensive transforms; focused reads followed the findings. **Inventory/pattern screening is not equivalent to profiling or line-by-line review of every child widget.** Auxiliary/legacy files are listed to make that limit explicit.

Inventory: **59 page files + 8 screen files**. Supporting sheets, cards, providers, database, outbox, logos and charts are covered by the area findings rather than this filename-suffix list.

| Domain | Page/screen file | Coverage interpretation |
| --- | --- | --- |
| core/navigation | `lib/core/navigation/main_menu_screen.dart` | Auxiliary/legacy pattern screening; no demonstrated change justified. |
| core/plaid | `lib/core/plaid/pages/plaid_sync_walkthrough_page.dart` | Auxiliary/legacy pattern screening; no demonstrated change justified. |
| core/plaid | `lib/core/plaid/widgets/plaid_sync_review_page.dart` | Auxiliary/legacy pattern screening; no demonstrated change justified. |
| core/ui | `lib/core/ui/pages/error_page.dart` | Auxiliary/legacy pattern screening; no demonstrated change justified. |
| core/ui | `lib/core/ui/pages/splash_screen.dart` | Auxiliary/legacy pattern screening; no demonstrated change justified. |
| app_lock | `lib/features/app_lock/presentation/pages/app_lock_page.dart` | Auxiliary/legacy pattern screening; no demonstrated change justified. |
| app_lock | `lib/features/app_lock/presentation/pages/app_lock_setup_page.dart` | Auxiliary/legacy pattern screening; no demonstrated change justified. |
| auth | `lib/features/auth/presentation/pages/auth_callback_screen.dart` | Auxiliary/legacy pattern screening; no demonstrated change justified. |
| auth | `lib/features/auth/presentation/pages/login_screen.dart` | Auxiliary/legacy pattern screening; no demonstrated change justified. |
| auth | `lib/features/auth/presentation/pages/register_screen.dart` | Auxiliary/legacy pattern screening; no demonstrated change justified. |
| avatar | `lib/features/avatar/presentation/pages/avatar_customizer_screen.dart` | Auxiliary/legacy pattern screening; no demonstrated change justified. |
| goals | `lib/features/goals/presentation/pages/goals_list_page.dart` | Abandoned; reachability inspected, no extension or optimization. |
| home | `lib/features/home/presentation/pages/budget_dashboard_demo_screen.dart` | Auxiliary/legacy pattern screening; no demonstrated change justified. |
| home | `lib/features/home/presentation/pages/category_details_page.dart` | Focused main/read/render path plus pattern screening; see findings. |
| home | `lib/features/home/presentation/pages/currency_rates_page.dart` | Auxiliary/legacy pattern screening; no demonstrated change justified. |
| home | `lib/features/home/presentation/pages/dashboard_page.dart` | Auxiliary/legacy pattern screening; no demonstrated change justified. |
| home | `lib/features/home/presentation/pages/home_page.dart` | Focused main/read/render path plus pattern screening; see findings. |
| home | `lib/features/home/presentation/pages/merchant_bulk_update_page.dart` | Auxiliary/legacy pattern screening; no demonstrated change justified. |
| home | `lib/features/home/presentation/pages/merchant_selection_page.dart` | Auxiliary/legacy pattern screening; no demonstrated change justified. |
| home | `lib/features/home/presentation/pages/overview_dashboard_page.dart` | Auxiliary/legacy pattern screening; no demonstrated change justified. |
| home | `lib/features/home/presentation/pages/transactions_page.dart` | Focused main/read/render path plus pattern screening; see findings. |
| households | `lib/features/households/presentation/pages/budget_detail_page.dart` | Supporting path / scoped pattern screening; no device certification. |
| households | `lib/features/households/presentation/pages/create_budget_page.dart` | Supporting path / scoped pattern screening; no device certification. |
| households | `lib/features/households/presentation/pages/create_space_page.dart` | Supporting path / scoped pattern screening; no device certification. |
| households | `lib/features/households/presentation/pages/daily_financial_details_page.dart` | Supporting path / scoped pattern screening; no device certification. |
| households | `lib/features/households/presentation/pages/household_expenses_page.dart` | Supporting path / scoped pattern screening; no device certification. |
| households | `lib/features/households/presentation/pages/household_invitation_handler_page.dart` | Supporting path / scoped pattern screening; no device certification. |
| households | `lib/features/households/presentation/pages/household_invites_page.dart` | Supporting path / scoped pattern screening; no device certification. |
| households | `lib/features/households/presentation/pages/household_join_page.dart` | Supporting path / scoped pattern screening; no device certification. |
| households | `lib/features/households/presentation/pages/household_member_details_page.dart` | Supporting path / scoped pattern screening; no device certification. |
| households | `lib/features/households/presentation/pages/household_members_page.dart` | Supporting path / scoped pattern screening; no device certification. |
| households | `lib/features/households/presentation/pages/household_onboarding_page.dart` | Supporting path / scoped pattern screening; no device certification. |
| households | `lib/features/households/presentation/pages/household_settings_page.dart` | Supporting path / scoped pattern screening; no device certification. |
| households | `lib/features/households/presentation/pages/invite_members_page.dart` | Supporting path / scoped pattern screening; no device certification. |
| households | `lib/features/households/presentation/pages/settlement_calculation_breakdown_page.dart` | Supporting path / scoped pattern screening; no device certification. |
| households | `lib/features/households/presentation/pages/settlement_history_page.dart` | Supporting path / scoped pattern screening; no device certification. |
| households | `lib/features/households/presentation/pages/split_builder_page.dart` | Supporting path / scoped pattern screening; no device certification. |
| import | `lib/features/import/presentation/pages/import_wizard_page.dart` | Auxiliary/legacy pattern screening; no demonstrated change justified. |
| import_review | `lib/features/import_review/presentation/pages/import_review_page.dart` | Auxiliary/legacy pattern screening; no demonstrated change justified. |
| income | `lib/features/income/presentation/pages/income_list_page.dart` | Supporting path / scoped pattern screening; no device certification. |
| insights | `lib/features/insights/presentation/pages/browse_page.dart` | Focused main/read/render path plus pattern screening; see findings. |
| insights | `lib/features/insights/presentation/pages/insights_page.dart` | Supporting path / scoped pattern screening; no device certification. |
| insights | `lib/features/insights/presentation/pages/monthly_report_page.dart` | Focused main/read/render path plus pattern screening; see findings. |
| onboarding | `lib/features/onboarding/presentation/pages/onboarding_account_preparing_page.dart` | Auxiliary/legacy pattern screening; no demonstrated change justified. |
| onboarding | `lib/features/onboarding/presentation/pages/onboarding_flow_page.dart` | Auxiliary/legacy pattern screening; no demonstrated change justified. |
| onboarding | `lib/features/onboarding/presentation/pages/onboarding_post_auth_flow_page.dart` | Auxiliary/legacy pattern screening; no demonstrated change justified. |
| onboarding | `lib/features/onboarding/presentation/pages/onboarding_pre_auth_flow_page.dart` | Auxiliary/legacy pattern screening; no demonstrated change justified. |
| onboarding | `lib/features/onboarding/presentation/pages/onboarding_preview_page.dart` | Auxiliary/legacy pattern screening; no demonstrated change justified. |
| onboarding | `lib/features/onboarding/presentation/pages/onboarding_save_budget_page.dart` | Auxiliary/legacy pattern screening; no demonstrated change justified. |
| pockets | `lib/features/pockets/presentation/pages/pocket_details_page.dart` | Focused main/read/render path plus pattern screening; see findings. |
| pockets | `lib/features/pockets/presentation/pages/pockets_ai_budget_suggestions_page.dart` | Auxiliary/legacy pattern screening; no demonstrated change justified. |
| pockets | `lib/features/pockets/presentation/pages/pockets_page.dart` | Focused main/read/render path plus pattern screening; see findings. |
| profile | `lib/features/profile/presentation/pages/android_notification_capture_page.dart` | Auxiliary/legacy pattern screening; no demonstrated change justified. |
| profile | `lib/features/profile/presentation/pages/email_import_settings_page.dart` | Auxiliary/legacy pattern screening; no demonstrated change justified. |
| profile | `lib/features/profile/presentation/pages/financial_month_settings_page.dart` | Auxiliary/legacy pattern screening; no demonstrated change justified. |
| profile | `lib/features/profile/presentation/pages/ios_wallet_capture_page.dart` | Auxiliary/legacy pattern screening; no demonstrated change justified. |
| profile | `lib/features/profile/presentation/pages/settings_page.dart` | Auxiliary/legacy pattern screening; no demonstrated change justified. |
| recurring | `lib/features/recurring/pages/recurring_history_page.dart` | Supporting path / scoped pattern screening; no device certification. |
| recurring | `lib/features/recurring/pages/recurring_transactions_page.dart` | Focused main/read/render path plus pattern screening; see findings. |
| reminders | `lib/features/reminders/presentation/pages/reminder_page.dart` | Auxiliary/legacy pattern screening; no demonstrated change justified. |
| subscription | `lib/features/subscription/presentation/pages/paywall_screen.dart` | Auxiliary/legacy pattern screening; no demonstrated change justified. |
| subscription | `lib/features/subscription/presentation/pages/plan_selection_page.dart` | Auxiliary/legacy pattern screening; no demonstrated change justified. |
| wallets | `lib/features/wallets/presentation/pages/archived_wallets_page.dart` | Focused main/read/render path plus pattern screening; see findings. |
| wallets | `lib/features/wallets/presentation/pages/bank_connections_page.dart` | Supporting path / scoped pattern screening; no device certification. |
| wallets | `lib/features/wallets/presentation/pages/wallet_details_page.dart` | Focused main/read/render path plus pattern screening; see findings. |
| wallets | `lib/features/wallets/presentation/pages/wallets_history_page.dart` | Supporting path / scoped pattern screening; no device certification. |
| wallets | `lib/features/wallets/presentation/pages/wallets_page.dart` | Focused main/read/render path plus pattern screening; see findings. |
