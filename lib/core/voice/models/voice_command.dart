import 'package:equatable/equatable.dart';

/// Enum representing different types of voice commands
enum VoiceCommandType {
  /// Chat navigation commands
  newChat,
  clearChat,
  sendMessage,
  
  /// Scroll and navigation commands
  scrollUp,
  scrollDown,
  goToTop,
  goToBottom,
  
  /// Recording control commands
  stopRecording,
  startRecording,
  cancelRecording,
  
  /// General application commands
  help,
  settings,
  close,
  minimize,
  
  /// Unknown command
  unknown,
}

/// Represents a voice command with its pattern and metadata
class VoiceCommand extends Equatable {
  /// The type of command
  final VoiceCommandType type;
  
  /// Primary command patterns (exact matches)
  final List<String> patterns;
  
  /// Alternative patterns (fuzzy matches)
  final List<String> alternatives;
  
  /// Minimum confidence score for fuzzy matching (0.0 - 1.0)
  final double minConfidence;
  
  /// Language-specific patterns
  final Map<String, List<String>> languagePatterns;
  
  /// Whether this command requires confirmation
  final bool requiresConfirmation;
  
  /// Command description for help system
  final String description;
  
  /// Whether this command can be executed while recording
  final bool availableDuringRecording;

  const VoiceCommand({
    required this.type,
    required this.patterns,
    this.alternatives = const [],
    this.minConfidence = 0.7,
    this.languagePatterns = const {},
    this.requiresConfirmation = false,
    required this.description,
    this.availableDuringRecording = true,
  });

  /// Get patterns for a specific language, fallback to default patterns
  List<String> getPatternsForLanguage(String languageCode) {
    return languagePatterns[languageCode] ?? patterns;
  }
  
  /// Get all possible patterns including alternatives
  List<String> getAllPatterns([String? languageCode]) {
    final basePatterns = languageCode != null 
        ? getPatternsForLanguage(languageCode)
        : patterns;
    return [...basePatterns, ...alternatives];
  }

  @override
  List<Object?> get props => [
        type,
        patterns,
        alternatives,
        minConfidence,
        languagePatterns,
        requiresConfirmation,
        description,
        availableDuringRecording,
      ];
}

/// Result of voice command matching
class VoiceCommandMatch extends Equatable {
  /// The matched command
  final VoiceCommand command;
  
  /// Confidence score (0.0 - 1.0)
  final double confidence;
  
  /// The original input text that was matched
  final String inputText;
  
  /// The specific pattern that was matched
  final String matchedPattern;
  
  /// Whether this was an exact or fuzzy match
  final bool isExactMatch;
  
  /// Additional parameters extracted from the input
  final Map<String, dynamic> parameters;

  const VoiceCommandMatch({
    required this.command,
    required this.confidence,
    required this.inputText,
    required this.matchedPattern,
    required this.isExactMatch,
    this.parameters = const {},
  });

  @override
  List<Object?> get props => [
        command,
        confidence,
        inputText,
        matchedPattern,
        isExactMatch,
        parameters,
      ];
}

/// Command execution result
class VoiceCommandResult extends Equatable {
  /// Whether the command was executed successfully
  final bool success;
  
  /// Result message
  final String message;
  
  /// The command that was executed
  final VoiceCommand command;
  
  /// Any data returned from command execution
  final Map<String, dynamic> data;
  
  /// Error details if execution failed
  final String? error;

  const VoiceCommandResult({
    required this.success,
    required this.message,
    required this.command,
    this.data = const {},
    this.error,
  });

  @override
  List<Object?> get props => [success, message, command, data, error];
}