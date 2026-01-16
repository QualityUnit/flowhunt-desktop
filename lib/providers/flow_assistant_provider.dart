import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../sdk/api_client.dart';
import '../sdk/services/flow_assistant_service.dart';
import '../sdk/models/flow_assistant.dart';
import 'auth_provider.dart';

// API Client Provider
final apiClientProvider = Provider<FlowHuntApiClient>((ref) {
  final authService = ref.watch(authServiceProvider);
  final dio = ref.watch(dioProvider);

  return FlowHuntApiClient(
    authService: authService,
    dio: dio,
  );
});

// Flow Assistant Service Provider
final flowAssistantServiceProvider = Provider<FlowAssistantService>((ref) {
  final apiClient = ref.watch(apiClientProvider);

  return FlowAssistantService(apiClient: apiClient);
});

// Flow Assistant State
class FlowAssistantState {
  final SessionResponse? currentSession;
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isPolling;
  final String? error;
  final String? currentFlowId;

  const FlowAssistantState({
    this.currentSession,
    this.messages = const [],
    this.isLoading = false,
    this.isPolling = false,
    this.error,
    this.currentFlowId,
  });

  FlowAssistantState copyWith({
    SessionResponse? currentSession,
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isPolling,
    String? error,
    String? currentFlowId,
    bool clearError = false,
  }) {
    return FlowAssistantState(
      currentSession: currentSession ?? this.currentSession,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isPolling: isPolling ?? this.isPolling,
      error: clearError ? null : (error ?? this.error),
      currentFlowId: currentFlowId ?? this.currentFlowId,
    );
  }
}

// Flow Assistant Notifier
class FlowAssistantNotifier extends Notifier<FlowAssistantState> {
  late final FlowAssistantService _service;
  final Logger _logger = Logger();

  @override
  FlowAssistantState build() {
    _service = ref.watch(flowAssistantServiceProvider);

    // Handle cleanup when the notifier is disposed
    ref.onDispose(() {
      _service.dispose();
    });

    return const FlowAssistantState();
  }

  // Initialize a new chat session
  Future<void> initializeSession({
    required String flowId,
    String? sessionName,
    Map<String, dynamic>? inputs,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      currentFlowId: flowId,
    );

    try {
      // TODO: Get workspace_id from user profile or settings
      // Using a placeholder UUID for now - this should come from user's actual workspace
      const workspaceId = '00000000-0000-0000-0000-000000000000'; // Replace with actual workspace UUID

      final session = await _service.createSession(
        flowId: flowId,
        workspaceId: workspaceId,
        sessionName: sessionName ?? 'FlowHunt Desktop Session',
        inputs: inputs,
      );

      state = state.copyWith(
        currentSession: session,
        messages: [],
        isLoading: false,
      );

      // Start polling for new messages
      _startPolling(session.sessionId);

      _logger.i('Initialized session: ${session.sessionId}');
    } catch (e) {
      _logger.e('Failed to initialize session: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to start chat session: ${e.toString()}',
      );
    }
  }

