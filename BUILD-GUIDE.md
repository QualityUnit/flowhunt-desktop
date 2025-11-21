# FlowHunt Desktop - Complete Build Guide

**Version:** 1.0.0
**Last Updated:** November 2025

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Manual Build Instructions](#manual-build-instructions)
3. [Platform-Specific Details](#platform-specific-details)
4. [Advanced Topics](#advanced-topics)
5. [GitHub Actions (CI/CD)](#github-actions-cicd)
6. [Troubleshooting](#troubleshooting)
7. [Distribution](#distribution)

---

## Quick Start

### TL;DR - Build Now

```bash
# Make executable (first time only)
chmod +x build.sh

# Build for your platform
./build.sh macos     # On macOS → Creates DMG
./build.sh windows   # On Windows → Creates ZIP
./build.sh linux     # On Linux → Creates TAR.GZ

# Find your installer in the dist/ folder
ls -lh dist/
```

### What You Get

| Platform | Output File | Size | Type |
|----------|-------------|------|------|
| **macOS** | `FlowHunt-Desktop-1.0.0-macOS.dmg` | ~50-80 MB | DMG Installer |
| **Windows** | `FlowHunt-Desktop-1.0.0-Windows.zip` | ~40-60 MB | ZIP Archive |
| **Linux** | `FlowHunt-Desktop-1.0.0-Linux.tar.gz` | ~40-60 MB | TAR.GZ Archive |

---

## Manual Build Instructions

### Prerequisites

#### All Platforms
- **Flutter SDK** (3.9.0 or higher)
  ```bash
  flutter --version
  ```
- **Git**

#### macOS Specific
- macOS 11.0 or higher
- Xcode 13 or higher (or at least Command Line Tools)
  ```bash
  xcode-select --install
  ```
- CocoaPods (optional, usually auto-installed)
  ```bash
  sudo gem install cocoapods
  ```

#### Windows Specific
- Windows 10 or higher
- Visual Studio 2022 with "Desktop development with C++" workload
- Windows 10 SDK

#### Linux Specific
- Ubuntu 20.04 or higher (or equivalent)
- Required packages:
  ```bash
  sudo apt-get update
  sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev
  ```

### Step-by-Step: First Build

#### 1. Open Terminal

**macOS:**
- Press `Cmd+Space`, type "Terminal", press Enter

**Windows:**
- Press `Win+R`, type `cmd`, press Enter
- Or use Git Bash or PowerShell

**Linux:**
- Press `Ctrl+Alt+T`

#### 2. Navigate to Project Directory

```bash
cd /path/to/flowHunt-desktop
```

#### 3. Verify Flutter Installation

```bash
flutter --version
flutter doctor
```

Expected output:
```
Flutter 3.9.0 • channel stable
[✓] Flutter (Channel stable, 3.9.0)
[✓] macOS toolchain - develop for macOS apps
```

#### 4. Make Build Script Executable (First Time Only)

```bash
chmod +x build.sh
```

#### 5. Run the Build

```bash
./build.sh macos    # For macOS
./build.sh windows  # For Windows
./build.sh linux    # For Linux
./build.sh all      # Build all compatible platforms
```

You'll see colored progress output:

```
ℹ Flutter version: Flutter 3.9.0 • channel stable

═══════════════════════════════════════════════
  Building for macOS
═══════════════════════════════════════════════

ℹ Getting dependencies...
ℹ Building macOS app...
ℹ Creating DMG installer...
✓ macOS DMG created: dist/FlowHunt-Desktop-1.0.0-macOS.dmg (52M)
ℹ Location: /path/to/flowHunt-desktop/dist/FlowHunt-Desktop-1.0.0-macOS.dmg
```

#### 6. Find Your Installer

```bash
ls -lh dist/
```

Output:
```
FlowHunt-Desktop-1.0.0-macOS.dmg
```

#### 7. Test the Installer

**macOS:**
```bash
open dist/FlowHunt-Desktop-1.0.0-macOS.dmg
```

**Windows:**
```powershell
explorer dist\FlowHunt-Desktop-1.0.0-Windows.zip
```

**Linux:**
```bash
# Extract and test
tar -xzf dist/FlowHunt-Desktop-1.0.0-Linux.tar.gz -C /tmp/test
/tmp/test/flowhunt_desktop
```

### Build Commands Reference

```bash
# Show help
./build.sh

# Build for specific platform
./build.sh macos
./build.sh windows
./build.sh linux

# Build all platforms (where possible)
./build.sh all

# Clean all build artifacts
./build.sh clean
```

---

## Platform-Specific Details

### macOS DMG Creation

The script creates a professional DMG installer with:
- ✅ Application bundle
- ✅ Symbolic link to Applications folder
- ✅ Drag-and-drop installation

#### Manual DMG Creation (Without Script)

```bash
# Build the app
flutter build macos --release

# App location
APP_PATH="build/macos/Build/Products/Release/flowhunt_desktop.app"

# Create temporary directory
mkdir -p dmg_tmp
cp -R "$APP_PATH" dmg_tmp/
ln -s /Applications dmg_tmp/Applications

# Create DMG
hdiutil create -volname "FlowHunt Desktop" \
               -srcfolder dmg_tmp \
               -ov \
               -format UDZO \
               FlowHunt-Desktop.dmg

# Clean up
rm -rf dmg_tmp
```

#### Code Signing (Production)

For distribution outside the App Store:

```bash
# 1. Sign the app bundle
codesign --deep --force --verify --verbose \
  --sign "Developer ID Application: Your Name (TEAM_ID)" \
  build/macos/Build/Products/Release/flowhunt_desktop.app

# 2. Create signed DMG
hdiutil create -volname "FlowHunt Desktop" \
  -srcfolder build/macos/Build/Products/Release/flowhunt_desktop.app \
  -ov -format UDZO \
  dist/FlowHunt-Desktop-signed.dmg

# 3. Sign the DMG
codesign --sign "Developer ID Application: Your Name (TEAM_ID)" \
  dist/FlowHunt-Desktop-signed.dmg

# 4. Notarize with Apple (requires Apple Developer account)
xcrun notarytool submit dist/FlowHunt-Desktop-signed.dmg \
  --apple-id "your@email.com" \
  --team-id "TEAM_ID" \
  --password "app-specific-password" \
  --wait

# 5. Staple the notarization ticket
xcrun stapler staple dist/FlowHunt-Desktop-signed.dmg
```

**Get app-specific password:**
1. Go to https://appleid.apple.com
2. Sign in → Security → App-Specific Passwords
3. Generate new password

---

### Windows Package Creation

The script creates a ZIP archive. For production, consider MSIX.

#### Manual Windows Build

```bash
# Build the app
flutter build windows --release

# App location
# build\windows\x64\runner\Release\

# Create ZIP (PowerShell)
Compress-Archive -Path build\windows\x64\runner\Release\* `
  -DestinationPath FlowHunt-Desktop-Windows.zip
```

#### Creating MSIX Package (Production)

**Prerequisites:**
- Visual Studio 2022
- Windows SDK Packaging Tools

**Steps:**

1. Install Windows SDK:
   ```powershell
   # Or install via Visual Studio Installer
   ```

2. Create certificate (for testing):
   ```powershell
   New-SelfSignedCertificate -Type Custom -Subject "CN=FlowHunt" `
     -KeyUsage DigitalSignature -FriendlyName "FlowHunt Certificate" `
     -CertStoreLocation "Cert:\CurrentUser\My"
   ```

3. Create MSIX manifest:
   ```xml
   <!-- windows/runner/AppxManifest.xml -->
   <?xml version="1.0" encoding="utf-8"?>
   <Package xmlns="http://schemas.microsoft.com/appx/manifest/foundation/windows10" ...>
     <!-- Configure package details -->
   </Package>
   ```

4. Build MSIX:
   ```bash
   flutter build windows --release
   # Use makeappx and signtool from Windows SDK
   ```

#### Code Signing (Production)

```powershell
# Using signtool (requires code signing certificate)
signtool sign /f certificate.pfx `
  /p "password" `
  /t http://timestamp.digicert.com `
  flowhunt_desktop.exe
```

---

### Linux Package Creation

The script creates a TAR.GZ archive. For better distribution, create AppImage or DEB.

#### Manual Linux Build

```bash
# Build the app
flutter build linux --release

# App location
# build/linux/x64/release/bundle/

# Create TAR.GZ
tar -czf FlowHunt-Desktop-Linux.tar.gz \
  -C build/linux/x64/release/bundle .
```

#### Creating AppImage

**Prerequisites:**
```bash
wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
chmod +x appimagetool-x86_64.AppImage
```

**Steps:**

1. Create AppDir structure:
   ```bash
   mkdir -p AppDir/usr/bin
   mkdir -p AppDir/usr/share/applications
   mkdir -p AppDir/usr/share/icons/hicolor/256x256/apps
   ```

2. Copy application files:
   ```bash
   cp -r build/linux/x64/release/bundle/* AppDir/usr/bin/
   ```

3. Create desktop entry:
   ```bash
   cat > AppDir/usr/share/applications/flowhunt-desktop.desktop << 'EOF'
   [Desktop Entry]
   Name=FlowHunt Desktop
   Exec=flowhunt_desktop
   Icon=flowhunt-desktop
   Type=Application
   Categories=Utility;Development;
   Comment=Create AI Agents and connect them to your stack
   EOF
   ```

4. Copy icon (if available):
   ```bash
   # cp assets/icon.png AppDir/usr/share/icons/hicolor/256x256/apps/flowhunt-desktop.png
   ```

5. Create AppRun script:
   ```bash
   cat > AppDir/AppRun << 'EOF'
   #!/bin/bash
   SELF=$(readlink -f "$0")
   HERE=${SELF%/*}
   export PATH="${HERE}/usr/bin:${PATH}"
   exec "${HERE}/usr/bin/flowhunt_desktop" "$@"
   EOF
   chmod +x AppDir/AppRun
   ```

6. Build AppImage:
   ```bash
   ./appimagetool-x86_64.AppImage AppDir FlowHunt-Desktop-1.0.0-x86_64.AppImage
   ```

#### Creating DEB Package

**Steps:**

1. Create debian directory structure:
   ```bash
   mkdir -p debian/flowhunt-desktop/DEBIAN
   mkdir -p debian/flowhunt-desktop/usr/bin
   mkdir -p debian/flowhunt-desktop/usr/share/applications
   mkdir -p debian/flowhunt-desktop/usr/share/icons/hicolor/256x256/apps
   ```

2. Create control file:
   ```bash
   cat > debian/flowhunt-desktop/DEBIAN/control << 'EOF'
   Package: flowhunt-desktop
   Version: 1.0.0
   Section: utils
   Priority: optional
   Architecture: amd64
   Depends: libgtk-3-0, libblkid1, liblzma5
   Maintainer: FlowHunt <support@flowhunt.com>
   Description: FlowHunt Desktop - Create AI Agents
    FlowHunt Desktop application for creating and managing AI agents.
    Connect them to your stack and automate workflows.
   EOF
   ```

3. Copy files:
   ```bash
   cp -r build/linux/x64/release/bundle/* debian/flowhunt-desktop/usr/bin/
   ```

4. Create desktop entry:
   ```bash
   cat > debian/flowhunt-desktop/usr/share/applications/flowhunt-desktop.desktop << 'EOF'
   [Desktop Entry]
   Name=FlowHunt Desktop
   Exec=/usr/bin/flowhunt_desktop
   Icon=flowhunt-desktop
   Type=Application
   Categories=Utility;Development;
   EOF
   ```

5. Build DEB:
   ```bash
   dpkg-deb --build debian/flowhunt-desktop
   mv debian/flowhunt-desktop.deb FlowHunt-Desktop-1.0.0-amd64.deb
   ```

---

## Advanced Topics

### Building Without the Script

If you prefer to build manually:

#### macOS:
```bash
flutter clean
flutter pub get
flutter build macos --release

# App at: build/macos/Build/Products/Release/flowhunt_desktop.app
```

#### Windows:
```bash
flutter clean
flutter pub get
flutter build windows --release

# App at: build\windows\x64\runner\Release\
```

#### Linux:
```bash
flutter clean
flutter pub get
flutter build linux --release

# App at: build/linux/x64/release/bundle/
```

### Version Management

Version is automatically read from `pubspec.yaml`:

```yaml
version: 1.0.0+1  # Format: major.minor.patch+build
```

**To update version:**

1. Edit `pubspec.yaml`:
   ```yaml
   version: 1.2.0+3
   ```

2. Build - new version is automatically used

### Custom Build Configuration

Edit `build.sh` to customize:

```bash
# Change app name
APP_NAME="Your App Name"

# Change bundle ID
BUNDLE_ID="com.yourcompany.yourapp"

# Change build directory
BUILD_DIR="custom_build"

# Change output directory
DIST_DIR="releases"
```

### Clean Build

Remove all build artifacts:

```bash
./build.sh clean
```

This removes:
- `build/` directory
- `dist/` directory
- Runs `flutter clean`

---

## GitHub Actions (CI/CD)

### Optional Automation

The project includes GitHub Actions for automatic builds. This is **optional** - you can build manually anytime.

### Workflow File

Location: `.github/workflows/build.yml`

### How It Works

1. **Trigger:** Push a git tag
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

2. **Actions:** Automatically builds for:
   - macOS (DMG)
   - Windows (ZIP)
   - Linux (TAR.GZ)

3. **Output:** Creates GitHub Release with all installers attached

### Workflow Configuration

```yaml
name: Build FlowHunt Desktop

on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:  # Allow manual trigger

jobs:
  build-macos:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.9.0'
      - run: ./build.sh macos
      - uses: actions/upload-artifact@v3
        with:
          name: macos-dmg
          path: dist/*.dmg

  # Similar for Windows and Linux...
```

### Manual Trigger

You can also trigger builds manually from GitHub:
1. Go to Actions tab
2. Select "Build FlowHunt Desktop"
3. Click "Run workflow"

### Artifacts

Build artifacts are available for 30 days:
- Go to Actions tab
- Click on workflow run
- Download artifacts

---

## Troubleshooting

### Common Issues

#### ❌ Permission Denied: build.sh

**Error:**
```
bash: ./build.sh: Permission denied
```

**Solution:**
```bash
chmod +x build.sh
```

---

#### ❌ Flutter Not Found

**Error:**
```
flutter: command not found
```

**Solution:**
```bash
# Check if Flutter is installed
which flutter

# If not found, add to PATH
export PATH="$PATH:$HOME/flutter/bin"

# Make permanent (add to ~/.bashrc or ~/.zshrc)
echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.zshrc
source ~/.zshrc
```

---

#### ❌ Xcode Command Line Tools Required (macOS)

**Error:**
```
xcode-select: error: tool 'xcodebuild' requires Xcode
```

**Solution:**
```bash
xcode-select --install
```

---

#### ❌ GTK Libraries Missing (Linux)

**Error:**
```
error while loading shared libraries: libgtk-3.so.0
```

**Solution:**
```bash
sudo apt-get install libgtk-3-0 libblkid1 liblzma5
```

---

#### ❌ Build Fails: "ninja: build stopped"

**Solution:**

1. Clean and retry:
   ```bash
   ./build.sh clean
   ./build.sh macos
   ```

2. Check Flutter doctor:
   ```bash
   flutter doctor -v
   ```

3. Update Flutter:
   ```bash
   flutter upgrade
   ```

---

#### ❌ macOS: "App is damaged and can't be opened"

**Cause:** Unsigned app downloaded from internet (Gatekeeper)

**User Solutions:**

1. **Right-click method:**
   - Right-click app
   - Select "Open"
   - Click "Open" in dialog

2. **Command line:**
   ```bash
   xattr -cr /Applications/flowhunt_desktop.app
   ```

**Developer Solution:** Sign and notarize the app (see Code Signing section)

---

#### ❌ Windows: "Windows protected your PC"

**Cause:** Unsigned executable (SmartScreen)

**User Solutions:**
- Click "More info"
- Click "Run anyway"

**Developer Solution:** Sign executable with code signing certificate

---

#### ❌ DMG Creation Fails

**Error:**
```
hdiutil: create failed - Operation not permitted
```

**Solution:**
1. Check disk space:
   ```bash
   df -h
   ```

2. Try different format:
   ```bash
   hdiutil create -format UDBZ ...
   ```

3. Grant Terminal full disk access:
   - System Preferences → Security & Privacy → Privacy
   - Full Disk Access → Add Terminal

---

### Debug Mode

To see detailed build output:

```bash
# Enable verbose output
flutter build macos --release --verbose

# Or add to build.sh
set -x  # Print commands as they execute
```

---

## Distribution

### For Testing

Share the file from `dist/` folder:
- Email the DMG/ZIP/TAR.GZ
- Upload to cloud storage (Dropbox, Google Drive)
- Share via internal file server

**File sizes:**
- macOS DMG: ~50-80 MB
- Windows ZIP: ~40-60 MB
- Linux TAR.GZ: ~40-60 MB

### For Production

#### macOS
✅ Sign with Developer ID certificate
✅ Notarize with Apple
✅ Distribute DMG
✅ Users can install via drag-and-drop

#### Windows
✅ Sign executable with code signing certificate
✅ Create MSIX for Microsoft Store (optional)
✅ Distribute ZIP or installer
✅ Users extract and run

#### Linux
✅ Create AppImage for universal compatibility
✅ Create DEB for Ubuntu/Debian
✅ Create RPM for Fedora/RHEL (optional)
✅ Distribute via package managers

### Update Management

**Manual Updates:**
- Users download new version
- Replace old app with new version

**Automatic Updates:**
- Implement update checker in app
- Use packages like `flutter_updater`
- Host release manifest (JSON)

Example update manifest:
```json
{
  "version": "1.0.0",
  "build": 1,
  "platforms": {
    "macos": {
      "url": "https://releases.flowhunt.com/FlowHunt-Desktop-1.0.0-macOS.dmg",
      "sha256": "abc123..."
    },
    "windows": {
      "url": "https://releases.flowhunt.com/FlowHunt-Desktop-1.0.0-Windows.zip",
      "sha256": "def456..."
    },
    "linux": {
      "url": "https://releases.flowhunt.com/FlowHunt-Desktop-1.0.0-Linux.tar.gz",
      "sha256": "ghi789..."
    }
  }
}
```

---

## Summary

### Key Points

✅ **Manual builds are the default** - No GitHub required
✅ **One script for all platforms** - `./build.sh`
✅ **Professional installers** - DMG, ZIP, TAR.GZ
✅ **CI/CD ready** - Optional GitHub Actions
✅ **Production ready** - Code signing instructions included

### Quick Commands

```bash
./build.sh macos     # Build DMG on macOS
./build.sh windows   # Build ZIP on Windows
./build.sh linux     # Build TAR.GZ on Linux
./build.sh all       # Build all platforms
./build.sh clean     # Clean everything
./build.sh           # Show help
```

### File Locations

```
flowHunt-desktop/
├── build.sh                 # Build script
├── BUILD-GUIDE.md           # This document
├── dist/                    # Installers (created by script)
│   ├── *.dmg               # macOS installer
│   ├── *.zip               # Windows installer
│   └── *.tar.gz            # Linux installer
└── .github/
    └── workflows/
        └── build.yml        # CI/CD (optional)
```

### Getting Help

- 📖 This guide: Complete reference
- 🔧 Script help: `./build.sh`
- 🐛 Issues: GitHub Issues
- 💬 Support: support@flowhunt.com

---

## Appendix

### Build Script Source

The build script (`build.sh`) is well-commented and can be modified:

```bash
# View the script
cat build.sh

# Edit the script
nano build.sh  # or vim, code, etc.
```

### Environment Variables

Customize build behavior:

```bash
# Custom Flutter path
export FLUTTER_ROOT=/custom/path/to/flutter

# Custom output directory
export DIST_DIR=releases

# Then build
./build.sh macos
```

### Testing Checklist

Before releasing:

- [ ] Build completes without errors
- [ ] Installer size is reasonable
- [ ] App launches successfully
- [ ] All features work
- [ ] No console errors
- [ ] Version number is correct
- [ ] Code is signed (production)
- [ ] App is notarized (macOS production)

### License & Copyright

Configure in your `pubspec.yaml`:

```yaml
name: flowhunt_desktop
description: FlowHunt Desktop - Create AI Agents
version: 1.0.0+1
author: Your Name
homepage: https://flowhunt.com
```

---

**End of Build Guide**

Last updated: November 2025
Script version: 1.0
Flutter version: 3.9.0+
