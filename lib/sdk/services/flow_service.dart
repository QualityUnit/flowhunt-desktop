import 'package:logger/logger.dart';

import '../api_client.dart';
import '../models/flow.dart';

class FlowService {
  final FlowHuntApiClient _apiClient;
  final Logger _logger = Logger();

  FlowService({
    required FlowHuntApiClient apiClient,
  }) : _apiClient = apiClient;

  /// Get all flows for a workspace (private workspace flows)
  Future<List<FlowResponse>> getFlows({
    required String workspaceId,
    int? limit,
    int? offset,
  }) async {
    try {
      _logger.d('Fetching workspace flows for: $workspaceId (limit: $limit, offset: $offset)');

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

  /// Get all public flows (from all workspaces)
  Future<List<FlowResponse>> getAllPublicFlows({
    required String workspaceId,
    int? limit,
    int? offset,
  }) async {
    try {
      _logger.d('Fetching public flows (limit: $limit, offset: $offset)');

      final request = FlowSearchRequest(
        limit: limit,
        offset: offset,
      );

      final response = await _apiClient.post<List<dynamic>>(
        '/flows/all',
        queryParameters: {'workspace_id': workspaceId},
        data: request.toJson(),
      );

      _logger.d('Raw API response type: ${response.runtimeType}');
      _logger.d('Raw API response length: ${response.length}');

      final flows = response.map((json) {
        try {
          final flow = FlowResponse.fromJson(json as Map<String, dynamic>);
          _logger.d('Parsed public flow: ${flow.flowId} - ${flow.name}');
          return flow;
        } catch (e) {
          _logger.e('Failed to parse public flow from JSON: $json', error: e);
          rethrow;
        }
      }).toList();

      _logger.i('Successfully fetched ${flows.length} public flows');

      final validFlows = flows.where((f) => f.flowId != null && f.name != null).length;
      _logger.i('Valid public flows (with flowId and name): $validFlows');

      return flows;
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to fetch public flows',
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
      // API expects: {human_input: "value", stream_response: false, variables: {}}
      // NOT: {flow_input: {human_input: "value"}, stream_response: false}
      final requestData = {
        ...flowInput, // Spread the flowInput directly (should contain 'human_input')
        'stream_response': streamResponse,
        'variables': {}, // Empty variables object by default
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
      // API expects: {human_input: "value", stream_response: false, variables: {}}
      // NOT: {flow_input: {human_input: "value"}, stream_response: false}
      final requestData = {
        ...flowInput, // Spread the flowInput directly (should contain 'human_input')
        'stream_response': streamResponse,
        'variables': {}, // Empty variables object by default
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
      _logger.i('===== CHECK TASK STATUS =====');
      _logger.i('Flow ID: $flowId');
      _logger.i('Task ID: $taskId');
      _logger.i('Workspace ID: $workspaceId');
      _logger.i('URL path: /flows/$flowId/$taskId');
      _logger.i('Query params: workspace_id=$workspaceId');
      _logger.i('=============================');

      final response = await _apiClient.get<Map<String, dynamic>>(
        '/flows/$flowId/$taskId',
        queryParameters: {'workspace_id': workspaceId},
      );

      _logger.i('Response received:');
      _logger.i('Response data: $response');

      final taskResponse = TaskResponse.fromJson(response);
      _logger.i('Task $taskId status: ${taskResponse.status}');
      if (taskResponse.result != null) {
        _logger.d('Task result type: ${taskResponse.result.runtimeType}');
      }
      if (taskResponse.errorMessage != null) {
        _logger.w('Task error message: ${taskResponse.errorMessage}');
      }

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

  /// Create a new flow session
  Future<FlowSessionResponse> createSession({
    required String flowId,
    required String workspaceId,
    String? chatbotId,
  }) async {
    try {
      _logger.i('===== CREATE FLOW SESSION =====');
      _logger.i('Flow ID: $flowId');
      _logger.i('Workspace ID: $workspaceId');
      _logger.i('URL path: /flows/sessions/from_flow/create');
      _logger.i('===============================');

      final response = await _apiClient.post<Map<String, dynamic>>(
        '/flows/sessions/from_flow/create',
        queryParameters: {'workspace_id': workspaceId},
        data: {
          'flow_id': flowId,
        },
      );

      final sessionResponse = FlowSessionResponse.fromJson(response);
      _logger.i('Session created successfully. Session ID: ${sessionResponse.sessionId}');

      return sessionResponse;
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to create session for flow: $flowId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Invoke a flow session with a message
  Future<SessionInvokeResponse> invokeSession({
    required String sessionId,
    required String workspaceId,
    required String message,
  }) async {
    try {
      _logger.i('===== INVOKE FLOW SESSION =====');
      _logger.i('Session ID: $sessionId');
      _logger.i('Workspace ID: $workspaceId');
      _logger.i('Message: $message');
      _logger.i('URL path: /flows/sessions/$sessionId/invoke');
      _logger.i('===============================');

      final response = await _apiClient.post<Map<String, dynamic>>(
        '/flows/sessions/$sessionId/invoke',
        queryParameters: {'workspace_id': workspaceId},
        data: {'message': message},
      );

      final invokeResponse = SessionInvokeResponse.fromJson(response);
      _logger.i('Session invoked successfully. Status: ${invokeResponse.status}');

      return invokeResponse;
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to invoke session: $sessionId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get session invocation responses (poll for results)
  Future<SessionInvocationResponse> getSessionResponses({
    required String sessionId,
    required String workspaceId,
    required int fromTimestamp,
  }) async {
    try {
      _logger.d('===== POLL SESSION RESPONSES =====');
      _logger.d('Session ID: $sessionId');
      _logger.d('From timestamp (Unix): $fromTimestamp');
      _logger.d('Workspace ID: $workspaceId');
      _logger.d('URL path: /flows/sessions/$sessionId/invocation_response/$fromTimestamp');
      _logger.d('==================================');

      final response = await _apiClient.post<dynamic>(
        '/flows/sessions/$sessionId/invocation_response/$fromTimestamp',
        queryParameters: {'workspace_id': workspaceId},
      );

      _logger.d('Response type: ${response.runtimeType}');
      _logger.d('Response data: $response');

      // Handle the response - API returns array of messages directly
      final SessionInvocationResponse invocationResponse;
      if (response is List) {
        // API returns array of messages directly
        final messages = (response as List).map((item) =>
          SessionMessage.fromJson(item as Map<String, dynamic>)
        ).toList();

        // Extract last timestamp from last message if available
        int? lastTimestamp;
        if (messages.isNotEmpty && messages.last.timestamp != null) {
          try {
            lastTimestamp = int.parse(messages.last.timestamp!);
          } catch (e) {
            _logger.w('Failed to parse timestamp from last message: ${messages.last.timestamp}');
          }
        }

        invocationResponse = SessionInvocationResponse(
          messages: messages,
          hasMore: false, // No pagination info when array is returned directly
          lastTimestamp: lastTimestamp,
        );
      } else if (response is Map<String, dynamic>) {
        // API returns object with messages array
        invocationResponse = SessionInvocationResponse.fromJson(response);
      } else {
        throw Exception('Unexpected response type: ${response.runtimeType}');
      }

      final messageCount = invocationResponse.messages?.length ?? 0;
      _logger.d('Received $messageCount messages, hasMore: ${invocationResponse.hasMore}');

      return invocationResponse;
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to get session responses: $sessionId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
