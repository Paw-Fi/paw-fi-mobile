# Moneko Mobile - Deployment Guide

## Pre-Deployment Checklist

### 1. Code Generation
```bash
# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Generate Riverpod and Freezed code
dart run build_runner build --delete-conflicting-outputs
```

### 2. Environment Configuration

Ensure both environment files exist:
- `.env` - Production credentials
- `.env.development` - Development credentials

Verify credentials match backend:
```bash
# Check production env
cat .env

# Check development env
cat .env.development
```

### 3. Version Bumping

Update version in `pubspec.yaml`:
```yaml
version: 1.0.0+1  # format: major.minor.patch+buildNumber
```

## Platform-Specific Setup

### iOS Deployment

#### 1. Configure iOS Project
```bash
cd ios
pod install
cd ..
```

#### 2. Update Info.plist
Add required permissions in `ios/Runner/Info.plist`:
```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Moneko needs access to your photo library to update your avatar</string>
<key>NSCameraUsageDescription</key>
<string>Moneko needs access to your camera to take photos for your avatar</string>
```

#### 3. Configure Signing
- Open `ios/Runner.xcworkspace` in Xcode
- Select Runner → Signing & Capabilities
- Set Team and Bundle Identifier

#### 4. Build for iOS
```bash
# Development
flutter build ios --dart-define=ENV=development --debug

# Production
flutter build ios --dart-define=ENV=production --release
```

#### 5. Submit to App Store
```bash
# Create IPA
flutter build ipa --dart-define=ENV=production

# Upload via Xcode or Transporter
open build/ios/archive/Runner.xcarchive
```

### Android Deployment

#### 1. Configure Signing

Create `android/key.properties`:
```properties
storePassword=<your-store-password>
keyPassword=<your-key-password>
keyAlias=upload
storeFile=<path-to-keystore>
```

