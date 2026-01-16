import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';

part 'flow.g.dart';

@JsonSerializable()
class FlowSearchRequest {
  final int? limit;
  final int? offset;

  FlowSearchRequest({
    this.limit,
    this.offset,
  });

  factory FlowSearchRequest.fromJson(Map<String, dynamic> json) =>
      _$FlowSearchRequestFromJson(json);

  Map<String, dynamic> toJson() => _$FlowSearchRequestToJson(this);
}

@JsonSerializable()
class FlowResponse {
  @JsonKey(name: 'id')
  final String? flowId;

  final String? name;
  final String? description;

  @JsonKey(name: 'category_id')
  final String? catId;

  @JsonKey(name: 'flow_type')
  final String? flowType;

  @JsonKey(name: 'component_count')
  final int? componentCount;

  @JsonKey(name: 'executed_at')
  final String? executedAt;

  @JsonKey(name: 'enable_cache')
  final bool? enableCache;

  @JsonKey(name: 'last_modified')
  final String? lastModified;

  @JsonKey(name: 'chatbot_id')
  final String? chatbotId;

  FlowResponse({
    this.flowId,
    this.name,
    this.description,
    this.catId,
    this.flowType,
    this.componentCount,
    this.executedAt,
    this.enableCache,
    this.lastModified,
    this.chatbotId,
  });

  factory FlowResponse.fromJson(Map<String, dynamic> json) =>
      _$FlowResponseFromJson(json);

  Map<String, dynamic> toJson() => _$FlowResponseToJson(this);
}

@JsonSerializable()
class FlowInvokeRequest {
  @JsonKey(name: 'flow_input')
  final Map<String, dynamic> flowInput;

  @JsonKey(name: 'stream_response')
  final bool? streamResponse;

  FlowInvokeRequest({
    required this.flowInput,
    this.streamResponse,
  });

  factory FlowInvokeRequest.fromJson(Map<String, dynamic> json) =>
      _$FlowInvokeRequestFromJson(json);

  Map<String, dynamic> toJson() => _$FlowInvokeRequestToJson(this);
}

@JsonSerializable()
class TaskResponse {
  final String? id;

  final String? status;

  @JsonKey(name: 'result', fromJson: _resultFromJson)
  final dynamic result;

  @JsonKey(name: 'error_message')
  final String? errorMessage;

  TaskResponse({
    this.id,
    this.status,
    this.result,
    this.errorMessage,
  });

  static dynamic _resultFromJson(dynamic json) {
    // Handle both String and Map types
    if (json is String || json is Map<String, dynamic> || json == null) {
      return json;
    }
    return json;
  }

  factory TaskResponse.fromJson(Map<String, dynamic> json) {
    // Handle both 'id' and 'task_id' fields (singleton API may return 'task_id')
    // Use the generated function and override id if needed
    final taskResponse = _$TaskResponseFromJson(json);
    final id = json['id'] as String? ?? json['task_id'] as String?;
    return TaskResponse(
      id: id ?? taskResponse.id,
      status: taskResponse.status,
      result: taskResponse.result,
      errorMessage: taskResponse.errorMessage,
    );
  }

  Map<String, dynamic> toJson() => _$TaskResponseToJson(this);

  // Helper getters for backwards compatibility
  String? get taskId => id;

  // Extract the AI answer from the result - only use ai_answer field
  String? get aiAnswer {
    if (result == null) return null;

    try {
      Map<String, dynamic> resultMap;

      // If result is a String, decode it as JSON
      if (result is String) {
        resultMap = json.decode(result as String) as Map<String, dynamic>;
      }
      // If result is already a Map, use it directly
      else if (result is Map<String, dynamic>) {
        resultMap = result as Map<String, dynamic>;
      } else {
        return null;
      }

      // Only use the ai_answer field from the result
      if (resultMap.containsKey('ai_answer')) {
        return resultMap['ai_answer'] as String?;
      }

      return null;
    } catch (e) {
      // If JSON parsing fails, return the raw result if it's a string
      if (result is String) return result as String;
      return null;
    }
  }

