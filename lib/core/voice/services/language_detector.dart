import 'package:logger/logger.dart';

import '../models/language_detection.dart';

/// Service responsible for detecting language from text input
class LanguageDetector {
  final Logger _logger = Logger();
  
  /// Supported languages with their characteristics
  static const Map<String, SupportedLanguage> _supportedLanguages = {
    'en': SupportedLanguage(
      code: 'en',
      name: 'English',
      nativeName: 'English',
      speechLocale: 'en-US',
      commonWords: [
        'the', 'and', 'to', 'of', 'a', 'in', 'is', 'it', 'you', 'that',
        'he', 'was', 'for', 'on', 'are', 'as', 'with', 'his', 'they', 'i',
        'new', 'chat', 'start', 'stop', 'help', 'send', 'message', 'scroll',
        'up', 'down', 'record', 'cancel', 'settings'
      ],
    ),
    'es': SupportedLanguage(
      code: 'es',
      name: 'Spanish',
      nativeName: 'Español',
      speechLocale: 'es-ES',
      commonWords: [
        'el', 'la', 'de', 'que', 'y', 'a', 'en', 'un', 'es', 'se',
        'no', 'te', 'lo', 'le', 'da', 'su', 'por', 'son', 'con', 'para',
        'nuevo', 'chat', 'empezar', 'parar', 'ayuda', 'enviar', 'mensaje',
        'desplazar', 'arriba', 'abajo', 'grabar', 'cancelar', 'configuración'
      ],
    ),
    'fr': SupportedLanguage(
      code: 'fr',
      name: 'French',
      nativeName: 'Français',
      speechLocale: 'fr-FR',
      commonWords: [
        'le', 'de', 'et', 'à', 'un', 'il', 'être', 'et', 'en', 'avoir',
        'que', 'pour', 'dans', 'ce', 'son', 'une', 'sur', 'avec', 'ne', 'se',
        'nouveau', 'chat', 'commencer', 'arrêter', 'aide', 'envoyer', 'message',
        'défiler', 'haut', 'bas', 'enregistrer', 'annuler', 'paramètres'
      ],
    ),
    'de': SupportedLanguage(
      code: 'de',
      name: 'German',
      nativeName: 'Deutsch',
      speechLocale: 'de-DE',
      commonWords: [
        'der', 'die', 'und', 'in', 'den', 'von', 'zu', 'das', 'mit', 'sich',
        'des', 'auf', 'für', 'ist', 'im', 'dem', 'nicht', 'ein', 'eine', 'als',
        'neuer', 'chat', 'beginnen', 'stoppen', 'hilfe', 'senden', 'nachricht',
        'scrollen', 'oben', 'unten', 'aufnehmen', 'abbrechen', 'einstellungen'
      ],
    ),
    'zh': SupportedLanguage(
      code: 'zh',
      name: 'Chinese',
      nativeName: '中文',
      speechLocale: 'zh-CN',
      commonWords: [
        '的', '一', '是', '在', '不', '了', '有', '和', '人', '这',
        '中', '大', '为', '上', '个', '国', '我', '以', '要', '他',
        '新', '聊天', '开始', '停止', '帮助', '发送', '消息',
        '滚动', '上', '下', '录音', '取消', '设置'
      ],
    ),
    'ja': SupportedLanguage(
      code: 'ja',
      name: 'Japanese',
      nativeName: '日本語',
      speechLocale: 'ja-JP',
      commonWords: [
        'の', 'に', 'は', 'を', 'た', 'が', 'で', 'て', 'と', 'し',
        'れ', 'さ', 'ある', 'いる', 'も', 'する', 'から', 'な', 'こと', 'として',
        '新しい', 'チャット', '開始', '停止', 'ヘルプ', '送信', 'メッセージ',
        'スクロール', '上', '下', '録音', 'キャンセル', '設定'
      ],
    ),
  };
  
  /// Current language preferences
  LanguagePreferences _preferences = const LanguagePreferences();
  
  /// Get all supported languages
  List<SupportedLanguage> get supportedLanguages => 
      _supportedLanguages.values.toList();
  
  /// Get supported language by code
  SupportedLanguage? getLanguage(String code) => _supportedLanguages[code];
  
  /// Get current preferences
  LanguagePreferences get preferences => _preferences;
  
  /// Update language preferences
  void updatePreferences(LanguagePreferences preferences) {
    _preferences = preferences;
    _logger.i('Updated language preferences: primary=${preferences.primaryLanguage}, auto=${preferences.autoDetectionEnabled}');
  }
  
