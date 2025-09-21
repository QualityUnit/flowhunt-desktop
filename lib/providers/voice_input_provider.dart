import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../core/voice/voice_input_state.dart';
import '../core/voice/voice_recorder_service_simple.dart';

/// Provider for the voice recorder service
final voiceRecorderServiceProvider = Provider<VoiceRecorderService>((ref) {
  final service = VoiceRecorderService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Notifier for managing voice input state
class VoiceInputNotifier extends StateNotifier<VoiceInputState> {
  final VoiceRecorderService _service;
  final Logger _logger = Logger();
  
  StreamSubscription<double>? _audioLevelSubscription;
  StreamSubscription<String>? _transcriptionSubscription;
  Timer? _recordingDurationTimer;

  VoiceInputNotifier(this._service) : super(const VoiceInputState()) {
    _initialize();
  }

  /// Initialize the voice input system
  Future<void> _initialize() async {
    try {
      state = state.copyWith(status: VoiceInputStatus.initializing);
      
      // Initialize the service
      await _service.initialize();
      
      // Check permission
      final hasPermission = await _service.hasPermission();
      
      // Get available engines
      final availableEngines = _service.getAvailableEngines();
      
      state = state.copyWith(
        status: VoiceInputStatus.idle,
        isInitialized: true,
        hasPermission: hasPermission,
        availableEngines: availableEngines,
        currentEngine: availableEngines.isNotEmpty 
            ? availableEngines.first 
            : SpeechEngine.osNative,
      );
      
      _logger.i('Voice input initialized. Engines available: $availableEngines');
    } catch (e) {
      _logger.e('Failed to initialize voice input: $e');
      state = state.copyWith(
        status: VoiceInputStatus.error,
        error: VoiceInputError(
          message: 'Failed to initialize voice input: ${e.toString()}',
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

  /// Start voice recording
  Future<void> startRecording({String? locale}) async {
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
      
      // Subscribe to audio level and transcription streams
      _subscribeToStreams();
      
      // Start recording timer
      _startRecordingTimer();
      
      // Start the actual recording
      await _service.startRecording(
        engine: state.currentEngine,
        locale: locale,
      );
      
      _logger.i('Recording started');
    } catch (e) {
      _logger.e('Failed to start recording: $e');
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
        
        _logger.i('Recording completed: ${recordingFile.filename}');
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
      _logger.e('Failed to stop recording: $e');
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
      
      _logger.i('Recording cancelled');
    } catch (e) {
      _logger.e('Failed to cancel recording: $e');
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

  /// Change the current speech engine
  void changeEngine(SpeechEngine engine) {
    if (!state.availableEngines.contains(engine)) {
      _logger.w('Engine not available: $engine');
      return;
    }
    
    if (state.isRecording) {
      _logger.w('Cannot change engine while recording');
      return;
    }
    
    state = state.copyWith(currentEngine: engine);
    _logger.i('Changed speech engine to: $engine');
  }

  /// Delete a saved recording file
  Future<void> deleteRecording(String recordingId) async {
    try {
      // TODO: Delete actual files from disk
      // final file = state.savedFiles.firstWhere((f) => f.id == recordingId);
      // final audioFile = File(file.audioPath);
      // final textFile = File(file.textPath);
      // if (await audioFile.exists()) await audioFile.delete();
      // if (await textFile.exists()) await textFile.delete();
      
      final updatedFiles = state.savedFiles.where((f) => f.id != recordingId).toList();
      state = state.copyWith(savedFiles: updatedFiles);
      
      _logger.i('Deleted recording: $recordingId');
    } catch (e) {
      _logger.e('Failed to delete recording: $e');
      state = state.copyWith(
        error: VoiceInputError(
          message: 'Failed to delete recording: ${e.toString()}',
          type: VoiceInputErrorType.fileSystemError,
        ),
      );
    }
  }

  /// Clear all saved recordings
  Future<void> clearAllRecordings() async {
    try {
      // TODO: Delete actual files from disk
      
      state = state.copyWith(savedFiles: []);
      _logger.i('Cleared all recordings');
    } catch (e) {
      _logger.e('Failed to clear recordings: $e');
      state = state.copyWith(
        error: VoiceInputError(
          message: 'Failed to clear recordings: ${e.toString()}',
          type: VoiceInputErrorType.fileSystemError,
        ),
      );
    }
  }

  /// Subscribe to service streams
  void _subscribeToStreams() {
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
  }

  /// Unsubscribe from service streams
  void _unsubscribeFromStreams() {
    _audioLevelSubscription?.cancel();
    _transcriptionSubscription?.cancel();
    _audioLevelSubscription = null;
    _transcriptionSubscription = null;
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

  @override
  void dispose() {
    _stopRecordingTimer();
    _unsubscribeFromStreams();
    super.dispose();
  }
}

/// Provider for voice input state
final voiceInputProvider = StateNotifierProvider<VoiceInputNotifier, VoiceInputState>((ref) {
  final service = ref.watch(voiceRecorderServiceProvider);
  return VoiceInputNotifier(service);
});

/// Convenience providers for specific state values
final hasVoicePermissionProvider = Provider<bool>((ref) {
  return ref.watch(voiceInputProvider.select((state) => state.hasPermission));
});

final isVoiceRecordingProvider = Provider<bool>((ref) {
  return ref.watch(voiceInputProvider.select((state) => state.isRecording));
});

final voiceTranscriptionProvider = Provider<String>((ref) {
  return ref.watch(voiceInputProvider.select((state) => state.transcription));
});

final voiceAudioLevelProvider = Provider<double>((ref) {
  return ref.watch(voiceInputProvider.select((state) => state.audioLevel));
});

final voiceRecordingDurationProvider = Provider<Duration>((ref) {
  return ref.watch(voiceInputProvider.select((state) => state.recordingDuration));
});

final canStartVoiceRecordingProvider = Provider<bool>((ref) {
  return ref.watch(voiceInputProvider.select((state) => state.canStartRecording));
});