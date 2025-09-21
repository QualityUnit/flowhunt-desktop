import 'dart:async';
import 'dart:math';
import 'package:logger/logger.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/vad_state.dart';

/// Service responsible for Voice Activity Detection (VAD)
class VoiceActivityDetector {
  final Logger _logger = Logger();
  // Audio recording disabled - record package not available
  final SpeechToText _speechToText = SpeechToText();
  
  /// Stream controller for VAD results
  final StreamController<VadResult> _vadResultController = StreamController<VadResult>.broadcast();
  
  /// Stream controller for VAD events
  final StreamController<VadEvent> _vadEventController = StreamController<VadEvent>.broadcast();
  
  /// Current VAD configuration
  VadConfiguration _config = const VadConfiguration();
  
  /// Current VAD state
  VadState _currentState = VadState.idle;
  
  /// Audio level history for noise calculation
  final List<double> _audioLevelHistory = [];
  static const int _historyLength = 50;
  
  /// Voice activity tracking
  int _voiceFrameCount = 0;
  int _silenceFrameCount = 0;
  DateTime? _voiceStartTime;
  DateTime? _silenceStartTime;
  
  /// Background noise level
  double _backgroundNoiseLevel = 0.0;
  
  /// Timers for various operations
  Timer? _vadTimer;
  Timer? _silenceTimer;
  Timer? _maxDurationTimer;
  
  /// Recording state
  bool _isRecording = false;
  bool _isInitialized = false;
  
  /// Get VAD results stream
  Stream<VadResult> get vadResultStream => _vadResultController.stream;
  
  /// Get VAD events stream
  Stream<VadEvent> get vadEventStream => _vadEventController.stream;
  
  /// Get current configuration
  VadConfiguration get configuration => _config;
  
  /// Get current state
  VadState get currentState => _currentState;
  
  /// Check if VAD is active
  bool get isActive => _currentState != VadState.idle && _currentState != VadState.error;
  
  /// Initialize VAD system
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _logger.i('Initializing Voice Activity Detector...');
      
      // Initialize speech recognition for wake word detection
      if (_config.wakeWordEnabled) {
        final isAvailable = await _speechToText.initialize(
          onError: _onSpeechError,
          onStatus: _onSpeechStatus,
        );
        
        if (!isAvailable) {
          _logger.w('Speech recognition not available for wake word detection');
        }
      }
      
      // Note: Audio recording disabled - record package not available
      _logger.w('Audio recording disabled - record package not available');
      
