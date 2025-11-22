#!/bin/bash

# FlowHunt Desktop Build Script
# Creates distribution packages for macOS, Windows, and Linux
#
# Usage:
#   ./build.sh macos          # Build macOS DMG
#   ./build.sh windows        # Build Windows installer (requires Windows or Wine)
#   ./build.sh linux          # Build Linux AppImage and DEB
#   ./build.sh all            # Build for all platforms
#   ./build.sh clean          # Clean build artifacts

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="FlowHunt Desktop"
BUNDLE_ID="com.flowhunt.desktop"
VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //' | tr -d ' ')
BUILD_DIR="build"
DIST_DIR="dist"

# Print colored output
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_header() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
    echo ""
}

# Check if Flutter is installed
check_flutter() {
    if ! command -v flutter &> /dev/null; then
        print_error "Flutter is not installed or not in PATH"
        exit 1
    fi
    print_info "Flutter version: $(flutter --version | head -1)"
}

# Clean build artifacts
clean_build() {
    print_header "Cleaning Build Artifacts"

    print_info "Removing build directories..."
    rm -rf build/
    rm -rf dist/

    print_info "Running flutter clean..."
    flutter clean

    print_success "Clean completed"
}

# Build for macOS
build_macos() {
    print_header "Building for macOS"

    if [[ "$OSTYPE" != "darwin"* ]]; then
        print_warning "macOS builds require macOS"
        return 1
    fi

    print_info "Getting dependencies..."
    flutter pub get

    print_info "Building macOS app..."
    flutter build macos --release

    print_info "Creating DMG installer..."

    # Create dist directory
    mkdir -p "$DIST_DIR"

    # Path to built app (use the actual app name from the build)
    APP_PATH="$BUILD_DIR/macos/Build/Products/Release/$APP_NAME.app"
    DMG_NAME="FlowHunt-Desktop-$VERSION-macOS.dmg"
    DMG_PATH="$DIST_DIR/$DMG_NAME"

    if [ ! -d "$APP_PATH" ]; then
        print_error "Built app not found at $APP_PATH"
        print_info "Looking for alternative app names..."
        # Try to find the app with different naming conventions
        for possible_app in "$BUILD_DIR/macos/Build/Products/Release/"*.app; do
            if [ -d "$possible_app" ]; then
                APP_PATH="$possible_app"
                print_info "Found app at: $APP_PATH"
                break
            fi
        done

        if [ ! -d "$APP_PATH" ]; then
            print_error "No .app bundle found in Release directory"
            return 1
        fi
    fi

    # Create temporary directory for DMG
    DMG_TMP="$BUILD_DIR/dmg_tmp"
    rm -rf "$DMG_TMP"
    mkdir -p "$DMG_TMP"

    # Copy app to temp directory
    cp -R "$APP_PATH" "$DMG_TMP/"

    # Create Applications symlink
    ln -s /Applications "$DMG_TMP/Applications"

    # Create DMG
    print_info "Creating DMG image..."
    hdiutil create -volname "$APP_NAME" \
                   -srcfolder "$DMG_TMP" \
                   -ov \
                   -format UDZO \
                   "$DMG_PATH"

    # Clean up temp directory
    rm -rf "$DMG_TMP"

    # Get DMG size
    DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)

    print_success "macOS DMG created: $DMG_PATH ($DMG_SIZE)"
    print_info "Location: $(pwd)/$DMG_PATH"
}

# Build for Windows
build_windows() {
    print_header "Building for Windows"

    print_info "Getting dependencies..."
    flutter pub get

    print_info "Building Windows app..."
    flutter build windows --release

    print_info "Creating Windows installer..."

    # Create dist directory
    mkdir -p "$DIST_DIR"

    # Path to built app
    WINDOWS_BUILD_PATH="$BUILD_DIR/windows/x64/runner/Release"

    if [ ! -d "$WINDOWS_BUILD_PATH" ]; then
        print_error "Built app not found at $WINDOWS_BUILD_PATH"
        return 1
    fi

    # Create ZIP package
    ZIP_NAME="FlowHunt-Desktop-$VERSION-Windows.zip"
    ZIP_PATH="$DIST_DIR/$ZIP_NAME"

    print_info "Creating ZIP package..."
    (cd "$WINDOWS_BUILD_PATH" && zip -r "../../../../../$ZIP_PATH" .)

    # Get ZIP size
    ZIP_SIZE=$(du -h "$ZIP_PATH" | cut -f1)

    print_success "Windows package created: $ZIP_PATH ($ZIP_SIZE)"
    print_info "Location: $(pwd)/$ZIP_PATH"

    print_warning "Note: For a proper Windows installer (MSIX), you'll need:"
    print_warning "  1. Visual Studio with Windows SDK"
    print_warning "  2. Code signing certificate"
    print_warning "  3. Run 'flutter build windows --release' on Windows"
    print_warning "  4. Use Windows Packaging Tools to create MSIX"
}

# Build for Linux
build_linux() {
    print_header "Building for Linux"

    print_info "Getting dependencies..."
    flutter pub get

    print_info "Building Linux app..."
    flutter build linux --release

    print_info "Creating Linux packages..."

    # Create dist directory
    mkdir -p "$DIST_DIR"

    # Path to built app
    LINUX_BUILD_PATH="$BUILD_DIR/linux/x64/release/bundle"

    if [ ! -d "$LINUX_BUILD_PATH" ]; then
        print_error "Built app not found at $LINUX_BUILD_PATH"
        return 1
    fi

    # Create TAR.GZ package
    TAR_NAME="FlowHunt-Desktop-$VERSION-Linux.tar.gz"
    TAR_PATH="$DIST_DIR/$TAR_NAME"

    print_info "Creating TAR.GZ package..."
    tar -czf "$TAR_PATH" -C "$LINUX_BUILD_PATH" .

    # Get TAR size
    TAR_SIZE=$(du -h "$TAR_PATH" | cut -f1)

    print_success "Linux package created: $TAR_PATH ($TAR_SIZE)"
    print_info "Location: $(pwd)/$TAR_PATH"

    print_warning "Note: For AppImage or DEB packages, you'll need:"
    print_warning "  - AppImage: Use appimagetool"
    print_warning "  - DEB: Create debian control files and use dpkg-deb"
}

# Show usage
show_usage() {
    echo "FlowHunt Desktop Build Script"
    echo ""
    echo "Usage:"
    echo "  ./build.sh macos          Build macOS DMG"
    echo "  ./build.sh windows        Build Windows installer"
    echo "  ./build.sh linux          Build Linux packages"
    echo "  ./build.sh all            Build for all platforms"
    echo "  ./build.sh clean          Clean build artifacts"
    echo ""
    echo "Current version: $VERSION"
}

# Main script
main() {
    if [ $# -eq 0 ]; then
        show_usage
        exit 0
    fi

    check_flutter

    case "$1" in
        macos)
            build_macos
            ;;
        windows)
            build_windows
            ;;
        linux)
            build_linux
            ;;
        all)
            if [[ "$OSTYPE" == "darwin"* ]]; then
                build_macos
            else
                print_warning "Skipping macOS build (requires macOS)"
            fi

            if [[ "$OSTYPE" == "linux-gnu"* ]]; then
                build_linux
            else
                print_warning "Skipping Linux build (requires Linux)"
            fi

            build_windows

            print_header "Build Summary"
            print_info "All available builds completed"
            print_info "Check the $DIST_DIR directory for installers"
            ;;
        clean)
            clean_build
            ;;
        *)
            print_error "Unknown command: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Run main
main "$@"
