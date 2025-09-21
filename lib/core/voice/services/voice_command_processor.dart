import 'package:logger/logger.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';

import '../models/voice_command.dart';

/// Service responsible for processing and matching voice commands
class VoiceCommandProcessor {
  final Logger _logger = Logger();
  
  /// Pre-defined voice commands with multi-language support
  static final List<VoiceCommand> _defaultCommands = [
    // Chat navigation commands
    VoiceCommand(
      type: VoiceCommandType.newChat,
      patterns: ['new chat', 'start new chat', 'create chat'],
      alternatives: ['new conversation', 'fresh chat', 'begin chat'],
      languagePatterns: {
        'es': ['nuevo chat', 'nueva conversación', 'empezar chat'],
        'fr': ['nouveau chat', 'nouvelle conversation', 'commencer chat'],
        'de': ['neuer chat', 'neues gespräch', 'chat beginnen'],
        'zh': ['新聊天', '开始新聊天', '创建聊天'],
        'ja': ['新しいチャット', 'チャット開始', 'チャット作成'],
      },
      description: 'Start a new chat conversation',
      availableDuringRecording: false,
    ),
    
    VoiceCommand(
      type: VoiceCommandType.clearChat,
      patterns: ['clear chat', 'delete chat', 'reset chat'],
      alternatives: ['clean chat', 'remove chat', 'erase chat'],
      languagePatterns: {
        'es': ['limpiar chat', 'borrar chat', 'resetear chat'],
        'fr': ['effacer chat', 'supprimer chat', 'nettoyer chat'],
        'de': ['chat löschen', 'chat leeren', 'chat zurücksetzen'],
        'zh': ['清除聊天', '删除聊天', '重置聊天'],
        'ja': ['チャットクリア', 'チャット削除', 'チャットリセット'],
      },
      description: 'Clear the current chat conversation',
      requiresConfirmation: true,
      availableDuringRecording: false,
    ),
    
    VoiceCommand(
      type: VoiceCommandType.sendMessage,
      patterns: ['send message', 'send', 'submit'],
      alternatives: ['post message', 'deliver message', 'transmit'],
      languagePatterns: {
        'es': ['enviar mensaje', 'enviar', 'mandar'],
        'fr': ['envoyer message', 'envoyer', 'transmettre'],
        'de': ['nachricht senden', 'senden', 'übermitteln'],
        'zh': ['发送消息', '发送', '提交'],
        'ja': ['メッセージ送信', '送信', '投稿'],
      },
      description: 'Send the current message',
      availableDuringRecording: false,
    ),
    
    // Scroll and navigation commands
    VoiceCommand(
      type: VoiceCommandType.scrollUp,
      patterns: ['scroll up', 'move up', 'go up'],
      alternatives: ['page up', 'scroll back', 'move back'],
      languagePatterns: {
        'es': ['desplazar arriba', 'subir', 'ir arriba'],
        'fr': ['défiler haut', 'monter', 'aller haut'],
        'de': ['nach oben scrollen', 'hochscrollen', 'nach oben'],
        'zh': ['向上滚动', '上移', '往上'],
        'ja': ['上にスクロール', '上に移動', '上へ'],
      },
      description: 'Scroll up in the current view',
    ),
    
    VoiceCommand(
      type: VoiceCommandType.scrollDown,
      patterns: ['scroll down', 'move down', 'go down'],
      alternatives: ['page down', 'scroll forward', 'move forward'],
      languagePatterns: {
        'es': ['desplazar abajo', 'bajar', 'ir abajo'],
        'fr': ['défiler bas', 'descendre', 'aller bas'],
        'de': ['nach unten scrollen', 'runterscrollen', 'nach unten'],
        'zh': ['向下滚动', '下移', '往下'],
        'ja': ['下にスクロール', '下に移動', '下へ'],
      },
      description: 'Scroll down in the current view',
    ),
    
    VoiceCommand(
      type: VoiceCommandType.goToTop,
      patterns: ['go to top', 'scroll to top', 'top'],
      alternatives: ['beginning', 'start', 'first'],
      languagePatterns: {
        'es': ['ir al principio', 'subir al inicio', 'principio'],
        'fr': ['aller au début', 'défiler au début', 'début'],
        'de': ['zum anfang', 'nach oben scrollen', 'anfang'],
        'zh': ['到顶部', '滚动到顶部', '顶部'],
        'ja': ['トップへ', '最初へ', '上部へ'],
      },
      description: 'Scroll to the top of the current view',
    ),
    
    VoiceCommand(
      type: VoiceCommandType.goToBottom,
      patterns: ['go to bottom', 'scroll to bottom', 'bottom'],
      alternatives: ['end', 'last', 'final'],
      languagePatterns: {
        'es': ['ir al final', 'bajar al final', 'final'],
        'fr': ['aller à la fin', 'défiler à la fin', 'fin'],
        'de': ['zum ende', 'nach unten scrollen', 'ende'],
        'zh': ['到底部', '滚动到底部', '底部'],
        'ja': ['ボトムへ', '最後へ', '下部へ'],
      },
      description: 'Scroll to the bottom of the current view',
    ),
    
    // Recording control commands
    VoiceCommand(
      type: VoiceCommandType.stopRecording,
      patterns: ['stop recording', 'stop', 'finish recording'],
      alternatives: ['end recording', 'halt recording', 'cease recording'],
      languagePatterns: {
        'es': ['parar grabación', 'detener', 'finalizar grabación'],
        'fr': ['arrêter enregistrement', 'arrêter', 'finir enregistrement'],
        'de': ['aufnahme stoppen', 'stoppen', 'aufnahme beenden'],
        'zh': ['停止录音', '停止', '结束录音'],
        'ja': ['録音停止', '停止', '録音終了'],
      },
      description: 'Stop the current voice recording',
      availableDuringRecording: true,
    ),
    
    VoiceCommand(
      type: VoiceCommandType.startRecording,
      patterns: ['start recording', 'begin recording', 'record'],
      alternatives: ['commence recording', 'initiate recording', 'capture'],
      languagePatterns: {
        'es': ['iniciar grabación', 'empezar grabación', 'grabar'],
        'fr': ['commencer enregistrement', 'débuter enregistrement', 'enregistrer'],
        'de': ['aufnahme starten', 'aufnahme beginnen', 'aufnehmen'],
        'zh': ['开始录音', '开始录制', '录音'],
        'ja': ['録音開始', '録音始める', '録音'],
      },
      description: 'Start voice recording',
      availableDuringRecording: false,
    ),
    
    VoiceCommand(
      type: VoiceCommandType.cancelRecording,
      patterns: ['cancel recording', 'cancel', 'abort recording'],
      alternatives: ['discard recording', 'abandon recording', 'dismiss recording'],
      languagePatterns: {
        'es': ['cancelar grabación', 'cancelar', 'abortar grabación'],
        'fr': ['annuler enregistrement', 'annuler', 'abandonner enregistrement'],
        'de': ['aufnahme abbrechen', 'abbrechen', 'aufnahme verwerfen'],
        'zh': ['取消录音', '取消', '中止录音'],
        'ja': ['録音キャンセル', 'キャンセル', '録音中止'],
      },
      description: 'Cancel the current voice recording',
      availableDuringRecording: true,
    ),
    
    // General application commands
    VoiceCommand(
      type: VoiceCommandType.help,
      patterns: ['help', 'show help', 'commands'],
      alternatives: ['assistance', 'support', 'what can you do'],
      languagePatterns: {
        'es': ['ayuda', 'mostrar ayuda', 'comandos'],
        'fr': ['aide', 'afficher aide', 'commandes'],
        'de': ['hilfe', 'hilfe anzeigen', 'befehle'],
        'zh': ['帮助', '显示帮助', '命令'],
        'ja': ['ヘルプ', 'ヘルプ表示', 'コマンド'],
      },
      description: 'Show available voice commands',
    ),
    
    VoiceCommand(
      type: VoiceCommandType.settings,
      patterns: ['settings', 'preferences', 'options'],
      alternatives: ['configuration', 'setup', 'config'],
      languagePatterns: {
        'es': ['configuración', 'preferencias', 'opciones'],
        'fr': ['paramètres', 'préférences', 'options'],
        'de': ['einstellungen', 'präferenzen', 'optionen'],
        'zh': ['设置', '偏好', '选项'],
        'ja': ['設定', '環境設定', 'オプション'],
      },
      description: 'Open application settings',
      availableDuringRecording: false,
    ),
  ];
  
