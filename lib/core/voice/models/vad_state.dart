import 'package:equatable/equatable.dart';

/// Voice Activity Detection states
enum VadState {
  /// No voice activity detected, system is idle
  idle,
  
  /// Listening for wake word or voice activity
  listening,
  
  /// Voice activity detected, preparing to record
  voiceDetected,
  
  /// Currently recording speech
  recording,
  
  /// Processing recorded speech
  processing,
  
  /// Waiting for silence to stop recording
  waitingForSilence,
  
  /// Error in VAD processing
  error,
}

/// Voice Activity Detection configuration
class VadConfiguration extends Equatable {
  /// Enable/disable Voice Activity Detection
  final bool enabled;
  
  /// Wake word detection enabled
  final bool wakeWordEnabled;
  
  /// Wake word phrase (e.g., "Hey FlowHunt")
  final String wakeWord;
  
  /// Minimum audio level to trigger voice detection (0.0 - 1.0)
  final double voiceThreshold;
  
  /// Duration of silence before stopping recording (in milliseconds)
  final int silenceTimeout;
  
  /// Maximum recording duration (in milliseconds)
  final int maxRecordingDuration;
  
  /// Minimum voice duration to start recording (in milliseconds)
  final int minVoiceDuration;
  
  /// Background noise reduction level (0.0 - 1.0)
  final double noiseReduction;
  
  /// Push-to-talk mode (disables automatic detection)
  final bool pushToTalkMode;
  
  /// Auto-start recording on voice detection
  final bool autoStartRecording;
  
  /// Audio sensitivity level (0.0 - 1.0)
  final double sensitivity;
  
  /// Energy threshold for voice detection
  final double energyThreshold;
  
  /// Number of consecutive frames for voice confirmation
  final int voiceConfirmationFrames;
  
  /// Number of consecutive frames for silence confirmation
  final int silenceConfirmationFrames;

  const VadConfiguration({
    this.enabled = true,
    this.wakeWordEnabled = false,
    this.wakeWord = 'Hey FlowHunt',
    this.voiceThreshold = 0.3,
    this.silenceTimeout = 2000,
    this.maxRecordingDuration = 30000,
    this.minVoiceDuration = 500,
    this.noiseReduction = 0.5,
    this.pushToTalkMode = false,
    this.autoStartRecording = true,
    this.sensitivity = 0.7,
    this.energyThreshold = 0.4,
    this.voiceConfirmationFrames = 3,
    this.silenceConfirmationFrames = 5,
  });

  VadConfiguration copyWith({
    bool? enabled,
    bool? wakeWordEnabled,
    String? wakeWord,
    double? voiceThreshold,
    int? silenceTimeout,
    int? maxRecordingDuration,
    int? minVoiceDuration,
    double? noiseReduction,
    bool? pushToTalkMode,
    bool? autoStartRecording,
    double? sensitivity,
    double? energyThreshold,
    int? voiceConfirmationFrames,
    int? silenceConfirmationFrames,
  }) {
    return VadConfiguration(
      enabled: enabled ?? this.enabled,
      wakeWordEnabled: wakeWordEnabled ?? this.wakeWordEnabled,
      wakeWord: wakeWord ?? this.wakeWord,
      voiceThreshold: voiceThreshold ?? this.voiceThreshold,
      silenceTimeout: silenceTimeout ?? this.silenceTimeout,
      maxRecordingDuration: maxRecordingDuration ?? this.maxRecordingDuration,
      minVoiceDuration: minVoiceDuration ?? this.minVoiceDuration,
      noiseReduction: noiseReduction ?? this.noiseReduction,
      pushToTalkMode: pushToTalkMode ?? this.pushToTalkMode,
      autoStartRecording: autoStartRecording ?? this.autoStartRecording,
      sensitivity: sensitivity ?? this.sensitivity,
      energyThreshold: energyThreshold ?? this.energyThreshold,
      voiceConfirmationFrames: voiceConfirmationFrames ?? this.voiceConfirmationFrames,
      silenceConfirmationFrames: silenceConfirmationFrames ?? this.silenceConfirmationFrames,
    );
  }

  @override
  List<Object?> get props => [
        enabled,
        wakeWordEnabled,
        wakeWord,
        voiceThreshold,
        silenceTimeout,
        maxRecordingDuration,
        minVoiceDuration,
        noiseReduction,
        pushToTalkMode,
        autoStartRecording,
        sensitivity,
        energyThreshold,
        voiceConfirmationFrames,
        silenceConfirmationFrames,
      ];
}

/// Voice Activity Detection result
class VadResult extends Equatable {
  /// Current VAD state
  final VadState state;
  
  /// Whether voice activity is currently detected
  final bool isVoiceActive;
  
  /// Current audio level (0.0 - 1.0)
  final double audioLevel;
  
  /// Current energy level (0.0 - 1.0)
  final double energyLevel;
  
  /// Background noise level (0.0 - 1.0)
  final double noiseLevel;
  
  /// Duration of current voice activity (in milliseconds)
  final int voiceDuration;
  
  /// Duration of current silence (in milliseconds)
  final int silenceDuration;
  
  /// Whether wake word was detected
  final bool wakeWordDetected;
  
  /// Confidence of voice detection (0.0 - 1.0)
  final double confidence;
  
  /// Raw audio data (for advanced processing)
  final List<int>? audioData;

  const VadResult({
    required this.state,
    required this.isVoiceActive,
    required this.audioLevel,
    required this.energyLevel,
    required this.noiseLevel,
    required this.voiceDuration,
    required this.silenceDuration,
    this.wakeWordDetected = false,
    required this.confidence,
    this.audioData,
  });

  @override
  List<Object?> get props => [
        state,
        isVoiceActive,
        audioLevel,
        energyLevel,
        noiseLevel,
        voiceDuration,
        silenceDuration,
        wakeWordDetected,
        confidence,
        audioData,
      ];
}

/// Audio frame for VAD processing
class AudioFrame extends Equatable {
  /// Frame timestamp
  final DateTime timestamp;
  
  /// Audio data
  final List<int> data;
  
  /// Sample rate
  final int sampleRate;
  
  /// Number of channels
  final int channels;
  
  /// Bit depth
  final int bitDepth;

  const AudioFrame({
    required this.timestamp,
    required this.data,
    required this.sampleRate,
    required this.channels,
    required this.bitDepth,
  });

  @override
  List<Object?> get props => [timestamp, data, sampleRate, channels, bitDepth];
}

/// VAD event types for notification system
enum VadEventType {
  voiceStarted,
  voiceStopped,
  recordingStarted,
  recordingStopped,
  wakeWordDetected,
  silenceDetected,
  error,
}

/// VAD event for notifications
class VadEvent extends Equatable {
  /// Type of event
  final VadEventType type;
  
  /// Event timestamp
  final DateTime timestamp;
  
  /// Event data
  final Map<String, dynamic> data;
  
  /// Related VAD result
  final VadResult? vadResult;

  const VadEvent({
    required this.type,
    required this.timestamp,
    this.data = const {},
    this.vadResult,
  });

  @override
  List<Object?> get props => [type, timestamp, data, vadResult];
}