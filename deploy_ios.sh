#!/bin/bash

# iOS Deployment Script for Moneko Flutter App
# This script automates the complete iOS build and deployment process

set -e  # Exit on any error

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

# Check if we're in the correct directory
if [ ! -f "pubspec.yaml" ]; then
    print_error "pubspec.yaml not found. Please run this script from the Flutter project root directory."
    exit 1
fi

print_step "Starting iOS deployment process..."

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

# Step 4: Navigate to iOS directory and install pods
print_step "Step 4/6: Installing iOS pods..."
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
print_success "iOS pods installed"

# Step 5: Navigate back to root directory
print_step "Step 5/6: Returning to project root..."
cd ..
print_success "Back in project root directory"

# Step 6: Build iOS release
print_step "Step 6/6: Building iOS release for production..."
flutter build ios --release --dart-define=ENV=prod
print_success "iOS build completed successfully!"

print_step "Step 7/6: Building Android App Bundle for production..."
flutter build appbundle --release --dart-define=ENV=prod
print_success "Android App Bundle build completed successfully!"


print_success "🎉 App build process completed!"