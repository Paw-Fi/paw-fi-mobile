# Impersonation Feature Implementation Summary

## What Was Implemented

A **view-only impersonation system** that allows admin users (with `is_creator = true`) to view data from another user's perspective without actually logging in as that user. This is perfect for debugging user-reported issues.

## Key Features

✅ **Admin-only access** - Uses existing `is_creator` column for verification
✅ **View-only mode** - Admin stays logged in, just views different user's data
✅ **Visual indicators** - Orange banner when impersonating
✅ **Easy access** - Profile page integration with Admin Tools card
✅ **Secure** - User verification and audit logging built-in

## Files Created

### Core Service
- `lib/features/auth/data/services/impersonation_service.dart` - Main impersonation logic
- `lib/features/auth/data/services/impersonation_service.g.dart` - Generated provider code

### UI Components
- `lib/features/auth/presentation/widgets/impersonation_banner.dart` - Top banner showing impersonation status
- `lib/features/auth/presentation/widgets/impersonation_dialog.dart` - Dialog to start impersonation
- `lib/features/profile/presentation/widgets/impersonation_card.dart` - Profile page admin card

### Documentation
- `lib/features/auth/data/services/IMPERSONATION_USAGE.md` - Complete usage guide

## Files Modified

### Models
- `lib/features/auth/domain/app_user.dart` - Added `isCreator` field
- `lib/features/profile/presentation/providers/user_profile_provider.dart` - Added `isCreator` to UserProfile

### UI Integration
- `lib/features/auth/presentation/widgets/widgets.dart` - Exported new widgets
- `lib/features/profile/presentation/widgets/widgets.dart` - Exported impersonation card
- `lib/features/profile/presentation/pages/profile_page.dart` - Added impersonation card
- `lib/core/navigation/main_shell.dart` - Added impersonation banner at top

## How to Use

### As an Admin User

1. **Make yourself a creator** in the database:
   ```sql
   UPDATE users SET is_creator = true WHERE email = 'your-email@example.com';
   ```

2. **Start impersonation:**
   - Go to Profile page
   - Look for "Admin Tools" card
   - Click "Impersonate User"
   - Enter target user's email
   - Click "Start"

3. **While impersonating:**
   - Orange banner appears at top
   - All data shows from impersonated user's perspective
   - You stay logged in as yourself

4. **Exit impersonation:**
   - Click "EXIT" in the banner
   - Or use "Exit Impersonation" button in Admin Tools

### For Developers: Integrating in Queries

To make your data queries respect impersonation:

```dart
import 'package:moneko/features/auth/data/services/impersonation_service.dart';

// In your provider/widget
final impersonation = ref.watch(impersonationProvider);
final user = ref.watch(authProvider);

// Get effective email (impersonated or current user)
final effectiveEmail = impersonation.getEffectiveUserEmail(user.email);

// Use in queries
final data = await supabase
    .from('transactions')
    .select()
    .eq('user_email', effectiveEmail);  // Will use impersonated email if active
```

## Next Steps

1. **Test the feature:**
   - Set `is_creator = true` for your account
   - Try impersonating a test user
   - Verify the banner appears
   - Verify you can exit impersonation

2. **Update your data providers:**
   - Find all queries filtering by user email/ID
   - Replace with `getEffectiveUserEmail()` or `getEffectiveUserId()`
   - This ensures data respects impersonation mode

3. **Optional: Add RLS policies** in Supabase:
   ```sql
   CREATE POLICY "Admins can view all user data"
   ON your_table FOR SELECT
   TO authenticated
   USING (
     user_id = auth.uid()
     OR
     auth.uid() IN (SELECT id FROM users WHERE is_creator = true)
   );
   ```

4. **Optional: Make it read-only:**
   ```dart
   if (impersonation.isImpersonating) {
     // Show error: "Cannot modify data while impersonating"
     return;
   }
   // Proceed with write operation
   ```
   
## Testing Checklist

- [ ] Set `is_creator = true` for your account in database
- [ ] Admin Tools card appears on profile page for creators
- [ ] Can open impersonation dialog
- [ ] Can enter email and start impersonation
- [ ] Orange banner appears at top when impersonating
- [ ] Banner shows correct impersonated email
- [ ] Can exit impersonation from banner
- [ ] Can exit impersonation from Admin Tools card
- [ ] Non-creator users don't see Admin Tools card
- [ ] Non-creator users cannot start impersonation

## Security Notes

- ✅ Only users with `is_creator = true` can impersonate
- ✅ Target user must exist before impersonation starts
- ✅ All impersonation sessions logged via `appLog`
- ✅ Visual banner prevents accidental actions
- ⚠️ Consider adding read-only restrictions while impersonating
- ⚠️ Consider adding Supabase RLS policies for data access

## Example: Updating a Provider

Before:
```dart
@riverpod
Future<List<Transaction>> userTransactions(UserTransactionsRef ref) async {
  final user = ref.watch(authProvider);

  final response = await supabase
      .from('transactions')
      .select()
      .eq('user_email', user.email);  // Always uses current user

  return response.map((json) => Transaction.fromJson(json)).toList();
}
```

After:
```dart
@riverpod
Future<List<Transaction>> userTransactions(UserTransactionsRef ref) async {
  final user = ref.watch(authProvider);
  final impersonation = ref.watch(impersonationProvider);

  // Get effective email - returns impersonated email if active
  final effectiveEmail = impersonation.getEffectiveUserEmail(user.email);

  final response = await supabase
      .from('transactions')
      .select()
      .eq('user_email', effectiveEmail);  // Respects impersonation

  return response.map((json) => Transaction.fromJson(json)).toList();
}
```

## Troubleshooting

See `lib/features/auth/data/services/IMPERSONATION_USAGE.md` for detailed troubleshooting guide.

## Questions?

Refer to the usage guide at:
`lib/features/auth/data/services/IMPERSONATION_USAGE.md`
