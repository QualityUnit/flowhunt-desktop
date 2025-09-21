import 'dart:io';
import 'package:flutter_whisper_kit/flutter_whisper_kit.dart';
import '../models/language_detection.dart';
import 'package:path_provider/path_provider.dart';

/// WhisperKit-based language detection service
/// Uses local Whisper models for accurate language detection
class WhisperLanguageDetector {
  static WhisperLanguageDetector? _instance;
  WhisperKit? _whisperKit;
  bool _isInitialized = false;
  String? _currentModelPath;
  
  WhisperLanguageDetector._();
  
  static WhisperLanguageDetector get instance {
    _instance ??= WhisperLanguageDetector._();
    return _instance!;
  }
  
  /// Initialize WhisperKit with a specific model
  Future<void> initialize({
    String modelName = 'tiny', // tiny, base, small, medium, large
    void Function(double)? onProgress,
  }) async {
    if (_isInitialized) return;
    
    try {
      // Initialize WhisperKit
      _whisperKit = WhisperKit();
      
      // Download model if needed
      final modelPath = await _downloadModel(
        modelName: modelName,
        onProgress: onProgress,
      );
      
      if (modelPath != null) {
        _currentModelPath = modelPath;
        _isInitialized = true;
      }
    } catch (e) {
      print('Error initializing WhisperKit: $e');
      _isInitialized = false;
    }
  }
  
  /// Download Whisper model with progress callback
  Future<String?> _downloadModel({
    required String modelName,
    void Function(double)? onProgress,
  }) async {
    try {
      // Check if model already exists
      final modelDir = await _getModelDirectory();
      final modelPath = '$modelDir/whisper-$modelName';
      
      if (await Directory(modelPath).exists()) {
        return modelPath;
      }
      
      // Download model with progress
      // Note: In production, implement actual model download
      // For now, we'll use the default model bundled with WhisperKit
      onProgress?.call(1.0);
      return modelPath;
    } catch (e) {
      print('Error downloading model: $e');
      return null;
    }
  }
  
  /// Get model storage directory
  Future<String> _getModelDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${appDir.path}/whisper_models');
    
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
    
