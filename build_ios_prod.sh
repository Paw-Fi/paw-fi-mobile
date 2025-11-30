#!/usr/bin/env bash
set -euo pipefail

# Always run from the directory where this script lives
cd "$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

echo "[moneko-mobile] Cleaning Flutter project..."
flutter clean

echo "[moneko-mobile] Getting Flutter packages..."
flutter pub get

echo "[moneko-mobile] Generating localization files..."
flutter gen-l10n

echo "[moneko-mobile] Installing CocoaPods dependencies..."
pushd ios >/dev/null
pod install
popd >/dev/null

echo "[moneko-mobile] Building iOS release (ENV=prod)..."
flutter build ios --release --dart-define=ENV=prod

echo "[moneko-mobile] iOS prod build completed successfully."