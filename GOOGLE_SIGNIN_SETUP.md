# Google Sign-In Setup Guide

## Overview

Google Sign-In is fully implemented using Supabase OAuth. This guide covers the required platform configuration for deep linking.

## Prerequisites

1. Google Cloud Project with OAuth credentials configured in Supabase
2. Supabase project with Google provider enabled
3. Deep linking configured for both iOS and Android

## Deep Linking Configuration

The app uses the scheme `moneko://` for OAuth callbacks.

### iOS Configuration

#### 1. Update Info.plist

Add to `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLName</key>
    <string>com.moneko.app</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>moneko</string>
    </array>
  </dict>
</array>
```

#### 2. Handle Deep Links

The app already handles deep links via `go_router`. No additional configuration needed.

### Android Configuration

#### 1. Update AndroidManifest.xml

Add to `android/app/src/main/AndroidManifest.xml` inside the `<activity>` tag:

```xml
<!-- Deep linking for OAuth callback -->
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />

    <!-- moneko:// scheme -->
    <data
        android:scheme="moneko"
        android:host="auth" />
</intent-filter>
```

Full activity example:

```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTop"
    android:theme="@style/LaunchTheme"
    android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
    android:hardwareAccelerated="true"
    android:windowSoftInputMode="adjustResize">

    <!-- Standard launch intent -->
    <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
    </intent-filter>

    <!-- Deep linking for OAuth callback -->
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />

        <data
            android:scheme="moneko"
            android:host="auth" />
    </intent-filter>
</activity>
```

## Supabase Configuration

### 1. Enable Google Provider

In your Supabase dashboard:

1. Go to Authentication → Providers
2. Enable Google provider
3. Add your Google Client ID and Client Secret
4. Add redirect URLs:
   - `https://<your-project-ref>.supabase.co/auth/v1/callback`
   - `moneko://auth/callback` (for mobile)

### 2. Google Cloud Console

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project
3. Go to APIs & Services → Credentials
4. Add authorized redirect URIs:
   - `https://<your-project-ref>.supabase.co/auth/v1/callback`

## How It Works

### Authentication Flow

1. **User taps "Continue with Google"**
   ```dart
   supabase.auth.signInWithOAuth(
     OAuthProvider.google,
     redirectTo: 'moneko://auth/callback?next=/dashboard',
   )
   ```

2. **Browser opens for Google authentication**
   - User selects Google account
   - Grants permissions

3. **Google redirects to Supabase**
   - `https://<project>.supabase.co/auth/v1/callback`
   - Supabase processes the OAuth code

4. **Supabase redirects to app via deep link**
   - `moneko://auth/callback?next=/dashboard`
   - App handles the deep link

5. **AuthCallbackScreen processes the session**
   - Retrieves session from Supabase
   - Navigates to dashboard or avatar customizer

### Code Implementation

**Google Login Button** (`lib/features/auth/presentation/widgets/google_login_button.dart`):
```dart
await supabase.auth.signInWithOAuth(
  OAuthProvider.google,
  redirectTo: 'moneko://auth/callback?next=${Uri.encodeComponent(redirectUrl ?? '/dashboard')}',
  authScreenLaunchMode: LaunchMode.externalApplication,
  scopes: 'https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/userinfo.profile openid',
  queryParams: {
    'access_type': 'offline',
    'prompt': 'consent',
  },
);
```

**Auth Callback Handler** (`lib/features/auth/presentation/pages/auth_callback_screen.dart`):
```dart
final session = await supabase.auth.getSession();
if (session.session != null) {
  context.go(next ?? '/dashboard');
}
```

## Testing

### Test Deep Linking

**iOS**:
```bash
xcrun simctl openurl booted "moneko://auth/callback?next=/dashboard"
```

**Android**:
```bash
adb shell am start -W -a android.intent.action.VIEW -d "moneko://auth/callback?next=/dashboard" com.moneko.app
```

### Test Google Sign-In

1. Run the app: `flutter run`
2. Tap "Continue with Google"
3. Select Google account in browser
4. App should redirect back and log you in

## Troubleshooting

### Deep Link Not Working

**iOS**:
- Verify Info.plist configuration
- Check URL scheme matches (`moneko`)
- Rebuild the app

**Android**:
- Verify AndroidManifest.xml
- Check intent-filter is inside `<activity>` tag
- Rebuild the app: `flutter clean && flutter build apk`

### OAuth Errors

**"redirect_uri_mismatch"**:
- Verify redirect URI in Google Cloud Console matches Supabase callback URL
- Check Supabase dashboard has Google provider enabled

**"Session not found"**:
- Wait 1-2 seconds after redirect (AuthCallbackScreen does this automatically)
- Check Supabase project URL in `.env`

**Browser doesn't return to app**:
- Verify deep link configuration
- Test deep link manually first
- Check app is in foreground when OAuth starts

## Security Considerations

1. **PKCE Flow**: Supabase automatically uses PKCE for mobile OAuth
2. **Scopes**: Only request necessary scopes (email, profile)
3. **Redirect Validation**: Supabase validates redirect URLs
4. **Session Security**: Sessions stored securely by Supabase Flutter SDK

## Production Checklist

- [ ] Deep linking configured for iOS
- [ ] Deep linking configured for Android
- [ ] Google provider enabled in Supabase
- [ ] Redirect URLs added to Supabase
- [ ] Redirect URLs added to Google Cloud Console
- [ ] Test OAuth flow on real devices
- [ ] Test deep link handling
- [ ] Verify session persistence

## Additional Resources

- [Supabase OAuth Docs](https://supabase.com/docs/guides/auth/social-login)
- [Flutter Deep Linking](https://docs.flutter.dev/development/ui/navigation/deep-linking)
- [Google OAuth](https://developers.google.com/identity/protocols/oauth2)
