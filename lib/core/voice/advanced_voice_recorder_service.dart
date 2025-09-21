import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:logger/logger.dart';

import 'voice_input_state.dart';
import 'models/voice_command.dart';
import 'models/speaker_profile.dart';
import 'models/language_detection.dart';
import 'models/vad_state.dart';
import 'models/voice_settings.dart';
import 'services/voice_command_processor.dart';
import 'services/speaker_identification_service.dart';
import 'services/whisper_language_detector.dart';
import 'services/voice_activity_detector.dart';
import 'services/voice_settings_service.dart';

/// Advanced voice recorder service with all enhanced features
class AdvancedVoiceRecorderService {
  final Logger _logger = Logger();
  final SpeechToText _speechToText = SpeechToText();
  // Audio recording disabled - record package not available
  
  // Advanced feature services
  final VoiceCommandProcessor _commandProcessor = VoiceCommandProcessor();
  final SpeakerIdentificationService _speakerService = SpeakerIdentificationService();
  final LanguageDetector _languageDetector = LanguageDetector();
  final VoiceActivityDetector _vadService = VoiceActivityDetector();
  final VoiceSettingsService _settingsService = VoiceSettingsService();
  
  // Stream controllers
  StreamController<double>? _audioLevelController;
  StreamController<String>? _transcriptionController;
  StreamController<VoiceCommandMatch>? _commandController;
  StreamController<SpeakerIdentificationResult>? _speakerController;
  StreamController<LanguageDetectionResult>? _languageController;
  StreamController<VadResult>? _vadController;
  
  // State management
  Timer? _recordingTimer;
  String? _currentRecordingPath;
  DateTime? _recordingStartTime;
  bool _isInitialized = false;
  bool _isRecording = false;
  String _currentLanguage = 'en';
  SpeakerProfile? _currentSpeaker;
  
  // Subscription management
  StreamSubscription? _vadSubscription;
  StreamSubscription? _settingsSubscription;
  
  // Stream getters
  Stream<double> get audioLevelStream => 
      _audioLevelController?.stream ?? const Stream.empty();
  Stream<String> get transcriptionStream => 
      _transcriptionController?.stream ?? const Stream.empty();
  Stream<VoiceCommandMatch> get commandStream =>
      _commandController?.stream ?? const Stream.empty();
  Stream<SpeakerIdentificationResult> get speakerStream =>
      _speakerController?.stream ?? const Stream.empty();
  Stream<LanguageDetectionResult> get languageStream =>
      _languageController?.stream ?? const Stream.empty();
  Stream<VadResult> get vadStream =>
      _vadController?.stream ?? const Stream.empty();

  /// Initialize the advanced voice recorder service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _logger.i('Initializing Advanced Voice Recorder Service...');
      
      // Initialize settings service first
      await _settingsService.initialize();
      
