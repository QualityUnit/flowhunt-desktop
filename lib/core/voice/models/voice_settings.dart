import 'package:equatable/equatable.dart';

import 'language_detection.dart';
import 'vad_state.dart';

/// Comprehensive voice settings model
class VoiceSettings extends Equatable {
  /// General voice settings
  final bool voiceInputEnabled;
  final bool voiceCommandsEnabled;
  final bool voiceFeedbackEnabled;
  final double masterVolume;
  
  /// Language settings
  final LanguagePreferences languagePreferences;
  
  /// Voice Activity Detection settings
  final VadConfiguration vadConfiguration;
  
  /// Speaker identification settings
  final SpeakerIdentificationSettings speakerSettings;
  
  /// Voice command settings
  final VoiceCommandSettings commandSettings;
  
  /// Audio quality settings
  final AudioQualitySettings audioSettings;
  
  /// Privacy and security settings
  final VoicePrivacySettings privacySettings;
  
  /// Accessibility settings
  final VoiceAccessibilitySettings accessibilitySettings;

  const VoiceSettings({
    this.voiceInputEnabled = true,
    this.voiceCommandsEnabled = true,
    this.voiceFeedbackEnabled = true,
    this.masterVolume = 0.8,
    this.languagePreferences = const LanguagePreferences(),
    this.vadConfiguration = const VadConfiguration(),
    this.speakerSettings = const SpeakerIdentificationSettings(),
    this.commandSettings = const VoiceCommandSettings(),
    this.audioSettings = const AudioQualitySettings(),
    this.privacySettings = const VoicePrivacySettings(),
    this.accessibilitySettings = const VoiceAccessibilitySettings(),
  });

  VoiceSettings copyWith({
    bool? voiceInputEnabled,
    bool? voiceCommandsEnabled,
    bool? voiceFeedbackEnabled,
    double? masterVolume,
    LanguagePreferences? languagePreferences,
    VadConfiguration? vadConfiguration,
    SpeakerIdentificationSettings? speakerSettings,
    VoiceCommandSettings? commandSettings,
    AudioQualitySettings? audioSettings,
    VoicePrivacySettings? privacySettings,
    VoiceAccessibilitySettings? accessibilitySettings,
  }) {
    return VoiceSettings(
      voiceInputEnabled: voiceInputEnabled ?? this.voiceInputEnabled,
      voiceCommandsEnabled: voiceCommandsEnabled ?? this.voiceCommandsEnabled,
      voiceFeedbackEnabled: voiceFeedbackEnabled ?? this.voiceFeedbackEnabled,
      masterVolume: masterVolume ?? this.masterVolume,
      languagePreferences: languagePreferences ?? this.languagePreferences,
      vadConfiguration: vadConfiguration ?? this.vadConfiguration,
      speakerSettings: speakerSettings ?? this.speakerSettings,
      commandSettings: commandSettings ?? this.commandSettings,
      audioSettings: audioSettings ?? this.audioSettings,
      privacySettings: privacySettings ?? this.privacySettings,
      accessibilitySettings: accessibilitySettings ?? this.accessibilitySettings,
    );
  }

  @override
  List<Object?> get props => [
        voiceInputEnabled,
        voiceCommandsEnabled,
        voiceFeedbackEnabled,
        masterVolume,
        languagePreferences,
        vadConfiguration,
        speakerSettings,
        commandSettings,
        audioSettings,
        privacySettings,
        accessibilitySettings,
      ];
}

/// Speaker identification specific settings
class SpeakerIdentificationSettings extends Equatable {
  /// Enable speaker identification
  final bool enabled;
  
  /// Automatic speaker registration
  final bool autoRegisterNewSpeakers;
  
  /// Minimum confidence for speaker identification
  final double minIdentificationConfidence;
  
  /// Visual indicators for speakers
  final bool showSpeakerIndicators;
  
  /// Speaker profile learning mode
  final bool learningModeEnabled;
  
