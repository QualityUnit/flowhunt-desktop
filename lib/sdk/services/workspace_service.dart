import '../api_client.dart';
import '../models/workspace.dart';

class WorkspaceService {
  final FlowHuntApiClient _apiClient;

  WorkspaceService({
    required FlowHuntApiClient apiClient,
  }) : _apiClient = apiClient;

  /// Get all workspaces for the current user
  Future<List<WorkspaceRole>> getMyWorkspaces({
    int? limit,
    int? offset,
  }) async {
    final request = WorkspaceSearchRequest(
      limit: limit,
      offset: offset,
    );

    final response = await _apiClient.post<List<dynamic>>(
      '/workspaces/me/my_workspaces',
      data: request.toJson(),
    );

    return response.map((json) => WorkspaceRole.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Create a new workspace
  Future<WorkspaceResponse> createWorkspace(String name) async {
    final request = WorkspaceCreateRequest(name: name);
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/workspaces/create',
      data: request.toJson(),
    );
    return WorkspaceResponse.fromJson(response);
  }

  /// Get a specific workspace
  Future<WorkspaceResponse> getWorkspace(String workspaceId) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/workspaces/$workspaceId',
    );
    return WorkspaceResponse.fromJson(response);
  }

  /// Update a workspace
  Future<void> updateWorkspace(String workspaceId, {String? name}) async {
    final request = WorkspaceUpdateRequest(name: name);
    await _apiClient.put(
      '/workspaces/$workspaceId',
      data: request.toJson(),
    );
  }

  /// Delete a workspace
  Future<void> deleteWorkspace(String workspaceId) async {
    await _apiClient.delete('/workspaces/$workspaceId');
  }
}