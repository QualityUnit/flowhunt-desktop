import 'dart:async';
import 'package:logger/logger.dart';

import '../api_client.dart';
import '../models/flow_assistant.dart';

class FlowAssistantService {
  final FlowHuntApiClient _apiClient;
  final Logger _logger = Logger();

  Timer? _pollTimer;
  String? _currentSessionId;
  String? _lastMessageId;
  int _lastTimestamp = 0;

  FlowAssistantService({
    required FlowHuntApiClient apiClient,
  }) : _apiClient = apiClient;

  // Create a new session
  Future<SessionResponse> createSession({
    required String flowId,
    String? workspaceId,
    String? chatId,
    String? sessionName,
    Map<String, dynamic>? inputs,
  }) async {
    try {
      final request = CreateSessionRequest(
        flowId: flowId,
        chatId: chatId,
        sessionName: sessionName,
        inputs: inputs,
      );

      // workspace_id is required as a query parameter
      final queryParams = <String, dynamic>{};
      if (workspaceId != null) {
        queryParams['workspace_id'] = workspaceId;
      }

      _logger.i('Creating session with workspace_id: $workspaceId');
      _logger.i('Query params: $queryParams');

      final response = await _apiClient.post<Map<String, dynamic>>(
        '/flow_assistants/create',
        data: request.toJson(),
        queryParameters: queryParams,
      );

      // Parse the minimal response from API
      final createResponse = CreateSessionResponse.fromJson(response);
      _currentSessionId = createResponse.sessionId;

      // Create a full SessionResponse for the app to use
      final session = SessionResponse(
        sessionId: createResponse.sessionId,
        flowId: flowId,
        chatId: chatId,
        sessionName: sessionName,
        status: 'active',
        createdAt: createResponse.createdAt,
        updatedAt: createResponse.createdAt,
      );

      _logger.i('Created session: ${session.sessionId}');
      return session;
    } catch (e) {
      _logger.e('Failed to create session: $e');
      rethrow;
    }
  }

  // Send message to assistant
  Future<void> sendMessage({
    required String sessionId,
    required String message,
    String messageType = 'human',
    Map<String, dynamic>? inputs,
    bool streamResponse = false,
  }) async {
    try {
      final request = InvokeMessageRequest(
        message: message,
        messageType: messageType,
        inputs: inputs,
        streamResponse: streamResponse,
      );

      // The invoke endpoint returns an empty response
      // Messages come from polling
      await _apiClient.post<Map<String, dynamic>>(
        '/flow_assistants/$sessionId/invoke',
        data: request.toJson(),
      );

      _logger.i('Sent message to session $sessionId');
    } catch (e) {
      _logger.e('Failed to send message: $e');
      rethrow;
    }
  }

  // Poll for new messages using timestamp
  Future<PollResponse> pollMessages({
    required String sessionId,
    int? fromTimestamp,
  }) async {
    try {
      // Use the provided timestamp or the last known timestamp
      final timestamp = fromTimestamp ?? _lastTimestamp;

      // The API returns an array directly, not a wrapper object
      final response = await _apiClient.post<List<dynamic>>(
        '/flow_assistants/$sessionId/invocation_response/$timestamp',
        data: {}, // Empty body as per API spec
      );

      // Parse the array of events
      final events = response.map((e) => FlowEvent.fromJson(e as Map<String, dynamic>)).toList();

      // Update last timestamp if events were received
      if (events.isNotEmpty) {
        _lastTimestamp = events.last.createdAtTimestamp;
        _lastMessageId = events.last.eventId;
      }

      return events;
    } catch (e) {
      _logger.e('Failed to poll messages: $e');
      rethrow;
    }
  }

  // Start automatic polling
  void startPolling({
    required String sessionId,
    required Function(List<FlowEvent>) onMessages,
    Function(dynamic)? onError,
    Duration interval = const Duration(seconds: 2),
  }) {
    _stopPolling();
    _currentSessionId = sessionId;
    // Reset timestamp for new polling session
    _lastTimestamp = 0;

    _pollTimer = Timer.periodic(interval, (_) async {
      try {
        final events = await pollMessages(
          sessionId: sessionId,
          fromTimestamp: _lastTimestamp,
        );

        if (events.isNotEmpty) {
          onMessages(events);
        }
      } catch (e) {
        _logger.e('Polling error: $e');
        onError?.call(e);
      }
    });

    _logger.i('Started polling for session $sessionId');
  }

  // Stop automatic polling
  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _logger.i('Stopped polling');
  }

  // Clean up resources
  void dispose() {
    _stopPolling();
    _currentSessionId = null;
    _lastMessageId = null;
    _lastTimestamp = 0;
  }
}