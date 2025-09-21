import 'dart:io';
import 'dart:math';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/speaker_profile.dart';

/// Service responsible for speaker identification and voice fingerprinting
class SpeakerIdentificationService {
  final Logger _logger = Logger();
  
  /// Registered speaker profiles
  final Map<String, SpeakerProfile> _speakers = {};
  
  /// Minimum confidence threshold for speaker identification
  static const double kMinIdentificationConfidence = 0.6;
  
  /// Minimum samples required for reliable identification
  static const int kMinSamplesForIdentification = 3;
  
  /// Maximum number of speakers to track
  static const int kMaxSpeakers = 20;

  /// Get all registered speakers
  List<SpeakerProfile> get speakers => _speakers.values.toList();
  
  /// Get active speakers only
  List<SpeakerProfile> get activeSpeakers => 
      _speakers.values.where((s) => s.isActive).toList();
  
  /// Get speaker by ID
  SpeakerProfile? getSpeaker(String id) => _speakers[id];
  
  /// Register a new speaker profile
  Future<SpeakerProfile> registerSpeaker(String name, VoiceCharacteristics characteristics) async {
    if (_speakers.length >= kMaxSpeakers) {
      // Remove least used speaker
      final leastUsed = _speakers.values
          .reduce((a, b) => a.recognitionCount < b.recognitionCount ? a : b);
      await removeSpeaker(leastUsed.id);
    }
    
    final profile = SpeakerProfile.create(
      name: name,
      characteristics: characteristics,
    );
    
    _speakers[profile.id] = profile;
    await _saveSpeakerProfile(profile);
    
    _logger.i('Registered new speaker: ${profile.name} (ID: ${profile.id})');
    return profile;
  }
  
  /// Update an existing speaker profile
  Future<void> updateSpeaker(SpeakerProfile updatedProfile) async {
    _speakers[updatedProfile.id] = updatedProfile;
    await _saveSpeakerProfile(updatedProfile);
    _logger.d('Updated speaker profile: ${updatedProfile.name}');
  }
  
  /// Remove a speaker profile
  Future<void> removeSpeaker(String speakerId) async {
    final profile = _speakers.remove(speakerId);
    if (profile != null) {
      await _deleteSpeakerProfile(speakerId);
      _logger.i('Removed speaker: ${profile.name}');
    }
  }
  
  /// Identify speaker from voice characteristics
  Future<SpeakerIdentificationResult> identifySpeaker(VoiceCharacteristics characteristics, {String? audioReference}) async {
    if (_speakers.isEmpty) {
      _logger.d('No registered speakers for identification');
      return SpeakerIdentificationResult(
        confidence: 0.0,
        allMatches: [],
        isUnknownSpeaker: true,
        inputCharacteristics: characteristics,
        audioReference: audioReference,
      );
    }
    
    _logger.d('Identifying speaker from voice characteristics...');
    
    // Calculate similarity scores for all active speakers
    final matches = <SpeakerMatch>[];
    
    for (final speaker in activeSpeakers) {
      if (speaker.characteristics.sampleCount < kMinSamplesForIdentification) {
        continue; // Skip speakers with insufficient training data
      }
      
      final similarityScores = _calculateSimilarityScores(characteristics, speaker.characteristics);
      final overallConfidence = _calculateOverallConfidence(similarityScores);
      
      matches.add(SpeakerMatch(
        speaker: speaker,
        confidence: overallConfidence,
        similarityScores: similarityScores,
      ));
    }
    
    // Sort matches by confidence
    matches.sort((a, b) => b.confidence.compareTo(a.confidence));
    
    // Determine if we have a confident match
    final bestMatch = matches.isNotEmpty ? matches.first : null;
    final isConfidentMatch = bestMatch != null && bestMatch.confidence >= kMinIdentificationConfidence;
    
    SpeakerProfile? identifiedSpeaker;
    double confidence = 0.0;
    
    if (isConfidentMatch) {
      identifiedSpeaker = bestMatch.speaker;
      confidence = bestMatch.confidence;
      
      // Update speaker profile with new sample
      final updatedSpeaker = identifiedSpeaker.updateWithNewSample(characteristics, confidence);
      await updateSpeaker(updatedSpeaker);
      
      _logger.i('Identified speaker: ${identifiedSpeaker.name} (confidence: ${confidence.toStringAsFixed(2)})');
    } else {
      _logger.d('No confident speaker match found (best: ${bestMatch?.confidence.toStringAsFixed(2) ?? 'none'})');
    }
    
    return SpeakerIdentificationResult(
      identifiedSpeaker: identifiedSpeaker,
      confidence: confidence,
      allMatches: matches,
      isUnknownSpeaker: !isConfidentMatch,
      inputCharacteristics: characteristics,
      audioReference: audioReference,
    );
  }
  
