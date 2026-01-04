# rsupa

A flutter supabase auth starter build with riverpod

- supabase
- riverpod
- riverpod architecture

## Setup

- cp .env.example .env
- update url and anon keys

## Run
### Android
- flutter run -d emulator-5554 --dart-define=ENV=production

## Release to Production
### iOS
`
flutter build ios --release --dart-define=ENV=prod
`

### Android
`
flutter build appbundle --release --dart-define=ENV=prod
`

### Web
`
flutter build web --release --dart-define=ENV=prod
`

### Localization
`
flutter gen-l10n
`

## Testing

### Run Tests
```bash
flutter test
```

### Run Tests with Coverage
```bash
flutter test --coverage
```

### View Coverage Report (HTML)
```bash
# Install lcov (one-time setup on macOS)
brew install lcov

# Generate coverage
flutter test --coverage

# Generate HTML report
genhtml coverage/lcov.info -o coverage/html

# Open in browser
open coverage/html/index.html
```

**Current Coverage:** 1.6% (743 of 47,175 lines)

The HTML report shows:
- Overall coverage percentage
- Per-file coverage breakdown
- Line-by-line highlighting of covered/uncovered code
- Branch coverage details


