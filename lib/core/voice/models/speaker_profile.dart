import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

/// Voice characteristics for speaker identification
class VoiceCharacteristics extends Equatable {
  /// Fundamental frequency (pitch) statistics
  final double averagePitch;
  final double pitchVariance;
  final double minPitch;
  final double maxPitch;
  
  /// Speaking rate characteristics
  final double averageSpeakingRate; // words per minute
  final double pauseDuration; // average pause between words
  
  /// Voice quality indicators
  final double voiceIntensity; // average amplitude
  final double spectralCentroid; // brightness of voice
  final double spectralRolloff; // voice bandwidth
  
  /// Linguistic patterns
  final Map<String, double> wordFrequencies;
  final double averageWordLength;
  final List<String> commonPhrases;
  
  /// Audio fingerprint data
  final List<double> mfccFeatures; // Mel-frequency cepstral coefficients
  final List<double> formantFrequencies; // Vocal tract characteristics
  
  /// Confidence metrics
  final double overallConfidence;
  final int sampleCount; // Number of samples used to build this profile

  const VoiceCharacteristics({
    required this.averagePitch,
    required this.pitchVariance,
    required this.minPitch,
    required this.maxPitch,
    required this.averageSpeakingRate,
    required this.pauseDuration,
    required this.voiceIntensity,
    required this.spectralCentroid,
    required this.spectralRolloff,
    this.wordFrequencies = const {},
    required this.averageWordLength,
    this.commonPhrases = const [],
    this.mfccFeatures = const [],
    this.formantFrequencies = const [],
    required this.overallConfidence,
    required this.sampleCount,
  });

  VoiceCharacteristics copyWith({
    double? averagePitch,
    double? pitchVariance,
    double? minPitch,
    double? maxPitch,
    double? averageSpeakingRate,
    double? pauseDuration,
    double? voiceIntensity,
    double? spectralCentroid,
    double? spectralRolloff,
    Map<String, double>? wordFrequencies,
    double? averageWordLength,
    List<String>? commonPhrases,
    List<double>? mfccFeatures,
    List<double>? formantFrequencies,
    double? overallConfidence,
    int? sampleCount,
  }) {
    return VoiceCharacteristics(
      averagePitch: averagePitch ?? this.averagePitch,
      pitchVariance: pitchVariance ?? this.pitchVariance,
      minPitch: minPitch ?? this.minPitch,
      maxPitch: maxPitch ?? this.maxPitch,
      averageSpeakingRate: averageSpeakingRate ?? this.averageSpeakingRate,
      pauseDuration: pauseDuration ?? this.pauseDuration,
      voiceIntensity: voiceIntensity ?? this.voiceIntensity,
      spectralCentroid: spectralCentroid ?? this.spectralCentroid,
      spectralRolloff: spectralRolloff ?? this.spectralRolloff,
      wordFrequencies: wordFrequencies ?? this.wordFrequencies,
      averageWordLength: averageWordLength ?? this.averageWordLength,
      commonPhrases: commonPhrases ?? this.commonPhrases,
      mfccFeatures: mfccFeatures ?? this.mfccFeatures,
      formantFrequencies: formantFrequencies ?? this.formantFrequencies,
      overallConfidence: overallConfidence ?? this.overallConfidence,
      sampleCount: sampleCount ?? this.sampleCount,
    );
  }

  @override
  List<Object?> get props => [
        averagePitch,
        pitchVariance,
        minPitch,
        maxPitch,
        averageSpeakingRate,
        pauseDuration,
        voiceIntensity,
        spectralCentroid,
        spectralRolloff,
        wordFrequencies,
        averageWordLength,
        commonPhrases,
        mfccFeatures,
        formantFrequencies,
        overallConfidence,
        sampleCount,
      ];
}

/// Speaker profile containing identification information
class SpeakerProfile extends Equatable {
  /// Unique identifier for the speaker
  final String id;
  
  /// Display name for the speaker
  final String name;
  
  /// Voice characteristics fingerprint
  final VoiceCharacteristics characteristics;
  
  /// When the profile was created
  final DateTime createdAt;
  
  /// When the profile was last updated
  final DateTime lastUpdatedAt;
  