  /// Maximum number of speakers to track
  final int maxSpeakers;
  
  /// Speaker profile retention period (in days)
  final int profileRetentionDays;

  const SpeakerIdentificationSettings({
    this.enabled = true,
    this.autoRegisterNewSpeakers = false,
    this.minIdentificationConfidence = 0.7,
    this.showSpeakerIndicators = true,
    this.learningModeEnabled = true,
    this.maxSpeakers = 10,
    this.profileRetentionDays = 90,
  });

  SpeakerIdentificationSettings copyWith({
    bool? enabled,
    bool? autoRegisterNewSpeakers,
    double? minIdentificationConfidence,
    bool? showSpeakerIndicators,
    bool? learningModeEnabled,
    int? maxSpeakers,
    int? profileRetentionDays,
  }) {
    return SpeakerIdentificationSettings(
      enabled: enabled ?? this.enabled,
      autoRegisterNewSpeakers: autoRegisterNewSpeakers ?? this.autoRegisterNewSpeakers,
      minIdentificationConfidence: minIdentificationConfidence ?? this.minIdentificationConfidence,
      showSpeakerIndicators: showSpeakerIndicators ?? this.showSpeakerIndicators,
      learningModeEnabled: learningModeEnabled ?? this.learningModeEnabled,
      maxSpeakers: maxSpeakers ?? this.maxSpeakers,
      profileRetentionDays: profileRetentionDays ?? this.profileRetentionDays,
    );
  }

  @override
  List<Object?> get props => [
        enabled,
        autoRegisterNewSpeakers,
        minIdentificationConfidence,
        showSpeakerIndicators,
        learningModeEnabled,
        maxSpeakers,
        profileRetentionDays,
      ];
}

/// Voice command specific settings
class VoiceCommandSettings extends Equatable {
  /// Enable voice commands
  final bool enabled;
  
  /// Minimum confidence for command recognition
  final double minCommandConfidence;
  
  /// Enable fuzzy matching for commands
  final bool fuzzyMatchingEnabled;
  
  /// Command confirmation mode
  final CommandConfirmationMode confirmationMode;
  
  /// Enable audio feedback for commands
  final bool audioFeedbackEnabled;
  
  /// Enable visual feedback for commands
  final bool visualFeedbackEnabled;
  
  /// Custom command timeout (in seconds)
  final int commandTimeout;
  
  /// Enable command history
  final bool commandHistoryEnabled;

  const VoiceCommandSettings({
    this.enabled = true,
    this.minCommandConfidence = 0.7,
    this.fuzzyMatchingEnabled = true,
    this.confirmationMode = CommandConfirmationMode.auto,
    this.audioFeedbackEnabled = true,
    this.visualFeedbackEnabled = true,
    this.commandTimeout = 5,
    this.commandHistoryEnabled = true,
  });

  VoiceCommandSettings copyWith({
    bool? enabled,
    double? minCommandConfidence,
    bool? fuzzyMatchingEnabled,
    CommandConfirmationMode? confirmationMode,
    bool? audioFeedbackEnabled,
    bool? visualFeedbackEnabled,
    int? commandTimeout,
    bool? commandHistoryEnabled,
  }) {
    return VoiceCommandSettings(
      enabled: enabled ?? this.enabled,
      minCommandConfidence: minCommandConfidence ?? this.minCommandConfidence,
      fuzzyMatchingEnabled: fuzzyMatchingEnabled ?? this.fuzzyMatchingEnabled,
      confirmationMode: confirmationMode ?? this.confirmationMode,
      audioFeedbackEnabled: audioFeedbackEnabled ?? this.audioFeedbackEnabled,
      visualFeedbackEnabled: visualFeedbackEnabled ?? this.visualFeedbackEnabled,
      commandTimeout: commandTimeout ?? this.commandTimeout,
      commandHistoryEnabled: commandHistoryEnabled ?? this.commandHistoryEnabled,
    );
  }

