# Incomplete Households Pages

## Status: Excluded from Build

The following pages have been temporarily excluded from the build (renamed with `.todo` suffix) because they contain compilation errors and are incomplete implementations:

1. `household_invites_page.dart.todo`
2. `household_members_page.dart.todo`
3. `household_settings_page.dart.todo`
4. `household_split_builder_page.dart.todo`

## Why Excluded?

These pages were scaffold/stub implementations that referenced:
- Missing entity types (`HouseholdInvite`)
- Incomplete shadcn_flutter Button API usage
- Incomplete repository methods
- Missing data models

Since the households feature is **feature-flagged** (disabled by default in `feature_flags` table), these pages aren't accessible to users anyway. Excluding them allows the app to build while preserving the code for future implementation.

## Errors Found

### household_invites_page.dart
- Missing `style` parameter on `shadcnui.Button`
- Undefined `variant` parameter
- Wrong argument types for repository methods
- Missing `HouseholdInvite` entity type

### household_members_page.dart
- Missing `style` parameter on `shadcnui.Button`
- Undefined `variant` parameter

### household_settings_page.dart
- Undefined class `household`
- Missing required parameters on `createBudget()`
- Missing `style` parameter on buttons

### split_builder_page.dart
- Missing `style` parameter on `shadcnui.Button`

## To Re-enable

When implementing these pages properly:

1. **Rename back to `.dart`**:
   ```bash
   mv household_invites_page.dart.todo household_invites_page.dart
   ```

2. **Create missing entities**:
   - `HouseholdInvite` entity in `domain/entities/`

3. **Fix shadcn_flutter usage**:
   ```dart
   // Add required style parameter
   shadcnui.Button(
     style: shadcnui.ButtonStyle.primary,  // or .secondary, .destructive, etc.
     onPressed: () {},
     child: Text('Button'),
   )
   ```

4. **Implement repository methods**:
   - Complete `household_repository.dart` interface
   - Implement in `household_repository_impl.dart`

5. **Test thoroughly** before enabling feature flag

## Working Pages

These household pages **do** work and are included in the build:

- ✅ `household_invitation_handler_page.dart` - Handles deep link invite acceptance
- ✅ `household_overview_page.dart` - Main household dashboard

## Feature Flag

The households feature is controlled by the `households.enabled` feature flag in the database:

```sql
-- Check current status
SELECT * FROM feature_flags WHERE key = 'households.enabled';

-- Enable for testing (after pages are fixed)
UPDATE feature_flags SET enabled = true, rollout_percentage = 10 WHERE key = 'households.enabled';
```

## Next Steps

1. Complete the missing entity types
2. Fix shadcn_flutter Button usage throughout
3. Implement complete repository interface
4. Add proper error handling
5. Write tests for each page
6. Re-enable pages one by one
7. Test with feature flag enabled
8. Progressive rollout per feature flag documentation