  // Send a message to the assistant
  Future<void> sendMessage(String message) async {
    if (state.currentSession == null) {
      state = state.copyWith(
        error: 'No active session. Please initialize a session first.',
      );
      return;
    }

    // Don't add user message here - it will come from polling
    // Just add a loading placeholder for now
    final loadingMessage = ChatMessage(
      id: '${DateTime.now().millisecondsSinceEpoch}_loading',
      content: '',
      type: MessageType.loading,
      timestamp: DateTime.now(),
      isLoading: true,
    );

    state = state.copyWith(
      messages: [...state.messages, loadingMessage],
      clearError: true,
    );

    try {
      // Send message to API (returns void, messages come from polling)
      await _service.sendMessage(
        sessionId: state.currentSession!.sessionId,
        message: message,
      );

      // Don't remove loading here - let polling handle it
    } catch (e) {
      _logger.e('Failed to send message: $e');

      // Remove loading message and add error message
      final updatedMessages = state.messages
          .where((m) => !m.isLoading)
          .toList()
        ..add(
          ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            content: 'Failed to send message. Please try again.',
            type: MessageType.error,
            timestamp: DateTime.now(),
          ),
        );

      state = state.copyWith(
        messages: updatedMessages,
        error: 'Failed to send message: ${e.toString()}',
      );
    }
  }

  // Start polling for new messages
  void _startPolling(String sessionId) {
    if (state.isPolling) return;

    state = state.copyWith(isPolling: true);

    // Track processed message IDs to avoid duplicates
    final processedMessageIds = <String>{};

    _service.startPolling(
      sessionId: sessionId,
      onMessages: (events) {
        // Convert events to chat messages (filter out non-message events)
        final newChatMessages = <ChatMessage>[];

        for (final event in events) {
          final chatMessage = event.toChatMessage();
          if (chatMessage != null && !processedMessageIds.contains(chatMessage.id)) {
            newChatMessages.add(chatMessage);
            processedMessageIds.add(chatMessage.id);
          }
        }

        if (newChatMessages.isNotEmpty) {
          // Filter out any loading messages and append only truly new messages
          final existingMessageIds = state.messages.map((m) => m.id).toSet();
          final uniqueNewMessages = newChatMessages
              .where((m) => !existingMessageIds.contains(m.id))
              .toList();

          if (uniqueNewMessages.isNotEmpty) {
            final updatedMessages = state.messages
                .where((m) => !m.isLoading)
                .toList()
              ..addAll(uniqueNewMessages);

            state = state.copyWith(messages: updatedMessages);
          }
        }
      },
      onError: (error) {
        _logger.e('Polling error: $error');
        // Don't set error state for polling errors to avoid disrupting UX
      },
    );
  }

  // Clear current session and messages
  void clearSession() {
    if (state.currentSession != null) {
      _service.dispose();
    }

    state = const FlowAssistantState();
  }

  // Delete a message from the chat (local only)
  void deleteMessage(String messageId) {
    final updatedMessages = state.messages
        .where((m) => m.id != messageId)
        .toList();

    state = state.copyWith(messages: updatedMessages);
  }

  // Retry sending last failed message
  Future<void> retryLastMessage() async {
    final lastUserMessage = state.messages
        .where((m) => m.type == MessageType.human)
        .lastOrNull;

    if (lastUserMessage != null) {
      // Remove any error messages
      final cleanMessages = state.messages
          .where((m) => m.type != MessageType.error)
          .toList();

      state = state.copyWith(messages: cleanMessages);

      // Resend the message
      await sendMessage(lastUserMessage.content);
    }
  }

}

// Flow Assistant State Provider
final flowAssistantProvider =
    NotifierProvider<FlowAssistantNotifier, FlowAssistantState>(() {
  return FlowAssistantNotifier();
});

// Note: Session listing is not available in the current API
// Sessions are created on demand and not listed

// Available Flows Provider (mock for now, will be replaced with actual API call)
final availableFlowsProvider = Provider<List<FlowInfo>>((ref) {
  // This would normally come from an API call to list available flows
  // Using placeholder UUIDs - replace with actual flow IDs from your backend
  return [
    FlowInfo(
      id: '11111111-1111-1111-1111-111111111111', // Replace with actual flow UUID
      name: 'General Assistant',
      description: 'A general purpose AI assistant',
    ),
    FlowInfo(
      id: '22222222-2222-2222-2222-222222222222', // Replace with actual flow UUID
      name: 'Code Helper',
      description: 'Helps with programming questions',
    ),
    FlowInfo(
      id: '33333333-3333-3333-3333-333333333333', // Replace with actual flow UUID
      name: 'Creative Writer',
      description: 'Assists with creative writing tasks',
    ),
  ];
});

// Simple flow info model (will be replaced with proper model from API)
class FlowInfo {
  final String id;
  final String name;
  final String description;

  FlowInfo({
    required this.id,
    required this.name,
    required this.description,
  });
}