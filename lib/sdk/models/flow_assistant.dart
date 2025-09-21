import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'flow_assistant.g.dart';

// Session creation request
@JsonSerializable()
class CreateSessionRequest extends Equatable {
  @JsonKey(name: 'flow_id')
  final String flowId;

  @JsonKey(name: 'chat_id')
  final String? chatId;

  @JsonKey(name: 'session_name')
  final String? sessionName;

  final Map<String, dynamic>? inputs;

  const CreateSessionRequest({
    required this.flowId,
    this.chatId,
    this.sessionName,
    this.inputs,
  });

  factory CreateSessionRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateSessionRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CreateSessionRequestToJson(this);

  @override
  List<Object?> get props => [flowId, chatId, sessionName, inputs];
}

// Session creation response - minimal response from API
@JsonSerializable()
class CreateSessionResponse extends Equatable {
  @JsonKey(name: 'session_id')
  final String sessionId;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  const CreateSessionResponse({
    required this.sessionId,
    required this.createdAt,
  });

  factory CreateSessionResponse.fromJson(Map<String, dynamic> json) =>
      _$CreateSessionResponseFromJson(json);

  Map<String, dynamic> toJson() => _$CreateSessionResponseToJson(this);

  @override
  List<Object?> get props => [sessionId, createdAt];
}

// Session response - full session details
@JsonSerializable()
class SessionResponse extends Equatable {
  @JsonKey(name: 'session_id')
  final String sessionId;

  @JsonKey(name: 'flow_id')
  final String? flowId;

  @JsonKey(name: 'chat_id')
  final String? chatId;

  @JsonKey(name: 'session_name')
  final String? sessionName;

  final String? status;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  const SessionResponse({
    required this.sessionId,
    this.flowId,
    this.chatId,
    this.sessionName,
    this.status,
    required this.createdAt,
    this.updatedAt,
  });

  factory SessionResponse.fromJson(Map<String, dynamic> json) =>
      _$SessionResponseFromJson(json);

  Map<String, dynamic> toJson() => _$SessionResponseToJson(this);

  @override
  List<Object?> get props => [
        sessionId,
        flowId,
        chatId,
        sessionName,
        status,
        createdAt,
        updatedAt,
      ];
}

// Message invocation request
@JsonSerializable()
class InvokeMessageRequest extends Equatable {
  final String message;

  @JsonKey(name: 'message_type')
  final String messageType;

  final Map<String, dynamic>? inputs;

  @JsonKey(name: 'stream_response')
  final bool? streamResponse;

  const InvokeMessageRequest({
    required this.message,
    this.messageType = 'human',
    this.inputs,
    this.streamResponse,
  });

  factory InvokeMessageRequest.fromJson(Map<String, dynamic> json) =>
      _$InvokeMessageRequestFromJson(json);

  Map<String, dynamic> toJson() => _$InvokeMessageRequestToJson(this);

  @override
  List<Object?> get props => [message, messageType, inputs, streamResponse];
}

// Message response
@JsonSerializable()
class MessageResponse extends Equatable {
  @JsonKey(name: 'message_id')
  final String messageId;

  @JsonKey(name: 'session_id')
  final String sessionId;

  final String content;

  @JsonKey(name: 'message_type')
  final String messageType;

  final String? role;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  final Map<String, dynamic>? metadata;

  const MessageResponse({
    required this.messageId,
    required this.sessionId,
    required this.content,
    required this.messageType,
    this.role,
    required this.createdAt,
    this.metadata,
  });

  factory MessageResponse.fromJson(Map<String, dynamic> json) =>
      _$MessageResponseFromJson(json);

  Map<String, dynamic> toJson() => _$MessageResponseToJson(this);

  @override
  List<Object?> get props => [
        messageId,
        sessionId,
        content,
        messageType,
        role,
        createdAt,
        metadata,
      ];
}

// Event from polling response
@JsonSerializable()
class FlowEvent extends Equatable {
  @JsonKey(name: 'workspace_id')
  final String workspaceId;

  @JsonKey(name: 'session_id')
  final String sessionId;

  @JsonKey(name: 'event_id')
  final String eventId;

  @JsonKey(name: 'event_type')
  final String eventType;

  @JsonKey(name: 'created_at_timestamp', fromJson: _timestampFromJson)
  final int createdAtTimestamp;

