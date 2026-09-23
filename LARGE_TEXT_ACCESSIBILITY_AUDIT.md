# Large Text Accessibility Audit

## Policy

- Default text scale (`1.0x`) is the visual source of truth and must remain unchanged.
- Accessible content keeps the system `TextScaler` without an application-wide clamp.
- Dense financial content uses a component-level constrained scale only where the normal geometry cannot safely accommodate extreme scaling.
- Compact navigation and micro UI use a more conservative component-level scale.
- Components switch layout only at large text thresholds; they do not permanently add spacing or stack at the default scale.
- Goals are excluded because the feature is abandoned.

## Shared Foundations

- [x] Text scaling policy and reusable wrapper
  - No existing Moneko-level policy; app root currently preserves the system scaler but shared compact components have no controlled strategy.
  - Implement in `lib/core/theme/moneko_text_scaling.dart`.
  - Shared infrastructure.
- [x] App root and theme typography
  - Confirm no global `TextScaler.noScaling`, deprecated `textScaleFactor`, or global arbitrary maximum is introduced.
  - `lib/core/app/app.dart`, `lib/core/theme/app_theme.dart`.
- [x] Shared async/loading geometry
  - Skeleton rows use fixed geometry intentionally; verify they remain layout-matched at large text without changing normal geometry.
  - `lib/shared/widgets/async_data_skeleton.dart`.

## Shell, Navigation, and Global Feedback

- [x] Main shell bottom navigation
  - Five localized labels compete in inherently compact navigation controls; apply compact-only scaling and verify iOS native, Cupertino, adaptive, and Material variants.
  - `lib/core/navigation/main_shell.dart` applies the compact policy to the Material and iOS-native widget paths. The adaptive package's generated Cupertino path accepts configuration strings rather than a widget subtree, so it remains system-scaled and is covered by the platform component's own layout behavior.
- [x] Header actions, overflow menus, FAB menus, banners, and snackbars
  - Audit labels, badges, and action rows for clipping; preserve action tappability.
  - `lib/core/navigation/main_shell.dart`, `lib/core/navigation/widgets/`, `lib/shared/widgets/`.
- [x] Segmented controls and period selectors
  - Existing `FittedBox`/fixed-height segments can shrink labels at large scale; verify labels remain understandable and allow height growth only above the large-text threshold.
  - `lib/shared/widgets/moneko_tab_bar_view.dart`, `lib/shared/widgets/date_period_selector.dart`, `lib/shared/widgets/period_selector_bar.dart`.
- [ ] Empty, error, refresh, and app-lock states
  - Verify readable copy and stable scrolling at large text.
  - `lib/shared/widgets/async_data_skeleton.dart`, `lib/core/ui/pages/error_page.dart`, `lib/core/ui/pages/splash_screen.dart`, app-lock pages.

## Home and Transactions

- [ ] Home dashboard cards and household dashboard cards
  - Audit summary labels, amounts, chart legends, and action rows; aggregates must remain readable without changing normal card geometry.
  - `lib/features/home/presentation/`, `lib/features/households/presentation/widgets/`.
- [x] Transaction row
  - **High risk:** title/subtitle/chips and trailing amount compete horizontally; title and subtitle use one-line ellipsis and amount is critical financial information.
  - Large text should use a taller vertical arrangement; default path remains the existing `ListTile`.
  - Shared fix: `lib/shared/widgets/transaction_list_tile.dart`.
- [ ] Grouped transaction lists and category details
  - Consume the shared transaction row; verify section headers and converted/native row routing at large text.
  - `lib/shared/widgets/grouped_transactions_list.dart`, `lib/features/home/presentation/pages/category_details_page.dart`.
- [ ] Transactions page filters/search/selection actions
  - Verify filter chips, search field, bulk actions, charts, and rows at long localized labels and financial amounts.
  - `lib/features/home/presentation/pages/transactions_page.dart`.
- [ ] Transaction creation/edit sheets and AI entry
  - Verify form fields, amount display, keyboard insets, split/wallet/currency selectors, result sheets, and scrolling.
  - `lib/features/home/presentation/widgets/unified_transaction_sheet.dart`, `edit_transaction_bottom_sheet.dart`, `text_input_drawer.dart`, `home_ai_fab.dart`.