  // Extract outputs array if needed
  List<dynamic>? get outputs {
    if (result == null || result is! Map<String, dynamic>) return null;
    final resultData = result['outputs'];
    if (resultData is List) return resultData;
    return null;
  }

  // Extract credits from the result (credits divided by 1000000)
  double? get credits {
    if (result == null) return null;

    try {
      Map<String, dynamic> resultMap;

      // If result is a String, decode it as JSON
      if (result is String) {
        resultMap = json.decode(result as String) as Map<String, dynamic>;
      }
      // If result is already a Map, use it directly
      else if (result is Map<String, dynamic>) {
        resultMap = result as Map<String, dynamic>;
      } else {
        return null;
      }

      // Extract credits field
      if (resultMap.containsKey('credits')) {
        final creditsValue = resultMap['credits'];
        if (creditsValue is num) {
          return creditsValue / 1000000.0;
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }
}

// Flow Session Models
@JsonSerializable()
class FlowSessionResponse {
  @JsonKey(name: 'session_id')
  final String? sessionId;

  @JsonKey(name: 'flow_id')
  final String? flowId;

  @JsonKey(name: 'created_at')
  final String? createdAt;

  final String? status;

  FlowSessionResponse({
    this.sessionId,
    this.flowId,
    this.createdAt,
    this.status,
  });

  factory FlowSessionResponse.fromJson(Map<String, dynamic> json) =>
      _$FlowSessionResponseFromJson(json);

  Map<String, dynamic> toJson() => _$FlowSessionResponseToJson(this);
}

@JsonSerializable()
class SessionInvokeResponse {
  @JsonKey(name: 'session_id')
  final String? sessionId;

  final String? status;

  @JsonKey(name: 'message_id')
  final String? messageId;

  SessionInvokeResponse({
    this.sessionId,
    this.status,
    this.messageId,
  });

  factory SessionInvokeResponse.fromJson(Map<String, dynamic> json) =>
      _$SessionInvokeResponseFromJson(json);

  Map<String, dynamic> toJson() => _$SessionInvokeResponseToJson(this);
}

@JsonSerializable()
class SessionMessage {
  @JsonKey(name: 'event_id')
  final String? eventId;

  @JsonKey(name: 'event_type')
  final String? eventType;

  @JsonKey(name: 'created_at_timestamp', fromJson: _timestampFromJson)
  final int? createdAtTimestamp;

  @JsonKey(name: 'action_type')
  final String? actionType;

  final double? credits;

  final dynamic metadata;

  @JsonKey(name: 'component_name')
  final String? componentName;

  @JsonKey(name: 'workspace_id')
  final String? workspaceId;

  @JsonKey(name: 'session_id')
  final String? sessionId;

  SessionMessage({
    this.eventId,
    this.eventType,
    this.createdAtTimestamp,
    this.actionType,
    this.credits,
    this.metadata,
    this.componentName,
    this.workspaceId,
    this.sessionId,
  });

  // Custom converter to handle both String and int for timestamp
  static int? _timestampFromJson(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value);
    }
    if (value is num) return value.toInt();
    return null;
  }

  factory SessionMessage.fromJson(Map<String, dynamic> json) =>
      _$SessionMessageFromJson(json);

  Map<String, dynamic> toJson() => _$SessionMessageToJson(this);

  // Helper to get timestamp for polling
  String? get timestamp => createdAtTimestamp?.toString();
}

@JsonSerializable()
class SessionInvocationResponse {
  final List<SessionMessage>? messages;

  @JsonKey(name: 'has_more')
  final bool? hasMore;

  @JsonKey(name: 'last_timestamp')
  final int? lastTimestamp;

  SessionInvocationResponse({
    this.messages,
    this.hasMore,
    this.lastTimestamp,
  });

  factory SessionInvocationResponse.fromJson(Map<String, dynamic> json) =>
      _$SessionInvocationResponseFromJson(json);

  Map<String, dynamic> toJson() => _$SessionInvocationResponseToJson(this);
}
