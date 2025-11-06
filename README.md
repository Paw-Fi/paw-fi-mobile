# rsupa

A flutter supabase auth starter build with riverpod

- supabase
- riverpod
- riverpod architecture

## Setup

- cp .env.example .env
- update url and anon keys

## Release to Production
### iOS
`
flutter build ios --release --dart-define=ENV=prod
`

### Android
`
flutter build appbundle --release --dart-define=ENV=prod
`

### Localization
`
flutter gen-l10n
`