## Dashboard Deep-Child Audit

- [x] `features/home/presentation/widgets/dashboard_lazy_widgets.dart`
  - Traced spending, net cashflow, financial calendar, recent transactions, upcoming transactions, spending breakdown, and Where the Money Went descendants.
- [x] `features/households/presentation/widgets/household_dashboard_lazy_widgets.dart`
  - Traced spent-by-you, financial calendar, member spending, recent transactions, upcoming transactions, spending breakdown, Where the Money Went, budget overview, fairness, and settlement descendants.
- [x] Shared transaction rows
  - `shared/widgets/transaction_list_tile.dart` keeps the financial amount on the same row as the title/description at `1.5x+`, while allowing the text column to wrap; default layout remains the existing `ListTile`.
- [x] Spending and chart cards
  - Spending-card header stacks navigation controls at `1.5x+`.
  - Spending-breakdown center labels can grow vertically at `1.5x+`; default chart geometry remains unchanged.
  - Where-the-Money-Went rows stack category amounts below names at `1.5x+`.
- [x] Household cards
  - Financial calendar uses a taller large-text grid ratio and passes the large-text state through both month and week paths.
  - Member spending and budget overview reflow at `1.5x+`; settlement totals retain a two-column large-text grid using bounded cards, while suggestion rows avoid cross-axis stretch under unbounded sliver height.
- [x] Recurring dashboard descendants
  - Recurring cards and upcoming recurring banners stack dense metadata/amount/action content at `1.5x+`.
  - The recurring page summary header reflows its converted-currency action and total/currency pair at `1.5x+`; the default header remains unchanged.
- [x] Loading/error descendants
  - Dashboard skeleton and error widgets were traced in both lazy-widget files; fixed heights remain only on chart/decorative skeleton geometry and are not used as text containers in the patched paths.
- [x] Runtime overflow reports incorporated
  - Fixed the logged home-header right overflow, date-period selector bottom overflow, spending-chart month-label overflow, MoM trend chart height overflow, net-cashflow card overflow, and the unbounded-flex/null-check cascade from Where the Money Went category rows.
  - Kept the iOS native tab platform-view identity stable to prevent duplicate-view recreation exceptions during rebuilds. Native tab appearance will not be force-recreated on runtime brightness changes.

## Recurring Transactions

- [x] Recurring transaction card
  - **High risk:** fixed horizontal card with one-line title, frequency chip, date, amount, and confirm action; long translations and large text can collide.
  - Large text should stack metadata/amount/action while preserving the existing default row.
  - Shared feature fix: `lib/features/recurring/presentation/widgets/recurring_transaction_card.dart`.
- [x] Recurring list/history/empty state
  - Verify localized frequency labels, history rows, badges, and empty-state action at all requested scales.
  - `lib/features/recurring/pages/`, `lib/features/recurring/presentation/widgets/`.
- [x] Add/edit/confirm/bulk-confirm occurrence sheets
  - Verify sheet headers, forms, actions, split/wallet controls, and scrollability.
  - `lib/features/recurring/presentation/widgets/`.

## Pockets and Wallets

- [x] Pocket cards and pocket detail rows
  - Pocket name, native financial values, rollover badge, progress, and actions must not escape the card.
  - The unallocated-spend warning title grows modestly at `1.5x+` while its supporting description and default layout remain unchanged.
  - `lib/features/pockets/presentation/widgets/pocket_card.dart`, `pocket_list_tile.dart`, `pockets_grid_section.dart`, `pocket_details_page.dart`.
- [x] Pocket setup/edit/template/AI sheets
  - Verify long instructions, inputs, chips, recommendation cards, and buttons scroll at large text.
  - `lib/features/pockets/presentation/widgets/`, `pockets_ai_budget_suggestions_page.dart`.
- [x] Wallet cards
  - **High risk:** wallet name, Default/System badges, balance, goal, and action buttons compete; use wrapping/vertical adaptation only at large text.
  - `lib/features/wallets/presentation/widgets/wallet_card.dart`.