  static int _timestampFromJson(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  @JsonKey(name: 'action_type')
  final String actionType;

  @JsonKey(fromJson: _creditsFromJson)
  final double? credits;

  static double? _creditsFromJson(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  final Map<String, dynamic>? metadata;

  @JsonKey(name: 'component_name')
  final String? componentName;

  const FlowEvent({
    required this.workspaceId,
    required this.sessionId,
    required this.eventId,
    required this.eventType,
    required this.createdAtTimestamp,
    required this.actionType,
    this.credits,
    this.metadata,
    this.componentName,
  });

  factory FlowEvent.fromJson(Map<String, dynamic> json) =>
      _$FlowEventFromJson(json);

  Map<String, dynamic> toJson() => _$FlowEventToJson(this);

  @override
  List<Object?> get props => [
        workspaceId,
        sessionId,
        eventId,
        eventType,
        createdAtTimestamp,
        actionType,
        credits,
        metadata,
        componentName,
      ];

  // Convert to ChatMessage for UI
  ChatMessage? toChatMessage() {
    if (actionType != 'message') return null;

    final messageContent = metadata?['message'] as String?;
    if (messageContent == null) return null;

    // Parse the message content if it's in FlowHunt format
    String displayMessage = messageContent;
    if (messageContent.contains('```flowhunt')) {
      // Extract the JSON content
      final startIdx = messageContent.indexOf('```flowhunt') + 11;
      final endIdx = messageContent.lastIndexOf('```');
      if (startIdx < endIdx) {
        try {
          final jsonStr = messageContent.substring(startIdx, endIdx).trim();
          final jsonData = json.decode(jsonStr) as Map<String, dynamic>;
          displayMessage = jsonData['message'] as String? ?? messageContent;
        } catch (e) {
          // If parsing fails, use the original message
          displayMessage = messageContent;
        }
      }
    }

    return ChatMessage(
      id: eventId,
      content: displayMessage,
      type: _parseMessageType(eventType),
      timestamp: DateTime.fromMillisecondsSinceEpoch(createdAtTimestamp),
      metadata: metadata,
    );
  }

  MessageType _parseMessageType(String type) {
    switch (type.toLowerCase()) {
      case 'human':
        return MessageType.human;
      case 'ai':
      case 'assistant':
        return MessageType.ai;
      case 'system':
        return MessageType.system;
      case 'error':
        return MessageType.error;
      default:
        return MessageType.system;
    }
  }
}

// Poll response wrapper - actual response is just an array
typedef PollResponse = List<FlowEvent>;

// Session list response
@JsonSerializable()
class SessionListResponse extends Equatable {
  final List<SessionResponse> sessions;

  @JsonKey(name: 'total_count')
  final int totalCount;

  @JsonKey(name: 'page_size')
  final int pageSize;

  @JsonKey(name: 'current_page')
  final int currentPage;

  const SessionListResponse({
    required this.sessions,
    required this.totalCount,
    required this.pageSize,
    required this.currentPage,
  });

  factory SessionListResponse.fromJson(Map<String, dynamic> json) =>
      _$SessionListResponseFromJson(json);

  Map<String, dynamic> toJson() => _$SessionListResponseToJson(this);

  @override
  List<Object?> get props => [sessions, totalCount, pageSize, currentPage];
}

// Chat message for UI
class ChatMessage extends Equatable {
  final String id;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final bool isLoading;
  final Map<String, dynamic>? metadata;

  const ChatMessage({
    required this.id,
    required this.content,
    required this.type,
    required this.timestamp,
    this.isLoading = false,
    this.metadata,
  });

  ChatMessage copyWith({
    String? id,
    String? content,
    MessageType? type,
    DateTime? timestamp,
    bool? isLoading,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isLoading: isLoading ?? this.isLoading,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  List<Object?> get props => [id, content, type, timestamp, isLoading, metadata];
}

enum MessageType {
  human,
  ai,
  system,
  error,
  loading,
}

// Extension to convert API response to UI model
extension MessageResponseExtension on MessageResponse {
  ChatMessage toChatMessage() {
    return ChatMessage(
      id: messageId,
      content: content,
      type: _parseMessageType(messageType),
      timestamp: createdAt,
      metadata: metadata,
    );
  }

  MessageType _parseMessageType(String type) {
    switch (type.toLowerCase()) {
      case 'human':
        return MessageType.human;
      case 'ai':
      case 'assistant':
        return MessageType.ai;
      case 'system':
        return MessageType.system;
      case 'error':
        return MessageType.error;
      default:
        return MessageType.system;
    }
  }
}