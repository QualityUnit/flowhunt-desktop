# Voice-to-Text Implementation Documentation

## Overview

This document provides comprehensive documentation for the voice-to-text functionality implemented in the FlowHunt Desktop application. The feature allows users to input commands and messages using voice instead of typing, with real-time speech-to-text conversion and visual feedback.

## Features

### ✅ Core Functionality (Implemented)
- **Real-time Speech Recognition**: Uses macOS native Speech Framework for accurate transcription
- **Visual Feedback**: Audio level visualization and recording status indicators
- **Microphone Permissions**: Proper permission handling with user-friendly prompts
- **Chat Integration**: Seamless integration with the AI assistant chat interface
- **Transcription Storage**: Automatic saving of transcriptions to text files
- **Error Handling**: Comprehensive error handling and recovery mechanisms

### 🚧 Future Enhancements (Planned)
- **WhisperKit Integration**: Local AI-powered transcription as fallback
- **Audio Recording**: Save actual audio files (MP3 format) alongside transcriptions
- **Multi-language Support**: Support for different languages and locales
- **Voice Commands**: Predefined voice commands for navigation and actions
- **Cross-platform Support**: Enhanced support for Windows and Linux

## Architecture

### Core Components

#### 1. Voice Input State (`lib/core/voice/voice_input_state.dart`)
Defines the complete state model for voice input functionality:

```dart
enum VoiceInputStatus {
  idle,           // Ready to start recording
  initializing,   // Setting up speech recognition
  listening,      // Actively recording speech
  processing,     // Converting speech to text
  completed,      // Transcription finished
  error,         // Error occurred
}

enum SpeechEngine {
  osNative,      // macOS Speech Framework
  whisperKit,    // Local Whisper AI (future)
  openAIWhisper, // Cloud-based Whisper (future)
}
```

#### 2. Voice Recorder Service (`lib/core/voice/voice_recorder_service_simple.dart`)
Handles the actual speech recognition and audio processing:

- **Permission Management**: Checks and requests microphone permissions
- **Speech Recognition**: Initializes and manages macOS Speech Framework
- **Real-time Processing**: Streams transcription results as user speaks
- **File Management**: Saves transcriptions to device storage
- **Error Handling**: Comprehensive error management and recovery

#### 3. Voice Input Provider (`lib/providers/voice_input_provider.dart`)
Riverpod-based state management for voice input:

- **State Management**: Manages voice input state across the application
- **Stream Handling**: Processes audio level and transcription streams
- **Lifecycle Management**: Handles recording start, stop, and cancellation
- **Permission Handling**: Manages microphone permission requests

#### 4. Voice Recorder Widget (`lib/widgets/voice/voice_recorder_widget.dart`)
Reusable UI component for voice input:

- **Visual Feedback**: Animated microphone button with recording states
- **Audio Visualization**: Real-time audio level display
- **Compact Mode**: Space-efficient version for integration in chat interfaces
- **Full Mode**: Complete interface with status display and controls

## Platform Configuration

### macOS Setup

#### 1. Deployment Target
Updated to macOS 11.0 to support speech_to_text plugin:

```xml
<!-- macos/Runner.xcodeproj/project.pbxproj -->
MACOSX_DEPLOYMENT_TARGET = 11.0;

<!-- macos/Podfile -->
platform :osx, '11.0'
```

#### 2. Permissions
Added required permission descriptions:

```xml
<!-- macos/Runner/Info.plist -->
<key>NSMicrophoneUsageDescription</key>
<string>FlowHunt needs microphone access for voice-to-text input to convert your speech into text for AI conversations.</string>

<key>NSSpeechRecognitionUsageDescription</key>
<string>FlowHunt uses speech recognition to accurately convert your voice into text for seamless AI interactions.</string>
```

## Dependencies

```yaml
# pubspec.yaml
dependencies:
  speech_to_text: ^7.0.0          # OS-native speech recognition
  permission_handler: ^11.3.1     # Microphone permission management
  path_provider: ^2.1.4           # File system access for transcription storage
  just_audio: ^0.9.40            # Audio playback support
  path: ^1.9.0                   # Path manipulation utilities
```

## Usage

### Integration in Chat Interface

The voice recorder is integrated into the AI assistant chat interface with two instances:

1. **Initial Chat View**: Large microphone button in the center input area
2. **Active Chat View**: Compact microphone button in the message input toolbar

### User Workflow

1. **Permission Request**: First-time users are prompted to grant microphone access
2. **Start Recording**: Click the microphone button to begin voice input
3. **Real-time Feedback**: Visual audio levels and live transcription display
4. **Stop Recording**: Click the stop button or wait for automatic timeout
5. **Auto-send**: Transcribed text is automatically inserted and can be sent

### Widget Usage

```dart
// Compact mode for chat integration
VoiceRecorderWidget(
  compact: true,
  size: 32,
  onTranscription: (transcription) {
    messageController.text = transcription;
  },
  onRecordingComplete: (file) {
    if (messageController.text.trim().isNotEmpty) {
      sendMessage();
    }
  },
)

// Full mode for dedicated voice input screens
VoiceRecorderWidget(
  compact: false,
  onTranscription: (transcription) {
    // Handle real-time transcription updates
  },
  onRecordingComplete: (file) {
    // Handle completed recording with file details
  },
)
```

## State Management

### Provider Access

```dart
// Watch voice input state
final voiceState = ref.watch(voiceInputProvider);

// Access convenience providers
final hasPermission = ref.watch(hasVoicePermissionProvider);
final isRecording = ref.watch(isVoiceRecordingProvider);
final transcription = ref.watch(voiceTranscriptionProvider);
final audioLevel = ref.watch(voiceAudioLevelProvider);

// Control voice input
final notifier = ref.read(voiceInputProvider.notifier);
await notifier.startRecording();
await notifier.stopRecording();
await notifier.cancelRecording();
```

