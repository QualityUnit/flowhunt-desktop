import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../sdk/models/workspace.dart';
import '../sdk/services/workspace_service.dart';
import 'user_provider.dart';

// Provider for WorkspaceService
final workspaceServiceProvider = Provider<WorkspaceService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return WorkspaceService(apiClient: apiClient);
});

// State class for workspace management
class WorkspaceState {
  final List<WorkspaceRole> workspaces;
  final WorkspaceRole? currentWorkspace;
  final bool isLoading;
  final String? error;

  WorkspaceState({
    this.workspaces = const [],
    this.currentWorkspace,
    this.isLoading = false,
    this.error,
  });

  WorkspaceState copyWith({
    List<WorkspaceRole>? workspaces,
    WorkspaceRole? currentWorkspace,
    bool? isLoading,
    String? error,
  }) {
    return WorkspaceState(
      workspaces: workspaces ?? this.workspaces,
      currentWorkspace: currentWorkspace ?? this.currentWorkspace,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// State notifier for managing workspace data
class WorkspaceNotifier extends Notifier<WorkspaceState> {
  late final WorkspaceService _workspaceService;
  static const String _currentWorkspaceKey = 'current_workspace_id';

  @override
  WorkspaceState build() {
    _workspaceService = ref.watch(workspaceServiceProvider);
    return WorkspaceState();
  }

  Future<void> fetchWorkspaces() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final workspaces = await _workspaceService.getMyWorkspaces();

      // Get the saved workspace ID
      final prefs = await SharedPreferences.getInstance();
      final savedWorkspaceId = prefs.getString(_currentWorkspaceKey);

      // Find the saved workspace or use the first one
      WorkspaceRole? currentWorkspace;
      if (savedWorkspaceId != null) {
        currentWorkspace = workspaces.firstWhere(
          (w) => w.workspaceId == savedWorkspaceId,
          orElse: () => workspaces.first,
        );
      } else if (workspaces.isNotEmpty) {
        currentWorkspace = workspaces.first;
        // Save the first workspace as current
        await prefs.setString(_currentWorkspaceKey, currentWorkspace.workspaceId);
      }

      state = state.copyWith(
        workspaces: workspaces,
        currentWorkspace: currentWorkspace,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> switchWorkspace(WorkspaceRole workspace) async {
    if (state.currentWorkspace?.workspaceId == workspace.workspaceId) {
      return;
    }

    state = state.copyWith(currentWorkspace: workspace, error: null);

    // Save the current workspace ID
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentWorkspaceKey, workspace.workspaceId);

    // You might want to trigger a refresh of data for the new workspace here
    // For example, refresh flow assistants, integrations, etc.
  }

  Future<void> createWorkspace(String name) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _workspaceService.createWorkspace(name);

      // Refresh the list to get the updated workspaces with roles
      await fetchWorkspaces();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> updateWorkspace(String workspaceId, String name) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _workspaceService.updateWorkspace(workspaceId, name: name);

      // Update the workspace in the list
      final updatedWorkspaces = state.workspaces.map((w) {
        if (w.workspaceId == workspaceId) {
          return WorkspaceRole(
            workspaceId: w.workspaceId,
            workspaceName: name,
            ownerName: w.ownerName,
            ownerEmail: w.ownerEmail,
            role: w.role,
          );
        }
        return w;
      }).toList();

      // Update current workspace if it's the one being updated
      WorkspaceRole? updatedCurrent = state.currentWorkspace;
      if (state.currentWorkspace?.workspaceId == workspaceId) {
        updatedCurrent = WorkspaceRole(
          workspaceId: state.currentWorkspace!.workspaceId,
          workspaceName: name,
          ownerName: state.currentWorkspace!.ownerName,
          ownerEmail: state.currentWorkspace!.ownerEmail,
          role: state.currentWorkspace!.role,
        );
      }

      state = state.copyWith(
        workspaces: updatedWorkspaces,
        currentWorkspace: updatedCurrent,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> deleteWorkspace(String workspaceId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _workspaceService.deleteWorkspace(workspaceId);

      // Remove from list
      final updatedWorkspaces = state.workspaces.where((w) => w.workspaceId != workspaceId).toList();

      // If the deleted workspace was current, switch to the first available
      WorkspaceRole? newCurrent = state.currentWorkspace;
      if (state.currentWorkspace?.workspaceId == workspaceId) {
        newCurrent = updatedWorkspaces.isNotEmpty ? updatedWorkspaces.first : null;
        final prefs = await SharedPreferences.getInstance();
        if (newCurrent != null) {
          await prefs.setString(_currentWorkspaceKey, newCurrent.workspaceId);
        } else {
          await prefs.remove(_currentWorkspaceKey);
        }
      }

      state = state.copyWith(
        workspaces: updatedWorkspaces,
        currentWorkspace: newCurrent,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void clear() async {
    state = WorkspaceState();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentWorkspaceKey);
  }
}

// Provider for workspace state
final workspaceProvider = NotifierProvider<WorkspaceNotifier, WorkspaceState>(() {
  return WorkspaceNotifier();
});