  /// Extract voice characteristics from audio data (simplified implementation)
  Future<VoiceCharacteristics> extractCharacteristics(String audioPath, String transcription) async {
    try {
      _logger.d('Extracting voice characteristics from audio: $audioPath');
      
      // Note: This is a simplified implementation. In a real-world scenario,
      // you would use advanced audio processing libraries to extract actual
      // voice characteristics. For now, we'll generate simulated characteristics
      // based on available data.
      
      final file = File(audioPath);
      final fileSize = await file.exists() ? await file.length() : 0;
      final duration = _estimateDurationFromFileSize(fileSize);
      
      // Analyze transcription for linguistic patterns
      final words = transcription.split(' ').where((w) => w.isNotEmpty).toList();
      final wordFrequencies = _calculateWordFrequencies(words);
      final averageWordLength = words.isEmpty ? 0.0 : words.map((w) => w.length).reduce((a, b) => a + b) / words.length;
      final speakingRate = duration > 0 ? (words.length / duration) * 60 : 0.0; // words per minute
      
      // Generate simulated voice characteristics
      // In a real implementation, these would be extracted from actual audio analysis
      final random = Random();
      final baseFreq = 100 + random.nextInt(200); // 100-300 Hz range
      
      return VoiceCharacteristics(
        averagePitch: baseFreq.toDouble(),
        pitchVariance: 10 + random.nextDouble() * 30,
        minPitch: baseFreq - 20.0,
        maxPitch: baseFreq + 40.0,
        averageSpeakingRate: speakingRate,
        pauseDuration: 0.1 + random.nextDouble() * 0.5,
        voiceIntensity: 0.3 + random.nextDouble() * 0.4,
        spectralCentroid: 1000 + random.nextDouble() * 2000,
        spectralRolloff: 3000 + random.nextDouble() * 5000,
        wordFrequencies: wordFrequencies,
        averageWordLength: averageWordLength,
        commonPhrases: _extractCommonPhrases(transcription),
        mfccFeatures: _generateMockMfccFeatures(),
        formantFrequencies: _generateMockFormantFrequencies(),
        overallConfidence: 0.8 + random.nextDouble() * 0.2,
        sampleCount: 1,
      );
    } catch (e) {
      _logger.e('Error extracting voice characteristics: $e');
      rethrow;
    }
  }
  
  /// Calculate similarity scores between two voice characteristics
  Map<String, double> _calculateSimilarityScores(VoiceCharacteristics a, VoiceCharacteristics b) {
    final scores = <String, double>{};
    
    // Pitch similarity
    scores['pitch'] = _calculatePitchSimilarity(a, b);
    
    // Speaking rate similarity
    scores['speaking_rate'] = _calculateSpeakingRateSimilarity(a, b);
    
    // Voice quality similarity
    scores['voice_quality'] = _calculateVoiceQualitySimilarity(a, b);
    
    // Linguistic pattern similarity
    scores['linguistic'] = _calculateLinguisticSimilarity(a, b);
    
    // Spectral features similarity
    scores['spectral'] = _calculateSpectralSimilarity(a, b);
    
    return scores;
  }
  
  /// Calculate overall confidence from similarity scores
  double _calculateOverallConfidence(Map<String, double> scores) {
    if (scores.isEmpty) return 0.0;
    
    // Weighted average of similarity scores
    const weights = {
      'pitch': 0.25,
      'speaking_rate': 0.15,
      'voice_quality': 0.20,
      'linguistic': 0.20,
      'spectral': 0.20,
    };
    
    double weightedSum = 0.0;
    double totalWeight = 0.0;
    
    for (final entry in scores.entries) {
      final weight = weights[entry.key] ?? 0.0;
      weightedSum += entry.value * weight;
      totalWeight += weight;
    }
    
    return totalWeight > 0 ? weightedSum / totalWeight : 0.0;
  }
  