      _isInitialized = true;
      _logger.i('Voice Activity Detector initialized successfully');
    } catch (e) {
      _logger.e('Failed to initialize VAD: $e');
      rethrow;
    }
  }
  
  /// Start Voice Activity Detection
  Future<void> start() async {
    if (!_isInitialized) {
      throw Exception('VAD not initialized');
    }
    
    if (!_config.enabled) {
      _logger.w('VAD is disabled in configuration');
      return;
    }
    
    if (_config.pushToTalkMode) {
      _logger.i('VAD in push-to-talk mode, manual activation required');
      _setState(VadState.idle);
      return;
    }
    
    try {
      _logger.i('Starting Voice Activity Detection...');
      _setState(VadState.listening);
      
      // Start background listening for voice activity
      await _startBackgroundListening();
      
      // Start VAD processing timer
      _vadTimer = Timer.periodic(const Duration(milliseconds: 100), _processVadFrame);
      
      _emitEvent(VadEventType.voiceStarted);
    } catch (e) {
      _logger.e('Failed to start VAD: $e');
      _setState(VadState.error);
      _emitEvent(VadEventType.error, {'error': e.toString()});
    }
  }
  
  /// Stop Voice Activity Detection
  Future<void> stop() async {
    try {
      _logger.i('Stopping Voice Activity Detection...');
      
      // Cancel all timers
      _vadTimer?.cancel();
      _silenceTimer?.cancel();
      _maxDurationTimer?.cancel();
      
      // Stop recording if active
      if (_isRecording) {
        await _stopRecording();
      }
      
      // Stop speech recognition
      if (_speechToText.isListening) {
        await _speechToText.stop();
      }
      
      _setState(VadState.idle);
      _emitEvent(VadEventType.voiceStopped);
    } catch (e) {
      _logger.e('Error stopping VAD: $e');
    }
  }
  
  /// Update VAD configuration
  void updateConfiguration(VadConfiguration config) {
    _config = config;
    _logger.i('Updated VAD configuration');
    
    // Restart if configuration changed significantly
    if (isActive && !config.enabled) {
      stop();
    } else if (!isActive && config.enabled) {
      start();
    }
  }
  
  /// Manually trigger recording (for push-to-talk mode)
  Future<void> startManualRecording() async {
    if (_config.pushToTalkMode) {
      await _startRecording();
    } else {
      _logger.w('Manual recording only available in push-to-talk mode');
    }
  }
  
  /// Manually stop recording (for push-to-talk mode)
  Future<void> stopManualRecording() async {
    if (_config.pushToTalkMode && _isRecording) {
      await _stopRecording();
    }
  }
  
  /// Start background listening for voice activity
  Future<void> _startBackgroundListening() async {
    try {
      // Note: Audio recording disabled - record package not available
      _logger.w('Audio recording disabled - record package not available');
      
      // Start wake word detection if enabled
      if (_config.wakeWordEnabled && _speechToText.isAvailable) {
        await _speechToText.listen(
          onResult: _onWakeWordResult,
          listenFor: const Duration(hours: 24), // Continuous listening
          pauseFor: Duration(milliseconds: _config.silenceTimeout),
          onSoundLevelChange: _onSoundLevelChange,
          listenOptions: SpeechListenOptions(
            partialResults: true,
            cancelOnError: false,
            listenMode: ListenMode.search,
          ),
        );
      }
      
      _logger.d('Background listening started');
    } catch (e) {
      _logger.e('Failed to start background listening: $e');
      rethrow;
    }
  }
  
  /// Process VAD frame
  void _processVadFrame(Timer timer) {
    try {
      // Simulate audio level for now (in real implementation, this would come from actual audio processing)
      final audioLevel = _generateSimulatedAudioLevel();
      
      // Update background noise level
      _updateBackgroundNoise(audioLevel);
      
      // Calculate energy level
      final energyLevel = _calculateEnergyLevel(audioLevel);
      
      // Determine if voice is active
      final isVoiceActive = _isVoiceDetected(audioLevel, energyLevel);
      
      // Update voice/silence tracking
      _updateVoiceTracking(isVoiceActive);
      
      // Calculate confidence
      final confidence = _calculateConfidence(audioLevel, energyLevel);
      
      // Create VAD result
      final vadResult = VadResult(
        state: _currentState,
        isVoiceActive: isVoiceActive,
        audioLevel: audioLevel,
        energyLevel: energyLevel,
        noiseLevel: _backgroundNoiseLevel,
        voiceDuration: _getVoiceDuration(),
        silenceDuration: _getSilenceDuration(),
        confidence: confidence,
      );
      
      // Emit result
      _vadResultController.add(vadResult);
      
      // Process state transitions
      _processStateTransitions(vadResult);
      
    } catch (e) {
      _logger.e('Error processing VAD frame: $e');
    }
  }
  
  /// Generate simulated audio level (replace with real audio processing)
  double _generateSimulatedAudioLevel() {
    final random = Random();
    
    // Simulate varying audio levels
    if (_currentState == VadState.recording) {
      return 0.3 + random.nextDouble() * 0.4; // Higher levels during recording
    } else {
      return random.nextDouble() * 0.2; // Lower background levels
    }
  }
  
  /// Update background noise level
  void _updateBackgroundNoise(double audioLevel) {
    _audioLevelHistory.add(audioLevel);
    
    if (_audioLevelHistory.length > _historyLength) {
      _audioLevelHistory.removeAt(0);
    }
    
    if (_audioLevelHistory.isNotEmpty) {
      _backgroundNoiseLevel = _audioLevelHistory.reduce((a, b) => a + b) / _audioLevelHistory.length;
    }
  }
  
  /// Calculate energy level from audio level
  double _calculateEnergyLevel(double audioLevel) {
    // Apply noise reduction
    final reducedLevel = audioLevel - (_backgroundNoiseLevel * _config.noiseReduction);
    return reducedLevel.clamp(0.0, 1.0);
  }
  
  /// Determine if voice is detected
  bool _isVoiceDetected(double audioLevel, double energyLevel) {
    return energyLevel > _config.energyThreshold && 
           audioLevel > _config.voiceThreshold;
  }
  
  /// Update voice/silence tracking
  void _updateVoiceTracking(bool isVoiceActive) {
    if (isVoiceActive) {
      _voiceFrameCount++;
      _silenceFrameCount = 0;
      
      _voiceStartTime ??= DateTime.now();
      _silenceStartTime = null;
    } else {
      _silenceFrameCount++;
      _voiceFrameCount = 0;
      
      _silenceStartTime ??= DateTime.now();
    }
  }
  
  /// Calculate confidence score
  double _calculateConfidence(double audioLevel, double energyLevel) {
    final signalToNoise = _backgroundNoiseLevel > 0 
        ? audioLevel / _backgroundNoiseLevel 
        : audioLevel;
    
    final energyConfidence = energyLevel / _config.energyThreshold;
    final snrConfidence = (signalToNoise - 1.0).clamp(0.0, 1.0);
    
    return ((energyConfidence + snrConfidence) / 2.0).clamp(0.0, 1.0);
  }
  
  /// Get current voice duration
  int _getVoiceDuration() {
    if (_voiceStartTime == null) return 0;
    return DateTime.now().difference(_voiceStartTime!).inMilliseconds;
  }
  
  /// Get current silence duration
  int _getSilenceDuration() {
    if (_silenceStartTime == null) return 0;
    return DateTime.now().difference(_silenceStartTime!).inMilliseconds;
  }
  
  /// Process state transitions based on VAD result
  void _processStateTransitions(VadResult result) {
    switch (_currentState) {
      case VadState.listening:
        if (result.isVoiceActive && _voiceFrameCount >= _config.voiceConfirmationFrames) {
          _setState(VadState.voiceDetected);
        }
        break;
        
      case VadState.voiceDetected:
        if (_getVoiceDuration() >= _config.minVoiceDuration && _config.autoStartRecording) {
          _startRecording();
        } else if (!result.isVoiceActive && _silenceFrameCount >= _config.silenceConfirmationFrames) {
          _setState(VadState.listening);
        }
        break;
        
      case VadState.recording:
        if (!result.isVoiceActive && _silenceFrameCount >= _config.silenceConfirmationFrames) {
          _setState(VadState.waitingForSilence);
          _startSilenceTimer();
        }
        break;
        
      case VadState.waitingForSilence:
        if (result.isVoiceActive) {
          _setState(VadState.recording);
          _silenceTimer?.cancel();
        }
        break;
        
      default:
        break;
    }
  }
  
  /// Start recording
  Future<void> _startRecording() async {
    try {
      _logger.i('Starting voice recording...');
      _setState(VadState.recording);
      _isRecording = true;
      
      // Start maximum duration timer
      _maxDurationTimer = Timer(Duration(milliseconds: _config.maxRecordingDuration), () {
        _logger.i('Maximum recording duration reached');
        _stopRecording();
      });
      
      _emitEvent(VadEventType.recordingStarted);
    } catch (e) {
      _logger.e('Failed to start recording: $e');
      _setState(VadState.error);
    }
  }
  
  /// Stop recording
  Future<void> _stopRecording() async {
    try {
      _logger.i('Stopping voice recording...');
      _isRecording = false;
      _maxDurationTimer?.cancel();
      
      _setState(VadState.processing);
      
      // Simulate processing delay
      Timer(const Duration(milliseconds: 500), () {
        _setState(VadState.listening);
      });
      
      _emitEvent(VadEventType.recordingStopped);
    } catch (e) {
      _logger.e('Failed to stop recording: $e');
      _setState(VadState.error);
    }
  }
  
  /// Start silence timer
  void _startSilenceTimer() {
    _silenceTimer = Timer(Duration(milliseconds: _config.silenceTimeout), () {
      _logger.d('Silence timeout reached, stopping recording');
      _stopRecording();
    });
  }
  
  /// Set VAD state
  void _setState(VadState newState) {
    if (_currentState != newState) {
      _logger.d('VAD state changed: $_currentState -> $newState');
      _currentState = newState;
    }
  }
  
  /// Emit VAD event
  void _emitEvent(VadEventType type, [Map<String, dynamic>? data]) {
    final event = VadEvent(
      type: type,
      timestamp: DateTime.now(),
      data: data ?? {},
    );
    
    _vadEventController.add(event);
  }
  
  /// Handle wake word detection result
  void _onWakeWordResult(dynamic result) {
    if (result != null) {
      final recognizedWords = result.recognizedWords as String;
      
      if (recognizedWords.toLowerCase().contains(_config.wakeWord.toLowerCase())) {
        _logger.i('Wake word detected: $recognizedWords');
        _emitEvent(VadEventType.wakeWordDetected, {'wake_word': recognizedWords});
        
        if (_config.autoStartRecording) {
          _startRecording();
        }
      }
    }
  }
  
  /// Handle sound level changes
  void _onSoundLevelChange(double level) {
    // This is called by speech recognition for real audio levels
    final normalizedLevel = (level + 50) / 60;
    _updateBackgroundNoise(normalizedLevel.clamp(0.0, 1.0));
  }
  
  /// Handle speech recognition status
  void _onSpeechStatus(String status) {
    _logger.d('Speech status: $status');
  }
  
  /// Handle speech recognition error
  void _onSpeechError(dynamic error) {
    _logger.e('Speech error: $error');
  }
  
  /// Dispose VAD resources
  Future<void> dispose() async {
    await stop();
    await _vadResultController.close();
    await _vadEventController.close();
    // Note: Audio recording disabled - record package not available
    _isInitialized = false;
    _logger.i('VAD disposed');
  }
  
  /// Get VAD statistics
  Map<String, dynamic> getStatistics() {
    return {
      'current_state': _currentState.toString(),
      'is_active': isActive,
      'background_noise_level': _backgroundNoiseLevel,
      'voice_frame_count': _voiceFrameCount,
      'silence_frame_count': _silenceFrameCount,
      'is_recording': _isRecording,
      'config_enabled': _config.enabled,
      'wake_word_enabled': _config.wakeWordEnabled,
    };
  }
}