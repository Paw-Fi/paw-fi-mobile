# iOS Provisioning Profile Issues - Troubleshooting Guide

## Error: Provisioning profile doesn't support Associated Domains and Push Notifications

**Symptom**:
```
Error (Xcode): Provisioning profile "iOS Team Provisioning Profile: *" doesn't support the Associated Domains and Push Notifications capability.

Error (Xcode): Provisioning profile "iOS Team Provisioning Profile: *" doesn't include the aps-environment and com.apple.developer.associated-domains entitlements.
```

**Cause**: The provisioning profile was created before the entitlements were added to the project. Xcode needs to regenerate it with the new capabilities.

## Solution 1: Automatic Signing (Recommended for Development)

### Step 1: Open Project in Xcode
```bash
cd /Users/charles/side-projects/Moneko/moneko-mobile
open ios/Runner.xcworkspace
```

### Step 2: Enable Automatic Signing
1. In Xcode, select the **Runner** project in the navigator
2. Select the **Runner** target
3. Go to **Signing & Capabilities** tab
4. For **Debug** configuration:
   - Check **Automatically manage signing**
   - Select your **Team**: GW28HYRJ9H
   - Xcode will automatically create/update the provisioning profile

5. For **Release** configuration:
   - Switch scheme to **Release** (top left, next to device selector)
   - Check **Automatically manage signing**
   - Select your **Team**: GW28HYRJ9H

### Step 3: Verify Capabilities
Ensure these capabilities are present (they should be added automatically from entitlements):

**Debug Configuration**:
- ✅ Push Notifications (aps-environment: development)
- ✅ Associated Domains (applinks:moneko.app)

**Release Configuration**:
- ✅ Push Notifications (aps-environment: production)
- ✅ Associated Domains (applinks:moneko.app)

### Step 4: Clean and Rebuild
```bash
# Clean build folder
flutter clean
cd ios
rm -rf Pods/ Podfile.lock
pod install
cd ..

# Try building again
flutter build ios --release
```

## Solution 2: Manual Signing (For Production/App Store)

### Step 1: Apple Developer Portal Setup

1. Go to [Apple Developer Portal](https://developer.apple.com/account)
2. Navigate to **Certificates, Identifiers & Profiles**

### Step 2: Update App Identifier

1. Click **Identifiers** → Select your app ID (`com.moneko.mobile`)
2. Ensure these capabilities are **enabled**:
   - ✅ Push Notifications
   - ✅ Associated Domains
3. Click **Save**

### Step 3: Delete Old Provisioning Profiles

1. Click **Profiles**
2. Find profiles for `com.moneko.mobile`
3. Delete outdated profiles (they'll be regenerated)

### Step 4: Create New Provisioning Profiles

**For Development** (Debug builds):
1. Click **+** to create new profile
2. Select **iOS App Development**
3. Select App ID: `com.moneko.mobile`
4. Select your development certificate
5. Select test devices
6. Name it: `Moneko Development`
7. Download and double-click to install

**For Distribution** (Release builds):
1. Click **+** to create new profile
2. Select **App Store** (for App Store submission) or **Ad Hoc** (for TestFlight)
3. Select App ID: `com.moneko.mobile`
4. Select your distribution certificate
5. Name it: `Moneko App Store` or `Moneko Ad Hoc`
6. Download and double-click to install

### Step 5: Configure Xcode for Manual Signing

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select **Runner** project → **Runner** target
3. Go to **Signing & Capabilities**
4. **Uncheck** "Automatically manage signing"
5. Select provisioning profiles:
   - Debug: `Moneko Development`
   - Release: `Moneko App Store` (or `Moneko Ad Hoc`)

### Step 6: Verify Entitlements Match

In Xcode, check that capabilities are present:
- Runner.entitlements (Debug): aps-environment = development
- Runner-Production.entitlements (Release): aps-environment = production

## Solution 3: Quick Fix (If Urgent)

If you need to build immediately and can't wait for provisioning profile updates:

### Option A: Temporarily Remove Entitlements

1. Open `ios/Runner.xcodeproj/project.pbxproj`
2. Comment out the CODE_SIGN_ENTITLEMENTS lines:
```
// CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;
// CODE_SIGN_ENTITLEMENTS = Runner/Runner-Production.entitlements;
```

3. Build without entitlements (push notifications and deep links won't work)

⚠️ **Important**: This is only for emergency builds. Re-enable entitlements for production.

### Option B: Use Different Bundle Identifier

If you can't modify the existing App ID:

1. Create a new App ID in Apple Developer Portal
2. Update `PRODUCT_BUNDLE_IDENTIFIER` in Xcode
3. Enable capabilities for new App ID
4. Create provisioning profiles for new App ID

⚠️ **Not recommended** for production - users will see it as a different app.

## Verification Steps

After applying the fix, verify:

### 1. Check Provisioning Profile Includes Entitlements
```bash
# Extract provisioning profile
security cms -D -i ~/Library/MobileDevice/Provisioning\ Profiles/*.mobileprovision > profile.plist

# Check for entitlements
grep -A 5 "Entitlements" profile.plist
```

Should show:
```xml
<key>Entitlements</key>
<dict>
    <key>aps-environment</key>
    <string>development</string>  <!-- or production -->
    <key>com.apple.developer.associated-domains</key>
    <array>
        <string>applinks:moneko.app</string>
    </array>
</dict>
```

### 2. Build Succeeds
```bash
flutter build ios --release
# Should complete without provisioning errors
```

### 3. Check Embedded Entitlements in Built App
```bash
codesign -d --entitlements - build/ios/iphoneos/Runner.app
```

Should show the entitlements from Runner-Production.entitlements.

## Common Issues

### Issue: "No profiles for 'com.moneko.mobile' were found"

**Solution**:
1. Ensure App ID exists in Apple Developer Portal
2. Ensure team is selected in Xcode
3. Try "Download Manual Profiles" in Xcode → Preferences → Accounts

### Issue: "Signing certificate is not valid"

**Solution**:
1. Check certificate expiration in Apple Developer Portal
2. Regenerate certificate if expired
3. Download and install in Keychain Access

### Issue: "The executable was signed with invalid entitlements"

**Solution**:
1. Ensure entitlements in .entitlements file match App ID capabilities
2. Verify aps-environment matches build configuration (development/production)
3. Clean build folder and rebuild

### Issue: "Provisioning profile doesn't match entitlements file"

**Solution**:
1. Delete derived data: `rm -rf ~/Library/Developer/Xcode/DerivedData/*`
2. Restart Xcode
3. Regenerate provisioning profiles in Apple Developer Portal

## Prevention

To avoid this issue in the future:

1. **Use Automatic Signing** for development (Xcode handles profile updates)
2. **Document Capabilities**: Keep list of required capabilities in README
3. **Version Control**: Don't commit `.mobileprovision` files (they're user-specific)
4. **CI/CD**: Use Fastlane to manage provisioning profiles automatically

## References

- [Apple: Troubleshooting Code Signing](https://developer.apple.com/support/code-signing/)
- [Apple: Entitlements](https://developer.apple.com/documentation/bundleresources/entitlements)
- [Flutter: iOS Setup](https://docs.flutter.dev/deployment/ios)

