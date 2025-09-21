import 'package:json_annotation/json_annotation.dart';

part 'workspace.g.dart';

@JsonSerializable()
class WorkspaceCreateRequest {
  final String name;

  WorkspaceCreateRequest({
    required this.name,
  });

  factory WorkspaceCreateRequest.fromJson(Map<String, dynamic> json) =>
      _$WorkspaceCreateRequestFromJson(json);

  Map<String, dynamic> toJson() => _$WorkspaceCreateRequestToJson(this);
}

@JsonSerializable()
class WorkspaceResponse {
  @JsonKey(name: 'workspace_id')
  final String workspaceId;

  final String name;

  WorkspaceResponse({
    required this.workspaceId,
    required this.name,
  });

  factory WorkspaceResponse.fromJson(Map<String, dynamic> json) =>
      _$WorkspaceResponseFromJson(json);

  Map<String, dynamic> toJson() => _$WorkspaceResponseToJson(this);
}

@JsonSerializable()
class WorkspaceRole {
  @JsonKey(name: 'workspace_id')
  final String workspaceId;

  @JsonKey(name: 'workspace_name')
  final String workspaceName;

  @JsonKey(name: 'owner_name')
  final String ownerName;

  @JsonKey(name: 'owner_email')
  final String ownerEmail;

  final String role;

  WorkspaceRole({
    required this.workspaceId,
    required this.workspaceName,
    required this.ownerName,
    required this.ownerEmail,
    required this.role,
  });

  factory WorkspaceRole.fromJson(Map<String, dynamic> json) =>
      _$WorkspaceRoleFromJson(json);

  Map<String, dynamic> toJson() => _$WorkspaceRoleToJson(this);

  bool get isOwner => role == 'O';
  bool get isAdmin => role == 'A';
  bool get isEditor => role == 'E';
  bool get isMember => role == 'M';
  bool get isGuest => role == 'G';

  String get roleDisplayName {
    switch (role) {
      case 'O':
        return 'Owner';
      case 'A':
        return 'Admin';
      case 'E':
        return 'Editor';
      case 'M':
        return 'Member';
      case 'G':
        return 'Guest';
      default:
        return 'Unknown';
    }
  }
}

@JsonSerializable()
class WorkspaceSearchRequest {
  final int? limit;
  final int? offset;

  WorkspaceSearchRequest({
    this.limit,
    this.offset,
  });

  factory WorkspaceSearchRequest.fromJson(Map<String, dynamic> json) =>
      _$WorkspaceSearchRequestFromJson(json);

  Map<String, dynamic> toJson() => _$WorkspaceSearchRequestToJson(this);
}

@JsonSerializable()
class WorkspaceUpdateRequest {
  final String? name;

  WorkspaceUpdateRequest({
    this.name,
  });

  factory WorkspaceUpdateRequest.fromJson(Map<String, dynamic> json) =>
      _$WorkspaceUpdateRequestFromJson(json);

  Map<String, dynamic> toJson() => _$WorkspaceUpdateRequestToJson(this);
}