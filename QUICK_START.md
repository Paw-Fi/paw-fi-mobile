# Moneko Mobile - Quick Start Guide

## 🚀 Get Started in 3 Steps

### Step 1: Generate Code
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### Step 2: Run the App
```bash
# Development mode
flutter run --dart-define=ENV=development

# OR Production mode
flutter run
```

### Step 3: Test Authentication
1. Tap "Register" on login screen
2. Fill in your details (email, password, name)
3. Check email for 6-digit code
4. Enter code to verify
5. You're in! 🎉

---

## 📋 What's Already Built

✅ **Complete Authentication**
- Email/password registration
- OTP email verification
- Login/logout
- Password reset
- Session persistence

✅ **Design System**
- shadcn_flutter components
- Dark/light themes matching web
- Moneko brand colors

✅ **Environment Setup**
- Development & production configs
- Same backend as web app
- Ready for deployment

---

## 📖 Full Documentation

- **[README_AUTH_SETUP.md](./README_AUTH_SETUP.md)** - Complete setup guide
- **[DEPLOYMENT.md](./DEPLOYMENT.md)** - Build & deploy instructions
- **[PRODUCTION_READY_SUMMARY.md](./PRODUCTION_READY_SUMMARY.md)** - Feature overview

---

## 🔧 Common Commands

```bash
# Clean and rebuild
flutter clean && flutter pub get

# Generate code
dart run build_runner build --delete-conflicting-outputs

# Run development
flutter run --dart-define=ENV=development

# Build for Android
flutter build appbundle --dart-define=ENV=production --release

# Build for iOS
flutter build ipa --dart-define=ENV=production --release
```

---

## ❓ Need Help?

Check the [PRODUCTION_READY_SUMMARY.md](./PRODUCTION_READY_SUMMARY.md) for testing checklist and troubleshooting.