  /// Detect language from input text
  Future<LanguageDetectionResult> detectLanguage(String text) async {
    if (text.isEmpty) {
      return const LanguageDetectionResult(
        detectedLanguages: [],
        originalText: '',
        isSuccessful: false,
        error: 'Empty text provided',
      );
    }
    
    try {
      _logger.d('Detecting language for text: "${text.substring(0, text.length > 50 ? 50 : text.length)}..."');
      
      final normalizedText = _normalizeText(text);
      final words = normalizedText.split(' ').where((w) => w.isNotEmpty).toList();
      
      if (words.isEmpty) {
        return LanguageDetectionResult(
          detectedLanguages: [],
          originalText: text,
          isSuccessful: false,
          error: 'No valid words found',
        );
      }
      
      // Calculate scores for each language
      final languageScores = <String, double>{};
      
      for (final langEntry in _supportedLanguages.entries) {
        final langCode = langEntry.key;
        final language = langEntry.value;
        
        languageScores[langCode] = _calculateLanguageScore(words, language);
      }
      
      // Sort languages by score
      final sortedLanguages = languageScores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      // Create detected languages list
      final detectedLanguages = <DetectedLanguage>[];
      for (int i = 0; i < sortedLanguages.length; i++) {
        final entry = sortedLanguages[i];
        final language = _supportedLanguages[entry.key]!;
        
        detectedLanguages.add(DetectedLanguage(
          code: language.code,
          name: language.name,
          confidence: entry.value,
          isPrimary: i == 0,
        ));
      }
      
      // Filter out languages with very low confidence
      final filteredLanguages = detectedLanguages
          .where((lang) => lang.confidence > 0.1)
          .toList();
      
      final primaryLanguage = filteredLanguages.isNotEmpty 
          ? filteredLanguages.first 
          : null;
      
      final result = LanguageDetectionResult(
        detectedLanguages: filteredLanguages,
        primaryLanguage: primaryLanguage,
        originalText: text,
        isSuccessful: primaryLanguage != null,
      );
      
      if (primaryLanguage != null) {
        _logger.i('Detected language: ${primaryLanguage.code} (confidence: ${primaryLanguage.confidence.toStringAsFixed(2)})');
      } else {
        _logger.w('Could not reliably detect language');
      }
      
      return result;
    } catch (e) {
      _logger.e('Error detecting language: $e');
      return LanguageDetectionResult(
        detectedLanguages: [],
        originalText: text,
        isSuccessful: false,
        error: e.toString(),
      );
    }
  }
  
  /// Get the best language for the current input considering preferences
  String getBestLanguage(LanguageDetectionResult detection) {
    // If auto-detection is disabled, use primary language
    if (!_preferences.autoDetectionEnabled) {
      return _preferences.primaryLanguage;
    }
    
    // If detection failed, use fallback
    if (!detection.isSuccessful || detection.primaryLanguage == null) {
      return _preferences.fallbackLanguage;
    }
    
    final detected = detection.primaryLanguage!;
    
    // If confidence is below threshold, use fallback
    if (detected.confidence < _preferences.autoDetectionThreshold) {
      return _preferences.fallbackLanguage;
    }
    
    // If detected language is in preferred languages, use it
    if (_preferences.preferredLanguages.contains(detected.code)) {
      return detected.code;
    }
    
    // Otherwise, use primary language
    return _preferences.primaryLanguage;
  }
  
  /// Calculate language score based on word matching
  double _calculateLanguageScore(List<String> words, SupportedLanguage language) {
    if (words.isEmpty || language.commonWords.isEmpty) {
      return 0.0;
    }
    
    int matches = 0;
    final commonWordsLower = language.commonWords.map((w) => w.toLowerCase()).toSet();
    
    for (final word in words) {
      if (commonWordsLower.contains(word.toLowerCase())) {
        matches++;
      }
    }
    
    // Basic scoring: percentage of matched words
    double score = matches / words.length;
    
    // Boost score for languages with more common words matched
    if (matches > 0) {
      final commonWordBonus = matches / language.commonWords.length;
      score = (score + commonWordBonus) / 2;
    }
    
    // Apply length penalty for very short texts
    if (words.length < 3) {
      score *= 0.7;
    }
    
    // Apply character-based scoring for non-Latin scripts
    if (language.code == 'zh' || language.code == 'ja') {
      final text = words.join(' ');
      final nonLatinRatio = _calculateNonLatinRatio(text);
      if (nonLatinRatio > 0.5) {
        score += 0.3; // Boost for non-Latin scripts
      }
    }
    
    return score.clamp(0.0, 1.0);
  }
  
  /// Normalize text for language detection
  String _normalizeText(String text) {
    return text
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^\w\s\u4e00-\u9fff\u3040-\u309f\u30a0-\u30ff]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }
  
  /// Calculate ratio of non-Latin characters
  double _calculateNonLatinRatio(String text) {
    if (text.isEmpty) return 0.0;
    
    int nonLatinCount = 0;
    for (final char in text.runes) {
      // Check for CJK characters
      if ((char >= 0x4e00 && char <= 0x9fff) || // Chinese
          (char >= 0x3040 && char <= 0x309f) || // Hiragana
          (char >= 0x30a0 && char <= 0x30ff)) { // Katakana
        nonLatinCount++;
      }
    }
    
    return nonLatinCount / text.length;
  }
  
  /// Get speech recognition locale for a language
  String? getSpeechLocale(String languageCode) {
    return _supportedLanguages[languageCode]?.speechLocale;
  }
  
  /// Check if a language is supported for speech recognition
  bool isSpeechRecognitionSupported(String languageCode) {
    return _supportedLanguages[languageCode]?.speechRecognitionAvailable ?? false;
  }
  
  /// Check if a language is supported for command recognition
  bool isCommandRecognitionSupported(String languageCode) {
    return _supportedLanguages[languageCode]?.commandRecognitionAvailable ?? false;
  }
  
  /// Get display name for language code
  String getLanguageDisplayName(String languageCode) {
    final language = _supportedLanguages[languageCode];
    return language?.name ?? languageCode.toUpperCase();
  }
  
  /// Get native name for language code
  String getLanguageNativeName(String languageCode) {
    final language = _supportedLanguages[languageCode];
    return language?.nativeName ?? languageCode.toUpperCase();
  }
}