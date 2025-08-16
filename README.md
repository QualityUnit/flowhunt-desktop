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

### Windows:
```bash
flutter build windows --release
```

### macOS:
```bash
flutter build macos --release
```

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
