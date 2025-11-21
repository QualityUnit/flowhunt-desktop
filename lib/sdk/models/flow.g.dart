// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flow.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FlowSearchRequest _$FlowSearchRequestFromJson(Map<String, dynamic> json) =>
    FlowSearchRequest(
      limit: (json['limit'] as num?)?.toInt(),
      offset: (json['offset'] as num?)?.toInt(),
    );

Map<String, dynamic> _$FlowSearchRequestToJson(FlowSearchRequest instance) =>
    <String, dynamic>{'limit': instance.limit, 'offset': instance.offset};

FlowResponse _$FlowResponseFromJson(Map<String, dynamic> json) => FlowResponse(
  flowId: json['id'] as String?,
  name: json['name'] as String?,
  description: json['description'] as String?,
  catId: json['category_id'] as String?,
  flowType: json['flow_type'] as String?,
  componentCount: (json['component_count'] as num?)?.toInt(),
  executedAt: json['executed_at'] as String?,
  enableCache: json['enable_cache'] as bool?,
  lastModified: json['last_modified'] as String?,
  chatbotId: json['chatbot_id'] as String?,
);

Map<String, dynamic> _$FlowResponseToJson(FlowResponse instance) =>
    <String, dynamic>{
      'id': instance.flowId,
      'name': instance.name,
      'description': instance.description,
      'category_id': instance.catId,
      'flow_type': instance.flowType,
      'component_count': instance.componentCount,
      'executed_at': instance.executedAt,
      'enable_cache': instance.enableCache,
      'last_modified': instance.lastModified,
      'chatbot_id': instance.chatbotId,
    };

FlowInvokeRequest _$FlowInvokeRequestFromJson(Map<String, dynamic> json) =>
    FlowInvokeRequest(
      flowInput: json['flow_input'] as Map<String, dynamic>,
      streamResponse: json['stream_response'] as bool?,
    );

Map<String, dynamic> _$FlowInvokeRequestToJson(FlowInvokeRequest instance) =>
    <String, dynamic>{
      'flow_input': instance.flowInput,
      'stream_response': instance.streamResponse,
    };

TaskResponse _$TaskResponseFromJson(Map<String, dynamic> json) => TaskResponse(
  id: json['id'] as String?,
  status: json['status'] as String?,
  result: TaskResponse._resultFromJson(json['result']),
  errorMessage: json['error_message'] as String?,
);

Map<String, dynamic> _$TaskResponseToJson(TaskResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'status': instance.status,
      'result': instance.result,
      'error_message': instance.errorMessage,
    };

FlowSessionResponse _$FlowSessionResponseFromJson(Map<String, dynamic> json) =>
    FlowSessionResponse(
      sessionId: json['session_id'] as String?,
      flowId: json['flow_id'] as String?,
      createdAt: json['created_at'] as String?,
      status: json['status'] as String?,
    );

Map<String, dynamic> _$FlowSessionResponseToJson(
  FlowSessionResponse instance,
) => <String, dynamic>{
  'session_id': instance.sessionId,
  'flow_id': instance.flowId,
  'created_at': instance.createdAt,
  'status': instance.status,
};

SessionInvokeResponse _$SessionInvokeResponseFromJson(
  Map<String, dynamic> json,
) => SessionInvokeResponse(
  sessionId: json['session_id'] as String?,
  status: json['status'] as String?,
  messageId: json['message_id'] as String?,
);

Map<String, dynamic> _$SessionInvokeResponseToJson(
  SessionInvokeResponse instance,
) => <String, dynamic>{
  'session_id': instance.sessionId,
  'status': instance.status,
  'message_id': instance.messageId,
};

SessionMessage _$SessionMessageFromJson(Map<String, dynamic> json) =>
    SessionMessage(
      eventId: json['event_id'] as String?,
      eventType: json['event_type'] as String?,
      createdAtTimestamp: SessionMessage._timestampFromJson(
        json['created_at_timestamp'],
      ),
      actionType: json['action_type'] as String?,
      credits: (json['credits'] as num?)?.toDouble(),
      metadata: json['metadata'],
      componentName: json['component_name'] as String?,
      workspaceId: json['workspace_id'] as String?,
      sessionId: json['session_id'] as String?,
    );

Map<String, dynamic> _$SessionMessageToJson(SessionMessage instance) =>
    <String, dynamic>{
      'event_id': instance.eventId,
      'event_type': instance.eventType,
      'created_at_timestamp': instance.createdAtTimestamp,
      'action_type': instance.actionType,
      'credits': instance.credits,
      'metadata': instance.metadata,
      'component_name': instance.componentName,
      'workspace_id': instance.workspaceId,
      'session_id': instance.sessionId,
    };

SessionInvocationResponse _$SessionInvocationResponseFromJson(
  Map<String, dynamic> json,
) => SessionInvocationResponse(
  messages: (json['messages'] as List<dynamic>?)
      ?.map((e) => SessionMessage.fromJson(e as Map<String, dynamic>))
      .toList(),
  hasMore: json['has_more'] as bool?,
  lastTimestamp: (json['last_timestamp'] as num?)?.toInt(),
);

Map<String, dynamic> _$SessionInvocationResponseToJson(
  SessionInvocationResponse instance,
) => <String, dynamic>{
  'messages': instance.messages,
  'has_more': instance.hasMore,
  'last_timestamp': instance.lastTimestamp,
};