  final List<VoiceCommand> _commands = [..._defaultCommands];
  String _currentLanguage = 'en';
  bool _isRecording = false;

  /// Get all available commands
  List<VoiceCommand> get commands => List.unmodifiable(_commands);
  
  /// Get current language
  String get currentLanguage => _currentLanguage;
  
  /// Set current language for command matching
  void setLanguage(String languageCode) {
    _currentLanguage = languageCode;
    _logger.i('Voice command language set to: $languageCode');
  }
  
  /// Set recording state to filter available commands
  void setRecordingState(bool isRecording) {
    _isRecording = isRecording;
  }
  
  /// Add custom command
  void addCommand(VoiceCommand command) {
    _commands.add(command);
    _logger.d('Added custom voice command: ${command.type}');
  }
  
  /// Remove custom command
  void removeCommand(VoiceCommandType type) {
    _commands.removeWhere((cmd) => cmd.type == type);
    _logger.d('Removed voice command: $type');
  }
  
  /// Process input text and find matching command
  VoiceCommandMatch? processCommand(String inputText) {
    if (inputText.isEmpty) return null;
    
    final normalizedInput = _normalizeText(inputText);
    _logger.d('Processing voice command: "$normalizedInput"');
    
    // Filter commands based on recording state
    final availableCommands = _commands.where((cmd) {
      return _isRecording ? cmd.availableDuringRecording : true;
    }).toList();
    
    VoiceCommandMatch? bestMatch;
    double bestScore = 0.0;
    
    for (final command in availableCommands) {
      final match = _matchCommand(command, normalizedInput);
      if (match != null && match.confidence > bestScore) {
        bestMatch = match;
        bestScore = match.confidence;
      }
    }
    
    if (bestMatch != null) {
      _logger.i('Found voice command match: ${bestMatch.command.type} (confidence: ${bestMatch.confidence})');
    } else {
      _logger.d('No voice command match found for: "$normalizedInput"');
    }
    
    return bestMatch;
  }
  
