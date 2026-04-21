# Mobile Performance Optimization Guide

## Purpose

This document is a general performance and UX optimization guide for `moneko-mobile`, not just for Wallets.

It captures the patterns, rules, debugging workflow, and cache/invalidation architecture that should be reused when optimizing any data-heavy page in the app.

Primary goals:

1. Make pages feel instant.
2. Preserve all existing calculations and business behavior.
3. Avoid stale data after mutations.
4. Keep the UI stable and premium-feeling.
5. Give future developers and AI agents a repeatable playbook.

This guide was derived from real optimization work on:

1. `lib/features/wallets/presentation/pages/wallets_page.dart`
2. `lib/features/pockets/presentation/pages/pockets_page.dart`

But the guidance below should be applied broadly across the mobile app.

## Core Principle

Performance work must never change the meaning of the data.

If the old code showed `$2000`, the optimized code must still show `$2000` for the same user, scope, month, currency, and recurring preference.

Optimization is allowed to change:

1. when data is fetched
2. how data is cached
3. how UI is staged
4. which work is deferred
5. which work is prefetched

Optimization is not allowed to change:

1. the source of truth for calculations unless explicitly re-approved
2. the meaning of the selected scope
3. the meaning of the selected month
4. how recurring-aware or projection-aware math works
5. mutation correctness

## Non-Negotiable Invariants

These must remain true after any optimization.

1. Business math must not change.
2. Timezone-sensitive month calculations must remain timezone-correct.
3. Recurring-aware pages must remain recurring-aware.
4. Mutation results must appear without app restart.
5. Old async responses must never overwrite newer scope or invalidation state.
6. Cache freshness rules must never be stronger than mutation invalidation.

## The Real Pattern Used By Premium Apps

Apps like Revolut, YNAB, Splitwise, and similar high-quality finance apps usually feel fast because they do all of the following together:

1. Render cached content immediately.
2. Refresh in background.
3. Keep only current-view data on the first-paint path.
4. Move neighboring/secondary data behind the first useful frame.
5. Avoid blocking the whole page on unrelated async branches.
6. Invalidate broadly and safely after mutations.
7. Drop stale in-flight responses when scope or generation changes.
8. Use traces to optimize the real bottleneck instead of guessing.

This is the standard to follow in `moneko-mobile`.

## Required Workflow For Optimizing Any Page

Do not jump directly to refactors.

Use this order.

### 1. Instrument first

Before changing the architecture, add page-level and provider-level traces.

You need logs for:

1. page mount
2. page gating reasons
3. first useful paint
4. cache hit or miss
5. RPC start and success
6. projection or post-processing start and success
7. prefetch scheduling
8. background refresh start and success
9. mutation invalidation and refresh flow

Without this, optimization becomes guesswork.

### 2. Measure first useful paint

First useful paint matters more than raw backend completion.

The user does not care when the last background fetch ends.
The user cares when the page becomes meaningfully usable.

### 3. Separate critical path from background path

Explicitly define:

1. What must exist before the page is useful?
2. What can arrive after the page is already useful?

Only current-view essentials belong on the critical path.

### 4. Optimize the real bottleneck only

Typical bottlenecks:

1. auth/header gating
2. multiple parallel cold misses on first page open
3. serial provider chains
4. recurring projection or expensive local recomputation
5. edge function overhead for simple list fetches
6. stale cache invalidation bugs forcing cold reloads every time

### 5. Protect correctness before broad rollout

Any performance improvement must preserve:

1. scope correctness
2. month correctness
3. recurring correctness
4. mutation freshness

## Recommended Architecture Pattern

Use this architecture for heavy pages.

### 1. Cache-first page rendering

Preferred order:

1. session cache
2. persisted cache
3. network

Why:

1. session cache gives the fastest repeated navigation in the same app session
2. persisted cache gives the fastest first open after app launch
3. network refresh restores freshness without blocking the user

### 2. Stale-while-revalidate

When serving persisted cache:

1. render cache immediately
2. check freshness metadata
3. refresh only if stale
4. patch the UI in background when live data arrives

When serving session cache:

1. render immediately
2. avoid reflexively re-fetching on every re-entry
3. rely on invalidation and TTL instead of constant refresh

### 3. Current-view-first loading

On first open, load only the currently visible unit first.

Examples:

1. Wallets: current month snapshot first, older months later
2. Pockets: current month first, neighbor months after first useful paint

Do not kick off a wide prefetch window before the current view is ready.

### 4. Section-level rendering

Do not block the entire page on all async branches.

Split the page into independently useful sections.

Examples:

1. Wallet overview can render before wallet-list freshness finishes
2. Wallet list can render before bank connections finish
3. Pockets current month can render before neighbor-month prefetch finishes

### 5. Background prefetch only after unlock

Use an explicit unlock signal.

