import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/voice_settings.dart';
import '../models/language_detection.dart';
import '../models/vad_state.dart';

/// Service responsible for managing voice settings persistence and synchronization
class VoiceSettingsService {
  final Logger _logger = Logger();
  
  /// Current voice settings
  VoiceSettings _currentSettings = const VoiceSettings();
  
  /// Stream controller for settings changes
  final StreamController<VoiceSettings> _settingsController = StreamController<VoiceSettings>.broadcast();
  
  /// Settings file path
  String? _settingsFilePath;
  
  /// Whether the service is initialized
  bool _isInitialized = false;
  
  /// Get current settings
  VoiceSettings get currentSettings => _currentSettings;
  
  /// Get settings change stream
  Stream<VoiceSettings> get settingsStream => _settingsController.stream;
  
  /// Initialize the settings service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _logger.i('Initializing Voice Settings Service...');
      
      // Initialize settings file path
      await _initializeSettingsPath();
      
      // Load saved settings
      await _loadSettings();
      
      _isInitialized = true;
      _logger.i('Voice Settings Service initialized successfully');
    } catch (e) {
      _logger.e('Failed to initialize Voice Settings Service: $e');
      rethrow;
    }
  }
  
  /// Update voice settings
  Future<void> updateSettings(VoiceSettings newSettings) async {
    if (!_isInitialized) {
      throw Exception('Settings service not initialized');
    }
    
    try {
      _currentSettings = newSettings;
      
      // Save to persistent storage
      await _saveSettings();
      
      // Notify listeners
      _settingsController.add(_currentSettings);
      
      _logger.i('Voice settings updated successfully');
    } catch (e) {
      _logger.e('Failed to update voice settings: $e');
      rethrow;
    }
  }
  
  /// Update specific setting category
  Future<void> updateLanguagePreferences(LanguagePreferences preferences) async {
    await updateSettings(_currentSettings.copyWith(languagePreferences: preferences));
  }
  
  Future<void> updateVadConfiguration(VadConfiguration config) async {
    await updateSettings(_currentSettings.copyWith(vadConfiguration: config));
  }
  
  Future<void> updateSpeakerSettings(SpeakerIdentificationSettings settings) async {
    await updateSettings(_currentSettings.copyWith(speakerSettings: settings));
  }
  
  Future<void> updateCommandSettings(VoiceCommandSettings settings) async {
    await updateSettings(_currentSettings.copyWith(commandSettings: settings));
  }
  
  Future<void> updateAudioSettings(AudioQualitySettings settings) async {
    await updateSettings(_currentSettings.copyWith(audioSettings: settings));
  }
  
  Future<void> updatePrivacySettings(VoicePrivacySettings settings) async {
    await updateSettings(_currentSettings.copyWith(privacySettings: settings));
  }
  
  Future<void> updateAccessibilitySettings(VoiceAccessibilitySettings settings) async {
    await updateSettings(_currentSettings.copyWith(accessibilitySettings: settings));
  }
  
  /// Reset settings to defaults
  Future<void> resetToDefaults() async {
    _logger.i('Resetting voice settings to defaults');
    await updateSettings(const VoiceSettings());
  }
  
  /// Import settings from JSON
  Future<void> importSettings(Map<String, dynamic> json) async {
    try {
      final settings = _parseSettingsFromJson(json);
      await updateSettings(settings);
      _logger.i('Voice settings imported successfully');
    } catch (e) {
      _logger.e('Failed to import voice settings: $e');
      rethrow;
    }
  }
  
  /// Export settings to JSON
  Map<String, dynamic> exportSettings() {
    return _settingsToJson(_currentSettings);
  }
  
  /// Initialize settings file path
  Future<void> _initializeSettingsPath() async {
    final appDir = await getApplicationDocumentsDirectory();
    final settingsDir = Directory(path.join(appDir.path, 'FlowHunt', 'Voice'));
    
    if (!await settingsDir.exists()) {
      await settingsDir.create(recursive: true);
    }
    
    _settingsFilePath = path.join(settingsDir.path, 'voice_settings.json');
  }
  
  /// Load settings from storage
  Future<void> _loadSettings() async {
    try {
      // First, try to load from file
      if (_settingsFilePath != null) {
        final file = File(_settingsFilePath!);
        if (await file.exists()) {
          final jsonString = await file.readAsString();
          final json = jsonDecode(jsonString) as Map<String, dynamic>;
          _currentSettings = _parseSettingsFromJson(json);
          _logger.d('Voice settings loaded from file');
          return;
        }
      }
      
      // Fallback to SharedPreferences for backwards compatibility
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString('voice_settings');
      
      if (settingsJson != null) {
        final json = jsonDecode(settingsJson) as Map<String, dynamic>;
        _currentSettings = _parseSettingsFromJson(json);
        
        // Migrate to file storage
        await _saveSettings();
        await prefs.remove('voice_settings');
        
        _logger.d('Voice settings migrated from SharedPreferences to file');
      } else {
        _logger.d('No saved voice settings found, using defaults');
      }
    } catch (e) {
      _logger.w('Failed to load voice settings, using defaults: $e');
      _currentSettings = const VoiceSettings();
    }
  }
  
  /// Save settings to storage
  Future<void> _saveSettings() async {
    try {
      if (_settingsFilePath == null) {
        throw Exception('Settings file path not initialized');
      }
      
      final json = _settingsToJson(_currentSettings);
      final jsonString = jsonEncode(json);
      
      final file = File(_settingsFilePath!);
      await file.writeAsString(jsonString);
      
      _logger.d('Voice settings saved to file');
    } catch (e) {
      _logger.e('Failed to save voice settings: $e');
      rethrow;
    }
  }
  
  /// Parse settings from JSON
  VoiceSettings _parseSettingsFromJson(Map<String, dynamic> json) {
    return VoiceSettings(
      voiceInputEnabled: json['voice_input_enabled'] ?? true,
      voiceCommandsEnabled: json['voice_commands_enabled'] ?? true,
      voiceFeedbackEnabled: json['voice_feedback_enabled'] ?? true,
      masterVolume: (json['master_volume'] ?? 0.8).toDouble(),
      languagePreferences: _parseLanguagePreferences(json['language_preferences'] ?? {}),
      vadConfiguration: _parseVadConfiguration(json['vad_configuration'] ?? {}),
      speakerSettings: _parseSpeakerSettings(json['speaker_settings'] ?? {}),
      commandSettings: _parseCommandSettings(json['command_settings'] ?? {}),
      audioSettings: _parseAudioSettings(json['audio_settings'] ?? {}),
      privacySettings: _parsePrivacySettings(json['privacy_settings'] ?? {}),
      accessibilitySettings: _parseAccessibilitySettings(json['accessibility_settings'] ?? {}),
    );
  }
  
  /// Convert settings to JSON
  Map<String, dynamic> _settingsToJson(VoiceSettings settings) {
    return {
      'voice_input_enabled': settings.voiceInputEnabled,
      'voice_commands_enabled': settings.voiceCommandsEnabled,
      'voice_feedback_enabled': settings.voiceFeedbackEnabled,
      'master_volume': settings.masterVolume,
      'language_preferences': _languagePreferencesToJson(settings.languagePreferences),
      'vad_configuration': _vadConfigurationToJson(settings.vadConfiguration),
      'speaker_settings': _speakerSettingsToJson(settings.speakerSettings),
      'command_settings': _commandSettingsToJson(settings.commandSettings),
      'audio_settings': _audioSettingsToJson(settings.audioSettings),
      'privacy_settings': _privacySettingsToJson(settings.privacySettings),
      'accessibility_settings': _accessibilitySettingsToJson(settings.accessibilitySettings),
    };
  }
  
  /// Parse language preferences from JSON
  LanguagePreferences _parseLanguagePreferences(Map<String, dynamic> json) {
    return LanguagePreferences(
      primaryLanguage: json['primary_language'] ?? 'en',
      autoDetectionEnabled: json['auto_detection_enabled'] ?? true,
      autoDetectionThreshold: (json['auto_detection_threshold'] ?? 0.7).toDouble(),
      fallbackLanguage: json['fallback_language'] ?? 'en',
      autoSwitchEnabled: json['auto_switch_enabled'] ?? false,
      preferredLanguages: List<String>.from(json['preferred_languages'] ?? ['en']),
    );
  }
  
  /// Convert language preferences to JSON
  Map<String, dynamic> _languagePreferencesToJson(LanguagePreferences prefs) {
    return {
      'primary_language': prefs.primaryLanguage,
      'auto_detection_enabled': prefs.autoDetectionEnabled,
      'auto_detection_threshold': prefs.autoDetectionThreshold,
      'fallback_language': prefs.fallbackLanguage,
      'auto_switch_enabled': prefs.autoSwitchEnabled,
      'preferred_languages': prefs.preferredLanguages,
    };
  }
  
  /// Parse VAD configuration from JSON
  VadConfiguration _parseVadConfiguration(Map<String, dynamic> json) {
    return VadConfiguration(
      enabled: json['enabled'] ?? true,
      wakeWordEnabled: json['wake_word_enabled'] ?? false,
      wakeWord: json['wake_word'] ?? 'Hey FlowHunt',
      voiceThreshold: (json['voice_threshold'] ?? 0.3).toDouble(),
      silenceTimeout: json['silence_timeout'] ?? 2000,
      maxRecordingDuration: json['max_recording_duration'] ?? 30000,
      minVoiceDuration: json['min_voice_duration'] ?? 500,
      noiseReduction: (json['noise_reduction'] ?? 0.5).toDouble(),
      pushToTalkMode: json['push_to_talk_mode'] ?? false,
      autoStartRecording: json['auto_start_recording'] ?? true,
      sensitivity: (json['sensitivity'] ?? 0.7).toDouble(),
      energyThreshold: (json['energy_threshold'] ?? 0.4).toDouble(),
      voiceConfirmationFrames: json['voice_confirmation_frames'] ?? 3,
      silenceConfirmationFrames: json['silence_confirmation_frames'] ?? 5,
    );
  }
  
  /// Convert VAD configuration to JSON
  Map<String, dynamic> _vadConfigurationToJson(VadConfiguration config) {
    return {
      'enabled': config.enabled,
      'wake_word_enabled': config.wakeWordEnabled,
      'wake_word': config.wakeWord,
      'voice_threshold': config.voiceThreshold,
      'silence_timeout': config.silenceTimeout,
      'max_recording_duration': config.maxRecordingDuration,
      'min_voice_duration': config.minVoiceDuration,
      'noise_reduction': config.noiseReduction,
      'push_to_talk_mode': config.pushToTalkMode,
      'auto_start_recording': config.autoStartRecording,
      'sensitivity': config.sensitivity,
      'energy_threshold': config.energyThreshold,
      'voice_confirmation_frames': config.voiceConfirmationFrames,
      'silence_confirmation_frames': config.silenceConfirmationFrames,
    };
  }
  
  /// Parse speaker settings from JSON
  SpeakerIdentificationSettings _parseSpeakerSettings(Map<String, dynamic> json) {
    return SpeakerIdentificationSettings(
      enabled: json['enabled'] ?? true,
      autoRegisterNewSpeakers: json['auto_register_new_speakers'] ?? false,
      minIdentificationConfidence: (json['min_identification_confidence'] ?? 0.7).toDouble(),
      showSpeakerIndicators: json['show_speaker_indicators'] ?? true,
      learningModeEnabled: json['learning_mode_enabled'] ?? true,
      maxSpeakers: json['max_speakers'] ?? 10,
      profileRetentionDays: json['profile_retention_days'] ?? 90,
    );
  }
  
  /// Convert speaker settings to JSON
  Map<String, dynamic> _speakerSettingsToJson(SpeakerIdentificationSettings settings) {
    return {
      'enabled': settings.enabled,
      'auto_register_new_speakers': settings.autoRegisterNewSpeakers,
      'min_identification_confidence': settings.minIdentificationConfidence,
      'show_speaker_indicators': settings.showSpeakerIndicators,
      'learning_mode_enabled': settings.learningModeEnabled,
      'max_speakers': settings.maxSpeakers,
      'profile_retention_days': settings.profileRetentionDays,
    };
  }
  
  /// Parse command settings from JSON
  VoiceCommandSettings _parseCommandSettings(Map<String, dynamic> json) {
    return VoiceCommandSettings(
      enabled: json['enabled'] ?? true,
      minCommandConfidence: (json['min_command_confidence'] ?? 0.7).toDouble(),
      fuzzyMatchingEnabled: json['fuzzy_matching_enabled'] ?? true,
      confirmationMode: _parseConfirmationMode(json['confirmation_mode']),
      audioFeedbackEnabled: json['audio_feedback_enabled'] ?? true,
      visualFeedbackEnabled: json['visual_feedback_enabled'] ?? true,
      commandTimeout: json['command_timeout'] ?? 5,
      commandHistoryEnabled: json['command_history_enabled'] ?? true,
    );
  }
  
  /// Convert command settings to JSON
  Map<String, dynamic> _commandSettingsToJson(VoiceCommandSettings settings) {
    return {
      'enabled': settings.enabled,
      'min_command_confidence': settings.minCommandConfidence,
      'fuzzy_matching_enabled': settings.fuzzyMatchingEnabled,
      'confirmation_mode': settings.confirmationMode.toString(),
      'audio_feedback_enabled': settings.audioFeedbackEnabled,
      'visual_feedback_enabled': settings.visualFeedbackEnabled,
      'command_timeout': settings.commandTimeout,
      'command_history_enabled': settings.commandHistoryEnabled,
    };
  }
  
  /// Parse confirmation mode
  CommandConfirmationMode _parseConfirmationMode(dynamic value) {
    switch (value?.toString()) {
      case 'CommandConfirmationMode.none':
        return CommandConfirmationMode.none;
      case 'CommandConfirmationMode.always':
        return CommandConfirmationMode.always;
      case 'CommandConfirmationMode.destructiveOnly':
        return CommandConfirmationMode.destructiveOnly;
      default:
        return CommandConfirmationMode.auto;
    }
  }
  
  /// Parse audio settings from JSON
  AudioQualitySettings _parseAudioSettings(Map<String, dynamic> json) {
    return AudioQualitySettings(
      sampleRate: json['sample_rate'] ?? 16000,
      encodingQuality: _parseEncodingQuality(json['encoding_quality']),
      noiseReductionEnabled: json['noise_reduction_enabled'] ?? true,
      noiseReductionStrength: (json['noise_reduction_strength'] ?? 0.5).toDouble(),
      echoCancellationEnabled: json['echo_cancellation_enabled'] ?? true,
      autoGainControlEnabled: json['auto_gain_control_enabled'] ?? true,
      gainLevel: (json['gain_level'] ?? 1.0).toDouble(),
      compressionEnabled: json['compression_enabled'] ?? false,
    );
  }
  
  /// Convert audio settings to JSON
  Map<String, dynamic> _audioSettingsToJson(AudioQualitySettings settings) {
    return {
      'sample_rate': settings.sampleRate,
      'encoding_quality': settings.encodingQuality.toString(),
      'noise_reduction_enabled': settings.noiseReductionEnabled,
      'noise_reduction_strength': settings.noiseReductionStrength,
      'echo_cancellation_enabled': settings.echoCancellationEnabled,
      'auto_gain_control_enabled': settings.autoGainControlEnabled,
      'gain_level': settings.gainLevel,
      'compression_enabled': settings.compressionEnabled,
    };
  }
  
  /// Parse encoding quality
  AudioEncodingQuality _parseEncodingQuality(dynamic value) {
    switch (value?.toString()) {
      case 'AudioEncodingQuality.low':
        return AudioEncodingQuality.low;
      case 'AudioEncodingQuality.high':
        return AudioEncodingQuality.high;
      case 'AudioEncodingQuality.lossless':
        return AudioEncodingQuality.lossless;
      default:
        return AudioEncodingQuality.medium;
    }
  }
  
  /// Parse privacy settings from JSON
  VoicePrivacySettings _parsePrivacySettings(Map<String, dynamic> json) {
    return VoicePrivacySettings(
      storeRecordingsLocally: json['store_recordings_locally'] ?? true,
      autoDeleteOldRecordings: json['auto_delete_old_recordings'] ?? true,
      recordingRetentionDays: json['recording_retention_days'] ?? 30,
      encryptVoiceData: json['encrypt_voice_data'] ?? true,
      allowDataCollection: json['allow_data_collection'] ?? false,
      shareAnonymousStats: json['share_anonymous_stats'] ?? false,
      biometricAuthEnabled: json['biometric_auth_enabled'] ?? false,
    );
  }
  
  /// Convert privacy settings to JSON
  Map<String, dynamic> _privacySettingsToJson(VoicePrivacySettings settings) {
    return {
      'store_recordings_locally': settings.storeRecordingsLocally,
      'auto_delete_old_recordings': settings.autoDeleteOldRecordings,
      'recording_retention_days': settings.recordingRetentionDays,
      'encrypt_voice_data': settings.encryptVoiceData,
      'allow_data_collection': settings.allowDataCollection,
      'share_anonymous_stats': settings.shareAnonymousStats,
      'biometric_auth_enabled': settings.biometricAuthEnabled,
    };
  }
  
  /// Parse accessibility settings from JSON
  VoiceAccessibilitySettings _parseAccessibilitySettings(Map<String, dynamic> json) {
    return VoiceAccessibilitySettings(
      voiceDescriptionsEnabled: json['voice_descriptions_enabled'] ?? false,
      speechRate: (json['speech_rate'] ?? 1.0).toDouble(),
      feedbackVolume: (json['feedback_volume'] ?? 0.8).toDouble(),
      highContrastIndicators: json['high_contrast_indicators'] ?? false,
      largeVisualElements: json['large_visual_elements'] ?? false,
      voiceShortcutsEnabled: json['voice_shortcuts_enabled'] ?? true,
      simplifiedCommands: json['simplified_commands'] ?? false,
      extendedTimeouts: json['extended_timeouts'] ?? false,
    );
  }
  
  /// Convert accessibility settings to JSON
  Map<String, dynamic> _accessibilitySettingsToJson(VoiceAccessibilitySettings settings) {
    return {
      'voice_descriptions_enabled': settings.voiceDescriptionsEnabled,
      'speech_rate': settings.speechRate,
      'feedback_volume': settings.feedbackVolume,
      'high_contrast_indicators': settings.highContrastIndicators,
      'large_visual_elements': settings.largeVisualElements,
      'voice_shortcuts_enabled': settings.voiceShortcutsEnabled,
      'simplified_commands': settings.simplifiedCommands,
      'extended_timeouts': settings.extendedTimeouts,
    };
  }
  
  /// Dispose resources
  Future<void> dispose() async {
    await _settingsController.close();
    _isInitialized = false;
    _logger.i('Voice Settings Service disposed');
  }
  
  /// Get settings validation report
  Map<String, dynamic> validateSettings() {
    final issues = <String>[];
    final warnings = <String>[];
    
    // Validate VAD settings
    if (_currentSettings.vadConfiguration.silenceTimeout < 500) {
      warnings.add('Silence timeout is very short, may cause frequent interruptions');
    }
    
    if (_currentSettings.vadConfiguration.maxRecordingDuration > 300000) { // 5 minutes
      warnings.add('Maximum recording duration is very long');
    }
    
    // Validate audio settings
    if (_currentSettings.audioSettings.sampleRate < 8000) {
      issues.add('Sample rate is too low for good quality speech recognition');
    }
    
    // Validate speaker settings
    if (_currentSettings.speakerSettings.maxSpeakers > 50) {
      warnings.add('Large number of speakers may impact performance');
    }
    
    return {
      'is_valid': issues.isEmpty,
      'issues': issues,
      'warnings': warnings,
    };
  }
}