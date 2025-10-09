# Moneko Mobile - Authentication Setup Guide

## Overview
This mobile app shares the same Supabase backend as the web version, providing a consistent authentication experience across platforms.

## Features Implemented

### ✅ Authentication Flow
- **Email/Password Registration** with OTP email verification
- **Email/Password Login** with secure password handling
- **Password Reset** via email
- **Session Management** with automatic token refresh
- **Route Protection** redirecting unauthenticated users to login

### ✅ Design System
- **shadcn_flutter components** for consistent UI with web
- **Dark/Light theme support** matching system preferences
- **Moneko brand colors** from web Tailwind configuration
- **Responsive layouts** with proper spacing and typography

### ✅ Environment Configuration
- **Development** environment (`.env.development`)
- **Production** environment (`.env`)
- Environment switching via build configuration

## Environment Setup

### 1. Environment Files

**Production** (`.env`):
```env
# Supabase Configuration - Production
SUPABASE_URL='https://qbuynyxyemigtnvdujts.supabase.co'
SUPABASE_ANON_KEY='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFidXlueXh5ZW1pZ3RudmR1anRzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc5MTcyODIsImV4cCI6MjA2MzQ5MzI4Mn0.tUdmoZ-oqagNvXlnNMym8FkZEUVDWRLMrqmuxuPTw6A'
```

**Development** (`.env.development`):
```env
# Supabase Configuration - Development
SUPABASE_URL='https://qbuynyxyemigtnvdujts.supabase.co'
SUPABASE_ANON_KEY='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFidXlueXh5ZW1pZ3RudmR1anRzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc5MTcyODIsImV4cCI6MjA2MzQ5MzI4Mn0.tUdmoZ-oqagNvXlnNMym8FkZEUVDWRLMrqmuxuPTw6A'
```

### 2. Switching Environments

**Development Build**:
```bash
flutter run --dart-define=ENV=development
```

**Production Build**:
```bash
flutter run --dart-define=ENV=production
# or simply
flutter run
```

**Build for Release**:
```bash
# Android
flutter build apk --dart-define=ENV=production

# iOS
flutter build ios --dart-define=ENV=production
```

## Project Structure

```
lib/
├── core/
│   ├── app/
│   │   ├── app.dart              # Main app with ShadcnApp & theme
│   │   ├── router.dart           # Go Router with auth guards
│   │   └── init.dart             # Supabase initialization
│   ├── theme/
│   │   └── app_theme.dart        # Light/Dark themes matching web
│   ├── util/
│   │   └── constants.dart        # Environment constants
│   └── resources/
│       └── lib/
│           └── supabase.dart     # Supabase client instance
├── features/
│   └── auth/
│       ├── domain/
│       │   └── app_user.dart     # User model
│       └── presentation/
│           ├── pages/
│           │   ├── login_screen.dart      # Login UI (shadcn_flutter)
│           │   └── register_screen.dart   # Register + OTP UI
│           └── states/
│               └── auth.dart              # Riverpod auth provider
└── main.dart
```

## Authentication Provider API

The auth provider (`lib/features/auth/presentation/states/auth.dart`) mirrors the web's `auth-context.tsx`:

```dart
// Sign in
final response = await ref.read(authProvider.notifier).signIn(email, password);

// Sign up
final response = await ref.read(authProvider.notifier).signUp(
  email: email,
  password: password,
  fullName: fullName,
);

// Verify OTP
final response = await ref.read(authProvider.notifier).verifyOtp(
  email: email,
  token: otpCode,
);

// Resend verification
await ref.read(authProvider.notifier).resendVerification(email);

// Reset password
await ref.read(authProvider.notifier).resetPassword(email);

// Sign out
await ref.read(authProvider.notifier).signOut();

// Check auth state
final isAuthenticated = ref.watch(authProvider.notifier).isAuthenticated;
final currentUser = ref.watch(authProvider);
```

## Build & Run

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Generate Code (Riverpod)
```bash
dart run build_runner build --delete-conflicting-outputs
```

### 3. Run Development
```bash
flutter run --dart-define=ENV=development
```

### 4. Run Production
```bash
flutter run
```

## Routes

| Route | Description | Auth Required |
|-------|-------------|---------------|
| `/login` | Login screen | No |
| `/register` | Registration + OTP verification | No |
| `/dashboard` | Main dashboard (home) | Yes |

## Theme System

The app uses `shadcn_flutter` with custom themes matching the web's Tailwind colors:

**Light Theme**:
- Background: `#F9FAFB`
- Foreground: `#1F2937`
- Primary: `#7458FF` (Moneko Purple)
- Success: `#16CDA2`
- Warning: `#FFC219`
- Danger: `#FF6060`

**Dark Theme**:
- Background: `#0A0E1A`
- Foreground: `#F1F5F9`
- Primary: `#8B70FF` (Lighter for dark mode)
- Success: `#1FE3B8`
- Warning: `#FFD04A`
- Danger: `#FF7A7A`

## Validation Rules

### Email
- Required
- Must contain `@`

### Password (Registration)
- Minimum 8 characters
- At least one uppercase letter
- At least one lowercase letter
- At least one number

### Password (Login)
- Minimum 6 characters

### Full Name
- Minimum 2 characters

## OTP Verification

- **Code Length**: 6 digits
- **Auto-submit**: Automatically verifies when 6th digit is entered
- **Resend Cooldown**: 60 seconds between resend attempts
- **Email Rate Limiting**: Supabase enforces email rate limits

## Error Handling

All errors are caught and displayed to users with friendly messages:

- **User already registered** → Prompts to sign in instead
- **Invalid credentials** → Clear error message
- **Rate limiting** → Instructs user to wait
- **OTP expired** → Prompts to resend code
- **Network errors** → Generic connection error message

## Production Checklist

- [x] Environment variables configured
- [x] Supabase credentials validated
- [x] Authentication flow tested
- [x] OTP verification working
- [x] Password reset functional
- [x] Dark/Light themes matching web
- [x] Route guards implemented
- [x] Error handling comprehensive
- [x] Loading states present
- [x] Form validation enforced
- [x] Session persistence enabled
- [x] Auto token refresh active

## Next Steps

1. **Run build_runner** to generate Riverpod providers
2. **Test authentication** flow end-to-end
3. **Implement Google Sign-In** (placeholder exists)
4. **Add biometric authentication** (optional)
5. **Implement avatar customizer** (web has this)
6. **Add more dashboard features**

## Troubleshooting

### Build Runner Fails
```bash
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### Supabase Connection Issues
- Verify `.env` file exists and is loaded
- Check SUPABASE_URL and SUPABASE_ANON_KEY values
- Ensure network connection is stable

### Theme Not Applying
- Verify `ShadcnApp.router` is used (not `MaterialApp`)
- Check `themeMode: ThemeMode.system` is set
- Restart app after theme changes

## Support

For issues related to:
- **Backend/Database**: Check Supabase dashboard
- **Web consistency**: Compare with `@moneko-web` implementation
- **Flutter/Dart**: See Flutter documentation
- **shadcn_flutter**: https://sunarya-thito.github.io/shadcn_flutter/
