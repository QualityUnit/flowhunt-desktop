// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flow_assistant.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateSessionRequest _$CreateSessionRequestFromJson(
  Map<String, dynamic> json,
) => CreateSessionRequest(
  flowId: json['flow_id'] as String,
  chatId: json['chat_id'] as String?,
  sessionName: json['session_name'] as String?,
  inputs: json['inputs'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$CreateSessionRequestToJson(
  CreateSessionRequest instance,
) => <String, dynamic>{
  'flow_id': instance.flowId,
  'chat_id': instance.chatId,
  'session_name': instance.sessionName,
  'inputs': instance.inputs,
};

CreateSessionResponse _$CreateSessionResponseFromJson(
  Map<String, dynamic> json,
) => CreateSessionResponse(
  sessionId: json['session_id'] as String,
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$CreateSessionResponseToJson(
  CreateSessionResponse instance,
) => <String, dynamic>{
  'session_id': instance.sessionId,
  'created_at': instance.createdAt.toIso8601String(),
};

SessionResponse _$SessionResponseFromJson(Map<String, dynamic> json) =>
    SessionResponse(
      sessionId: json['session_id'] as String,
      flowId: json['flow_id'] as String?,
      chatId: json['chat_id'] as String?,
      sessionName: json['session_name'] as String?,
      status: json['status'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$SessionResponseToJson(SessionResponse instance) =>
    <String, dynamic>{
      'session_id': instance.sessionId,
      'flow_id': instance.flowId,
      'chat_id': instance.chatId,
      'session_name': instance.sessionName,
      'status': instance.status,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };

InvokeMessageRequest _$InvokeMessageRequestFromJson(
  Map<String, dynamic> json,
) => InvokeMessageRequest(
  message: json['message'] as String,
  messageType: json['message_type'] as String? ?? 'human',
  inputs: json['inputs'] as Map<String, dynamic>?,
  streamResponse: json['stream_response'] as bool?,
);

Map<String, dynamic> _$InvokeMessageRequestToJson(
  InvokeMessageRequest instance,
) => <String, dynamic>{
  'message': instance.message,
  'message_type': instance.messageType,
  'inputs': instance.inputs,
  'stream_response': instance.streamResponse,
};

MessageResponse _$MessageResponseFromJson(Map<String, dynamic> json) =>
    MessageResponse(
      messageId: json['message_id'] as String,
      sessionId: json['session_id'] as String,
      content: json['content'] as String,
      messageType: json['message_type'] as String,
      role: json['role'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$MessageResponseToJson(MessageResponse instance) =>
    <String, dynamic>{
      'message_id': instance.messageId,
      'session_id': instance.sessionId,
      'content': instance.content,
      'message_type': instance.messageType,
      'role': instance.role,
      'created_at': instance.createdAt.toIso8601String(),
      'metadata': instance.metadata,
    };

FlowEvent _$FlowEventFromJson(Map<String, dynamic> json) => FlowEvent(
  workspaceId: json['workspace_id'] as String,
  sessionId: json['session_id'] as String,
  eventId: json['event_id'] as String,
  eventType: json['event_type'] as String,
  createdAtTimestamp: FlowEvent._timestampFromJson(
    json['created_at_timestamp'],
  ),
  actionType: json['action_type'] as String,
  credits: FlowEvent._creditsFromJson(json['credits']),
  metadata: json['metadata'] as Map<String, dynamic>?,
  componentName: json['component_name'] as String?,
);

Map<String, dynamic> _$FlowEventToJson(FlowEvent instance) => <String, dynamic>{
  'workspace_id': instance.workspaceId,
  'session_id': instance.sessionId,
  'event_id': instance.eventId,
  'event_type': instance.eventType,
  'created_at_timestamp': instance.createdAtTimestamp,
  'action_type': instance.actionType,
  'credits': instance.credits,
  'metadata': instance.metadata,
  'component_name': instance.componentName,
};

SessionListResponse _$SessionListResponseFromJson(Map<String, dynamic> json) =>
    SessionListResponse(
      sessions: (json['sessions'] as List<dynamic>)
          .map((e) => SessionResponse.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalCount: (json['total_count'] as num).toInt(),
      pageSize: (json['page_size'] as num).toInt(),
      currentPage: (json['current_page'] as num).toInt(),
    );

Map<String, dynamic> _$SessionListResponseToJson(
  SessionListResponse instance,
) => <String, dynamic>{
  'sessions': instance.sessions,
  'total_count': instance.totalCount,
  'page_size': instance.pageSize,
  'current_page': instance.currentPage,
};
