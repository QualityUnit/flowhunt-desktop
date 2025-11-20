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
