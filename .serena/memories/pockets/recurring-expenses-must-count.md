Critical product rule for Moneko pockets: recurring expense transactions MUST be included in pockets spend calculations (only income should be excluded). Root incident: user had Rent pocket linked to 'rent', with expense row category='rent' but is_recurring=true; pocket showed 0 due to recurring exclusion.

Enforcement points:
1) Backend SQL RPC get_pockets_month_v1 must NOT filter recurring out. In filtered_expenses CTE, do not include `coalesce(e.is_recurring, false) = false`; keep income exclusion only: `lower(coalesce(e.type::text,'expense')) <> 'income'`.
2) Backend category matching should normalize with trim+lower to avoid hidden whitespace mismatches:
   - link_rows category: lower(trim(coalesce(l.category,'')))
   - joins/comparisons against expenses category: lower(trim(coalesce(fe.category,...)))
3) Mobile pockets provider actual expenses must NOT filter `!expense.isRecurring`; exclude only income.
4) Mobile pocket details provider must include recurring in current and previous month totals; exclude only income.
5) Keep projection dedupe as-is so projected recurring entries are deduped against actual entries and not double-counted.

Files touched in latest fix cycle:
- moneko-web/supabase/migrations/20260403120000_get_pockets_month_rpc.sql (clean deploy baseline)
- moneko-web/supabase/migrations/20260403133000_include_recurring_expenses_in_pockets.sql (forward migration for existing DBs)
- moneko-mobile/lib/features/pockets/presentation/state/pockets_providers.dart
- moneko-mobile/lib/features/pockets/presentation/state/pocket_details_provider.dart

Regression guard:
- Test added in `moneko-mobile/test/features/pockets/presentation/state/pockets_providers_test.dart`:
  `filterPocketActualExpenses includes recurring expenses and excludes only income`.
  Keep/update this test when refactoring pockets fetching logic.

Operational guidance:
- If pockets regression appears where category-linked recurring expenses are missing, first verify recurring exclusion predicates in both SQL and FE filters.
- Do not reintroduce recurring exclusion in pockets logic unless product explicitly changes requirements.