  /// Whether this profile is active for recognition
  final bool isActive;
  
  /// Custom color for visual identification
  final int colorCode;
  
  /// Avatar/icon identifier
  final String? avatarId;
  
  /// Additional metadata
  final Map<String, dynamic> metadata;
  
  /// Number of successful recognitions
  final int recognitionCount;
  
  /// Average confidence of recognitions
  final double averageRecognitionConfidence;

  const SpeakerProfile({
    required this.id,
    required this.name,
    required this.characteristics,
    required this.createdAt,
    required this.lastUpdatedAt,
    this.isActive = true,
    required this.colorCode,
    this.avatarId,
    this.metadata = const {},
    this.recognitionCount = 0,
    this.averageRecognitionConfidence = 0.0,
  });

  /// Create a new speaker profile
  factory SpeakerProfile.create({
    required String name,
    required VoiceCharacteristics characteristics,
    int? colorCode,
    String? avatarId,
    Map<String, dynamic>? metadata,
  }) {
    final now = DateTime.now();
    return SpeakerProfile(
      id: const Uuid().v4(),
      name: name,
      characteristics: characteristics,
      createdAt: now,
      lastUpdatedAt: now,
      colorCode: colorCode ?? _generateRandomColor(),
      avatarId: avatarId,
      metadata: metadata ?? {},
    );
  }

  static int _generateRandomColor() {
    // Generate a random color code (excluding too dark or too light colors)
    final colors = [
      0xFF2196F3, // Blue
      0xFF4CAF50, // Green
      0xFFFF9800, // Orange
      0xFF9C27B0, // Purple
      0xFFF44336, // Red
      0xFF00BCD4, // Cyan
      0xFFFFEB3B, // Yellow
      0xFF795548, // Brown
      0xFF607D8B, // Blue Grey
      0xFFE91E63, // Pink
    ];
    return colors[(DateTime.now().millisecondsSinceEpoch % colors.length)];
  }

