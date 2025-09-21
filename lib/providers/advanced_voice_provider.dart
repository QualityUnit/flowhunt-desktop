import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../core/voice/voice_input_state.dart';
import '../core/voice/advanced_voice_recorder_service.dart';
import '../core/voice/models/voice_command.dart';
import '../core/voice/models/speaker_profile.dart';
import '../core/voice/models/language_detection.dart';
import '../core/voice/models/vad_state.dart';
import '../core/voice/models/voice_settings.dart';

/// Provider for the advanced voice recorder service
final advancedVoiceRecorderServiceProvider = Provider<AdvancedVoiceRecorderService>((ref) {
  final service = AdvancedVoiceRecorderService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Enhanced state for advanced voice input
class AdvancedVoiceInputState extends VoiceInputState {
  /// Voice command matches
  final List<VoiceCommandMatch> recentCommands;
  
  /// Current speaker identification
  final SpeakerProfile? currentSpeaker;
  
  /// All identified speakers in session
  final List<SpeakerProfile> sessionSpeakers;
  
  /// Language detection results
  final LanguageDetectionResult? languageDetection;
  
  /// Current detected language
  final String currentLanguage;
  
  /// VAD state and results
  final VadState vadState;
  final VadResult? vadResult;
  
  /// Voice settings
  final VoiceSettings voiceSettings;
  
  /// Speaker identification confidence
  final double speakerConfidence;
  
  /// Command processing enabled
  final bool commandProcessingEnabled;
  
  /// Voice activity detection enabled
  final bool vadEnabled;

  const AdvancedVoiceInputState({
    // Base state properties
    super.status,
    super.hasPermission,
    super.isPermissionRequested,
    super.transcription,
    super.audioLevel,
    super.recordingDuration,
    super.error,
    super.savedFiles,
    super.currentEngine,
    super.availableEngines,
    super.isInitialized,
    
    // Advanced properties
    this.recentCommands = const [],
    this.currentSpeaker,
    this.sessionSpeakers = const [],
    this.languageDetection,
    this.currentLanguage = 'en',
    this.vadState = VadState.idle,
    this.vadResult,
    this.voiceSettings = const VoiceSettings(),
    this.speakerConfidence = 0.0,
    this.commandProcessingEnabled = true,
    this.vadEnabled = true,
  });

  @override
  AdvancedVoiceInputState copyWith({
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
    
    // Advanced properties
    List<VoiceCommandMatch>? recentCommands,
    SpeakerProfile? currentSpeaker,
    List<SpeakerProfile>? sessionSpeakers,
    LanguageDetectionResult? languageDetection,
    String? currentLanguage,
    VadState? vadState,
    VadResult? vadResult,
    VoiceSettings? voiceSettings,
    double? speakerConfidence,
    bool? commandProcessingEnabled,
    bool? vadEnabled,
  }) {
    return AdvancedVoiceInputState(
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
      
      recentCommands: recentCommands ?? this.recentCommands,
      currentSpeaker: currentSpeaker ?? this.currentSpeaker,
      sessionSpeakers: sessionSpeakers ?? this.sessionSpeakers,
      languageDetection: languageDetection ?? this.languageDetection,
      currentLanguage: currentLanguage ?? this.currentLanguage,
      vadState: vadState ?? this.vadState,
      vadResult: vadResult ?? this.vadResult,
      voiceSettings: voiceSettings ?? this.voiceSettings,
      speakerConfidence: speakerConfidence ?? this.speakerConfidence,
      commandProcessingEnabled: commandProcessingEnabled ?? this.commandProcessingEnabled,
      vadEnabled: vadEnabled ?? this.vadEnabled,
    );
  }

  @override
  List<Object?> get props => [
        ...super.props,
        recentCommands,
        currentSpeaker,
        sessionSpeakers,
        languageDetection,
        currentLanguage,
        vadState,
        vadResult,
        voiceSettings,
        speakerConfidence,
        commandProcessingEnabled,
        vadEnabled,
      ];
}

/// Advanced notifier for managing voice input state with enhanced features
class AdvancedVoiceInputNotifier extends StateNotifier<AdvancedVoiceInputState> {
  final AdvancedVoiceRecorderService _service;
  final Logger _logger = Logger();
  
  // Stream subscriptions
  StreamSubscription<double>? _audioLevelSubscription;
  StreamSubscription<String>? _transcriptionSubscription;
  StreamSubscription<VoiceCommandMatch>? _commandSubscription;
  StreamSubscription<SpeakerIdentificationResult>? _speakerSubscription;
  StreamSubscription<LanguageDetectionResult>? _languageSubscription;
  StreamSubscription<VadResult>? _vadSubscription;
  
  Timer? _recordingDurationTimer;

  AdvancedVoiceInputNotifier(this._service) : super(const AdvancedVoiceInputState()) {
    _initialize();
  }

  /// Initialize the advanced voice input system
  Future<void> _initialize() async {
    try {
      state = state.copyWith(status: VoiceInputStatus.initializing);
      
      // Initialize the service
      await _service.initialize();
      
      // Check permission
      final hasPermission = await _service.hasPermission();
      
      // Get available engines
      final availableEngines = _service.getAvailableEngines();
      
      // Get current settings
      final settings = _service.getSettings();
      
      state = state.copyWith(
        status: VoiceInputStatus.idle,
        isInitialized: true,
        hasPermission: hasPermission,
        availableEngines: availableEngines,
        currentEngine: availableEngines.isNotEmpty 
            ? availableEngines.first 
            : SpeechEngine.osNative,
        voiceSettings: settings,
        currentLanguage: settings.languagePreferences.primaryLanguage,
        commandProcessingEnabled: settings.commandSettings.enabled,
        vadEnabled: settings.vadConfiguration.enabled,
      );
      
      // Start VAD if enabled
      if (settings.vadConfiguration.enabled) {
        await _service.startVAD();
      }
      
      _logger.i('Advanced voice input initialized. Engines available: $availableEngines');
    } catch (e) {
      _logger.e('Failed to initialize advanced voice input: $e');
      state = state.copyWith(
        status: VoiceInputStatus.error,
        error: VoiceInputError(
          message: 'Failed to initialize advanced voice input: ${e.toString()}',
          type: VoiceInputErrorType.processingError,
        ),
      );
    }
  }

  /// Request microphone permission
  Future<void> requestPermission() async {
    if (state.hasPermission) return;
    
    try {
      state = state.copyWith(isPermissionRequested: true);
      
      final granted = await _service.requestPermission();
      
      state = state.copyWith(
        hasPermission: granted,
        isPermissionRequested: true,
        error: granted ? null : const VoiceInputError(
          message: 'Microphone permission is required for voice input',
          type: VoiceInputErrorType.permissionDenied,
        ),
      );
      
      if (granted) {
        _logger.i('Microphone permission granted');
      } else {
        _logger.w('Microphone permission denied');
      }
    } catch (e) {
      _logger.e('Error requesting permission: $e');
      state = state.copyWith(
        hasPermission: false,
        error: VoiceInputError(
          message: 'Error requesting microphone permission: ${e.toString()}',
          type: VoiceInputErrorType.permissionDenied,
        ),
      );
    }
  }

  /// Start voice recording with advanced features
  Future<void> startRecording({
    String? locale,
    bool enableCommands = true,
    bool enableSpeakerIdentification = true,
    bool enableLanguageDetection = true,
  }) async {
    if (!state.canStartRecording) {
      if (!state.hasPermission) {
        await requestPermission();
        if (!state.hasPermission) return;
      }
      
      if (!state.canStartRecording) {
        _logger.w('Cannot start recording. State: ${state.status}');
        return;
      }
    }
    
    try {
      state = state.copyWith(
        status: VoiceInputStatus.listening,
        clearError: true,
        clearTranscription: true,
        recordingDuration: Duration.zero,
      );
      
      // Subscribe to all streams
      _subscribeToStreams();
      
      // Start recording timer
      _startRecordingTimer();
      
      // Start the actual recording with advanced features
      await _service.startRecording(
        engine: state.currentEngine,
        locale: locale ?? state.currentLanguage,
        enableCommands: enableCommands,
        enableSpeakerIdentification: enableSpeakerIdentification,
        enableLanguageDetection: enableLanguageDetection,
      );
      
      _logger.i('Advanced recording started');
    } catch (e) {
      _logger.e('Failed to start advanced recording: $e');
      state = state.copyWith(
        status: VoiceInputStatus.error,
        error: VoiceInputError(
          message: 'Failed to start recording: ${e.toString()}',
          type: VoiceInputErrorType.processingError,
        ),
      );
      _unsubscribeFromStreams();
    }
  }

  /// Stop voice recording
  Future<void> stopRecording() async {
    if (!state.isRecording) return;
    
    try {
      state = state.copyWith(status: VoiceInputStatus.processing);
      
      // Stop recording and get the result
      final recordingFile = await _service.stopRecording();
      
      if (recordingFile != null) {
        // Add to saved files
        final updatedFiles = [...state.savedFiles, recordingFile];
        
        state = state.copyWith(
          status: VoiceInputStatus.completed,
          savedFiles: updatedFiles,
          transcription: recordingFile.transcription,
        );
        
        _logger.i('Advanced recording completed: ${recordingFile.filename}');
      } else {
        state = state.copyWith(
          status: VoiceInputStatus.error,
          error: const VoiceInputError(
            message: 'Failed to save recording',
            type: VoiceInputErrorType.fileSystemError,
          ),
        );
      }
    } catch (e) {
      _logger.e('Failed to stop advanced recording: $e');
      state = state.copyWith(
        status: VoiceInputStatus.error,
        error: VoiceInputError(
          message: 'Failed to stop recording: ${e.toString()}',
          type: VoiceInputErrorType.processingError,
        ),
      );
    } finally {
      _stopRecordingTimer();
      _unsubscribeFromStreams();
    }
  }

  /// Cancel current recording
  Future<void> cancelRecording() async {
    if (!state.isRecording) return;
    
    try {
      await _service.cancelRecording();
      
      state = state.copyWith(
        status: VoiceInputStatus.idle,
        clearTranscription: true,
        recordingDuration: Duration.zero,
        audioLevel: 0.0,
      );
      
      _logger.i('Advanced recording cancelled');
    } catch (e) {
      _logger.e('Failed to cancel advanced recording: $e');
      state = state.copyWith(
        status: VoiceInputStatus.error,
        error: VoiceInputError(
          message: 'Failed to cancel recording: ${e.toString()}',
          type: VoiceInputErrorType.processingError,
        ),
      );
    } finally {
      _stopRecordingTimer();
      _unsubscribeFromStreams();
    }
  }

  /// Register a new speaker
  Future<void> registerSpeaker(String name, String audioPath, String transcription) async {
    try {
      final speaker = await _service.registerSpeaker(name, audioPath, transcription);
      
      final updatedSpeakers = [...state.sessionSpeakers, speaker];
      state = state.copyWith(sessionSpeakers: updatedSpeakers);
      
      _logger.i('Registered new speaker: ${speaker.name}');
    } catch (e) {
      _logger.e('Failed to register speaker: $e');
      state = state.copyWith(
        error: VoiceInputError(
          message: 'Failed to register speaker: ${e.toString()}',
          type: VoiceInputErrorType.processingError,
        ),
      );
    }
  }

  /// Remove a speaker
  Future<void> removeSpeaker(String speakerId) async {
    try {
      await _service.removeSpeaker(speakerId);
      
      final updatedSpeakers = state.sessionSpeakers.where((s) => s.id != speakerId).toList();
      state = state.copyWith(sessionSpeakers: updatedSpeakers);
      
      if (state.currentSpeaker?.id == speakerId) {
        state = state.copyWith(currentSpeaker: null, speakerConfidence: 0.0);
      }
      
      _logger.i('Removed speaker: $speakerId');
    } catch (e) {
      _logger.e('Failed to remove speaker: $e');
    }
  }

  /// Update voice settings
  Future<void> updateSettings(VoiceSettings settings) async {
    try {
      await _service.updateSettings(settings);
      
      state = state.copyWith(
        voiceSettings: settings,
        currentLanguage: settings.languagePreferences.primaryLanguage,
        commandProcessingEnabled: settings.commandSettings.enabled,
        vadEnabled: settings.vadConfiguration.enabled,
      );
      
      _logger.i('Voice settings updated');
    } catch (e) {
      _logger.e('Failed to update voice settings: $e');
    }
  }

  /// Get voice command help
  String getCommandHelp() {
    return _service.getCommandHelp(language: state.currentLanguage);
  }

  /// Subscribe to service streams
  void _subscribeToStreams() {
    // Audio level stream
    _audioLevelSubscription = _service.audioLevelStream.listen(
      (level) {
        if (state.isRecording) {
          state = state.copyWith(audioLevel: level);
        }
      },
      onError: (error) {
        _logger.e('Audio level stream error: $error');
      },
    );
    
    // Transcription stream
    _transcriptionSubscription = _service.transcriptionStream.listen(
      (transcription) {
        if (state.isRecording) {
          state = state.copyWith(transcription: transcription);
        }
      },
      onError: (error) {
        _logger.e('Transcription stream error: $error');
      },
    );
    
    // Voice command stream
    _commandSubscription = _service.commandStream.listen(
      (command) {
        final updatedCommands = [...state.recentCommands, command];
        // Keep only last 10 commands
        if (updatedCommands.length > 10) {
          updatedCommands.removeAt(0);
        }
        
        state = state.copyWith(recentCommands: updatedCommands);
        _logger.d('Voice command detected: ${command.command.type}');
      },
      onError: (error) {
        _logger.e('Command stream error: $error');
      },
    );
    
    // Speaker identification stream
    _speakerSubscription = _service.speakerStream.listen(
      (result) {
        state = state.copyWith(
          currentSpeaker: result.identifiedSpeaker,
          speakerConfidence: result.confidence,
        );
        
        // Add new speakers to session list
        if (result.identifiedSpeaker != null) {
          final sessionSpeakers = [...state.sessionSpeakers];
          if (!sessionSpeakers.any((s) => s.id == result.identifiedSpeaker!.id)) {
            sessionSpeakers.add(result.identifiedSpeaker!);
            state = state.copyWith(sessionSpeakers: sessionSpeakers);
          }
        }
        
        _logger.d('Speaker identified: ${result.identifiedSpeaker?.name ?? 'Unknown'}');
      },
      onError: (error) {
        _logger.e('Speaker stream error: $error');
      },
    );
    
    // Language detection stream
    _languageSubscription = _service.languageStream.listen(
      (result) {
        state = state.copyWith(languageDetection: result);
        
        if (result.isSuccessful && result.primaryLanguage != null) {
          final detectedLanguage = result.primaryLanguage!.code;
          if (detectedLanguage != state.currentLanguage) {
            state = state.copyWith(currentLanguage: detectedLanguage);
            _logger.d('Language detected: $detectedLanguage');
          }
        }
      },
      onError: (error) {
        _logger.e('Language detection stream error: $error');
      },
    );
    
    // VAD stream
    _vadSubscription = _service.vadStream.listen(
      (result) {
        state = state.copyWith(
          vadState: result.state,
          vadResult: result,
        );
      },
      onError: (error) {
        _logger.e('VAD stream error: $error');
      },
    );
  }

  /// Unsubscribe from service streams
  void _unsubscribeFromStreams() {
    _audioLevelSubscription?.cancel();
    _transcriptionSubscription?.cancel();
    _commandSubscription?.cancel();
    _speakerSubscription?.cancel();
    _languageSubscription?.cancel();
    _vadSubscription?.cancel();
    
    _audioLevelSubscription = null;
    _transcriptionSubscription = null;
    _commandSubscription = null;
    _speakerSubscription = null;
    _languageSubscription = null;
    _vadSubscription = null;
  }

  /// Start recording duration timer
  void _startRecordingTimer() {
    _recordingDurationTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (state.isRecording) {
          final newDuration = Duration(seconds: timer.tick);
          state = state.copyWith(recordingDuration: newDuration);
        } else {
          timer.cancel();
        }
      },
    );
  }

  /// Stop recording duration timer
  void _stopRecordingTimer() {
    _recordingDurationTimer?.cancel();
    _recordingDurationTimer = null;
  }

  /// Reset to idle state
  void resetToIdle() {
    if (state.isRecording) {
      cancelRecording();
      return;
    }
    
    state = state.copyWith(
      status: VoiceInputStatus.idle,
      clearError: true,
      clearTranscription: true,
      recordingDuration: Duration.zero,
      audioLevel: 0.0,
    );
  }

  @override
  void dispose() {
    _stopRecordingTimer();
    _unsubscribeFromStreams();
    super.dispose();
  }
}