### State Properties

```dart
class VoiceInputState {
  final VoiceInputStatus status;      // Current recording status
  final bool hasPermission;           // Microphone permission granted
  final String transcription;         // Current transcription text
  final double audioLevel;            // Real-time audio level (0.0-1.0)
  final Duration recordingDuration;   // Current recording duration
  final VoiceInputError? error;       // Any error that occurred
  final List<RecordingFile> savedFiles; // History of saved recordings
  final SpeechEngine currentEngine;   // Currently active speech engine
  final bool isInitialized;          // Service initialization status
}
```

## File Storage

### Directory Structure

```
/Users/{username}/Documents/FlowHunt/Voice/
├── transcriptions/
│   ├── transcription_1632147200000.txt
│   ├── transcription_1632147260000.txt
│   └── ...
└── recordings/ (future)
    ├── recording_1632147200000.mp3
    ├── recording_1632147260000.mp3
    └── ...
```

### File Naming Convention

- **Transcriptions**: `transcription_{timestamp}.txt`
- **Audio Files**: `recording_{timestamp}.mp3` (future)
- **Timestamp**: Unix timestamp in milliseconds for unique identification

## Error Handling

### Error Types

```dart
enum VoiceInputErrorType {
  permissionDenied,              // Microphone permission not granted
  microphoneNotAvailable,        // Hardware microphone issues
  speechRecognitionUnavailable,  // OS speech recognition not available
  networkError,                  // Network issues (for cloud services)
  fileSystemError,              // File save/load errors
  processingError,              // General processing errors
  unknown,                      // Unexpected errors
}
```

### Recovery Mechanisms

- **Permission Errors**: Automatic permission request with user guidance
- **Hardware Errors**: Graceful degradation with user notification
- **Network Errors**: Fallback to offline processing when available
- **Processing Errors**: Retry mechanisms with exponential backoff

## Testing

### Unit Tests

Comprehensive test suite covering:

- **State Management**: Voice input provider state transitions
- **Permission Handling**: Microphone permission request flows
- **Recording Lifecycle**: Start, stop, and cancel operations
- **Error Scenarios**: Various error conditions and recovery
- **Service Integration**: Mock service interactions

### Running Tests

```bash
# Run all voice-related tests
flutter test test/voice/

# Run specific test file
flutter test test/voice/voice_input_provider_test.dart

# Run with coverage
flutter test --coverage
```

## Performance Considerations

### Memory Management

- **Stream Subscriptions**: Properly disposed to prevent memory leaks
- **Audio Buffers**: Efficient handling of real-time audio data
- **File Handles**: Automatic cleanup of temporary files

### Battery Optimization

- **Recording Timeout**: 5-minute maximum recording duration
- **Background Processing**: Minimal background activity when not recording
- **Efficient Animations**: Optimized visual feedback to reduce CPU usage

## Troubleshooting

### Common Issues

#### 1. Permission Denied
**Problem**: Microphone permission is denied or not requested
**Solution**: 
- Check system preferences for microphone access
- Ensure Info.plist contains proper permission descriptions
- Use `openAppSettings()` to direct users to system settings

#### 2. Speech Recognition Unavailable
**Problem**: macOS speech recognition not working
**Solution**:
- Verify macOS version is 11.0 or higher
- Check system language settings
- Ensure Siri is enabled in system preferences

#### 3. Build Errors
**Problem**: Compilation fails with platform version errors
**Solution**:
- Update macOS deployment target to 11.0
- Clean build directory: `flutter clean`
- Reinstall dependencies: `flutter pub get`

### Debug Logging

Enable detailed logging for debugging:

```dart
// Set debug logging in speech_to_text initialization
await _speechToText.initialize(
  onStatus: _onSpeechStatus,
  onError: _onSpeechError,
  debugLogging: true, // Enable debug output
);
```

## Future Roadmap

### Phase 2: Enhanced Audio Support
- [ ] Implement actual audio recording with file saving
- [ ] Add MP3 compression and format conversion
- [ ] Implement audio playback for recorded files

### Phase 3: WhisperKit Integration
- [ ] Add flutter_whisper_kit dependency
- [ ] Implement model selection and download UI
- [ ] Add offline transcription capabilities
- [ ] Model management and storage optimization

### Phase 4: Advanced Features
- [ ] Multi-language support with automatic detection
- [ ] Voice command recognition for app navigation
- [ ] Speaker identification for multi-user scenarios
- [ ] Custom vocabulary and training capabilities

### Phase 5: Cross-Platform
- [ ] Windows Speech API integration
- [ ] Linux speech recognition support
- [ ] Platform-specific optimizations

## Contributing

### Development Guidelines

1. **State Management**: Use Riverpod for all state management
2. **Error Handling**: Always implement comprehensive error handling
3. **Testing**: Write unit tests for all new functionality
4. **Documentation**: Update this README for any changes
5. **Platform Support**: Consider cross-platform compatibility

### Code Review Checklist

- [ ] Proper error handling and user feedback
- [ ] Memory leak prevention (dispose streams/controllers)
- [ ] Platform-specific permissions and configurations
- [ ] Unit tests with good coverage
- [ ] Documentation updates
- [ ] Performance optimization considerations

## Conclusion

The voice-to-text implementation provides a robust foundation for voice interaction in the FlowHunt Desktop application. The modular architecture allows for easy expansion and enhancement while maintaining excellent user experience and performance.

For questions or contributions, please refer to the main project documentation or create an issue in the GitHub repository.