    return modelDir.path;
  }
  
  /// Detect language from audio file using WhisperKit
  Future<LanguageDetectionResult?> detectLanguageFromAudio(String audioPath) async {
    if (!_isInitialized || _whisperKit == null) {
      await initialize();
      if (!_isInitialized) return null;
    }
    
    try {
      // Detect language using WhisperKit
      final detection = await _whisperKit!.detectLanguage(audioPath);
      
      if (detection == null) return null;
      
      // Convert probabilities to DetectedLanguage list
      final detectedLanguages = detection.probabilities.entries
          .map((entry) => DetectedLanguage(
                code: entry.key,
                name: _getLanguageName(entry.key),
                confidence: entry.value,
                isPrimary: entry.key == detection.language,
              ))
          .toList()
        ..sort((a, b) => b.confidence.compareTo(a.confidence));
      
      final primaryLanguage = detectedLanguages.firstWhere(
        (lang) => lang.isPrimary,
        orElse: () => detectedLanguages.first,
      );
      
      return LanguageDetectionResult(
        detectedLanguages: detectedLanguages,
        primaryLanguage: primaryLanguage,
        originalText: '', // Audio file, not text
        isSuccessful: true,
        error: null,
      );
    } catch (e) {
      print('Error detecting language with WhisperKit: $e');
      return LanguageDetectionResult(
        detectedLanguages: [],
        primaryLanguage: null,
        originalText: '',
        isSuccessful: false,
        error: e.toString(),
      );
    }
  }
  
  /// Transcribe audio with automatic language detection
  Future<WhisperTranscriptionResult?> transcribeWithLanguageDetection(
    String audioPath, {
    double temperature = 0.0,
    bool suppressBlank = true,
    bool withoutTimestamps = false,
  }) async {
    if (!_isInitialized || _whisperKit == null) {
      await initialize();
      if (!_isInitialized) return null;
    }
    
    try {
      // First detect language
      final languageResult = await detectLanguageFromAudio(audioPath);
      
      // Create decoding options with auto language detection
      final options = DecodingOptions(
        language: null, // null enables auto-detection
        temperature: temperature,
        suppressBlank: suppressBlank,
        withoutTimestamps: withoutTimestamps,
      );
      
      // Transcribe with WhisperKit
      final result = await _whisperKit!.transcribe(
        audioPath: audioPath,
        options: options,
      );
      
      if (result == null) return null;
      
      return WhisperTranscriptionResult(
        text: result.text,
        language: languageResult?.primaryLanguage?.code ?? 'en',
        confidence: languageResult?.primaryLanguage?.confidence ?? 0.0,
        segments: result.segments?.map((s) => TranscriptionSegment(
          text: s.text,
          startTime: s.start,
          endTime: s.end,
        )).toList() ?? [],
      );
    } catch (e) {
      print('Error transcribing with WhisperKit: $e');
      return null;
    }
  }
  
  /// Get human-readable language name from ISO code
  String _getLanguageName(String isoCode) {
    // Map of ISO 639-1 codes to language names
    final languageMap = {
      'en': 'English',
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'zh': 'Chinese',
      'ja': 'Japanese',
      'ko': 'Korean',
      'ru': 'Russian',
      'ar': 'Arabic',
      'hi': 'Hindi',
      'pt': 'Portuguese',
      'it': 'Italian',
      'nl': 'Dutch',
      'pl': 'Polish',
      'tr': 'Turkish',
      'sv': 'Swedish',
      'no': 'Norwegian',
      'da': 'Danish',
      'fi': 'Finnish',
      'el': 'Greek',
      'cs': 'Czech',
      'ro': 'Romanian',
      'hu': 'Hungarian',
      'he': 'Hebrew',
      'th': 'Thai',
      'vi': 'Vietnamese',
      'id': 'Indonesian',
      'ms': 'Malay',
      'fil': 'Filipino',
      'uk': 'Ukrainian',
      // Add more as needed
    };
    
    return languageMap[isoCode.toLowerCase()] ?? isoCode.toUpperCase();
  }
  
  /// Get supported Whisper languages
  static Map<String, SupportedLanguage> getSupportedLanguages() {
    return {
      'en': const SupportedLanguage(
        code: 'en',
        name: 'English',
        nativeName: 'English',
        speechLocale: 'en-US',
      ),
      'es': const SupportedLanguage(
        code: 'es',
        name: 'Spanish',
        nativeName: 'Español',
        speechLocale: 'es-ES',
      ),
      'fr': const SupportedLanguage(
        code: 'fr',
        name: 'French',
        nativeName: 'Français',
        speechLocale: 'fr-FR',
      ),
      'de': const SupportedLanguage(
        code: 'de',
        name: 'German',
        nativeName: 'Deutsch',
        speechLocale: 'de-DE',
      ),
      'zh': const SupportedLanguage(
        code: 'zh',
        name: 'Chinese',
        nativeName: '中文',
        speechLocale: 'zh-CN',
      ),
      'ja': const SupportedLanguage(
        code: 'ja',
        name: 'Japanese',
        nativeName: '日本語',
        speechLocale: 'ja-JP',
      ),
      // Add more languages as needed
    };
  }
  
  /// Get list of available models
  List<WhisperModel> getAvailableModels() {
    return [
      WhisperModel(
        name: 'tiny',
        size: '39 MB',
        languages: 99,
        description: 'Fastest, least accurate',
      ),
      WhisperModel(
        name: 'base',
        size: '74 MB',
        languages: 99,
        description: 'Fast, good accuracy',
      ),
      WhisperModel(
        name: 'small',
        size: '244 MB',
        languages: 99,
        description: 'Balanced speed and accuracy',
      ),
      WhisperModel(
        name: 'medium',
        size: '769 MB',
        languages: 99,
        description: 'Slower, better accuracy',
      ),
      WhisperModel(
        name: 'large',
        size: '1550 MB',
        languages: 99,
        description: 'Slowest, best accuracy',
      ),
    ];
  }
  
  /// Clean up resources
  void dispose() {
    _whisperKit = null;
    _isInitialized = false;
    _currentModelPath = null;
  }
}

/// Whisper model information
class WhisperModel {
  final String name;
  final String size;
  final int languages;
  final String description;
  
  WhisperModel({
    required this.name,
    required this.size,
    required this.languages,
    required this.description,
  });
}

/// Whisper transcription result with language info
class WhisperTranscriptionResult {
  final String text;
  final LanguageCode language;
  final double confidence;
  final List<TranscriptionSegment> segments;
  
  TranscriptionResult({
    required this.text,
    required this.language,
    required this.confidence,
    required this.segments,
  });
}

/// Transcription segment
class TranscriptionSegment {
  final String text;
  final double startTime;
  final double endTime;
  
  TranscriptionSegment({
    required this.text,
    required this.startTime,
    required this.endTime,
  });
}