/// Provider for advanced voice input state
final advancedVoiceInputProvider = StateNotifierProvider<AdvancedVoiceInputNotifier, AdvancedVoiceInputState>((ref) {
  final service = ref.watch(advancedVoiceRecorderServiceProvider);
  return AdvancedVoiceInputNotifier(service);
});

/// Convenience providers for specific advanced state values
final currentSpeakerProvider = Provider<SpeakerProfile?>((ref) {
  return ref.watch(advancedVoiceInputProvider.select((state) => state.currentSpeaker));
});

final recentCommandsProvider = Provider<List<VoiceCommandMatch>>((ref) {
  return ref.watch(advancedVoiceInputProvider.select((state) => state.recentCommands));
});

final currentLanguageProvider = Provider<String>((ref) {
  return ref.watch(advancedVoiceInputProvider.select((state) => state.currentLanguage));
});

final vadStateProvider = Provider<VadState>((ref) {
  return ref.watch(advancedVoiceInputProvider.select((state) => state.vadState));
});

final voiceSettingsProvider = Provider<VoiceSettings>((ref) {
  return ref.watch(advancedVoiceInputProvider.select((state) => state.voiceSettings));
});

final sessionSpeakersProvider = Provider<List<SpeakerProfile>>((ref) {
  return ref.watch(advancedVoiceInputProvider.select((state) => state.sessionSpeakers));
});