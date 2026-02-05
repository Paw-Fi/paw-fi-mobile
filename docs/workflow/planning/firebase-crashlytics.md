# Firebase Crashlytics Fix Plan (Moneko Mobile)

This plan covers fixing all open Crashlytics issues listed in `firebase-crashlytics-issues.json` (version 1.3.8). Each issue will be addressed one by one with strict TDD (tests first), validated, and only then marked `isFixed: true`.

Plan authority: This document.

## Scope

- Codebase: `moneko-mobile/`
- Source of truth for issues: `/Users/charles/side-projects/Moneko/firebase-crashlytics-issues.json`
- Platforms: iOS + Android issues listed in the file

## Global Rules

- Fix issues sequentially in the order they appear in the JSON.
- For each issue: write a failing test first, implement fix, verify, then update `isFixed`.
- Do not expand scope beyond the listed issues.
- Verify fix before marking `isFixed: true` (tests + targeted verification).

## Phase 0: Baseline Verification

Tasks:

- Confirm issue order and create a per-issue checklist.
- Identify code locations for each crash and any missing tests.

Acceptance Criteria:

- A clear, ordered list of 7 issues mapped to file locations.

## Phase 1: iOS Issue 1 (TimeoutException in main.dart)

Issue ID: 62faceae28e1eed5d635cd24335e87eb
Title: `package:moneko/main.dart - main.<fn>`

Tasks:

- Write a failing test that reproduces the timeout path.
- Implement fix to prevent unhandled timeout (retry/guard/fallback as appropriate).
- Verify with test(s) and any relevant integration/mock.
- Set `isFixed: true` for this issue after verification.

Acceptance Criteria:

- Test covers the timeout case and passes.
- App no longer throws unhandled `TimeoutException` in the reproduced path.

## Phase 2: iOS Issue 2 (RangeError in create_budget_from_template_sheet)

Issue ID: 7a9245c553bc60e519f0ee572716d59d
Title: `CreateBudgetFromTemplateSheet.build.<fn>.<fn>`

Tasks:

- Add a widget/unit test that triggers the out-of-range access.
- Fix list indexing and defensive bounds handling.
- Verify tests and UI behavior.
- Set `isFixed: true` after verification.

Acceptance Criteria:

- RangeError no longer occurs under test.
- UI handles list sizes safely (no crash).

## Phase 3: iOS Issue 3 (HttpException in main.dart)

Issue ID: 2bc003663a61f45690f1361f179aeea4
Title: `main.<fn>.<fn>`

Tasks:

- Write a failing test for the HttpException path (image/profile fetch).
- Implement error handling and fallback UI/logic.
- Verify with tests and targeted mock.
- Set `isFixed: true` after verification.

Acceptance Criteria:

- HttpException is handled without crashing.
- Tests pass and show fallback behavior.

## Phase 4: iOS Issue 4 (FunctionsClient.invoke ClientException)

Issue ID: 8ca02a10b4b2b5ac9b4ca0eb5c5cf46d
Title: `FunctionsClient.invoke` (bad file descriptor)

Tasks:

- Add tests for edge function call failures.
- Implement retry/backoff or error handling to avoid crash.
- Verify with tests and mock failures.
- Set `isFixed: true` after verification.

Acceptance Criteria:

- Function call errors are caught and surfaced safely.
- No uncaught ClientException in tests.

## Phase 5: Android Issue 1 (DartMessenger Reply already submitted)

Issue ID: 10820c7c03a9ac15f05741b4df042138
Title: `DartMessenger$Reply.reply`

Tasks:

- Write a failing test for double reply path (method channel or platform call).
- Fix to ensure single reply (guards, cancelation, or early return).
- Verify with tests.
- Set `isFixed: true` after verification.

Acceptance Criteria:

- No double-reply under test.
- Platform channel path returns once.

## Phase 6: Android Issue 2 (FunctionsClient.invoke batch size error)

Issue ID: 8a5008d83805ccf97628fa316d71fc9b
Title: `FunctionsClient.invoke` (batch size > 500)

Tasks:

- Add test for batch size handling.
- Implement batching/splitting logic and error handling.
- Verify tests and behavior.
- Set `isFixed: true` after verification.

Acceptance Criteria:

- Requests are split to respect 500 limit.
- No crash on large batches.

## Phase 7: Android Issue 3 (ref used after dispose in home_page)

Issue ID: 31559542e892efb56ac2601662eef849
Title: `_HomePageState.build.<fn>`

Tasks:

- Add a widget test to cover late async callback after dispose.
- Fix by guarding with `mounted` or ref lifecycle-safe patterns.
- Verify tests.
- Set `isFixed: true` after verification.

Acceptance Criteria:

- No ref access after dispose in test.
- Home page handles async completion safely.

## Verification Requirements (per issue)

- Add/extend tests in `test/` matching the feature path.
- Run targeted tests for the issue.
- Perform quick manual sanity check if UI-related.
- Only after verification, set `isFixed: true` in `firebase-crashlytics-issues.json`.

## Completion Criteria

- All 7 issues resolved with tests passing.
- `firebase-crashlytics-issues.json` updated with `isFixed: true` for each issue.
- No unrelated behavior changes.