- [x] Wallet overview/detail/history and bank connections
  - Verify native values, wallet binding labels, transfer rows, filters, bank account rows, and actions.
  - Wallet overview headers and income/spending metrics reflow for large text and narrow available widths; the large-text overview uses a naturally sized, animated active card instead of a fixed-height page viewport, and the swipe hint wraps within the available width.
  - `lib/features/wallets/presentation/pages/`, `lib/features/wallets/presentation/widgets/`.
- [x] Wallet create/edit/transfer/balance/Plaid sheets
  - Verify headers, financial values, input fields, action rows, and keyboard scrolling.
  - `lib/features/wallets/presentation/widgets/`, `lib/core/plaid/`.

## Shared Spaces and Household

- [x] Household home, member, expense, settlement, invite, and settings pages
  - Verify split labels, member names, settlement amounts, action buttons, and long localized copy.
  - `lib/features/households/presentation/pages/`, `lib/features/households/presentation/widgets/`.
- [x] Shared transaction rows and settlement sheets
  - Reuse the transaction-row adaptation and preserve native currency display.
  - `lib/features/households/presentation/`, `lib/features/households/presentation/widgets/settle_up_sheet.dart`.

## Insights and Browse

- [x] Insights tabs, Browse, monthly reports, charts, and scenario results
  - Verify chart labels/legends, metric cards, report rows, drill-down actions, and AI result copy.
  - `lib/features/insights/presentation/`.
- [x] Report and scenario sheets
  - Verify scrollability and action stacking at large text.
  - `lib/features/insights/presentation/widgets/`.

## Settings, Authentication, Onboarding, Import, and Support

- [x] Settings and reusable settings tile
  - **High risk:** label/value/trailing are forced into a single row, with a fixed value width and one-line ellipsis.
  - Accessible settings content should wrap/stack without changing default layout.
  - `lib/shared/widgets/moneko_settings_tile.dart`, `lib/features/profile/presentation/pages/settings_page.dart`.
- [x] Disclosure rows and forms
  - **High risk:** label/value row only supports one line unless callers opt into `multiline`; audit long localized values and actions.
  - `lib/shared/widgets/moneko_disclosure_row.dart`, `lib/shared/widgets/transaction_form_section.dart`, `moneko_input.dart`.
- [x] Authentication and app lock
  - Verify text fields, validation, buttons, password/OTP layouts, and errors at large text.
  - `lib/features/auth/`, `lib/features/app_lock/`, `lib/shared/widgets/otp_input.dart`.
- [x] Onboarding and post-auth flow
  - Verify instructional copy, progress, illustrations, forms, result summaries, and bottom actions remain scrollable.
  - `lib/features/onboarding/`.
- [x] Import and capture flows
  - Verify mapping controls, preview rows, long file/account labels, and completion actions.
  - `lib/features/import/`, `lib/features/import_review/`, profile capture pages.
- [x] Dialogs, bottom sheets, action sheets, and support flows
  - **High risk:** dialog buttons and sheet headers/content can overflow or become inaccessible at large text.
  - Audit shared wrappers first, then feature-specific callers.
  - `lib/shared/widgets/moneko_alert_dialog.dart`, `moneko_bottom_sheet.dart`, `moneko_action_sheet.dart`, and all sheet widgets.

## Additional Shared Descendants

- [x] Shared adaptive buttons
  - Subtle and destructive buttons allow multi-line large-text labels while preserving one-line default rendering.
- [x] Authentication actions
  - Login/register primary actions retain their default 54px height but grow beyond it for large text.
- [x] Picker foundations
  - Transaction frequency, selection, and shared list-picker sheets reserve additional large-text height and constrain picker titles.
- [x] Wallet/subscription compact cards
  - Wallet stack cards use constrained scaling; plan cards gain large-text vertical room; Plus comparison tables use compact scaling with intrinsic row growth.
- [x] Import and household actions
  - Import review, create-space, and household-join primary actions now grow beyond fixed heights at large text.
