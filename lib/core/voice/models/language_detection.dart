import 'package:equatable/equatable.dart';

/// Represents a detected language
class DetectedLanguage extends Equatable {
  /// Language code (ISO 639-1)
  final String code;
  
  /// Human-readable language name
  final String name;
  
  /// Confidence score (0.0 - 1.0)
  final double confidence;
  
  /// Whether this is the primary detected language
  final bool isPrimary;

  const DetectedLanguage({
    required this.code,
    required this.name,
    required this.confidence,
    this.isPrimary = false,
  });

  @override
  List<Object?> get props => [code, name, confidence, isPrimary];
}

/// Language detection result
class LanguageDetectionResult extends Equatable {
  /// List of detected languages sorted by confidence
  final List<DetectedLanguage> detectedLanguages;
  
  /// Primary (most confident) language
  final DetectedLanguage? primaryLanguage;
  
  /// Original text that was analyzed
  final String originalText;
  
  /// Whether detection was successful
  final bool isSuccessful;
  
  /// Error message if detection failed
  final String? error;

  const LanguageDetectionResult({
    required this.detectedLanguages,
    this.primaryLanguage,
    required this.originalText,
    required this.isSuccessful,
    this.error,
  });

  @override
  List<Object?> get props => [
        detectedLanguages,
        primaryLanguage,
        originalText,
        isSuccessful,
        error,
      ];
}

/// Supported language configuration
class SupportedLanguage extends Equatable {
  /// Language code (ISO 639-1)
  final String code;
  
  /// Human-readable name
  final String name;
  
  /// Native name
  final String nativeName;
  
  /// Whether this language is available for speech recognition
  final bool speechRecognitionAvailable;
  
  /// Whether this language is available for command recognition
  final bool commandRecognitionAvailable;
  
  /// Common words/phrases for language detection
  final List<String> commonWords;
  
  /// Language-specific speech recognition locale identifier
  final String? speechLocale;

  const SupportedLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
    this.speechRecognitionAvailable = true,
    this.commandRecognitionAvailable = true,
    this.commonWords = const [],
    this.speechLocale,
  });

  @override
  List<Object?> get props => [
        code,
        name,
        nativeName,
        speechRecognitionAvailable,
        commandRecognitionAvailable,
        commonWords,
        speechLocale,
      ];
}

/// Language preference settings
class LanguagePreferences extends Equatable {
  /// Preferred primary language
  final String primaryLanguage;
  
  /// Whether to enable automatic language detection
  final bool autoDetectionEnabled;
  
  /// Minimum confidence threshold for auto-detection
  final double autoDetectionThreshold;
  
  /// Fallback language when detection fails
  final String fallbackLanguage;
  
  /// Whether to switch language automatically during conversation
  final bool autoSwitchEnabled;
  
  /// List of preferred languages in order of preference
  final List<String> preferredLanguages;

  const LanguagePreferences({
    this.primaryLanguage = 'en',
    this.autoDetectionEnabled = true,
    this.autoDetectionThreshold = 0.7,
    this.fallbackLanguage = 'en',
    this.autoSwitchEnabled = false,
    this.preferredLanguages = const ['en'],
  });

  LanguagePreferences copyWith({
    String? primaryLanguage,
    bool? autoDetectionEnabled,
    double? autoDetectionThreshold,
    String? fallbackLanguage,
    bool? autoSwitchEnabled,
    List<String>? preferredLanguages,
  }) {
    return LanguagePreferences(
      primaryLanguage: primaryLanguage ?? this.primaryLanguage,
      autoDetectionEnabled: autoDetectionEnabled ?? this.autoDetectionEnabled,
      autoDetectionThreshold: autoDetectionThreshold ?? this.autoDetectionThreshold,
      fallbackLanguage: fallbackLanguage ?? this.fallbackLanguage,
      autoSwitchEnabled: autoSwitchEnabled ?? this.autoSwitchEnabled,
      preferredLanguages: preferredLanguages ?? this.preferredLanguages,
    );
  }

  @override
  List<Object?> get props => [
        primaryLanguage,
        autoDetectionEnabled,
        autoDetectionThreshold,
        fallbackLanguage,
        autoSwitchEnabled,
        preferredLanguages,
      ];
}