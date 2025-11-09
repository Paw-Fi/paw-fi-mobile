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

# Step 4: Create zip archive of dSYM files
print_step "Step 4/4: Creating zip archive of dSYM files..."

# Create timestamp for zip filename
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
ZIP_FILENAME="dsym_files_${TIMESTAMP}.zip"

# Create zip file
cd "$DSYM_OUTPUT_DIR"
zip -r "../$ZIP_FILENAME" .
cd ..

print_success "dSYM files zipped to: $ZIP_FILENAME"

# Clean up unzipped dSYM files to save space
print_step "Cleaning up unzipped dSYM files..."
rm -rf "$DSYM_OUTPUT_DIR"
print_success "Unzipped dSYM files deleted to save space"

# Instructions for uploading to Firebase Crashlytics
echo ""
print_success "🎉 dSYM extraction completed!"
print_warning "Files available:"
echo "• Zip archive: $ZIP_FILENAME"
echo ""

# Step 5: Upload to Firebase Crashlytics (optional)
print_step "Step 5/5: Uploading to Firebase Crashlytics..."

# Firebase iOS App ID
FIREBASE_APP_ID="1:1075784863194:ios:5d785653675dce8e2ec4e3"

# Check if Firebase CLI is available
if command -v firebase &> /dev/null; then
    print_step "Firebase CLI found. Uploading dSYM files..."
    echo "App ID: $FIREBASE_APP_ID"
    echo "File: $ZIP_FILENAME"
    
    # Upload to Firebase Crashlytics
    if firebase crashlytics:symbols:upload --app="$FIREBASE_APP_ID" "$ZIP_FILENAME"; then
        print_success "🎉 dSYM files uploaded successfully to Firebase Crashlytics!"
        print_warning "You can now view crash reports in the Firebase Console."
        echo ""
        echo "Firebase Console: https://console.firebase.google.com/project/moneko-9c2c6/crashlytics"
    else
        print_error "Failed to upload dSYM files to Firebase."
        print_warning "You can upload manually using:"
        echo "firebase crashlytics:symbols:upload --app=$FIREBASE_APP_ID $ZIP_FILENAME"
    fi
else
    print_warning "Firebase CLI not found. Skipping automatic upload."
    print_warning "To upload manually:"
    echo "1. Install Firebase CLI: npm install -g firebase-tools"
    echo "2. Run: firebase crashlytics:symbols:upload --app=$FIREBASE_APP_ID $ZIP_FILENAME"
fi

echo ""
print_success "✅ Complete workflow finished!"
echo "• dSYM files extracted and zipped: $ZIP_FILENAME"
echo "• Firebase upload: completed above (if CLI available)"
