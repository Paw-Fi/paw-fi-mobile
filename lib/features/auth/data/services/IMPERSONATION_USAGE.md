# Impersonation Service Usage Guide

## Overview

The impersonation service allows admin users (those with `is_creator = true` in the database) to view data from another user's perspective without actually logging in as that user. This is useful for debugging user-reported issues.

## Features

- ✅ View-only impersonation (admin stays logged in)
- ✅ Reuses existing `is_creator` column for admin verification
- ✅ Visual banner when impersonating
- ✅ Profile page integration for easy access
- ✅ Automatic filtering of data by impersonated user

## How to Use

### 1. Start Impersonation

As an admin, navigate to your Profile page. You'll see an "Admin Tools" card with an "Impersonate User" button.

1. Click "Impersonate User"
2. Enter the email address of the user you want to impersonate
3. Click "Start"

### 2. While Impersonating

- An orange banner appears at the top of the app showing you're in impersonation mode
- All data queries will show data for the impersonated user
- You remain logged in as yourself (admin)

### 3. Exit Impersonation

Click the "EXIT" button in the orange banner at the top, or use the "Exit Impersonation" button in the Admin Tools card.

## For Developers: Integrating in Your Code

### Using with Queries

When querying data that should respect impersonation:

```dart
// Import the service
import 'package:moneko/features/auth/data/services/impersonation_service.dart';

// In your widget or provider
final impersonation = ref.watch(impersonationProvider);
final user = ref.watch(authProvider);

// Get the effective email to use in queries
final effectiveEmail = impersonation.getEffectiveUserEmail(user.email);

// Use in Supabase queries
final data = await supabase
    .from('your_table')
    .select()
    .eq('user_email', effectiveEmail);  // Will use impersonated email if active
```

### Using with User ID

```dart
// Get the effective user ID
final effectiveUserId = await impersonation.getEffectiveUserId(user.uid);

// Use in Supabase queries
final data = await supabase
    .from('your_table')
    .select()
    .eq('user_id', effectiveUserId);
```

### Example: Updating a Provider

```dart
@riverpod
Future<List<Transaction>> userTransactions(UserTransactionsRef ref) async {
  final user = ref.watch(authProvider);
  final impersonation = ref.watch(impersonationProvider);

  // Get effective email - returns impersonated email if active, otherwise current user's email
  final effectiveEmail = impersonation.getEffectiveUserEmail(user.email);

  final response = await supabase
      .from('transactions')
      .select()
      .eq('user_email', effectiveEmail)
      .order('created_at', ascending: false);

  return response.map((json) => Transaction.fromJson(json)).toList();
}
```

## Security Considerations

### Built-in Protections

1. **Admin verification**: Only users with `is_creator = true` can impersonate
2. **User existence check**: Target user must exist before impersonation starts
3. **Audit logging**: All impersonation sessions are logged via `appLog`
4. **Visual indicators**: Prominent banner prevents accidental actions while impersonating
5. **No write access**: Consider making impersonated views read-only

### Recommended: RLS Policies

Update your Supabase RLS policies to allow admins to read any user's data:

```sql
-- Example: Allow admins to view all user data
CREATE POLICY "Admins can view all user data"
ON your_table FOR SELECT
TO authenticated
USING (
  -- User can see their own data
  user_id = auth.uid()
  OR
  -- OR admin can see any data
  auth.uid() IN (
    SELECT id FROM users WHERE is_creator = true
  )
);
```

### Recommended: Read-Only Mode

For maximum safety, consider making impersonation read-only by default:

```dart
// Check if in impersonation mode before writes
if (impersonation.isImpersonating) {
  // Show error: "Cannot modify data while impersonating"
  return;
}

// Proceed with write operation
await supabase.from('table').insert(data);
```

## Database Schema

The service uses the existing `is_creator` column in the `users` table:

```sql
create table if not exists public.users (
  id uuid primary key default gen_random_uuid(),
  email text not null unique,
  full_name text,
  avatar_url text,
  is_creator boolean default false,  -- Used for admin verification
  -- ... other columns
);
```

## Troubleshooting

### "Impersonation denied: user is not a creator"

Your account doesn't have `is_creator = true` in the database. Update it:

```sql
UPDATE users SET is_creator = true WHERE email = 'your-admin-email@example.com';
```

### "Impersonation failed: user not found"

The email you entered doesn't exist in the database. Double-check the email address.

### Data not showing for impersonated user

Make sure your queries use `getEffectiveUserEmail()` or `getEffectiveUserId()` instead of directly using the current user's email/ID.

### Impersonation banner not showing

The banner only shows when actively impersonating. Check:
1. Did impersonation start successfully?
2. Is the `ImpersonationBanner` widget included in your app shell?

## Files Created

- `lib/features/auth/data/services/impersonation_service.dart` - Core service
- `lib/features/auth/presentation/widgets/impersonation_banner.dart` - Top banner UI
- `lib/features/auth/presentation/widgets/impersonation_dialog.dart` - Start dialog
- `lib/features/profile/presentation/widgets/impersonation_card.dart` - Profile card
- Updated: `lib/features/auth/domain/app_user.dart` - Added `isCreator` field
- Updated: `lib/features/profile/presentation/providers/user_profile_provider.dart` - Added `isCreator`
- Updated: `lib/core/navigation/main_shell.dart` - Added banner

## Next Steps

After running code generation (`flutter pub run build_runner build --delete-conflicting-outputs`):

1. Test the feature with a creator account
2. Update your data providers to use `getEffectiveUserEmail()`
3. Consider adding read-only restrictions while impersonating
4. Add Supabase RLS policies for admin data access
