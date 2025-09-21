import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:logger/logger.dart';

import 'voice_input_state.dart';

/// Service responsible for handling audio recording and transcription
class VoiceRecorderService {
  final SpeechToText _speechToText = SpeechToText();
  final Logger _logger = Logger();
  
  StreamController<double>? _audioLevelController;
  StreamController<String>? _transcriptionController;
  Timer? _recordingTimer;
  Timer? _audioLevelTimer;
  
  String? _currentRecordingPath;
  DateTime? _recordingStartTime;
  bool _isInitialized = false;
  bool _isRecording = false;
  
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
    
    // Always try OS native first
    if (_speechToText.isAvailable) {
      engines.add(SpeechEngine.osNative);
    }
    
    // TODO: Add WhisperKit availability check
    // TODO: Add OpenAI Whisper availability check (requires network)
    
    return engines;
  }

  /// Start recording with real-time transcription
  Future<void> startRecording({
    SpeechEngine engine = SpeechEngine.osNative,
    String? locale,
  }) async {
    if (!_isInitialized) {
      throw Exception('Service not initialized');
    }
    
    if (_isRecording) {
      throw Exception('Already recording');
    }
    
    try {
      _logger.i('Starting recording with engine: $engine');
      
      // Create recording directory
      final directory = await _getRecordingDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'recording_$timestamp';
      _currentRecordingPath = path.join(directory.path, '$filename.wav');
      
      // Start audio recording
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _currentRecordingPath!,
      );
      
      // Start real-time transcription based on engine
      if (engine == SpeechEngine.osNative && _speechToText.isAvailable) {
        await _speechToText.listen(
          onResult: _onSpeechResult,
          listenFor: const Duration(minutes: 10), // Max recording time
          pauseFor: const Duration(seconds: 3),
          localeId: locale,
          onSoundLevelChange: _onSoundLevelChange,
          listenOptions: SpeechListenOptions(
            partialResults: true,
            cancelOnError: false,
            listenMode: ListenMode.confirmation,
          ),
        );
      }
      
      // Start timers
      _recordingStartTime = DateTime.now();
      _startRecordingTimer();
      _startAudioLevelTimer();
      
      _isRecording = true;
      _logger.i('Recording started successfully');
    } catch (e) {
      _logger.e('Failed to start recording: $e');
      await _cleanup();
      rethrow;
    }
  }

  /// Stop recording and return the result
  Future<RecordingFile?> stopRecording() async {
    if (!_isRecording) {
      return null;
    }
    
    try {
      _logger.i('Stopping recording...');
      
      // Stop timers
      _recordingTimer?.cancel();
      _audioLevelTimer?.cancel();
      
      // Stop speech recognition
      if (_speechToText.isListening) {
        await _speechToText.stop();
      }
      
      // Stop audio recording
      final audioPath = await _recorder.stop();
      
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
      
      // Save transcription to file
      final textPath = await _saveTranscription(audioPath, transcription);
      
      // Create recording file object
      final recordingFile = RecordingFile(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        audioPath: audioPath,
        textPath: textPath,
        filename: path.basenameWithoutExtension(audioPath),
        createdAt: _recordingStartTime ?? DateTime.now(),
        duration: duration,
        transcription: transcription,
        engine: SpeechEngine.osNative, // TODO: Use actual engine
      );
      
      _logger.i('Recording stopped successfully. Duration: ${duration.inSeconds}s');
      return recordingFile;
    } catch (e) {
      _logger.e('Failed to stop recording: $e');
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
      _logger.i('Cancelling recording...');
      
      // Stop everything
      _recordingTimer?.cancel();
      _audioLevelTimer?.cancel();
      
      if (_speechToText.isListening) {
        await _speechToText.cancel();
      }
      
      await _recorder.cancel();
      
      // Delete the recording file if it exists
      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
      
      _isRecording = false;
      _logger.i('Recording cancelled successfully');
    } catch (e) {
      _logger.e('Failed to cancel recording: $e');
    } finally {
      await _cleanup();
    }
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

  /// Start audio level monitoring timer
  void _startAudioLevelTimer() {
    _audioLevelTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      // Generate simulated audio level for now
      // TODO: Implement real audio level detection
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
    _recordingTimer?.cancel();
    _audioLevelTimer?.cancel();
    _recordingStartTime = null;
    _currentRecordingPath = null;
  }

  /// Dispose of the service
  Future<void> dispose() async {
    await _cleanup();
    await _audioLevelController?.close();
    await _transcriptionController?.close();
    await _recorder.dispose();
    _isInitialized = false;
  }
}