  SpeakerProfile copyWith({
    String? id,
    String? name,
    VoiceCharacteristics? characteristics,
    DateTime? createdAt,
    DateTime? lastUpdatedAt,
    bool? isActive,
    int? colorCode,
    String? avatarId,
    Map<String, dynamic>? metadata,
    int? recognitionCount,
    double? averageRecognitionConfidence,
  }) {
    return SpeakerProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      characteristics: characteristics ?? this.characteristics,
      createdAt: createdAt ?? this.createdAt,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      isActive: isActive ?? this.isActive,
      colorCode: colorCode ?? this.colorCode,
      avatarId: avatarId ?? this.avatarId,
      metadata: metadata ?? this.metadata,
      recognitionCount: recognitionCount ?? this.recognitionCount,
      averageRecognitionConfidence: averageRecognitionConfidence ?? this.averageRecognitionConfidence,
    );
  }

  /// Update profile with new voice sample
  SpeakerProfile updateWithNewSample(VoiceCharacteristics newCharacteristics, double confidence) {
    // Blend characteristics (weighted average based on sample count)
    final oldWeight = characteristics.sampleCount.toDouble();
    final newWeight = 1.0;
    final totalWeight = oldWeight + newWeight;
    
    final blendedCharacteristics = VoiceCharacteristics(
      averagePitch: (characteristics.averagePitch * oldWeight + newCharacteristics.averagePitch * newWeight) / totalWeight,
      pitchVariance: (characteristics.pitchVariance * oldWeight + newCharacteristics.pitchVariance * newWeight) / totalWeight,
      minPitch: (characteristics.minPitch + newCharacteristics.minPitch) / 2,
      maxPitch: (characteristics.maxPitch + newCharacteristics.maxPitch) / 2,
      averageSpeakingRate: (characteristics.averageSpeakingRate * oldWeight + newCharacteristics.averageSpeakingRate * newWeight) / totalWeight,
      pauseDuration: (characteristics.pauseDuration * oldWeight + newCharacteristics.pauseDuration * newWeight) / totalWeight,
      voiceIntensity: (characteristics.voiceIntensity * oldWeight + newCharacteristics.voiceIntensity * newWeight) / totalWeight,
      spectralCentroid: (characteristics.spectralCentroid * oldWeight + newCharacteristics.spectralCentroid * newWeight) / totalWeight,
      spectralRolloff: (characteristics.spectralRolloff * oldWeight + newCharacteristics.spectralRolloff * newWeight) / totalWeight,
      wordFrequencies: _blendWordFrequencies(characteristics.wordFrequencies, newCharacteristics.wordFrequencies),
      averageWordLength: (characteristics.averageWordLength * oldWeight + newCharacteristics.averageWordLength * newWeight) / totalWeight,
      commonPhrases: {...characteristics.commonPhrases, ...newCharacteristics.commonPhrases}.toList(),
      mfccFeatures: _blendFeatures(characteristics.mfccFeatures, newCharacteristics.mfccFeatures),
      formantFrequencies: _blendFeatures(characteristics.formantFrequencies, newCharacteristics.formantFrequencies),
      overallConfidence: (characteristics.overallConfidence * oldWeight + newCharacteristics.overallConfidence * newWeight) / totalWeight,
      sampleCount: characteristics.sampleCount + 1,
    );
    
    final newRecognitionCount = recognitionCount + 1;
    final newAverageConfidence = (averageRecognitionConfidence * recognitionCount + confidence) / newRecognitionCount;
    
    return copyWith(
      characteristics: blendedCharacteristics,
      lastUpdatedAt: DateTime.now(),
      recognitionCount: newRecognitionCount,
      averageRecognitionConfidence: newAverageConfidence,
    );
  }

  static Map<String, double> _blendWordFrequencies(Map<String, double> old, Map<String, double> new_) {
    final result = Map<String, double>.from(old);
    for (final entry in new_.entries) {
      result[entry.key] = (result[entry.key] ?? 0.0) + entry.value;
    }
    return result;
  }

  static List<double> _blendFeatures(List<double> old, List<double> new_) {
    if (old.isEmpty) return new_;
    if (new_.isEmpty) return old;
    
    final maxLength = old.length > new_.length ? old.length : new_.length;
    final result = <double>[];
    
    for (int i = 0; i < maxLength; i++) {
      final oldValue = i < old.length ? old[i] : 0.0;
      final newValue = i < new_.length ? new_[i] : 0.0;
      result.add((oldValue + newValue) / 2);
    }
    
    return result;
  }

  @override
  List<Object?> get props => [
        id,
        name,
        characteristics,
        createdAt,
        lastUpdatedAt,
        isActive,
        colorCode,
        avatarId,
        metadata,
        recognitionCount,
        averageRecognitionConfidence,
      ];
}

/// Result of speaker identification
class SpeakerIdentificationResult extends Equatable {
  /// Identified speaker profile (null if unknown speaker)
  final SpeakerProfile? identifiedSpeaker;
  
  /// Confidence score (0.0 - 1.0)
  final double confidence;
  
  /// All possible speaker matches sorted by confidence
  final List<SpeakerMatch> allMatches;
  
  /// Whether this is a new/unknown speaker
  final bool isUnknownSpeaker;
  
  /// Voice characteristics extracted from the input
  final VoiceCharacteristics inputCharacteristics;
  
  /// Original audio data or path
  final String? audioReference;

  const SpeakerIdentificationResult({
    this.identifiedSpeaker,
    required this.confidence,
    required this.allMatches,
    required this.isUnknownSpeaker,
    required this.inputCharacteristics,
    this.audioReference,
  });

  @override
  List<Object?> get props => [
        identifiedSpeaker,
        confidence,
        allMatches,
        isUnknownSpeaker,
        inputCharacteristics,
        audioReference,
      ];
}

/// Individual speaker match result
class SpeakerMatch extends Equatable {
  /// The speaker profile
  final SpeakerProfile speaker;
  
  /// Match confidence score
  final double confidence;
  
  /// Detailed similarity scores for different characteristics
  final Map<String, double> similarityScores;

  const SpeakerMatch({
    required this.speaker,
    required this.confidence,
    this.similarityScores = const {},
  });

  @override
  List<Object?> get props => [speaker, confidence, similarityScores];
}