Generate keystore if needed:
```bash
keytool -genkey -v -keystore ~/moneko-upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

#### 2. Update Build Configuration

Ensure `android/app/build.gradle` has signing config:
```gradle
android {
    ...
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

#### 3. Build for Android
```bash
# Development APK
flutter build apk --dart-define=ENV=development --debug

# Production APK
flutter build apk --dart-define=ENV=production --release

# Production App Bundle (recommended for Play Store)
flutter build appbundle --dart-define=ENV=production --release
```

#### 4. Submit to Google Play

Upload `build/app/outputs/bundle/release/app-release.aab` to Google Play Console.

## Environment-Specific Builds

### Development Build
```bash
# Run on device/simulator
flutter run --dart-define=ENV=development

# Build installable
flutter build apk --dart-define=ENV=development
```

### Staging Build (if needed)
```bash
# Create .env.staging first, then:
flutter run --dart-define=ENV=staging
```

### Production Build
```bash
# Android
flutter build appbundle --dart-define=ENV=production --release

# iOS
flutter build ipa --dart-define=ENV=production --release
```

## Build Artifacts

### Android
- **APK**: `build/app/outputs/flutter-apk/app-release.apk`
- **App Bundle**: `build/app/outputs/bundle/release/app-release.aab`

### iOS
- **IPA**: `build/ios/ipa/*.ipa`
- **Archive**: `build/ios/archive/Runner.xcarchive`

## Testing Before Deployment

### 1. Unit Tests
```bash
flutter test
```

### 2. Integration Tests
```bash
flutter test integration_test/
```

### 3. Manual Testing Checklist
- [ ] Email/password registration works
- [ ] OTP verification email received
- [ ] OTP code validates correctly
- [ ] Email/password login works
- [ ] Password reset email received
- [ ] Session persists after app restart
- [ ] Dark theme matches web design
- [ ] Light theme matches web design
- [ ] Loading states display correctly
- [ ] Error messages are user-friendly
- [ ] Navigation guards redirect properly
- [ ] Forms validate input correctly

## Release Process

### 1. Pre-Release
```bash
# Update version
# Edit pubspec.yaml: version: X.Y.Z+BUILD

# Generate code
dart run build_runner build --delete-conflicting-outputs

# Run tests
flutter test

# Build release
flutter build appbundle --dart-define=ENV=production --release  # Android
flutter build ipa --dart-define=ENV=production --release  # iOS
```

### 2. Release Notes

Create release notes documenting:
- New features
- Bug fixes
- Breaking changes
- Migration steps (if any)

### 3. Submit to Stores

**Google Play**:
1. Open Google Play Console
2. Select app → Production → Create new release
3. Upload `app-release.aab`
4. Add release notes
5. Review and roll out

**App Store**:
1. Open App Store Connect
2. Select app → + Version
3. Upload IPA via Xcode/Transporter
4. Fill in app information
5. Submit for review

## Post-Deployment

### 1. Monitor Metrics
- Crash reports (Firebase Crashlytics)
- Performance monitoring
- User analytics
- Backend logs (Supabase)

### 2. User Feedback
- Monitor app store reviews
- Check support channels
- Track reported issues

### 3. Rollback Plan

If critical issues arise:

**Google Play**:
- Use "Halt rollout" in Play Console
- Release previous version

**App Store**:
- Submit expedited review with fix
- Remove current version from sale if needed

## Continuous Integration (Optional)

### GitHub Actions Example

`.github/workflows/deploy.yml`:
```yaml
name: Deploy

on:
  push:
    tags:
      - 'v*'

jobs:
  build-android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: dart run build_runner build --delete-conflicting-outputs
      - run: flutter build appbundle --dart-define=ENV=production --release
      - uses: actions/upload-artifact@v3
        with:
          name: app-bundle
          path: build/app/outputs/bundle/release/app-release.aab

  build-ios:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: dart run build_runner build --delete-conflicting-outputs
      - run: flutter build ios --dart-define=ENV=production --release --no-codesign
```

## Troubleshooting

### Build Failures

**Issue**: Code generation errors
```bash
# Solution
flutter clean
rm -rf .dart_tool
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

**Issue**: Signing errors (iOS)
```bash
# Solution: Clean build folder
flutter clean
cd ios
pod deintegrate
pod install
cd ..
flutter build ios
```

**Issue**: Gradle build fails (Android)
```bash
# Solution: Clear Gradle cache
cd android
./gradlew clean
cd ..
flutter clean
flutter build apk
```

### Runtime Issues

**Issue**: White screen on launch
- Check for initialization errors in logs
- Verify Supabase credentials
- Ensure `.env` file is loaded

**Issue**: Authentication not working
- Verify Supabase URL and anon key
- Check network connectivity
- Review Supabase auth settings

**Issue**: Theme not applying
- Verify `ShadcnApp.router` usage
- Check theme data configuration
- Restart app after changes

## Security Checklist

- [ ] No hardcoded secrets in code
- [ ] `.env` files in `.gitignore`
- [ ] Supabase RLS policies enabled
- [ ] HTTPS only connections
- [ ] Certificate pinning (optional)
- [ ] ProGuard enabled (Android release)
- [ ] Bitcode enabled (iOS release)
- [ ] Debug logging disabled in release

## Performance Optimization

- [ ] App size optimized
- [ ] Images compressed
- [ ] Lazy loading implemented
- [ ] Network caching enabled
- [ ] Database queries optimized

## Compliance

- [ ] Privacy policy URL added
- [ ] Terms of service URL added
- [ ] Data retention policy documented
- [ ] GDPR compliance verified
- [ ] Age rating appropriate
- [ ] Content descriptors accurate

## Support

For deployment issues:
- Flutter: https://docs.flutter.dev/deployment
- Google Play: https://support.google.com/googleplay/android-developer
- App Store: https://developer.apple.com/app-store/
- Supabase: https://supabase.com/docs