Example:

1. page mounts
2. current view loads
3. first useful paint occurs
4. prefetch unlocks
5. neighboring windows begin loading

This avoids first-open stampedes.

## Cache Design Rules

### Session cache

Use for:

1. repeated navigation in the same session
2. keeping the page feeling instant when revisited

Do:

1. store only states that are safe to rehydrate directly
2. key it precisely
3. clear it on relevant invalidations

Do not:

1. auto-refresh on every same-session re-entry without reason
2. let old scope results overwrite the active scope

### Persisted cache

Use for:

1. fast first open after app launch
2. continuity across app restarts

Persist:

1. the state payload
2. `cached_at` timestamp
3. enough data to reconstruct the UI without recomputation

Do not:

1. store partial state that cannot be trusted on hydration
2. serve persisted cache after a relevant mutation invalidation window

### Cache key rules

A page cache key often needs all of the following:

1. user id
2. scope type
3. household or portfolio id if present
4. current month or period anchor
5. selected currency
6. recurring toggle or calculation-affecting flags
7. fallback or bootstrap flags when they affect output

If any calculation-affecting dimension is missing from the key, stale or wrong data can be served.

## Invalidation Rules

Invalidation is the most important correctness layer.

If invalidation is weak, the page may feel fast but remain wrong.

### Required invalidation behavior

When a mutation can affect a page's output:

1. clear session cache for the relevant user scope or entire user when safer
2. clear persisted cache for the relevant user scope or entire user when safer
3. bump a refresh or generation signal
4. invalidate the relevant provider families
5. temporarily bypass persisted cache reads while invalidation is active

### Prefer broad invalidation over narrow incorrect invalidation

For finance views, narrow invalidation is dangerous when:

1. the mutation can affect multiple scopes
2. the mutation can affect multiple currencies
3. multiple period caches exist for the same user

If unsure, clear all caches for the user.

### Ignore provider attach as an invalidation event

One real bug encountered:

1. a cache invalidation listener fired on provider attach
2. this cleared caches during normal startup
3. every page open became a cold miss

Rule:

1. do not treat initial listener registration as a real data change
2. only invalidate on actual transitions

## Race Condition Rules

These are critical.

### 1. Scope race protection

Before any async fetch:

1. capture a request key

After the await:

1. recompute current request key
2. if they differ, drop the result

This prevents old scope results from overwriting a newly selected scope.

### 2. Generation race protection

Before async refresh:

1. capture current refresh generation or signal

After the await:

1. compare it to the latest generation
2. if changed, drop the result

This prevents pre-mutation or pre-invalidation responses from re-populating stale data.

### 3. Bypass window safety

If bypassing persisted cache during invalidation:

1. use a counter or token, not a fragile global bool
2. overlapping invalidations must not cancel each other early

## Tracing Requirements

Every heavy page should have a trace family like:

1. `PageOpen`
2. provider load trace
3. RPC trace
4. projection or post-processing trace
5. background prefetch trace

### Minimum events to log

At page level:

1. page mount
2. page state and scope
3. blocking reason if any
4. first useful paint
5. prefetch scheduling

At provider level:

1. load start
2. cache hit or miss
3. stale cache background refresh
4. RPC start and success
5. projection start and success
6. backend state ready
7. load success and load error

## How To Read A Trace

### Healthy page

Good signs:

1. `persisted-cache-hit` or `session-cache-hit`
2. `first-useful-paint` under roughly `100ms` to `150ms`
3. prefetch unlock happens after first useful paint
4. background work continues after the user already sees useful content

### Bad page

Bad signs:

1. multiple parallel cold misses on first open
2. full-page block on preference loading, neighboring months, or unrelated data
3. repeated `cache-miss` for pages that were just visited
4. same-session re-entry always triggering expensive refresh
5. background prewarm on Home loading unrelated scopes before entry

## Wallets Lessons

### Original problem

Original critical path:

1. wait for auth headers
2. fetch wallet list
3. fetch history
4. fetch 3 snapshots
5. then paint

Measured outcome before optimization:

1. first useful paint around `1073ms`
2. wallet list edge function around `1063ms`
3. page state bootstrap around `937ms`

### What fixed it

1. cache-first rendering
2. section-level rendering
3. current-month-first bootstrap
4. background month prefetch later
5. broad mutation invalidation
6. race-safe refresh behavior

Measured outcome after optimization:

1. first useful paint around `73ms`

### Important Wallets-specific rules

1. wallet cards should still prefer selected-month snapshot balances for display
2. user month boundaries must stay tied to user timezone
3. recurring-aware month history must not be replaced by simpler data accidentally
4. heavy Home prewarm must stay limited or disabled

## Pockets Lessons

### Original problem

Original pockets first-open behavior showed:

