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

// Poll response wrapper
@JsonSerializable()
class PollResponse extends Equatable {
  final List<MessageResponse> messages;

  @JsonKey(name: 'has_more')
  final bool hasMore;

  @JsonKey(name: 'last_message_id')
  final String? lastMessageId;

  @JsonKey(name: 'last_timestamp')
  final int? lastTimestamp;

  const PollResponse({
    required this.messages,
    required this.hasMore,
    this.lastMessageId,
    this.lastTimestamp,
  });

  factory PollResponse.fromJson(Map<String, dynamic> json) =>
      _$PollResponseFromJson(json);

  Map<String, dynamic> toJson() => _$PollResponseToJson(this);

  @override
  List<Object?> get props => [messages, hasMore, lastMessageId, lastTimestamp];
}

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