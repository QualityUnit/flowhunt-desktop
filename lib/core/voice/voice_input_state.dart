import 'package:equatable/equatable.dart';

/// Represents different states of voice input
enum VoiceInputStatus {
  idle,
  initializing,
  listening,
  processing,
  completed,
  error,
}

/// Represents different speech recognition engines
enum SpeechEngine {
  osNative,
  whisperKit,
  openAIWhisper,
}

/// Represents errors that can occur during voice input
class VoiceInputError extends Equatable {
  final String message;
  final String? code;
  final VoiceInputErrorType type;

  const VoiceInputError({
    required this.message,
    this.code,
    required this.type,
  });

  @override
  List<Object?> get props => [message, code, type];
}

enum VoiceInputErrorType {
  permissionDenied,
  microphoneNotAvailable,
  speechRecognitionUnavailable,
  networkError,
  fileSystemError,
  processingError,
  unknown,
}

/// Represents a saved recording file
class RecordingFile extends Equatable {
  final String id;
  final String audioPath;
  final String textPath;
  final String filename;
  final DateTime createdAt;
  final Duration duration;
  final String transcription;
  final SpeechEngine engine;

  const RecordingFile({
    required this.id,
    required this.audioPath,
    required this.textPath,
    required this.filename,
    required this.createdAt,
    required this.duration,
    required this.transcription,
    required this.engine,
  });

  @override
  List<Object?> get props => [
        id,
        audioPath,
        textPath,
        filename,
        createdAt,
        duration,
        transcription,
        engine,
      ];
}

/// Main state class for voice input functionality
class VoiceInputState extends Equatable {
  final VoiceInputStatus status;
  final bool hasPermission;
  final bool isPermissionRequested;
  final String transcription;
  final double audioLevel;
  final Duration recordingDuration;
  final VoiceInputError? error;
  final List<RecordingFile> savedFiles;
  final SpeechEngine currentEngine;
  final List<SpeechEngine> availableEngines;
  final bool isInitialized;

  const VoiceInputState({
    this.status = VoiceInputStatus.idle,
    this.hasPermission = false,
    this.isPermissionRequested = false,
    this.transcription = '',
    this.audioLevel = 0.0,
    this.recordingDuration = Duration.zero,
    this.error,
    this.savedFiles = const [],
    this.currentEngine = SpeechEngine.osNative,
    this.availableEngines = const [SpeechEngine.osNative],
    this.isInitialized = false,
  });

  VoiceInputState copyWith({
    VoiceInputStatus? status,
    bool? hasPermission,
    bool? isPermissionRequested,
    String? transcription,
    double? audioLevel,
    Duration? recordingDuration,
    VoiceInputError? error,
    List<RecordingFile>? savedFiles,
    SpeechEngine? currentEngine,
    List<SpeechEngine>? availableEngines,
    bool? isInitialized,
    bool clearError = false,
    bool clearTranscription = false,
  }) {
    return VoiceInputState(
      status: status ?? this.status,
      hasPermission: hasPermission ?? this.hasPermission,
      isPermissionRequested: isPermissionRequested ?? this.isPermissionRequested,
      transcription: clearTranscription ? '' : (transcription ?? this.transcription),
      audioLevel: audioLevel ?? this.audioLevel,
      recordingDuration: recordingDuration ?? this.recordingDuration,
      error: clearError ? null : (error ?? this.error),
      savedFiles: savedFiles ?? this.savedFiles,
      currentEngine: currentEngine ?? this.currentEngine,
      availableEngines: availableEngines ?? this.availableEngines,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }

  bool get isRecording => status == VoiceInputStatus.listening;
  bool get isProcessing => status == VoiceInputStatus.processing;
  bool get canStartRecording => 
      isInitialized && 
      hasPermission && 
      status == VoiceInputStatus.idle &&
      availableEngines.isNotEmpty;
  bool get hasError => error != null;

  @override
  List<Object?> get props => [
        status,
        hasPermission,
        isPermissionRequested,
        transcription,
        audioLevel,
        recordingDuration,
        error,
        savedFiles,
        currentEngine,
        availableEngines,
        isInitialized,
      ];
}