1. no persisted cache reuse
2. immediate multi-month loading on first open
3. current month competing with neighboring months
4. month cache being thrown away too aggressively

Measured outcome before optimization:

1. first useful paint roughly `1142ms`
2. current-month cold load roughly `646ms` to `816ms`

### What fixed it

1. current-month-first load
2. prefetch locked until first useful paint
3. persisted pockets cache
4. removal of accidental startup invalidation
5. keeping month cache alive across provider dispose
6. persisted cache freshness metadata so re-entry does not always revalidate

Measured outcome after optimization:

1. first useful paint roughly `126ms`

### Important Pockets-specific rules

1. recurring preference is calculation-affecting and must remain in the cache key
2. current month should load before neighbor months
3. page should not block on neighbor-month prefetch
4. provider attach must not clear pockets cache
5. persisted pockets cache must include freshness metadata

## UI/UX Rules

To achieve premium-feeling UX, performance and staging must work together.

### Do

1. show real cached content immediately
2. keep the layout stable while background refresh runs
3. use partial content instead of whole-page skeletons when possible
4. keep only what is necessary on the first-paint path
5. use placeholders for offscreen or neighbor content
6. make pull-to-refresh wait for real network work
7. make post-mutation freshness stronger than cache TTL

### Do not

1. return to full-page loading once trusted cached content exists
2. launch wide prefetch before current view is ready
3. invalidate cache on normal provider attach
4. assume one cache key is enough for a finance view
5. let persisted cache survive wallet or pocket mutations incorrectly
6. let offscreen content compete with the current view on first open

## Mutation Checklist

Any save, edit, delete, recurring action, budget action, copy action, or account action that can affect a page must verify all of the following:

1. session cache is cleared appropriately
2. persisted cache is cleared appropriately
3. refresh signal is bumped
4. provider family rebuilds are triggered
5. current page reflects new values without app restart
6. in-flight stale responses cannot repopulate old values

## Common Failure Modes

Watch for these.

### 1. Startup invalidation bug

Symptom:

1. every open is a cold miss
2. persisted cache never appears to work

Likely cause:

1. invalidation listener fires on initial attach

### 2. Same-session background refresh tax

Symptom:

1. page feels fast from cache
2. but still launches full background network refresh every time you revisit it

Likely cause:

1. session cache is treated as always stale
2. persisted freshness metadata is missing

### 3. Stale after mutation

Symptom:

1. page stays old until restart

Likely cause:

1. invalidation too narrow
2. persisted cache bypass missing
3. generic save/edit provider forgot to trigger page refresh

### 4. Over-prefetching

Symptom:

1. first open loads current page plus many offscreen neighbors
2. current view is slower because background months compete for time

Likely cause:

1. prefetch starts before first useful paint

### 5. Provider dispose destroys reusable cache

Symptom:

1. revisit previously loaded page or month
2. still get full `cache-miss`

Likely cause:

1. provider disposal invalidates cache too aggressively

## Recommended Optimization Order For Any New Page

When optimizing a new heavy page, use this order.

### Phase 1. Instrument

1. add page trace
2. add provider trace
3. capture first useful paint

### Phase 2. Reduce critical path

1. identify current-view essentials
2. remove neighboring or secondary work from first open

### Phase 3. Add cache-first rendering

1. session cache
2. persisted cache
3. background refresh if stale

### Phase 4. Harden invalidation

1. user-wide clearing if needed
2. generation protection
3. persisted-cache bypass during invalidation

### Phase 5. Tune prefetch

1. unlock only after current view is usable
2. limit to likely-neighbor content

### Phase 6. Tune backend freshness cost

Only after the UX already feels fast should you spend time shrinking background refresh cost.

## Verification Checklist

Before claiming a page optimization is correct, verify all relevant items below.

1. `flutter analyze` passes for changed files
2. relevant provider tests pass when tests are part of the task
3. first useful paint is materially improved
4. revisiting the page uses cache instead of cold loading again
5. revisiting already loaded neighbor views uses cache when expected
6. mutations update the page without app restart
7. scope switches do not show stale previous-scope data
8. no startup trace shows accidental invalidation or over-prefetch

## Example Success Baselines From This Project

### Wallets

1. first useful paint improved from about `1073ms` to about `73ms`

### Pockets

1. first useful paint improved from about `1142ms` to about `126ms`

These are examples, not universal targets.

The real target is:

1. page feels instant
2. math is unchanged
3. freshness is correct

## Final Rule

Optimize the perceived experience first, then optimize the hidden background cost second.

For `moneko-mobile`, the winning formula is:

1. trace first
2. current-view-first
3. cache-first render
4. stale-while-revalidate
5. prefetch only after useful paint
6. mutation invalidation stronger than cache freshness
7. never let stale async work win

If future agents follow those seven rules, they should be able to optimize other pages in the app without regressing correctness or UX.
