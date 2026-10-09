#!/bin/bash

# iOS Deployment Script for Moneko Flutter App
# Refreshes release configuration and versions, creates a signed Xcode archive,
# verifies packaged versions, opens the archive in Xcode, and builds Android releases.
#
# Usage:
#   ./deploy_ios.sh             archive iOS and build Android APK + App Bundle
#   ./deploy_ios.sh --clean     flutter clean first (troubleshooting/fresh state)
#   ./deploy_ios.sh --android   accepted for compatibility; Android always builds

set -eo pipefail  # Exit on command and pipeline failures

# Resolve paths relative to this script, even when invoked from another folder.
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_step() {
    echo -e "${BLUE}📱 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Flags
DO_CLEAN=false
BUILD_ANDROID=true
for arg in "$@"; do
    case "$arg" in
        --clean) DO_CLEAN=true ;;
        --android) BUILD_ANDROID=true ;;
        --help|-h)
            echo "Usage: $0 [--clean] [--android]"
            exit 0
            ;;
        *)
            print_error "Unknown argument: $arg (use --help)"
            exit 1
            ;;
    esac
done

# Check if we're in the correct directory
if [ ! -f "pubspec.yaml" ]; then
    print_error "pubspec.yaml not found. Please run this script from the Flutter project root directory."
    exit 1
fi

# Require an explicit iOS version and build number before changing anything.
VERSION_LINE=$(sed -n '/^version:/p' pubspec.yaml)
VERSION_PATTERN="^version:[[:space:]]*['\"]?([0-9]+\\.[0-9]+\\.[0-9]+)\\+([0-9]+)['\"]?[[:space:]]*(#.*)?$"
if [[ ! "$VERSION_LINE" =~ $VERSION_PATTERN ]]; then
    print_error "Expected version: x.y.z+build in pubspec.yaml; found: $VERSION_LINE"
    exit 1
fi
BUILD_NAME=${BASH_REMATCH[1]}
BUILD_NUMBER=${BASH_REMATCH[2]}

print_step "Starting iOS release preparation..."
print_step "Using pubspec.yaml version $BUILD_NAME ($BUILD_NUMBER)"

# Step 1: Optional clean
if [ "$DO_CLEAN" = true ]; then
    print_step "Step 1/4: Running flutter clean..."
    flutter clean
    print_success "Flutter clean completed"
else
    print_step "Step 1/4: Skipping flutter clean (use --clean to enable)"
fi

# Step 2: Get dependencies
# Regenerates localizations (pubspec flutter: generate: true).
# pub get alone can retain stale version values in Generated.xcconfig.
print_step "Step 2/4: Running flutter pub get..."
flutter pub get
print_success "Dependencies installed"

# Explicitly regenerate the configuration used by Xcode's Release archive.
# --config-only avoids compiling the app twice; --no-codesign skips signing
# during preparation. The actual archive still uses normal Xcode signing.
print_step "Refreshing Flutter release configuration..."
flutter build ios --release --config-only --no-codesign \
    --build-name="$BUILD_NAME" --build-number="$BUILD_NUMBER" \
    --dart-define=ENV=prod
if ! grep -Fxq "FLUTTER_BUILD_NAME=$BUILD_NAME" ios/Flutter/Generated.xcconfig || \
   ! grep -Fxq "FLUTTER_BUILD_NUMBER=$BUILD_NUMBER" ios/Flutter/Generated.xcconfig; then
    print_error "Flutter generated configuration does not match pubspec.yaml"
    exit 1
fi
print_success "Flutter version and build number refreshed"

# Step 3: Navigate to iOS directory and install pods
print_step "Step 3/4: Installing iOS pods..."
cd ios

# Ensure pod command is available - try to source shell environment or use full path
if ! command -v pod &> /dev/null; then
    print_warning "pod command not found, trying to source shell environment..."
    # Try to source bash/zsh profile to get Ruby paths (ignore errors)
    if [ -f ~/.zshrc ]; then
        source ~/.zshrc 2>/dev/null || true
    elif [ -f ~/.bash_profile ]; then
        source ~/.bash_profile 2>/dev/null || true
    fi

    # If still not found, try the common Homebrew path
    if ! command -v pod &> /dev/null; then
        export PATH="/opt/homebrew/lib/ruby/gems/3.2.0/bin:$PATH"
    fi
