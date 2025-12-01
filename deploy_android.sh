#!/bin/bash

# Android Deployment Script for Moneko Flutter App
# This script automates the complete Android build and deployment process

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_step() {
    echo -e "${BLUE}🤖 $1${NC}"
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

print_step "Starting Android deployment process..."

# Step 1: Clean Flutter project
print_step "Step 1/6: Running flutter clean..."
flutter clean
print_success "Flutter clean completed"

# Step 2: Get dependencies
print_step "Step 2/6: Running flutter pub get..."
flutter pub get
print_success "Dependencies installed"

# Step 3: Generate localizations
print_step "Step 3/6: Running flutter gen-l10n..."
flutter gen-l10n
print_success "Localizations generated"

# Step 6: Build Android App Bundle for release
print_step "Step 6/6: Building Android App Bundle for production..."
flutter build appbundle --release --dart-define=ENV=prod
print_success "Android App Bundle build completed successfully!"

print_success "🎉 Android deployment process completed!"
print_warning "Note: The built AAB file is located in build/app/outputs/bundle/release/"
print_warning "You can now upload the AAB file to Google Play Console"

echo ""
echo "Next steps:"
echo "1. Navigate to Google Play Console: https://play.google.com/console"
echo "2. Select your app"
echo "3. Go to Release -> Production -> Create new release"
echo "4. Upload the AAB file from build/app/outputs/bundle/release/app-release.aab"
echo ""
echo "Or use command line with Google Play Developer API:"
echo "java -jar publisher.jar --credential your-credential.json --package-name com.your.package --aab-file build/app/outputs/bundle/release/app-release.aab"