  @override
  List<Object?> get props => [
        enabled,
        minCommandConfidence,
        fuzzyMatchingEnabled,
        confirmationMode,
        audioFeedbackEnabled,
        visualFeedbackEnabled,
        commandTimeout,
        commandHistoryEnabled,
      ];
}

/// Command confirmation modes
enum CommandConfirmationMode {
  /// No confirmation required
  none,
  
  /// Automatic confirmation based on confidence
  auto,
  
  /// Always require user confirmation
  always,
  
  /// Confirm only for destructive actions
  destructiveOnly,
}

/// Audio quality settings
class AudioQualitySettings extends Equatable {
  /// Sample rate for audio recording
  final int sampleRate;
  
  /// Audio encoding quality
  final AudioEncodingQuality encodingQuality;
  
  /// Enable noise reduction
  final bool noiseReductionEnabled;
  
  /// Noise reduction strength (0.0 - 1.0)
  final double noiseReductionStrength;
  
  /// Enable echo cancellation
  final bool echoCancellationEnabled;
  
  /// Audio gain control
  final bool autoGainControlEnabled;
  
  /// Manual gain level (0.0 - 2.0)
  final double gainLevel;
  
  /// Audio compression
  final bool compressionEnabled;

  const AudioQualitySettings({
    this.sampleRate = 16000,
    this.encodingQuality = AudioEncodingQuality.medium,
    this.noiseReductionEnabled = true,
    this.noiseReductionStrength = 0.5,
    this.echoCancellationEnabled = true,
    this.autoGainControlEnabled = true,
    this.gainLevel = 1.0,
    this.compressionEnabled = false,
  });

  AudioQualitySettings copyWith({
    int? sampleRate,
    AudioEncodingQuality? encodingQuality,
    bool? noiseReductionEnabled,
    double? noiseReductionStrength,
    bool? echoCancellationEnabled,
    bool? autoGainControlEnabled,
    double? gainLevel,
    bool? compressionEnabled,
  }) {
    return AudioQualitySettings(
      sampleRate: sampleRate ?? this.sampleRate,
      encodingQuality: encodingQuality ?? this.encodingQuality,
      noiseReductionEnabled: noiseReductionEnabled ?? this.noiseReductionEnabled,
      noiseReductionStrength: noiseReductionStrength ?? this.noiseReductionStrength,
      echoCancellationEnabled: echoCancellationEnabled ?? this.echoCancellationEnabled,
      autoGainControlEnabled: autoGainControlEnabled ?? this.autoGainControlEnabled,
      gainLevel: gainLevel ?? this.gainLevel,
      compressionEnabled: compressionEnabled ?? this.compressionEnabled,
    );
  }

  @override
  List<Object?> get props => [
        sampleRate,
        encodingQuality,
        noiseReductionEnabled,
        noiseReductionStrength,
        echoCancellationEnabled,
        autoGainControlEnabled,
        gainLevel,
        compressionEnabled,
      ];
}

/// Audio encoding quality levels
enum AudioEncodingQuality {
  low,
  medium,
  high,
  lossless,
}

/// Privacy and security settings
class VoicePrivacySettings extends Equatable {
  /// Store voice recordings locally
  final bool storeRecordingsLocally;
  
  /// Automatically delete old recordings
  final bool autoDeleteOldRecordings;
  
  /// Recording retention period (in days)
  final int recordingRetentionDays;
  
  /// Encrypt stored voice data
  final bool encryptVoiceData;
  
  /// Allow voice data collection for improvement
  final bool allowDataCollection;
  
  /// Share anonymous usage statistics
  final bool shareAnonymousStats;
  
  /// Biometric voice authentication
  final bool biometricAuthEnabled;

  const VoicePrivacySettings({
    this.storeRecordingsLocally = true,
    this.autoDeleteOldRecordings = true,
    this.recordingRetentionDays = 30,
    this.encryptVoiceData = true,
    this.allowDataCollection = false,
    this.shareAnonymousStats = false,
    this.biometricAuthEnabled = false,
  });