      // Initialize speech to text
      final isAvailable = await _speechToText.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
        debugLogging: true,
      );
      
      if (!isAvailable) {
        _logger.w('Speech to text not available');
      }
      
      // Initialize stream controllers
      _audioLevelController = StreamController<double>.broadcast();
      _transcriptionController = StreamController<String>.broadcast();
      _commandController = StreamController<VoiceCommandMatch>.broadcast();
      _speakerController = StreamController<SpeakerIdentificationResult>.broadcast();
      _languageController = StreamController<LanguageDetectionResult>.broadcast();
      _vadController = StreamController<VadResult>.broadcast();
      
      // Initialize advanced services
      await _vadService.initialize();
      await _speakerService.loadSpeakerProfiles();
      
      // Setup language preferences
      _languageDetector.updatePreferences(_settingsService.currentSettings.languagePreferences);
      _currentLanguage = _settingsService.currentSettings.languagePreferences.primaryLanguage;
      _commandProcessor.setLanguage(_currentLanguage);
      
      // Setup VAD configuration
      _vadService.updateConfiguration(_settingsService.currentSettings.vadConfiguration);
      
      // Subscribe to streams
      _setupStreamSubscriptions();
      
      _isInitialized = true;
      _logger.i('Advanced Voice Recorder Service initialized successfully');
    } catch (e) {
      _logger.e('Failed to initialize Advanced Voice Recorder Service: $e');
      rethrow;
    }
  }

  /// Setup stream subscriptions for advanced features
  void _setupStreamSubscriptions() {
    // Subscribe to VAD results
    _vadSubscription = _vadService.vadResultStream.listen(
      (vadResult) {
        _vadController?.add(vadResult);
        
        // Auto-start/stop recording based on VAD
        _handleVadResult(vadResult);
      },
      onError: (error) {
        _logger.e('VAD stream error: $error');
      },
    );
    
    // Subscribe to settings changes
    _settingsSubscription = _settingsService.settingsStream.listen(
      (settings) {
        _updateFromSettings(settings);
      },
      onError: (error) {
        _logger.e('Settings stream error: $error');
      },
    );
  }

  /// Handle VAD results for automatic recording control
  void _handleVadResult(VadResult vadResult) {
    final settings = _settingsService.currentSettings;
    
    if (!settings.vadConfiguration.enabled || settings.vadConfiguration.pushToTalkMode) {
      return; // Manual mode only
    }
    
    switch (vadResult.state) {
      case VadState.voiceDetected:
        if (!_isRecording && settings.vadConfiguration.autoStartRecording) {
          _startRecordingFromVad();
        }
        break;
      case VadState.waitingForSilence:
        // Recording will be stopped by VAD service automatically
        break;
      default:
        break;
    }
  }

  /// Update service configuration from settings
  void _updateFromSettings(VoiceSettings settings) {
    // Update language settings
    _languageDetector.updatePreferences(settings.languagePreferences);
    if (_currentLanguage != settings.languagePreferences.primaryLanguage) {
      _currentLanguage = settings.languagePreferences.primaryLanguage;
      _commandProcessor.setLanguage(_currentLanguage);
    }
    
    // Update VAD configuration
    _vadService.updateConfiguration(settings.vadConfiguration);
    
    // Update command processor recording state
    _commandProcessor.setRecordingState(_isRecording);
    
    _logger.d('Service updated from settings changes');
  }

  /// Check and request microphone permission
  Future<bool> requestPermission() async {
    try {
      final status = await Permission.microphone.status;
      
      if (status.isGranted) {
        return true;
      }
      
      if (status.isDenied) {
        final result = await Permission.microphone.request();
        return result.isGranted;
      }
      
      if (status.isPermanentlyDenied) {
        await openAppSettings();
        return false;
      }
      
      return false;
    } catch (e) {
      _logger.e('Error requesting microphone permission: $e');
      return false;
    }
  }

  /// Check if microphone permission is granted
  Future<bool> hasPermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// Get available speech recognition engines
  List<SpeechEngine> getAvailableEngines() {
    final engines = <SpeechEngine>[];
    
    if (_speechToText.isAvailable) {
      engines.add(SpeechEngine.osNative);
    }
    
    return engines;
  }

  /// Start recording with advanced features
  Future<void> startRecording({
    SpeechEngine engine = SpeechEngine.osNative,
    String? locale,
    bool enableCommands = true,
    bool enableSpeakerIdentification = true,
    bool enableLanguageDetection = true,
  }) async {
    if (!_isInitialized) {
      throw Exception('Service not initialized');
    }
    
    if (_isRecording) {
      throw Exception('Already recording');
    }
    
    try {
      _logger.i('Starting advanced recording with engine: $engine');
      
      // Create recording directory and file
      final directory = await _getRecordingDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'recording_$timestamp';
      _currentRecordingPath = path.join(directory.path, '$filename.wav');
      
      // Start audio recording
      // Note: Audio recording disabled - record package not available
      _logger.w('Audio recording disabled - record package not available');
      
      // Start speech recognition
      if (engine == SpeechEngine.osNative && _speechToText.isAvailable) {
        final speechLocale = locale ?? _languageDetector.getSpeechLocale(_currentLanguage);
        
        await _speechToText.listen(
          onResult: (result) => _onSpeechResult(result, enableCommands, enableLanguageDetection),
          listenFor: Duration(milliseconds: _settingsService.currentSettings.vadConfiguration.maxRecordingDuration),
          pauseFor: Duration(milliseconds: _settingsService.currentSettings.vadConfiguration.silenceTimeout),
          localeId: speechLocale,
          onSoundLevelChange: _onSoundLevelChange,
          listenOptions: SpeechListenOptions(
            partialResults: true,
            cancelOnError: false,
            listenMode: ListenMode.confirmation,
          ),
        );
      }
      
      // Update command processor state
      _commandProcessor.setRecordingState(true);
      
      // Start timers and tracking
      _recordingStartTime = DateTime.now();
      _startRecordingTimer();
      
      _isRecording = true;
      _logger.i('Advanced recording started successfully');
    } catch (e) {
      _logger.e('Failed to start advanced recording: $e');
      await _cleanup();
      rethrow;
    }
  }

  /// Start recording triggered by VAD
  Future<void> _startRecordingFromVad() async {
    try {
      await startRecording(
        enableCommands: _settingsService.currentSettings.commandSettings.enabled,
        enableSpeakerIdentification: _settingsService.currentSettings.speakerSettings.enabled,
        enableLanguageDetection: _settingsService.currentSettings.languagePreferences.autoDetectionEnabled,
      );
    } catch (e) {
      _logger.e('Failed to start recording from VAD: $e');
    }
  }

  /// Process voice commands from transcription
  Future<void> processVoiceCommand(String transcription) async {
    if (!_settingsService.currentSettings.commandSettings.enabled) {
      return;
    }
    
    try {
      final match = _commandProcessor.processCommand(transcription);
      if (match != null) {
        _commandController?.add(match);
        
        // Execute command if confidence is high enough
        if (match.confidence >= _settingsService.currentSettings.commandSettings.minCommandConfidence) {
          await _executeVoiceCommand(match);
        }
      }
    } catch (e) {
      _logger.e('Error processing voice command: $e');
    }
  }

  /// Execute voice command
  Future<void> _executeVoiceCommand(VoiceCommandMatch match) async {
    try {
      _logger.i('Executing voice command: ${match.command.type}');
      
      switch (match.command.type) {
        case VoiceCommandType.stopRecording:
          if (_isRecording) {
            await stopRecording();
          }
          break;
        case VoiceCommandType.cancelRecording:
          if (_isRecording) {
            await cancelRecording();
          }
          break;
        case VoiceCommandType.startRecording:
          if (!_isRecording) {
            await startRecording();
          }
          break;
        default:
          // Other commands would be handled by the UI layer
          _logger.d('Command ${match.command.type} forwarded to UI layer');
          break;
      }
    } catch (e) {
      _logger.e('Error executing voice command: $e');
    }
  }

  /// Identify speaker from current recording
  Future<void> _identifySpeaker(String audioPath, String transcription) async {
    if (!_settingsService.currentSettings.speakerSettings.enabled) {
      return;
    }
    
    try {
      // Extract voice characteristics
      final characteristics = await _speakerService.extractCharacteristics(audioPath, transcription);
      
      // Identify speaker
      final result = await _speakerService.identifySpeaker(characteristics, audioReference: audioPath);
      
      _speakerController?.add(result);
      
      // Update current speaker
      _currentSpeaker = result.identifiedSpeaker;
      
      // Auto-register new speaker if enabled
      if (result.isUnknownSpeaker && _settingsService.currentSettings.speakerSettings.autoRegisterNewSpeakers) {
        final newSpeaker = await _speakerService.registerSpeaker(
          'Unknown Speaker ${DateTime.now().millisecondsSinceEpoch}',
          characteristics,
        );
        _currentSpeaker = newSpeaker;
        _logger.i('Auto-registered new speaker: ${newSpeaker.name}');
      }
    } catch (e) {
      _logger.e('Error identifying speaker: $e');
    }
  }

  /// Detect language from transcription
  Future<void> _detectLanguage(String transcription) async {
    if (!_settingsService.currentSettings.languagePreferences.autoDetectionEnabled) {
      return;
    }
    
    try {
      final result = await _languageDetector.detectLanguage(transcription);
      _languageController?.add(result);
      
      if (result.isSuccessful) {
        final bestLanguage = _languageDetector.getBestLanguage(result);
        
        if (bestLanguage != _currentLanguage) {
          _currentLanguage = bestLanguage;
          _commandProcessor.setLanguage(_currentLanguage);
          _logger.i('Switched to detected language: $bestLanguage');
        }
      }
    } catch (e) {
      _logger.e('Error detecting language: $e');
    }
  }

  /// Stop recording and return the enhanced result
  Future<RecordingFile?> stopRecording() async {
    if (!_isRecording) {
      return null;
    }
    
    try {
      _logger.i('Stopping advanced recording...');
      
      // Stop timers
      _recordingTimer?.cancel();
      
      // Stop speech recognition
      if (_speechToText.isListening) {
        await _speechToText.stop();
      }
      
      // Stop audio recording
      // Note: Audio recording disabled - record package not available
      final audioPath = _currentRecordingPath;
      
      // Update command processor state
      _commandProcessor.setRecordingState(false);
      
      _isRecording = false;
      
      if (audioPath == null || _currentRecordingPath == null) {
        _logger.w('No recording path available');
        return null;
      }
      
      // Calculate duration
      final duration = _recordingStartTime != null 
          ? DateTime.now().difference(_recordingStartTime!)
          : Duration.zero;
      
      // Get final transcription
      final transcription = _getLastTranscription();
      
      // Perform advanced analysis
      await Future.wait([
        _identifySpeaker(audioPath, transcription),
        _detectLanguage(transcription),
      ]);
      
      // Save transcription to file
      final textPath = await _saveTranscription(audioPath, transcription);
      
      // Create enhanced recording file object
      final recordingFile = RecordingFile(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        audioPath: audioPath,
        textPath: textPath,
        filename: path.basenameWithoutExtension(audioPath),
        createdAt: _recordingStartTime ?? DateTime.now(),
        duration: duration,
        transcription: transcription,
        engine: SpeechEngine.osNative,
      );
      
      _logger.i('Advanced recording completed. Duration: ${duration.inSeconds}s');
      return recordingFile;
    } catch (e) {
      _logger.e('Failed to stop advanced recording: $e');
      rethrow;
    } finally {
      await _cleanup();
    }
  }

  /// Cancel current recording
  Future<void> cancelRecording() async {
    if (!_isRecording) {
      return;
    }
    
    try {
      _logger.i('Cancelling advanced recording...');
      
      // Stop everything
      _recordingTimer?.cancel();
      
      if (_speechToText.isListening) {
        await _speechToText.cancel();
      }
      
      // Note: Audio recording disabled - record package not available
      
      // Update command processor state
      _commandProcessor.setRecordingState(false);
      
      // Delete the recording file if it exists
      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
      
      _isRecording = false;
      _logger.i('Advanced recording cancelled successfully');
    } catch (e) {
      _logger.e('Failed to cancel advanced recording: $e');
    } finally {
      await _cleanup();
    }
  }

  /// Start Voice Activity Detection
  Future<void> startVAD() async {
    try {
      await _vadService.start();
      _logger.i('Voice Activity Detection started');
    } catch (e) {
      _logger.e('Failed to start VAD: $e');
      rethrow;
    }
  }

  /// Stop Voice Activity Detection
  Future<void> stopVAD() async {
    try {
      await _vadService.stop();
      _logger.i('Voice Activity Detection stopped');
    } catch (e) {
      _logger.e('Failed to stop VAD: $e');
    }
  }

  /// Register a new speaker manually
  Future<SpeakerProfile> registerSpeaker(String name, String audioPath, String transcription) async {
    try {
      final characteristics = await _speakerService.extractCharacteristics(audioPath, transcription);
      return await _speakerService.registerSpeaker(name, characteristics);
    } catch (e) {
      _logger.e('Failed to register speaker: $e');
      rethrow;
    }
  }

  /// Get all registered speakers
  List<SpeakerProfile> getSpeakers() {
    return _speakerService.speakers;
  }

  /// Remove a speaker
  Future<void> removeSpeaker(String speakerId) async {
    await _speakerService.removeSpeaker(speakerId);
  }

  /// Get current voice settings
  VoiceSettings getSettings() {
    return _settingsService.currentSettings;
  }

  /// Update voice settings
  Future<void> updateSettings(VoiceSettings settings) async {
    await _settingsService.updateSettings(settings);
  }

  /// Get voice command help
  String getCommandHelp({String? language}) {
    return _commandProcessor.getHelpText(language: language);
  }

  /// Get service statistics
  Map<String, dynamic> getStatistics() {
    return {
      'is_initialized': _isInitialized,
      'is_recording': _isRecording,
      'current_language': _currentLanguage,
      'current_speaker': _currentSpeaker?.name,
      'vad_stats': _vadService.getStatistics(),
      'speaker_stats': _speakerService.getSpeakerStatistics(),
      'available_engines': getAvailableEngines().map((e) => e.toString()).toList(),
    };
  }

  /// Handle speech recognition results with advanced processing
  void _onSpeechResult(dynamic result, bool enableCommands, bool enableLanguageDetection) {
    if (result != null) {
      final transcription = result.recognizedWords as String;
      _transcriptionController?.add(transcription);
      
      // Process voice commands
      if (enableCommands) {
        processVoiceCommand(transcription);
      }
      
      // Detect language if enabled
      if (enableLanguageDetection) {
        _detectLanguage(transcription);
      }
    }
  }

  /// Handle sound level changes
  void _onSoundLevelChange(double level) {
    final normalizedLevel = (level + 50) / 60;
    _audioLevelController?.add(normalizedLevel.clamp(0.0, 1.0));
  }

  /// Handle speech recognition status changes
  void _onSpeechStatus(String status) {
    _logger.d('Speech status: $status');
  }

  /// Handle speech recognition errors
  void _onSpeechError(dynamic error) {
    _logger.e('Speech error: $error');
  }

  /// Get the last transcription result
  String _getLastTranscription() {
    if (_speechToText.isAvailable) {
      return _speechToText.lastRecognizedWords;
    }
    return '';
  }

  /// Get recording directory
  Future<Directory> _getRecordingDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final recordingDir = Directory(path.join(appDir.path, 'FlowHunt', 'Voice', 'recordings'));
    
    if (!await recordingDir.exists()) {
      await recordingDir.create(recursive: true);
    }
    
    return recordingDir;
  }

  /// Save transcription to text file
  Future<String> _saveTranscription(String audioPath, String transcription) async {
    final audioFile = File(audioPath);
    final basename = path.basenameWithoutExtension(audioFile.path);
    final directory = audioFile.parent;
    final textPath = path.join(directory.path, '$basename.txt');
    
    final textFile = File(textPath);
    await textFile.writeAsString(transcription);
    
    return textPath;
  }

  /// Start recording timer
  void _startRecordingTimer() {
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Timer updates will be handled by the provider
    });
  }

  /// Cleanup resources
  Future<void> _cleanup() async {
    _recordingTimer?.cancel();
    _recordingStartTime = null;
    _currentRecordingPath = null;
    _currentSpeaker = null;
  }

  /// Dispose of the service
  Future<void> dispose() async {
    await _cleanup();
    await _vadSubscription?.cancel();
    await _settingsSubscription?.cancel();
    
    await _audioLevelController?.close();
    await _transcriptionController?.close();
    await _commandController?.close();
    await _speakerController?.close();
    await _languageController?.close();
    await _vadController?.close();
    
    await _vadService.dispose();
    await _settingsService.dispose();
    // Note: Audio recording disabled - record package not available
    
    _isInitialized = false;
    _logger.i('Advanced Voice Recorder Service disposed');
  }
}