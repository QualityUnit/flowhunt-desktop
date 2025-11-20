import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../sdk/models/flow.dart';
import '../sdk/services/flow_service.dart';
import 'user_provider.dart';

// Provider for FlowService
final flowServiceProvider = Provider<FlowService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return FlowService(apiClient: apiClient);
});

// Provider for fetching flows for a specific workspace
final flowsProvider = FutureProvider.family<List<FlowResponse>, String>((ref, workspaceId) async {
  final flowService = ref.watch(flowServiceProvider);
  return flowService.getFlows(workspaceId: workspaceId);
});

// Provider for invoking a flow
final invokeFlowProvider = Provider<Future<TaskResponse> Function({
  required String flowId,
  required String workspaceId,
  required Map<String, dynamic> flowInput,
  bool streamResponse,
})>((ref) {
  final flowService = ref.watch(flowServiceProvider);
  return ({
    required String flowId,
    required String workspaceId,
    required Map<String, dynamic> flowInput,
    bool streamResponse = false,
  }) {
    return flowService.invokeFlow(
      flowId: flowId,
      workspaceId: workspaceId,
      flowInput: flowInput,
      streamResponse: streamResponse,
    );
  };
});
