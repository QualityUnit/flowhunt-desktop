#!/bin/bash

# Release macOS build to GitHub
# Usage: ./release-macos.sh 1.0.0

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }

# Check arguments
if [ -z "$1" ]; then
    echo "Usage: ./release-macos.sh <version>"
    echo "Example: ./release-macos.sh 1.0.0"
    exit 1
fi

VERSION="$1"
TAG_NAME="macos-$VERSION"
DMG_NAME="FlowHunt-Desktop-$VERSION-macOS.dmg"
DMG_PATH="dist/$DMG_NAME"

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    print_error "GitHub CLI (gh) is not installed"
    print_info "Install with: brew install gh"
    exit 1
fi

# Check if authenticated with gh
if ! gh auth status &> /dev/null; then
    print_error "Not authenticated with GitHub CLI"
    print_info "Run: gh auth login"
    exit 1
fi

# Check if on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    print_error "This script must be run on macOS"
    exit 1
fi

print_info "Building macOS release v$VERSION..."

# Build macOS DMG
./build.sh macos

# Check if DMG was created
if [ ! -f "$DMG_PATH" ]; then
    # Try alternative path with version from pubspec
    PUBSPEC_VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //' | tr -d ' ')
    ALT_DMG_PATH="dist/FlowHunt-Desktop-$PUBSPEC_VERSION-macOS.dmg"

    if [ -f "$ALT_DMG_PATH" ]; then
        DMG_PATH="$ALT_DMG_PATH"
        DMG_NAME="FlowHunt-Desktop-$PUBSPEC_VERSION-macOS.dmg"
    else
        print_error "DMG not found at $DMG_PATH"
        exit 1
    fi
fi

print_success "DMG created: $DMG_PATH"

# Create and push tag
print_info "Creating tag $TAG_NAME..."
git tag -a "$TAG_NAME" -m "macOS release $VERSION"
git push origin "$TAG_NAME"

print_success "Tag $TAG_NAME pushed"

# Create GitHub release and upload DMG
print_info "Creating GitHub release..."
gh release create "$TAG_NAME" \
    --title "macOS $VERSION" \
    --notes "macOS release version $VERSION" \
    "$DMG_PATH"

print_success "Release created: macOS $VERSION"
print_info "DMG uploaded: $DMG_NAME"

# Print release URL
REPO_URL=$(gh repo view --json url -q .url)
print_success "View release at: $REPO_URL/releases/tag/$TAG_NAME"
