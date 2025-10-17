# Force Update - Quick Start

## 🚀 Quick Setup (5 minutes)

### 1. Install Dependencies
```bash
cd moneko-mobile
flutter pub get
```

### 2. Generate Code
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 3. Create Database Table

Copy and run this SQL in Supabase SQL Editor:

```sql
CREATE TABLE IF NOT EXISTS app_version_config (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  platform TEXT NOT NULL CHECK (platform IN ('ios', 'android')),
  min_version TEXT NOT NULL,
  latest_version TEXT NOT NULL,
  force_update BOOLEAN NOT NULL DEFAULT false,
  update_message TEXT,
  ios_app_store_url TEXT,
  android_play_store_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (platform)
);

ALTER TABLE app_version_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "public_read" ON app_version_config FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "service_role_all" ON app_version_config FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Insert iOS config
INSERT INTO app_version_config (platform, min_version, latest_version, force_update, ios_app_store_url)
VALUES ('ios', '1.0.0', '1.0.0', false, 'https://testflight.apple.com/join/YOUR_CODE')
ON CONFLICT (platform) DO NOTHING;

-- Insert Android config
INSERT INTO app_version_config (platform, min_version, latest_version, force_update, android_play_store_url)
VALUES ('android', '1.0.0', '1.0.0', false, 'https://play.google.com/store/apps/details?id=com.moneko.app')
ON CONFLICT (platform) DO NOTHING;
```

### 4. Update Main App

Find your `main.dart` or main app widget and wrap it:

```dart
import 'package:moneko/features/app_version/presentation/widgets/version_check_wrapper.dart';

// Find where you return MaterialApp.router or MaterialApp
// Wrap it with VersionCheckWrapper:

@override
Widget build(BuildContext context, WidgetRef ref) {
  return VersionCheckWrapper(  // ← Add this
    child: MaterialApp.router(
      // ... existing code ...
    ),
  );
}
```

### 5. Test It!

```bash
# Set your current version to 1.0.0 (in pubspec.yaml if not already)
# Then update database to force update:
```

```sql
UPDATE app_version_config
SET min_version = '1.0.1', force_update = true
WHERE platform = 'ios';
```

```bash
# Run app
flutter run

# You should see the force update dialog after 1 second!
```

### 6. Reset After Testing

```sql
UPDATE app_version_config
SET min_version = '1.0.0', force_update = false
WHERE platform = 'ios';
```

---

## 📝 Day-to-Day Usage

### When Releasing New Version:

1. **Release v1.0.1 to TestFlight**

2. **Wait 1-2 days** for testing

3. **Force all users to update:**
   ```sql
   UPDATE app_version_config
   SET 
     min_version = '1.0.1',
     latest_version = '1.0.1',
     force_update = true,
     updated_at = now()
   WHERE platform = 'ios';
   ```

4. **Done!** All users with v1.0.0 will see the update dialog.

### To Disable Force Update:

```sql
UPDATE app_version_config
SET force_update = false
WHERE platform = 'ios';
```

---

## 🔧 Update Your TestFlight Link

```sql
UPDATE app_version_config
SET ios_app_store_url = 'https://testflight.apple.com/join/YOUR_ACTUAL_CODE'
WHERE platform = 'ios';
```

---

## ✅ That's It!

**Full documentation**: See `FORCE_UPDATE_SETUP.md`

**Key Points:**
- ✅ Non-blocking: Doesn't slow down app startup
- ✅ Flexible: Enable/disable via database
- ✅ User-friendly: Clear messaging about why update is needed
- ✅ Force update: User cannot dismiss the dialog
- ✅ Platform-aware: Different configs for iOS/Android
