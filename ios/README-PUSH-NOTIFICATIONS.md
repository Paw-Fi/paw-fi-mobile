# iOS Push Notifications Configuration

## Overview

The Moneko iOS app uses Firebase Cloud Messaging (FCM) for push notifications, which requires proper Apple Push Notification service (APNs) configuration.

## Environment Configuration

### Development vs Production

The app uses **two separate entitlements files** to ensure correct APNs environment configuration:

| Build Configuration | Entitlements File | APNs Environment | Use Case |
|---------------------|------------------|------------------|----------|
| **Debug** | `Runner.entitlements` | `development` | Local development, TestFlight (sandbox) |
| **Release** | `Runner-Production.entitlements` | `production` | App Store distribution |
| **Profile** | `Runner-Production.entitlements` | `production` | Performance profiling for release |

### Why This Matters

- **Development APNs certificates** only work with apps built with `aps-environment: development`
- **Production APNs certificates** only work with apps built with `aps-environment: production`
- App Store requires `production` environment, but using it during development will fail
- TestFlight builds can use either, but typically use `development` for sandbox testing

## Firebase Configuration

### APNs Certificate Upload

1. **Development Certificate**:
   - Generated from Apple Developer Portal → Certificates → Apple Push Notification service SSL (Sandbox)
   - Upload to Firebase Console → Project Settings → Cloud Messaging → APNs Development Certificates

2. **Production Certificate**:
   - Generated from Apple Developer Portal → Certificates → Apple Push Notification service SSL (Production)
   - Upload to Firebase Console → Project Settings → Cloud Messaging → APNs Production Certificates

### FCM Server Key

The backend Edge Functions use the FCM Server Key to send push notifications:

```bash
# Set in Supabase Edge Function environment variables
FCM_SERVER_KEY=your-firebase-server-key-here
```

Get this from: Firebase Console → Project Settings → Cloud Messaging → Server key

## Build Configuration in Xcode

The `project.pbxproj` file has been configured to automatically use the correct entitlements file:

```xml
<!-- Debug Configuration -->
<key>CODE_SIGN_ENTITLEMENTS</key>
<string>Runner/Runner.entitlements</string>

<!-- Release Configuration -->
<key>CODE_SIGN_ENTITLEMENTS</key>
<string>Runner/Runner-Production.entitlements</string>

<!-- Profile Configuration -->
<key>CODE_SIGN_ENTITLEMENTS</key>
<string>Runner/Runner-Production.entitlements</string>
```

## Verification

### Test Development Builds

```bash
# Build and run on simulator/device
flutter run --debug

# Verify aps-environment
security cms -D -i path/to/Runner.app/embedded.mobileprovision | grep aps-environment
# Should show: development
```

### Test Production Builds

```bash
# Build release mode
flutter build ios --release

# Archive for App Store
# Xcode → Product → Archive
# Export and verify aps-environment in IPA
```

### Test Push Notifications

1. **Register Device**: App should call `households-register-device` Edge Function on launch
2. **Send Test Notification**: Trigger a household action (invite, split, etc.)
3. **Verify Delivery**: Check device receives notification
4. **Check Logs**: Review Supabase Edge Function logs for errors

## Troubleshooting

### "Invalid APNs Environment"

**Problem**: Push notifications fail with environment mismatch

**Solution**:
1. Verify entitlements file: `Runner.entitlements` (dev) vs `Runner-Production.entitlements` (prod)
2. Check build configuration in Xcode
3. Regenerate provisioning profiles if needed

### "Registration Failed"

**Problem**: Device registration fails in `device_registration_service.dart`

**Solution**:
1. Verify FCM_SERVER_KEY is set in Edge Function environment
2. Check Firebase Console → Cloud Messaging for APNs certificates
3. Verify app has notification permissions granted

### "Notifications Not Received"

**Problem**: No errors but notifications don't appear

**Solution**:
1. Check quiet hours settings in user preferences
2. Verify device is marked `is_active: true` in database
3. Check notification_events table for `is_sent: true` and `sent_at` timestamp
4. Review `households-process-notifications` Edge Function logs

## CI/CD Considerations

### GitHub Actions / Fastlane

Ensure your CI/CD pipeline:

1. **Uses correct provisioning profile** for App Store builds (production APNs)
2. **Sets build configuration** to Release or Profile for production builds
3. **Validates entitlements** before archiving:

```yaml
# Example GitHub Actions step
- name: Validate Entitlements
  run: |
    ENTITLEMENTS=$(xcodebuild -showBuildSettings -project ios/Runner.xcodeproj -configuration Release | grep CODE_SIGN_ENTITLEMENTS | awk '{print $3}')
    if [[ "$ENTITLEMENTS" != *"Production"* ]]; then
      echo "Error: Release build must use Production entitlements"
      exit 1
    fi
```

## References

- [Apple Push Notification service](https://developer.apple.com/documentation/usernotifications)
- [Firebase Cloud Messaging for iOS](https://firebase.google.com/docs/cloud-messaging/ios/client)
- [Flutter firebase_messaging plugin](https://pub.dev/packages/firebase_messaging)
- [Households Feature Push Notification Flow](../../moneko-web/supabase/functions/README-HOUSEHOLDS.md)

