# OAuth Google Sign-In Fix Summary

## Problem
When using Google Sign-In on mobile (both Android and iOS), after authentication in the browser, the app redirects back to the webpage instead of the mobile app, causing the app to wait indefinitely for the callback.

## ⚠️ CRITICAL: Supabase Configuration Required

**Before testing, you MUST configure Supabase:**

1. Go to your Supabase Dashboard
2. Navigate to **Authentication** → **URL Configuration**
3. Under "Redirect URLs", add:
   ```
   moneko://auth/callback
   ```
4. Click **Save**

Without this configuration, Supabase will reject the mobile deep link redirect!

## Root Cause
1. **Missing Android OAuth deep link**: AndroidManifest.xml only had `moneko://payment` configured, not `moneko://auth/callback`
2. **No OAuth callback handler**: DeepLinkService wasn't handling auth callbacks
3. **Incomplete deep link flow**: OAuth tokens weren't being properly intercepted by the app

## Fixes Applied

### 1. AndroidManifest.xml
**Added OAuth callback deep link configuration:**
```xml
<!-- Deep Link for OAuth callback -->
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="moneko" android:host="auth" android:pathPrefix="/callback"/>
</intent-filter>
```

### 2. DeepLinkService
**Added OAuth callback handling:**
- Intercepts `moneko://auth/callback` deep links
- Navigates to AuthCallbackScreen which processes the Supabase session
- Preserves the `next` query parameter for post-auth navigation

### 3. Existing Configuration (Already Correct)
✅ **Info.plist** - Already has `moneko` URL scheme configured  
✅ **GoogleLoginButton** - Uses correct `redirectTo` with deep link  
✅ **AuthCallbackScreen** - Properly waits for and processes Supabase session  
✅ **Router** - Has `/auth/callback` route configured  

## OAuth Flow After Fix

1. **User clicks "Continue with Google"**
   - App calls `supabase.auth.signInWithOAuth()`
   - Opens Google auth in external browser
   - Sets `redirectTo: 'moneko://auth/callback?next=/dashboard'`

2. **User authenticates with Google**
   - Google redirects to Supabase
   - Supabase processes OAuth and creates session
   - Supabase redirects to `moneko://auth/callback` with tokens

3. **Mobile OS intercepts deep link**
   - Android/iOS recognizes `moneko://auth/callback`
   - Opens the Moneko app (or brings it to foreground)

4. **App handles deep link**
   - DeepLinkService receives URI
   - Navigates to `/auth/callback` route
   - AuthCallbackScreen checks for session

5. **Session established**
   - Supabase automatically processes tokens from URL
   - User navigates to dashboard (or avatar for new users)

## 🔧 Required Steps to Apply Fix

### 1. Configure Supabase (CRITICAL - Do This First!)
```
1. Open Supabase Dashboard
2. Go to Authentication → URL Configuration
3. Add redirect URL: moneko://auth/callback
4. Save
```

### 2. Clean and Rebuild App (Required for Native Changes)

**Both platforms need a full rebuild since AndroidManifest.xml changed:**

```bash
# Clean the project
flutter clean

# Get dependencies
flutter pub get

# iOS: Clean native build
cd ios && rm -rf Pods Podfile.lock && pod install && cd ..

# Rebuild and run
flutter run
```

### 3. Testing Checklist

#### Android
- [ ] Verify Supabase redirect URL is configured
- [ ] Full rebuild completed (flutter clean)
- [ ] Click "Continue with Google"
- [ ] Complete Google authentication in browser
- [ ] **App should automatically return** (not stay in browser)
- [ ] Check logs for: `🔗 Deep link received: moneko://auth/callback`
- [ ] Verify session established and navigation works

#### iOS
- [ ] Verify Supabase redirect URL is configured
- [ ] Full rebuild completed (flutter clean + pod install)
- [ ] Click "Continue with Google"
- [ ] Complete Google authentication in browser  
- [ ] **App should automatically return** (not stay in browser)
- [ ] Check logs for: `🔗 Deep link received: moneko://auth/callback`
- [ ] Verify session established and navigation works

## Implementation Details

### Key Components

1. **AndroidManifest.xml** (`android/app/src/main/AndroidManifest.xml`)
   - Registers `moneko://auth/callback` as valid deep link

2. **Info.plist** (`ios/Runner/Info.plist`)
   - Already configured with `moneko` URL scheme

3. **DeepLinkService** (`lib/core/services/deep_link_service.dart`)
   - Listens for all deep links
   - Routes OAuth callbacks to AuthCallbackScreen

4. **GoogleLoginButton** (`lib/features/auth/presentation/widgets/google_login_button.dart`)
   - Triggers OAuth with proper redirect URL
   - Uses `LaunchMode.externalApplication` for browser

5. **AuthCallbackScreen** (`lib/features/auth/presentation/pages/auth_callback_screen.dart`)
   - Waits for Supabase to establish session
   - Determines if user is new or returning
   - Navigates accordingly

## Debugging Tips

If issues persist:

1. **Check logs for deep link events:**
   ```
   🔗 Deep link received: moneko://auth/callback
   🔐 OAuth callback received
   ```

2. **Verify Supabase redirect URL in dashboard:**
   - Go to Supabase Dashboard → Authentication → URL Configuration
   - Add `moneko://auth/callback` to "Redirect URLs"

3. **Test deep link manually:**
   ```bash
   # Android
   adb shell am start -W -a android.intent.action.VIEW -d "moneko://auth/callback?next=/dashboard"
   
   # iOS (Simulator)
   xcrun simctl openurl booted "moneko://auth/callback?next=/dashboard"
   ```

4. **Check Android logcat:**
   ```bash
   adb logcat | grep -i "moneko"
   ```

## Notes

- The fix follows Supabase's latest documentation for Flutter OAuth
- Deep links use the `moneko://` scheme matching the app's configuration
- Session tokens are automatically handled by Supabase Flutter SDK
- No manual token parsing is required
- Works for both new and existing users

## References

- [Supabase Flutter Auth Documentation](https://supabase.com/docs/reference/dart/auth-signinwithoauth)
- [Flutter Deep Linking Guide](https://docs.flutter.dev/development/ui/navigation/deep-linking)
- [app_links Package](https://pub.dev/packages/app_links)
