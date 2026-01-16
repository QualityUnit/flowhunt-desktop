import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../sdk/models/addon.dart';
import 'workspace_provider.dart';

class AddonState {
  final List<Addon> availableAddons;
  final List<WorkspaceAddon> workspaceAddons;
  final Addon? activeAddon;
  final bool isLoading;
  final String? error;

  AddonState({
    this.availableAddons = const [],
    this.workspaceAddons = const [],
    this.activeAddon,
    this.isLoading = false,
    this.error,
  });

  AddonState copyWith({
    List<Addon>? availableAddons,
    List<WorkspaceAddon>? workspaceAddons,
    Addon? activeAddon,
    bool? isLoading,
    String? error,
  }) {
    return AddonState(
      availableAddons: availableAddons ?? this.availableAddons,
      workspaceAddons: workspaceAddons ?? this.workspaceAddons,
      activeAddon: activeAddon ?? this.activeAddon,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AddonNotifier extends Notifier<AddonState> {
  @override
  AddonState build() {
    // Create the default addon
    final defaultAddon = Addon(
      id: 'default',
      name: 'Default',
      description: 'Default addon for standard FlowHunt features',
      icon: 'default',
      isActive: true,
    );

    // Listen to workspace changes
    ref.listen(workspaceProvider, (previous, next) {
      if (next.currentWorkspace != null) {
        _loadWorkspaceAddons(next.currentWorkspace!.workspaceId);
      }
    });

    return AddonState(
      availableAddons: [defaultAddon],
      activeAddon: defaultAddon,
    );
  }

  Future<void> loadAddons() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // In the future, this will fetch from API
      // For now, we'll use the default addon
      final defaultAddon = Addon(
        id: 'default',
        name: 'Default',
        description: 'Default addon for standard FlowHunt features',
        icon: 'default',
        isActive: true,
      );

      state = state.copyWith(
        availableAddons: [defaultAddon],
        activeAddon: defaultAddon,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load addons: $e',
      );
    }
  }

  Future<void> _loadWorkspaceAddons(String workspaceId) async {
    // For now, create a default workspace addon
    final defaultWorkspaceAddon = WorkspaceAddon(
      workspaceId: workspaceId,
      addonId: 'default',
      isActive: true,
      activatedAt: DateTime.now(),
    );

    state = state.copyWith(
      workspaceAddons: [defaultWorkspaceAddon],
    );

    // Set the default addon as active
    if (state.availableAddons.isNotEmpty) {
      state = state.copyWith(activeAddon: state.availableAddons.first);
    }
  }

  Future<void> activateAddon(String addonId) async {
    final addon = state.availableAddons.firstWhere(
      (a) => a.id == addonId,
      orElse: () => throw Exception('Addon not found'),
    );

    state = state.copyWith(activeAddon: addon);

    // In the future, this will persist to backend
  }

  Future<void> deactivateAddon(String addonId) async {
    if (state.activeAddon?.id == addonId) {
      // Switch to default addon if deactivating current
      final defaultAddon = state.availableAddons.firstWhere(
        (a) => a.id == 'default',
        orElse: () => state.availableAddons.first,
      );
      state = state.copyWith(activeAddon: defaultAddon);
    }

    // In the future, this will persist to backend
  }

  Future<void> updateAddonSettings(String addonId, Map<String, dynamic> settings) async {
    final workspaceState = ref.read(workspaceProvider);
    if (workspaceState.currentWorkspace == null) return;

    final workspaceId = workspaceState.currentWorkspace!.workspaceId;

    final updatedAddons = state.workspaceAddons.map((wa) {
      if (wa.workspaceId == workspaceId && wa.addonId == addonId) {
        return WorkspaceAddon(
          workspaceId: wa.workspaceId,
          addonId: wa.addonId,
          isActive: wa.isActive,
          activatedAt: wa.activatedAt,
          settings: settings,
        );
      }
      return wa;
    }).toList();

    state = state.copyWith(workspaceAddons: updatedAddons);

    // In the future, this will persist to backend
  }
}

final addonProvider = NotifierProvider<AddonNotifier, AddonState>(() {
  return AddonNotifier();
});