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


