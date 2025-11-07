#!/bin/bash

# Script to extract dSYM files for iOS app
# This script builds the iOS app and extracts the dSYM files for crash reporting

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${BLUE}🔍 $1${NC}"
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

# Check if we're in the correct directory
if [ ! -f "pubspec.yaml" ]; then
    print_error "pubspec.yaml not found. Please run this script from the Flutter project root directory."
    exit 1
fi

print_step "Extracting dSYM files for iOS app..."

# Step 1: Clean and build the app
print_step "Step 1/3: Cleaning and building iOS app..."
flutter clean
flutter pub get
flutter gen-l10n
cd ios && pod install && cd ..

# Step 2: Build and archive the app
print_step "Step 2/3: Building iOS archive..."
flutter build ios --release --dart-define=ENV=prod

# Step 3: Extract dSYM files
print_step "Step 3/3: Extracting dSYM files..."

# Find the most recent archive
ARCHIVE_DIR=$(find ~/Library/Developer/Xcode/Archives -name "*.xcarchive" -type d | sort -t '-' -k 2 -n | tail -1)

if [ -z "$ARCHIVE_DIR" ]; then
    print_error "No archive found. Please make sure the build completed successfully."
    exit 1
fi

print_success "Found archive: $ARCHIVE_DIR"

# Create dSYM output directory
DSYM_OUTPUT_DIR="./dsym_files"
mkdir -p "$DSYM_OUTPUT_DIR"

# Copy dSYM files from the archive
DSYM_SOURCE="$ARCHIVE_DIR/dSYMs"
if [ -d "$DSYM_SOURCE" ]; then
    cp -r "$DSYM_SOURCE"/* "$DSYM_OUTPUT_DIR/"
    print_success "dSYM files copied to: $DSYM_OUTPUT_DIR"
    
    # List the dSYM files
    echo ""
    print_step "dSYM files extracted:"
    find "$DSYM_OUTPUT_DIR" -name "*.dSYM" -type d | while read dsym; do
        echo "  📦 $dsym"
    done
else
    print_error "No dSYM files found in the archive."
    exit 1
fi

# Instructions for uploading to Firebase Crashlytics
echo ""
print_success "🎉 dSYM extraction completed!"
print_warning "Next steps for Firebase Crashlytics:"
echo "1. Open Firebase Console -> Your App -> Crashlytics"
echo "2. Go to 'dSYM files' tab"
echo "3. Upload the dSYM files from: $DSYM_OUTPUT_DIR"
echo ""
echo "Or use Firebase CLI to upload automatically:"
echo "firebase crashlytics:symbols:upload --app=YOUR_IOS_APP_ID $DSYM_OUTPUT_DIR/*.app.dSYM"
echo ""
print_warning "Note: Make sure you have the Firebase CLI installed and authenticated."
