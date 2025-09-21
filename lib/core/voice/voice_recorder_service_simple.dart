import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:logger/logger.dart';

import 'voice_input_state.dart';

/// Simplified service for speech-to-text without audio recording initially
class VoiceRecorderService {
  final SpeechToText _speechToText = SpeechToText();
  final Logger _logger = Logger();
  
  StreamController<double>? _audioLevelController;
  StreamController<String>? _transcriptionController;
  Timer? _audioLevelTimer;
  
  bool _isInitialized = false;
  bool _isListening = false;
  DateTime? _listeningStartTime;
  
  // Stream getters
  Stream<double> get audioLevelStream => 
      _audioLevelController?.stream ?? const Stream.empty();
  Stream<String> get transcriptionStream => 
      _transcriptionController?.stream ?? const Stream.empty();

  /// Initialize the voice recorder service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _logger.i('Initializing voice recorder service...');
      
      // Initialize speech to text
      final isAvailable = await _speechToText.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
        debugLogging: true,
      );
      
      if (!isAvailable) {
        _logger.w('Speech to text not available');
        throw Exception('Speech recognition not available on this device');
      }
      
      _audioLevelController = StreamController<double>.broadcast();
      _transcriptionController = StreamController<String>.broadcast();
      
      _isInitialized = true;
      _logger.i('Voice recorder service initialized successfully');
    } catch (e) {
      _logger.e('Failed to initialize voice recorder service: $e');
      rethrow;
    }
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
    
    // Check if OS native speech recognition is available
    if (_speechToText.isAvailable) {
      engines.add(SpeechEngine.osNative);
    }
    
    return engines;
  }

  /// Start listening for speech
  Future<void> startRecording({
    SpeechEngine engine = SpeechEngine.osNative,
    String? locale,
  }) async {
    if (!_isInitialized) {
      throw Exception('Service not initialized');
    }
    
    if (_isListening) {
      throw Exception('Already listening');
    }
    
    try {
      _logger.i('Starting speech recognition with engine: $engine');
      
      // Start speech recognition
      if (engine == SpeechEngine.osNative && _speechToText.isAvailable) {
        await _speechToText.listen(
          onResult: _onSpeechResult,
          listenFor: const Duration(minutes: 5), // Max listening time
          pauseFor: const Duration(seconds: 3),
          localeId: locale,
          onSoundLevelChange: _onSoundLevelChange,
          listenOptions: SpeechListenOptions(
            partialResults: true,
            cancelOnError: false,
            listenMode: ListenMode.confirmation,
          ),
        );
      } else {
        throw Exception('Speech recognition engine not available');
      }
      
      // Start audio level simulation timer
      _startAudioLevelTimer();
      
      _isListening = true;
      _listeningStartTime = DateTime.now();
      _logger.i('Speech recognition started successfully');
    } catch (e) {
      _logger.e('Failed to start speech recognition: $e');
      await _cleanup();
      rethrow;
    }
  }

  /// Stop listening and return the result
  Future<RecordingFile?> stopRecording() async {
    if (!_isListening) {
      return null;
    }
    
    try {
      _logger.i('Stopping speech recognition...');
      
      // Stop audio level timer
      _audioLevelTimer?.cancel();
      
      // Stop speech recognition
      if (_speechToText.isListening) {
        await _speechToText.stop();
      }
      
      _isListening = false;
      
      // Calculate duration
      final duration = _listeningStartTime != null 
          ? DateTime.now().difference(_listeningStartTime!)
          : Duration.zero;
      
      // Get final transcription
      final transcription = _getLastTranscription();
      
      if (transcription.isNotEmpty) {
        // Create a mock recording file (without actual audio file for now)
        final recordingFile = RecordingFile(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          audioPath: '', // No audio file for now
          textPath: await _saveTranscription(transcription),
          filename: 'speech_${DateTime.now().millisecondsSinceEpoch}',
          createdAt: _listeningStartTime ?? DateTime.now(),
          duration: duration,
          transcription: transcription,
          engine: SpeechEngine.osNative,
        );
        
        _logger.i('Speech recognition completed. Duration: ${duration.inSeconds}s');
        return recordingFile;
      }
      
      return null;
    } catch (e) {
      _logger.e('Failed to stop speech recognition: $e');
      rethrow;
    } finally {
      await _cleanup();
    }
  }

  /// Cancel current listening session
  Future<void> cancelRecording() async {
    if (!_isListening) {
      return;
    }
    
    try {
      _logger.i('Cancelling speech recognition...');
      
      // Stop timers
      _audioLevelTimer?.cancel();
      
      if (_speechToText.isListening) {
        await _speechToText.cancel();
      }
      
      _isListening = false;
      _logger.i('Speech recognition cancelled successfully');
    } catch (e) {
      _logger.e('Failed to cancel speech recognition: $e');
    } finally {
      await _cleanup();
    }
  }

  /// Get transcription directory
  Future<Directory> _getTranscriptionDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final transcriptionDir = Directory(path.join(appDir.path, 'FlowHunt', 'Voice', 'transcriptions'));
    
    if (!await transcriptionDir.exists()) {
      await transcriptionDir.create(recursive: true);
    }
    
    return transcriptionDir;
  }

  /// Save transcription to text file
  Future<String> _saveTranscription(String transcription) async {
    try {
      final directory = await _getTranscriptionDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'transcription_$timestamp.txt';
      final textPath = path.join(directory.path, filename);
      
      final textFile = File(textPath);
      await textFile.writeAsString(transcription);
      
      return textPath;
    } catch (e) {
      _logger.e('Failed to save transcription: $e');
      return '';
    }
  }

  /// Start audio level simulation timer
  void _startAudioLevelTimer() {
    _audioLevelTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      // Generate simulated audio level for visual feedback
      final level = Random().nextDouble() * 0.5 + 0.1;
      _audioLevelController?.add(level);
    });
  }

  /// Handle speech recognition status changes
  void _onSpeechStatus(String status) {
    _logger.d('Speech status: $status');
  }

  /// Handle speech recognition errors
  void _onSpeechError(dynamic error) {
    _logger.e('Speech error: $error');
  }

  /// Handle speech recognition results
  void _onSpeechResult(dynamic result) {
    if (result != null) {
      final transcription = result.recognizedWords as String;
      _transcriptionController?.add(transcription);
      _logger.d('Speech result: $transcription');
    }
  }

  /// Handle sound level changes
  void _onSoundLevelChange(double level) {
    // Normalize level (0-1 range)
    final normalizedLevel = (level + 50) / 60; // Assuming dB range -50 to 10
    _audioLevelController?.add(normalizedLevel.clamp(0.0, 1.0));
  }

  /// Get the last transcription result
  String _getLastTranscription() {
    if (_speechToText.isAvailable) {
      return _speechToText.lastRecognizedWords;
    }
    return '';
  }

  /// Cleanup resources
  Future<void> _cleanup() async {
    _audioLevelTimer?.cancel();
    _listeningStartTime = null;
  }

  /// Dispose of the service
  Future<void> dispose() async {
    await _cleanup();
    await _audioLevelController?.close();
    await _transcriptionController?.close();
    _isInitialized = false;
  }
}