  /// Match a specific command against input text
  VoiceCommandMatch? _matchCommand(VoiceCommand command, String inputText) {
    final patterns = command.getAllPatterns(_currentLanguage);
    
    // First, try exact matches
    for (final pattern in patterns) {
      final normalizedPattern = _normalizeText(pattern);
      if (normalizedPattern == inputText) {
        return VoiceCommandMatch(
          command: command,
          confidence: 1.0,
          inputText: inputText,
          matchedPattern: pattern,
          isExactMatch: true,
        );
      }
    }
    
    // Then try fuzzy matches
    double bestRatio = 0.0;
    String bestPattern = '';
    
    for (final pattern in patterns) {
      final normalizedPattern = _normalizeText(pattern);
      final matchRatio = ratio(inputText, normalizedPattern) / 100.0;
      
      if (matchRatio > bestRatio) {
        bestRatio = matchRatio;
        bestPattern = pattern;
      }
      
      // Also check if input contains the pattern or vice versa
      if (inputText.contains(normalizedPattern) || normalizedPattern.contains(inputText)) {
        final containsRatio = _calculateContainsRatio(inputText, normalizedPattern);
        if (containsRatio > bestRatio) {
          bestRatio = containsRatio;
          bestPattern = pattern;
        }
      }
    }
    
    // Return match if confidence is above threshold
    if (bestRatio >= command.minConfidence) {
      return VoiceCommandMatch(
        command: command,
        confidence: bestRatio,
        inputText: inputText,
        matchedPattern: bestPattern,
        isExactMatch: false,
        parameters: _extractParameters(inputText, bestPattern),
      );
    }
    
    return null;
  }
  
  /// Normalize text for better matching
  String _normalizeText(String text) {
    return text
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove punctuation
        .replaceAll(RegExp(r'\s+'), ' '); // Normalize whitespace
  }
  
  /// Calculate ratio for contains matching
  double _calculateContainsRatio(String input, String pattern) {
    if (input.isEmpty || pattern.isEmpty) return 0.0;
    
    if (input.contains(pattern)) {
      return pattern.length / input.length;
    } else if (pattern.contains(input)) {
      return input.length / pattern.length;
    }
    
    return 0.0;
  }
  
  /// Extract parameters from input text
  Map<String, dynamic> _extractParameters(String input, String pattern) {
    final parameters = <String, dynamic>{};
    
    // Basic parameter extraction - can be enhanced based on needs
    // For example, extracting numbers, names, etc.
    final words = input.split(' ');
    final patternWords = pattern.split(' ');
    
    // Find words in input that are not in pattern (potential parameters)
    final extraWords = words.where((word) => 
        !patternWords.any((pWord) => pWord.toLowerCase() == word.toLowerCase())
    ).toList();
    
    if (extraWords.isNotEmpty) {
      parameters['extra_words'] = extraWords;
    }
    
    return parameters;
  }
  
  /// Get help text for all available commands
  String getHelpText({String? language}) {
    final lang = language ?? _currentLanguage;
    final buffer = StringBuffer();
    buffer.writeln('Available Voice Commands:');
    buffer.writeln('========================');
    
    final groupedCommands = <String, List<VoiceCommand>>{};
    
    for (final command in _commands) {
      String category;
      switch (command.type) {
        case VoiceCommandType.newChat:
        case VoiceCommandType.clearChat:
        case VoiceCommandType.sendMessage:
          category = 'Chat Navigation';
          break;
        case VoiceCommandType.scrollUp:
        case VoiceCommandType.scrollDown:
        case VoiceCommandType.goToTop:
        case VoiceCommandType.goToBottom:
          category = 'Scroll & Navigation';
          break;
        case VoiceCommandType.startRecording:
        case VoiceCommandType.stopRecording:
        case VoiceCommandType.cancelRecording:
          category = 'Recording Control';
          break;
        default:
          category = 'General';
      }
      
      groupedCommands.putIfAbsent(category, () => []).add(command);
    }
    
    for (final category in groupedCommands.keys) {
      buffer.writeln('\n$category:');
      for (final command in groupedCommands[category]!) {
        final patterns = command.getPatternsForLanguage(lang);
        buffer.writeln('  • ${patterns.first} - ${command.description}');
      }
    }
    
    return buffer.toString();
  }
  
  /// Get commands by category
  List<VoiceCommand> getCommandsByType(List<VoiceCommandType> types) {
    return _commands.where((cmd) => types.contains(cmd.type)).toList();
  }
}