// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workspace.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WorkspaceCreateRequest _$WorkspaceCreateRequestFromJson(
  Map<String, dynamic> json,
) => WorkspaceCreateRequest(name: json['name'] as String);

Map<String, dynamic> _$WorkspaceCreateRequestToJson(
  WorkspaceCreateRequest instance,
) => <String, dynamic>{'name': instance.name};

WorkspaceResponse _$WorkspaceResponseFromJson(Map<String, dynamic> json) =>
    WorkspaceResponse(
      workspaceId: json['workspace_id'] as String,
      name: json['name'] as String,
    );

Map<String, dynamic> _$WorkspaceResponseToJson(WorkspaceResponse instance) =>
    <String, dynamic>{
      'workspace_id': instance.workspaceId,
      'name': instance.name,
    };

WorkspaceRole _$WorkspaceRoleFromJson(Map<String, dynamic> json) =>
    WorkspaceRole(
      workspaceId: json['workspace_id'] as String,
      workspaceName: json['workspace_name'] as String,
      ownerName: json['owner_name'] as String,
      ownerEmail: json['owner_email'] as String,
      role: json['role'] as String,
    );

Map<String, dynamic> _$WorkspaceRoleToJson(WorkspaceRole instance) =>
    <String, dynamic>{
      'workspace_id': instance.workspaceId,
      'workspace_name': instance.workspaceName,
      'owner_name': instance.ownerName,
      'owner_email': instance.ownerEmail,
      'role': instance.role,
    };

WorkspaceSearchRequest _$WorkspaceSearchRequestFromJson(
  Map<String, dynamic> json,
) => WorkspaceSearchRequest(
  limit: (json['limit'] as num?)?.toInt(),
  offset: (json['offset'] as num?)?.toInt(),
);

Map<String, dynamic> _$WorkspaceSearchRequestToJson(
  WorkspaceSearchRequest instance,
) => <String, dynamic>{'limit': instance.limit, 'offset': instance.offset};

WorkspaceUpdateRequest _$WorkspaceUpdateRequestFromJson(
  Map<String, dynamic> json,
) => WorkspaceUpdateRequest(name: json['name'] as String?);

Map<String, dynamic> _$WorkspaceUpdateRequestToJson(
  WorkspaceUpdateRequest instance,
) => <String, dynamic>{'name': instance.name};