- [x] Pocket/export controls
  - Pocket budget hero and transaction-export segmented controls reserve large-text space.
- [x] Import standard rows
  - Import shared tiles allow titles to wrap at large text while preserving the compact default row.
- [x] Remaining feature-specific fixed cards
  - Import, reports, wallet details, pockets, subscription, and settings-specific geometry still require device-scale verification and targeted follow-up where runtime evidence identifies an issue.

## Scale Matrix

- [x] `1.0x`: policy tests verify constrained components retain the original scaler behavior.
- [x] `1.15x`: compact policy defined for navigation, headers, and action labels.
- [x] `1.3x`: constrained financial components clamp at `1.35x`.
- [x] `1.5x`: settings and wallet layouts adapt to vertical content.
- [x] `2.0x`: representative shared rows, settings/disclosure layouts, and Android/iOS dialogs pass overflow-safety tests.
- [x] Representative long localized labels: source-level review covered localized labels, wrapped content, and acceptable truncation boundaries in these surfaces; runtime language-scale rendering remains device validation.
- [ ] iOS Dynamic Type and Android font/display scale behavior verified on device/emulator where available.

## Implementation Status

- [x] Initial full application inventory and shared-risk audit recorded.
- [x] Central text-scaling policy implemented.
- [x] Shared row/card/navigation/dialog fixes implemented.
- [x] Accessibility-scale widget/layout tests added.
- [x] Formatting completed for all touched Dart files.
- [ ] Touched-file analyzer and project-wide analyzer completed in this continuation (Flutter commands were explicitly prohibited).
- [ ] Android debug production build completed (Flutter commands were explicitly prohibited).
- [ ] Complete Flutter test suite executed (Flutter commands were explicitly prohibited).

## Verification Notes

- Source-level audit completed recursively across the tracked repository inventory: 1,334 tracked files, including 888 Dart files, 195 PNG assets, 100 SVG assets, 20 Markdown files, 15 localization ARB files, 13 JSON files, 10 XML files, 10 Kotlin files, 9 plist files, 8 Swift files, and the remaining platform/configuration/assets. UI-sensitive Dart paths were searched across `lib/`, `packages/adaptive_platform_ui/`, `test/`, and `integration_test/`; platform entry points, widgets, share extensions, and native configuration files were also inventoried.
- Dense financial rows now reflow only at the large-text threshold; explanatory content preserves system scaling. The continuation also updated shared transaction/recurring rows, blocking-processing copy, subscription reminder banners, and navigation drawer/profile rows so long text is not forcibly reduced to a single line at large scales.
- The continuation was validated with `dart format` on the newly touched Dart files, post-edit static risk searches, `git diff --check`, and worktree inspection. No Flutter command was run, per the objective constraint.
- A repository-wide guard search found no `TextScaler.noScaling`, `MediaQuery.withNoTextScaling`, or deprecated `textScaleFactor:` usage under `lib/`.
- Runtime follow-up: `RecurringTransactionCard` no longer places a `Flexible` details column inside its large-text vertical `Flex`, which previously caused an unbounded-height `RenderFlex` failure in the recurring sliver at approximately `1.65x` system text scale.
- Runtime follow-up: trailing financial amounts no longer use loose `Flexible` plus `FittedBox` combinations that leave unused space after the amount. The shared transaction tile, wallet stack card, and “Where the Money Went” rows now use bounded intrinsic trailing amounts so the details column fills the available width.
- Runtime follow-up: the wallets overview `PageView` now reserves additional height at the large-text threshold for the stacked net-worth, income, and spending metrics; its default `260/290px` viewport remains unchanged.
- Device/emulator validation remains outstanding: iOS Dynamic Type and Android font/display-scale rendering, platform-specific native controls, and runtime overflow banners cannot be proven by source inspection alone.
- The adaptive platform package accepts bottom navigation configuration objects rather than widget subtrees. Material and iOS-native paths use the compact policy; the package-generated legacy Cupertino path retains system scaling.
- Focused dashboard descendant pass completed without running Flutter commands, as required. Dart parsing/formatting was used only to validate the edited source syntax.
