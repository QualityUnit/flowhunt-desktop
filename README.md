# FlowHunt Desktop

A cross-platform desktop application for FlowHunt that allows users to create AI Agents, set up triggers, and connect integrations to their stack.

## Features

- **OAuth 2.0 Authentication** with PKCE flow for secure authentication
- **Cross-platform Support** for Windows and macOS
- **Modern UI/UX** with Material Design 3
- **AI Agent Management** (Coming Soon)
- **Trigger System** (Coming Soon)
- **Integration Framework** (Coming Soon)
- **Local & Remote LLM Support** (Coming Soon)

## Project Structure

```
lib/
├── core/
│   ├── auth/           # Authentication services
│   └── constants/      # App constants
├── screens/
│   ├── onboarding/     # Welcome screen
│   ├── auth/           # Login screen
│   └── dashboard/      # Main dashboard
├── providers/          # Riverpod providers
├── router/             # App routing
└── main.dart           # App entry point
```

## Getting Started

### Prerequisites

- Flutter SDK (3.9.0 or higher)
- Windows/macOS development environment
- Git

### Installation

1. Clone the repository:
```bash
git clone https://github.com/yasha-dev1/flowhunt-dektop.git
cd flowhunt-dektop
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run -d windows  # For Windows
flutter run -d macos    # For macOS
```

## Testing

### Run all tests:
```bash
flutter test
```

### Run unit tests:
```bash
flutter test test/unit/
```

### Run widget tests:
```bash
flutter test test/widget/
```

### Run integration tests:
```bash
flutter test integration_test/
```

## Building for Production

We provide a comprehensive build script that creates professional installers for all platforms.

### Quick Build

```bash
# Make executable (first time only)
chmod +x build.sh

# Build for your platform
./build.sh macos     # Creates DMG installer
./build.sh windows   # Creates ZIP package
./build.sh linux     # Creates TAR.GZ package
```

**Output:** Installers are placed in the `dist/` directory.

### Complete Build Guide

For detailed instructions including:
- Manual builds
- Code signing
- Creating AppImage/DEB packages
- CI/CD with GitHub Actions
- Troubleshooting

See **[BUILD-GUIDE.md](BUILD-GUIDE.md)** for the complete documentation.

## Deployment & Releases

FlowHunt Desktop supports automated deployment through GitHub Actions and a convenient build script.

### Quick Deploy (Recommended)

The easiest way to create a new release:

```bash
# 1. Update version in pubspec.yaml
# Change: version: 1.0.2+2
# To:     version: 1.0.3+3

# 2. Build and release in one command
./build.sh macos --release
```

This automatically:
- ✅ Builds the macOS release app
- ✅ Creates a DMG installer
- ✅ Commits version changes
- ✅ Creates and pushes git tag
- ✅ Creates GitHub release
- ✅ Uploads DMG to release
- ✅ Triggers CI/CD for Windows/Linux builds

### Prerequisites for Deployment

**One-time setup:**

```bash
# Install GitHub CLI
brew install gh

# Authenticate with GitHub
gh auth login
```

### Build Commands

```bash
# Build with automatic GitHub release
./build.sh macos --release      # Build macOS and release
./build.sh windows --release    # Build Windows and release
./build.sh linux --release      # Build Linux and release
./build.sh all --release        # Build all platforms and release

# Build without releasing (local testing)
./build.sh macos               # Just create DMG
./build.sh windows             # Just create ZIP
./build.sh linux               # Just create TAR.GZ
```

### Manual Deployment

If you prefer to deploy manually:

```bash
# 1. Update version in pubspec.yaml
# version: 1.0.3+3

# 2. Commit changes
git add .
git commit -m "v1.0.3: Description of changes"
git push origin main

# 3. Create and push tag
git tag -a v1.0.3 -m "Release v1.0.3"
git push origin v1.0.3

# 4. Create release with GitHub CLI
gh release create v1.0.3 \
  --title "v1.0.3 - Release Title" \
  --notes "Release notes here" \
  dist/*.dmg
```

### Automated CI/CD

When you push a version tag (e.g., `v1.0.3`), GitHub Actions automatically:
1. Builds for macOS, Windows, and Linux
2. Creates DMG, ZIP, and TAR.GZ installers
3. Creates a GitHub release
4. Uploads all platform builds to the release

**Workflow file:** `.github/workflows/build.yml`

### Version Management

Version format: `MAJOR.MINOR.PATCH+BUILD`

Example: `1.0.3+3`
- `1.0.3` - Semantic version (major.minor.patch)
- `+3` - Build number (increments with each build)

**When to increment:**
- **Major** (1.x.x) - Breaking changes
- **Minor** (x.1.x) - New features (backward compatible)
- **Patch** (x.x.1) - Bug fixes
- **Build** (+x) - Every release

### Release Checklist

Before releasing:

- [ ] Update version in `pubspec.yaml`
- [ ] Test the build locally: `flutter build macos --release`
- [ ] Run tests: `flutter test`
- [ ] Check for warnings: `flutter analyze`
- [ ] Update CHANGELOG.md (if exists)
- [ ] Commit all changes
- [ ] Run `./build.sh macos --release`
- [ ] Verify release on GitHub
- [ ] Test download and installation

### Troubleshooting Deployment

**Build fails:**
```bash
# Clean and rebuild
flutter clean
flutter pub get
./build.sh macos
```

**GitHub CLI not authenticated:**
```bash
gh auth login
gh auth status
```

**Tag already exists:**
```bash
# Delete local and remote tag
git tag -d v1.0.3
git push origin :v1.0.3

# Create new tag
git tag -a v1.0.3 -m "Release v1.0.3"
git push origin v1.0.3
```

**Release not appearing:**
- Check GitHub Actions status in the "Actions" tab
- Ensure the tag follows the `v*` pattern
- Verify you have push permissions to the repository

## Configuration

The app uses the following configuration:
- **OAuth Redirect URI**: `http://localhost:8080/callback`
- **API Base URL**: `https://api.flowhunt.io`
- **Window Size**: 1280x800 (min: 800x600)

## Technologies Used

- **Flutter** - UI framework
- **Riverpod** - State management
- **GoRouter** - Navigation
- **Dio** - HTTP client
- **Flutter Secure Storage** - Secure token storage
- **Window Manager** - Desktop window control

## Contributing

Please see the GitHub issues for planned features and bug reports.

## License

Copyright © 2025 FlowHunt. All rights reserved.
