# Authentication Flow Tests

This directory contains comprehensive widget tests for the authentication flows in the Moneko mobile app.

## Test Coverage

### Login Screen (`login_screen_test.dart`)
Tests the complete login flow including:

**UI Rendering**
- All essential UI elements (title, OAuth buttons, email/password fields, links)
- Password visibility toggle functionality
- Loading states and disabled fields

**Email Validation**
- Empty email detection
- Invalid email format detection
- Valid email acceptance

**Password Validation**
- Empty password detection
- Minimum length requirement (6 characters)
- Valid password acceptance

**Sign In Flow**
- Successful authentication and navigation to dashboard
- Device registration initialization
- Failed authentication error handling
- Keyboard submit action support
- Network error handling

**Navigation**
- Forgot password dialog display
- Navigation to register screen
- OAuth button state management

**Error Handling**
- Error shake animation
- Error message display and clearing
- Validation error feedback

**Edge Cases**
- Device registration failure handling
- Email whitespace trimming
- Widget disposal during async operations

### Register Screen (`register_screen_test.dart`)
Tests the complete registration and OTP verification flow:

**UI Rendering**
- Registration form with all input fields
- OAuth buttons and divider
- Password requirements display
- Terms agreement text

**Full Name Validation**
- Empty name detection
- Minimum length requirement (2 characters)
- Valid name acceptance

**Email Validation**
- Empty email detection
- Invalid format detection
- Valid email acceptance

**Password Validation**
- Minimum length requirement (8 characters)
- Uppercase letter requirement
- Lowercase letter requirement
- Number requirement
- Valid password acceptance

**Sign Up Flow**
- Successful registration transition to OTP view
- Failed registration error handling
- Keyboard submit action support

**OTP Verification Flow**
- OTP view rendering
- Successful verification and navigation to avatar
- Device registration initialization
- Resend OTP with cooldown
- Back button navigation to registration form

**Navigation**
- Navigation to login screen
- OAuth button state management

**Edge Cases**
- Input whitespace trimming
- Widget disposal during async operations
- Error clearing on retry

## Test Architecture

### Mocking Strategy
- **Auth Provider**: Mocked using Mockito to simulate authentication operations
- **GoRouter**: Mocked to verify navigation calls
- **DeviceRegistrationService**: Mocked to isolate push notification logic
- **Supabase**: Isolated through provider overrides, no actual network calls

### Test Structure
Each test file follows this pattern:
1. **Setup**: Create mocks and test widget wrapper
2. **Group Organization**: Tests grouped by feature area
3. **Assertions**: Verify both UI state and provider interactions
4. **Cleanup**: Automatic through Flutter test framework

### Key Testing Principles
- **Behavior over Implementation**: Tests focus on user-facing behavior
- **Isolation**: External dependencies are mocked
- **Determinism**: Tests produce consistent results
- **Coverage**: Critical paths and edge cases are tested
- **Maintainability**: Clear naming and organization

## Running Tests

### Run all auth tests
```bash
cd moneko-mobile
flutter test test/features/auth/
```

### Run specific test file
```bash
flutter test test/features/auth/presentation/pages/login_screen_test.dart
flutter test test/features/auth/presentation/pages/register_screen_test.dart
```

### Run with coverage
```bash
flutter test --coverage test/features/auth/
```

### Generate mock files (if needed)
```bash
flutter pub run build_runner build
```

## Test Data

### Valid Test Credentials
- **Email**: `test@example.com`
- **Password**: `password123` (login), `Password123` (register)
- **Full Name**: `John Doe`

### Invalid Test Cases
- **Email**: `invalid-email`, empty string
- **Password**: `12345` (too short), `password` (no uppercase), `PASSWORD` (no lowercase), `Password` (no number)
- **Full Name**: `A` (too short), empty string

## Dependencies

### Test Dependencies
- `flutter_test`: Flutter testing framework
- `mockito`: Mocking library
- `hooks_riverpod`: State management testing
- `go_router`: Navigation testing

### Mock Generation
Mocks are generated using `@GenerateMocks` annotation and `build_runner`:
- `MockAuth`: Simulates authentication operations
- `MockGoRouter`: Simulates navigation
- `MockDeviceRegistrationService`: Simulates push notification registration

## Future Enhancements

### Potential Test Additions
1. **Integration Tests**: End-to-end flow testing
2. **Golden Tests**: Visual regression testing
3. **Performance Tests**: Widget build performance
4. **Accessibility Tests**: Screen reader and semantic testing
5. **Localization Tests**: Multi-language support verification

### Areas for Expansion
- OAuth flow testing (Google, Wallet)
- Password reset flow testing
- Session persistence testing
- Biometric authentication testing
