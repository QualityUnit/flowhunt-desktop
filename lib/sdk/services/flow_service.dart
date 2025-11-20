import 'package:logger/logger.dart';

import '../api_client.dart';
import '../models/flow.dart';

class FlowService {
  final FlowHuntApiClient _apiClient;
  final Logger _logger = Logger();

  FlowService({
    required FlowHuntApiClient apiClient,
  }) : _apiClient = apiClient;

  /// Get all flows for a workspace
  Future<List<FlowResponse>> getFlows({
    required String workspaceId,
    int? limit,
    int? offset,
  }) async {
    try {
      _logger.d('Fetching flows for workspace: $workspaceId (limit: $limit, offset: $offset)');

      final request = FlowSearchRequest(
        limit: limit,
        offset: offset,
      );

      final response = await _apiClient.post<List<dynamic>>(
        '/flows/',
        queryParameters: {'workspace_id': workspaceId},
        data: request.toJson(),
      );

      _logger.d('Raw API response type: ${response.runtimeType}');
      _logger.d('Raw API response length: ${response.length}');
      if (response.isNotEmpty) {
        _logger.d('First flow raw data: ${response.first}');
      }

      final flows = response.map((json) {
        try {
          final flow = FlowResponse.fromJson(json as Map<String, dynamic>);
          _logger.d('Parsed flow: ${flow.flowId} - ${flow.name}');
          return flow;
        } catch (e) {
          _logger.e('Failed to parse flow from JSON: $json', error: e);
          rethrow;
        }
      }).toList();

      _logger.i('Successfully fetched ${flows.length} flows for workspace: $workspaceId');

      final validFlows = flows.where((f) => f.flowId != null && f.name != null).length;
      _logger.i('Valid flows (with flowId and name): $validFlows');

      return flows;
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to fetch flows for workspace: $workspaceId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Invoke a flow
  Future<TaskResponse> invokeFlow({
    required String flowId,
    required String workspaceId,
    required Map<String, dynamic> flowInput,
    bool streamResponse = false,
  }) async {
    try {
      _logger.i('===== INVOKE FLOW (NORMAL) =====');
      _logger.i('Flow ID received as parameter: $flowId');
      _logger.i('Workspace ID: $workspaceId');
      _logger.i('Flow input: $flowInput');
      _logger.i('URL path will be: /flows/$flowId/invoke');
      _logger.i('Query params: workspace_id=$workspaceId');

      // Send data directly without wrapping in FlowInvokeRequest
      // API expects: {human_input: "value", stream_response: false}
      // NOT: {flow_input: {human_input: "value"}, stream_response: false}
      final requestData = {
        ...flowInput, // Spread the flowInput directly (should contain 'human_input')
        'stream_response': streamResponse,
      };

      _logger.i('Request body: $requestData');
      _logger.i('================================');

      final response = await _apiClient.post<Map<String, dynamic>>(
        '/flows/$flowId/invoke',
        queryParameters: {'workspace_id': workspaceId},
        data: requestData,
      );

      final taskResponse = TaskResponse.fromJson(response);
      _logger.i('Flow invoked successfully. Task ID: ${taskResponse.id}, Status: ${taskResponse.status}');

      return taskResponse;
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to invoke flow: $flowId in workspace: $workspaceId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Invoke a flow as singleton (only one instance runs at a time)
  Future<TaskResponse> invokeFlowSingleton({
    required String flowId,
    required String workspaceId,
    required Map<String, dynamic> flowInput,
    bool streamResponse = false,
  }) async {
    try {
      _logger.i('===== INVOKE FLOW (SINGLETON) =====');
      _logger.i('Flow ID received as parameter: $flowId');
      _logger.i('Workspace ID: $workspaceId');
      _logger.i('Flow input: $flowInput');
      _logger.i('URL path will be: /flows/$flowId/invoke_singleton');
      _logger.i('Query params: workspace_id=$workspaceId');

      // Send data directly without wrapping in FlowInvokeRequest
      // API expects: {human_input: "value", stream_response: false}
      // NOT: {flow_input: {human_input: "value"}, stream_response: false}
      final requestData = {
        ...flowInput, // Spread the flowInput directly (should contain 'human_input')
        'stream_response': streamResponse,
      };

      _logger.i('Request body: $requestData');
      _logger.i('===================================');

      final response = await _apiClient.post<Map<String, dynamic>>(
        '/flows/$flowId/invoke_singleton',
        queryParameters: {'workspace_id': workspaceId},
        data: requestData,
      );

      final taskResponse = TaskResponse.fromJson(response);
      _logger.i('Flow invoked as singleton successfully. Task ID: ${taskResponse.id}, Status: ${taskResponse.status}');

      return taskResponse;
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to invoke flow as singleton: $flowId in workspace: $workspaceId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Check the status of a flow task
  Future<TaskResponse> checkTaskStatus({
    required String flowId,
    required String taskId,
    required String workspaceId,
  }) async {
    try {
      _logger.d('Checking task status: $taskId for flow: $flowId');

      final response = await _apiClient.get<Map<String, dynamic>>(
        '/flows/$flowId/$taskId',
        queryParameters: {'workspace_id': workspaceId},
      );

      final taskResponse = TaskResponse.fromJson(response);
      _logger.d('Task $taskId status: ${taskResponse.status}');

      return taskResponse;
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to check task status: $taskId for flow: $flowId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