fi

pod install
cd ..
print_success "iOS pods installed"

# Step 4: Sync every shipping target, including the widget and share extension.
# Extensions do not inherit Flutter's Generated.xcconfig. Keep their local
# Flutter values aligned, and make Xcode's Version/Build reference those values.
# Locate configurations by target identity, preserving unrelated project edits.
print_step "Step 4/4: Syncing app and extension versions..."
python3 - "$BUILD_NAME" "$BUILD_NUMBER" <<'PY'
import json
from pathlib import Path
import re
import subprocess
import sys

build_name, build_number = sys.argv[1:]
project = Path("ios/Runner.xcodeproj/project.pbxproj")
objects = json.loads(subprocess.check_output(
    ["plutil", "-convert", "json", "-o", "-", str(project)]
))["objects"]
source = project.read_text()
for target in objects.values():
    if target.get("productType") not in (
        "com.apple.product-type.application", "com.apple.product-type.app-extension"
    ):
        continue
    configs = objects[target["buildConfigurationList"]]["buildConfigurations"]
    for config_id in configs:
        pattern = re.compile(
            rf"(\t\t{re.escape(config_id)} /\*[^\n]*\*/ = \{{\n.*?\t\t\tbuildSettings = \{{\n)"
            r"(.*?)(\t\t\t\};)", re.DOTALL
        )
        match = pattern.search(source)
        if not match:
            sys.exit(f"Could not locate {target['name']} configuration {config_id}")
        settings = match[2]
        values = {
            "CURRENT_PROJECT_VERSION": '"$(FLUTTER_BUILD_NUMBER)"',
            "MARKETING_VERSION": '"$(FLUTTER_BUILD_NAME)"',
        }
        if target["productType"] == "com.apple.product-type.app-extension":
            values.update(FLUTTER_BUILD_NAME=build_name, FLUTTER_BUILD_NUMBER=build_number)
        for key, value in values.items():
            line = f"\t\t\t\t{key} = {value};\n"
            setting = re.compile(rf"^\t\t\t\t{key} = [^\n]*;\n", re.MULTILINE)
            settings = setting.sub(lambda _: line, settings) if setting.search(settings) else settings + line
        source = source[:match.start(2)] + settings + source[match.end(2):]
project.write_text(source)
PY
print_success "App, widget, and share extension versions synced"

# Create a signed archive without exporting or uploading an IPA.
ARCHIVE_PATH="$PWD/build/ios/archive/Moneko-$BUILD_NAME-$BUILD_NUMBER-$(date +%Y%m%d-%H%M%S).xcarchive"
mkdir -p "$(dirname "$ARCHIVE_PATH")"
print_step "Archiving iOS release with Xcode..."
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner \
    -configuration Release -destination 'generic/platform=iOS' \
    -archivePath "$ARCHIVE_PATH" -allowProvisioningUpdates archive

# Verify the actual packaged versions before reporting success.
APP_PATH="$ARCHIVE_PATH/Products/Applications/Runner.app"
shopt -s nullglob
for BUNDLE_PATH in "$APP_PATH" "$APP_PATH"/PlugIns/*.appex; do
    ACTUAL_NAME=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$BUNDLE_PATH/Info.plist")
    ACTUAL_NUMBER=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$BUNDLE_PATH/Info.plist")
    if [ "$ACTUAL_NAME" != "$BUILD_NAME" ] || [ "$ACTUAL_NUMBER" != "$BUILD_NUMBER" ]; then
        print_error "Archive version mismatch in $BUNDLE_PATH: $ACTUAL_NAME ($ACTUAL_NUMBER)"
        exit 1
    fi
done
print_success "Archive verified: $ARCHIVE_PATH"
open "$ARCHIVE_PATH"

# Android release builds (always enabled, matching the original script).
if [ "$BUILD_ANDROID" = true ]; then
    print_step "Building Android APK for production..."
    flutter build apk --release --dart-define=ENV=prod
    print_success "Android APK build completed successfully!"

    print_step "Building Android App Bundle for production..."
    flutter build appbundle --release --dart-define=ENV=prod
    print_success "Android App Bundle build completed successfully!"
fi

print_success "🎉 iOS archive and Android builds complete! Continue iOS validation/distribution in Xcode."