  double _calculatePitchSimilarity(VoiceCharacteristics a, VoiceCharacteristics b) {
    final pitchDiff = (a.averagePitch - b.averagePitch).abs();
    final maxPitch = max(a.averagePitch, b.averagePitch);
    return maxPitch > 0 ? 1.0 - (pitchDiff / maxPitch).clamp(0.0, 1.0) : 0.0;
  }
  
  double _calculateSpeakingRateSimilarity(VoiceCharacteristics a, VoiceCharacteristics b) {
    final rateDiff = (a.averageSpeakingRate - b.averageSpeakingRate).abs();
    final maxRate = max(a.averageSpeakingRate, b.averageSpeakingRate);
    return maxRate > 0 ? 1.0 - (rateDiff / maxRate).clamp(0.0, 1.0) : 0.0;
  }
  
  double _calculateVoiceQualitySimilarity(VoiceCharacteristics a, VoiceCharacteristics b) {
    final intensityDiff = (a.voiceIntensity - b.voiceIntensity).abs();
    final pauseDiff = (a.pauseDuration - b.pauseDuration).abs();
    
    final intensitySim = 1.0 - intensityDiff.clamp(0.0, 1.0);
    final pauseSim = 1.0 - (pauseDiff / 2.0).clamp(0.0, 1.0);
    
    return (intensitySim + pauseSim) / 2.0;
  }
  
  double _calculateLinguisticSimilarity(VoiceCharacteristics a, VoiceCharacteristics b) {
    // Word frequency similarity
    final commonWords = a.wordFrequencies.keys.toSet().intersection(b.wordFrequencies.keys.toSet());
    final totalWords = a.wordFrequencies.keys.toSet().union(b.wordFrequencies.keys.toSet()).length;
    final wordSimilarity = totalWords > 0 ? commonWords.length / totalWords : 0.0;
    
    // Average word length similarity
    final wordLengthDiff = (a.averageWordLength - b.averageWordLength).abs();
    final wordLengthSim = 1.0 - (wordLengthDiff / 10.0).clamp(0.0, 1.0);
    
    return (wordSimilarity + wordLengthSim) / 2.0;
  }
  
  double _calculateSpectralSimilarity(VoiceCharacteristics a, VoiceCharacteristics b) {
    final centroidDiff = (a.spectralCentroid - b.spectralCentroid).abs();
    final rolloffDiff = (a.spectralRolloff - b.spectralRolloff).abs();
    
    final centroidSim = 1.0 - (centroidDiff / 5000.0).clamp(0.0, 1.0);
    final rolloffSim = 1.0 - (rolloffDiff / 10000.0).clamp(0.0, 1.0);
    
    return (centroidSim + rolloffSim) / 2.0;
  }
  
  double _estimateDurationFromFileSize(int fileSize) {
    // Rough estimation: 16-bit 44.1kHz stereo = ~176KB per second
    return fileSize / (176 * 1024);
  }
  
  Map<String, double> _calculateWordFrequencies(List<String> words) {
    final frequencies = <String, double>{};
    for (final word in words) {
      final normalizedWord = word.toLowerCase().replaceAll(RegExp(r'[^\w]'), '');
      if (normalizedWord.isNotEmpty) {
        frequencies[normalizedWord] = (frequencies[normalizedWord] ?? 0.0) + 1.0;
      }
    }
    
    // Normalize frequencies
    final total = frequencies.values.fold(0.0, (sum, freq) => sum + freq);
    if (total > 0) {
      for (final key in frequencies.keys) {
        frequencies[key] = frequencies[key]! / total;
      }
    }
    
    return frequencies;
  }
  
  List<String> _extractCommonPhrases(String transcription) {
    // Simple phrase extraction - could be enhanced with NLP
    final sentences = transcription.split(RegExp(r'[.!?]')).where((s) => s.trim().isNotEmpty);
    return sentences.map((s) => s.trim().toLowerCase()).take(5).toList();
  }
  
