import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../sdk/models/flow.dart';
import '../sdk/services/flow_service.dart';
import 'user_provider.dart';

// Wrapper class to track flow source (workspace vs public)
class FlowWithSource {
  final FlowResponse flow;
  final bool isPublic;

  FlowWithSource({
    required this.flow,
    required this.isPublic,
  });

  // Convenience getters to access FlowResponse properties
  String? get flowId => flow.flowId;
  String? get name => flow.name;
  String? get description => flow.description;
  String? get catId => flow.catId;
  String? get flowType => flow.flowType;
  int? get componentCount => flow.componentCount;
  String? get executedAt => flow.executedAt;
  bool? get enableCache => flow.enableCache;
  String? get lastModified => flow.lastModified;
  String? get chatbotId => flow.chatbotId;
}

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

// Provider for fetching flows from both current workspace and public flows
final combinedFlowsProvider = FutureProvider.family<List<FlowWithSource>, String>((ref, workspaceId) async {
  final flowService = ref.watch(flowServiceProvider);

  // Fetch workspace flows and public flows in parallel
  final results = await Future.wait([
    flowService.getFlows(workspaceId: workspaceId),
    flowService.getAllPublicFlows(workspaceId: workspaceId),
  ]);

  final workspaceFlows = results[0];
  final publicFlows = results[1];

  // Combine flows: workspace flows first, then public flows
  final combinedFlows = <FlowWithSource>[
    ...workspaceFlows.map((flow) => FlowWithSource(flow: flow, isPublic: false)),
    ...publicFlows.map((flow) => FlowWithSource(flow: flow, isPublic: true)),
  ];

  return combinedFlows;
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