  VoicePrivacySettings copyWith({
    bool? storeRecordingsLocally,
    bool? autoDeleteOldRecordings,
    int? recordingRetentionDays,
    bool? encryptVoiceData,
    bool? allowDataCollection,
    bool? shareAnonymousStats,
    bool? biometricAuthEnabled,
  }) {
    return VoicePrivacySettings(
      storeRecordingsLocally: storeRecordingsLocally ?? this.storeRecordingsLocally,
      autoDeleteOldRecordings: autoDeleteOldRecordings ?? this.autoDeleteOldRecordings,
      recordingRetentionDays: recordingRetentionDays ?? this.recordingRetentionDays,
      encryptVoiceData: encryptVoiceData ?? this.encryptVoiceData,
      allowDataCollection: allowDataCollection ?? this.allowDataCollection,
      shareAnonymousStats: shareAnonymousStats ?? this.shareAnonymousStats,
      biometricAuthEnabled: biometricAuthEnabled ?? this.biometricAuthEnabled,
    );
  }

  @override
  List<Object?> get props => [
        storeRecordingsLocally,
        autoDeleteOldRecordings,
        recordingRetentionDays,
        encryptVoiceData,
        allowDataCollection,
        shareAnonymousStats,
        biometricAuthEnabled,
      ];
}

/// Accessibility settings for voice features
class VoiceAccessibilitySettings extends Equatable {
  /// Enable voice UI descriptions
  final bool voiceDescriptionsEnabled;
  
  /// Speech rate for voice feedback (0.5 - 2.0)
  final double speechRate;
  
  /// Voice feedback volume (0.0 - 1.0)
  final double feedbackVolume;
  
  /// Enable high contrast visual indicators
  final bool highContrastIndicators;
  
  /// Larger visual feedback elements
  final bool largeVisualElements;
  
  /// Enable voice shortcuts for common actions
  final bool voiceShortcutsEnabled;
  
  /// Simplified command set for easier use
  final bool simplifiedCommands;
  
  /// Extended timeout for voice input
  final bool extendedTimeouts;

  const VoiceAccessibilitySettings({
    this.voiceDescriptionsEnabled = false,
    this.speechRate = 1.0,
    this.feedbackVolume = 0.8,
    this.highContrastIndicators = false,
    this.largeVisualElements = false,
    this.voiceShortcutsEnabled = true,
    this.simplifiedCommands = false,
    this.extendedTimeouts = false,
  });

  VoiceAccessibilitySettings copyWith({
    bool? voiceDescriptionsEnabled,
    double? speechRate,
    double? feedbackVolume,
    bool? highContrastIndicators,
    bool? largeVisualElements,
    bool? voiceShortcutsEnabled,
    bool? simplifiedCommands,
    bool? extendedTimeouts,
  }) {
    return VoiceAccessibilitySettings(
      voiceDescriptionsEnabled: voiceDescriptionsEnabled ?? this.voiceDescriptionsEnabled,
      speechRate: speechRate ?? this.speechRate,
      feedbackVolume: feedbackVolume ?? this.feedbackVolume,
      highContrastIndicators: highContrastIndicators ?? this.highContrastIndicators,
      largeVisualElements: largeVisualElements ?? this.largeVisualElements,
      voiceShortcutsEnabled: voiceShortcutsEnabled ?? this.voiceShortcutsEnabled,
      simplifiedCommands: simplifiedCommands ?? this.simplifiedCommands,
      extendedTimeouts: extendedTimeouts ?? this.extendedTimeouts,
    );
  }

  @override
  List<Object?> get props => [
        voiceDescriptionsEnabled,
        speechRate,
        feedbackVolume,
        highContrastIndicators,
        largeVisualElements,
        voiceShortcutsEnabled,
        simplifiedCommands,
        extendedTimeouts,
      ];
}