  List<double> _generateMockMfccFeatures() {
    // Generate 13 MFCC coefficients (standard)
    final random = Random();
    return List.generate(13, (_) => random.nextDouble() * 20 - 10);
  }
  
  List<double> _generateMockFormantFrequencies() {
    // Generate 3-4 formant frequencies
    final random = Random();
    return [
      700 + random.nextDouble() * 300,  // F1: 700-1000 Hz
      1200 + random.nextDouble() * 800, // F2: 1200-2000 Hz
      2500 + random.nextDouble() * 500, // F3: 2500-3000 Hz
    ];
  }
  
  /// Load speaker profiles from storage
  Future<void> loadSpeakerProfiles() async {
    try {
      final directory = await _getSpeakerProfilesDirectory();
      final files = directory.listSync().where((f) => f.path.endsWith('.json'));
      
      for (final file in files) {
        try {
          // In a real implementation, you would deserialize JSON data
          // For now, we'll skip actual file loading
          _logger.d('Would load speaker profile from: ${file.path}');
        } catch (e) {
          _logger.w('Failed to load speaker profile from ${file.path}: $e');
        }
      }
      
      _logger.i('Loaded ${_speakers.length} speaker profiles');
    } catch (e) {
      _logger.e('Error loading speaker profiles: $e');
    }
  }
  
  /// Save speaker profile to storage
  Future<void> _saveSpeakerProfile(SpeakerProfile profile) async {
    try {
      final directory = await _getSpeakerProfilesDirectory();
      final file = File(path.join(directory.path, '${profile.id}.json'));
      
      // In a real implementation, you would serialize the profile to JSON
      // For now, we'll just create a placeholder file
      await file.writeAsString('{"id": "${profile.id}", "name": "${profile.name}"}');
      
      _logger.d('Saved speaker profile: ${profile.name}');
    } catch (e) {
      _logger.e('Error saving speaker profile: $e');
    }
  }
  
  /// Delete speaker profile from storage
  Future<void> _deleteSpeakerProfile(String speakerId) async {
    try {
      final directory = await _getSpeakerProfilesDirectory();
      final file = File(path.join(directory.path, '$speakerId.json'));
      
      if (await file.exists()) {
        await file.delete();
        _logger.d('Deleted speaker profile file: $speakerId');
      }
    } catch (e) {
      _logger.e('Error deleting speaker profile: $e');
    }
  }
  
  /// Get speaker profiles directory
  Future<Directory> _getSpeakerProfilesDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final speakerDir = Directory(path.join(appDir.path, 'FlowHunt', 'Voice', 'speakers'));
    
    if (!await speakerDir.exists()) {
      await speakerDir.create(recursive: true);
    }
    
    return speakerDir;
  }
  
  /// Clear all speaker profiles
  Future<void> clearAllSpeakers() async {
    try {
      final directory = await _getSpeakerProfilesDirectory();
      final files = directory.listSync();
      
      for (final file in files) {
        await file.delete();
      }
      
      _speakers.clear();
      _logger.i('Cleared all speaker profiles');
    } catch (e) {
      _logger.e('Error clearing speaker profiles: $e');
    }
  }
  
  /// Get speaker statistics
  Map<String, dynamic> getSpeakerStatistics() {
    final stats = <String, dynamic>{};
    
    stats['total_speakers'] = _speakers.length;
    stats['active_speakers'] = activeSpeakers.length;
    
    if (_speakers.isNotEmpty) {
      final recognitionCounts = _speakers.values.map((s) => s.recognitionCount).toList();
      final averageConfidences = _speakers.values.map((s) => s.averageRecognitionConfidence).toList();
      
      stats['average_recognitions'] = recognitionCounts.reduce((a, b) => a + b) / recognitionCounts.length;
      stats['average_confidence'] = averageConfidences.reduce((a, b) => a + b) / averageConfidences.length;
      stats['most_recognized_speaker'] = _speakers.values.reduce((a, b) => a.recognitionCount > b.recognitionCount ? a : b).name;
    }
    
    return stats;
  }
}