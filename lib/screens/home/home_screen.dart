import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/workspace_provider.dart';
import '../../providers/flow_assistant_provider.dart';
import '../../providers/addon_provider.dart';
import '../../sdk/models/flow_assistant.dart';
import '../../sdk/models/workspace.dart';
import '../../widgets/markdown/fh_markdown.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _isSidebarCollapsed = false;
  bool _isInSettingsMenu = false;
  late AnimationController _sidebarAnimationController;
  late Animation<double> _sidebarAnimation;

  // Track if we're in a conversation (will be updated by child widget)
  bool _isInConversation = false;

  // Callback to update conversation state
  void _updateConversationState(bool inConversation) {
    setState(() {
      _isInConversation = inConversation;
    });
  }

  // Callback to handle new chat
  void _handleNewChat() {
    // Clear the session first
    ref.read(flowAssistantProvider.notifier).clearSession();

    setState(() {
      _isInConversation = false;
      // Force rebuild of AI Assistant Chat widget by changing key
      _selectedIndex = 0;
    });
  }

  List<_NavigationItem> get _navigationItems => [
    _NavigationItem(
      icon: _isInConversation ? Icons.add : Icons.home_outlined,
      selectedIcon: _isInConversation ? Icons.add : Icons.home,
      label: _isInConversation ? 'New Chat' : 'Home',
    ),
    _NavigationItem(
      icon: Icons.smart_toy_outlined,
      selectedIcon: Icons.smart_toy,
      label: 'AI Agents',
    ),
  ];

  // Settings item separated to be placed at the bottom
  _NavigationItem get _settingsItem => _NavigationItem(
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
    label: 'Settings',
  );

  List<_NavigationItem> get _settingsMenuItems => [
    _NavigationItem(
      icon: Icons.arrow_back,
      selectedIcon: Icons.arrow_back,
      label: 'Back',
    ),
    _NavigationItem(
      icon: Icons.hub_outlined,
      selectedIcon: Icons.hub,
      label: 'Connectors',
    ),
    _NavigationItem(
      icon: Icons.extension_outlined,
      selectedIcon: Icons.extension,
      label: 'Addons',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _sidebarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _sidebarAnimation = Tween<double>(
      begin: 280.0,
      end: 70.0,
    ).animate(CurvedAnimation(
      parent: _sidebarAnimationController,
      curve: Curves.easeInOutCubic,
    ));
  }

  @override
  void dispose() {
    _sidebarAnimationController.dispose();
    super.dispose();
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarCollapsed = !_isSidebarCollapsed;
      if (_isSidebarCollapsed) {
        _sidebarAnimationController.forward();
      } else {
        _sidebarAnimationController.reverse();
      }
    });
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Clear user and workspace data
      ref.read(userProvider.notifier).clear();
      ref.read(workspaceProvider.notifier).clear();
      // Sign out
      final authService = ref.read(authServiceProvider);
      await authService.signOut();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Row(
        children: [
          // Sidebar Navigation
          AnimatedBuilder(
            animation: _sidebarAnimation,
            builder: (context, child) => Container(
            width: _sidebarAnimation.value,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                right: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: Column(
              children: [
                // App Header with Workspace Selector and Collapse Button
                Stack(
                  children: [
                    Container(
                  padding: EdgeInsets.all(_isSidebarCollapsed ? 12 : 24),
                  child: Column(
                    children: [
                      // Logo and Title
                      Row(
                        mainAxisAlignment: _isSidebarCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                        children: [
                          Container(
                            width: _isSidebarCollapsed ? 36 : 48,
                            height: _isSidebarCollapsed ? 36 : 48,
                            padding: EdgeInsets.all(_isSidebarCollapsed ? 6 : 8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: SvgPicture.asset(
                              'assets/icons/flowhunt-logo.svg',
                              colorFilter: ColorFilter.mode(
                                theme.colorScheme.primary,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                          if (!_isSidebarCollapsed) ...[
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'FlowHunt',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Desktop',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                      if (!_isSidebarCollapsed) ...[
                        const SizedBox(height: 16),
                        // Workspace Dropdown
                      Consumer(
                        builder: (context, ref, _) {
                          final workspaceState = ref.watch(workspaceProvider);

                          if (workspaceState.isLoading && workspaceState.workspaces.isEmpty) {
                            return const LinearProgressIndicator();
                          }

                          if (workspaceState.workspaces.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                border: Border.all(
                                  color: theme.dividerColor.withValues(alpha: 0.2),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    size: 16,
                                    color: theme.colorScheme.error,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'No workspaces',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              border: Border.all(
                                color: theme.dividerColor.withValues(alpha: 0.2),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<WorkspaceRole>(
                                value: workspaceState.currentWorkspace,
                                isExpanded: true,
                                isDense: false,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                icon: Icon(
                                  Icons.arrow_drop_down,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                                borderRadius: BorderRadius.circular(8),
                                items: workspaceState.workspaces.map((workspace) {
                                  return DropdownMenuItem<WorkspaceRole>(
                                    value: workspace,
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.business_outlined,
                                          size: 16,
                                          color: theme.colorScheme.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                workspace.workspaceName,
                                                style: theme.textTheme.bodyMedium?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (workspace.role != 'M')
                                                Text(
                                                  workspace.roleDisplayName,
                                                  style: theme.textTheme.bodySmall?.copyWith(
                                                    color: workspace.isOwner || workspace.isAdmin
                                                        ? theme.colorScheme.primary
                                                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                                    fontSize: 10,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (workspace) {
                                  if (workspace != null) {
                                    ref.read(workspaceProvider.notifier).switchWorkspace(workspace);
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
                      ],
                    ],
                  ),
                ),
                    // Collapse/Expand Button
                    Positioned(
                      top: 12,
                      right: 8,
                      child: IconButton(
                        onPressed: _toggleSidebar,
                        icon: Icon(
                          _isSidebarCollapsed
                            ? Icons.keyboard_arrow_right
                            : Icons.keyboard_arrow_left,
                          size: 20,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: theme.colorScheme.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: theme.dividerColor.withValues(alpha: 0.2),
                            ),
                          ),
                        ),
                        tooltip: _isSidebarCollapsed ? 'Expand sidebar' : 'Collapse sidebar',
                      ),
                    ),
                  ],
                ),

                const Divider(height: 1),

                // Navigation Items
                Expanded(
                  child: Column(
                    children: [
                      // Main navigation items or settings menu
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _isInSettingsMenu ? _settingsMenuItems.length : _navigationItems.length,
                          itemBuilder: (context, index) {
                            final items = _isInSettingsMenu ? _settingsMenuItems : _navigationItems;
                            final item = items[index];
                            final isSelected = _selectedIndex == index;

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 2,
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    if (_isInSettingsMenu) {
                                      if (index == 0) {
                                        // Back button
                                        setState(() {
                                          _isInSettingsMenu = false;
                                          _selectedIndex = 0; // Go back to Home
                                        });
                                      } else {
                                        setState(() {
                                          _selectedIndex = index;
                                        });
                                      }
                                    } else {
                                      if (index == 0 && _isInConversation) {
                                        // Handle new chat
                                        _handleNewChat();
                                      } else {
                                        setState(() {
                                          _selectedIndex = index;
                                        });
                                      }
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: _isSidebarCollapsed ? 8 : 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected && !(_isInSettingsMenu && index == 0)
                                          ? theme.colorScheme.primary.withValues(alpha: 0.1)
                                          : null,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: _isSidebarCollapsed
                                        ? MainAxisAlignment.center
                                        : MainAxisAlignment.start,
                                      children: [
                                        Icon(
                                          isSelected ? item.selectedIcon : item.icon,
                                          color: (_isInSettingsMenu && index == 0)
                                              ? theme.colorScheme.onSurface.withValues(alpha: 0.6)
                                              : isSelected
                                                  ? theme.colorScheme.primary
                                                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                          size: 24,
                                        ),
                                        if (!_isSidebarCollapsed) ...[
                                          const SizedBox(width: 16),
                                          Text(
                                            item.label,
                                            style: TextStyle(
                                              color: (_isInSettingsMenu && index == 0)
                                                  ? theme.colorScheme.onSurface.withValues(alpha: 0.8)
                                                  : isSelected
                                                      ? theme.colorScheme.primary
                                                      : theme.colorScheme.onSurface.withValues(alpha: 0.8),
                                              fontWeight: isSelected && !(_isInSettingsMenu && index == 0)
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      // Settings button at the bottom (only in main menu)
                      if (!_isInSettingsMenu) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 2,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _isInSettingsMenu = true;
                                  _selectedIndex = 2; // Select Addons by default
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: _isSidebarCollapsed ? 8 : 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: _isSidebarCollapsed
                                    ? MainAxisAlignment.center
                                    : MainAxisAlignment.start,
                                  children: [
                                    Icon(
                                      _settingsItem.icon,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                      size: 24,
                                    ),
                                    if (!_isSidebarCollapsed) ...[
                                      const SizedBox(width: 16),
                                      Text(
                                        _settingsItem.label,
                                        style: TextStyle(
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                                          fontWeight: FontWeight.normal,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),

                const Divider(height: 1),

                // User Profile Section
                Consumer(
                  builder: (context, ref, _) {
                    final userState = ref.watch(userProvider);
                    final user = userState.user;

                    return Container(
                      padding: EdgeInsets.all(_isSidebarCollapsed ? 8 : 16),
                      child: _isSidebarCollapsed
                          ? Center(
                              child: Tooltip(
                                message: user?.displayName ?? 'User Account',
                                child: CircleAvatar(
                                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                                  radius: 20,
                                  backgroundImage: user?.avatarUrl != null
                                      ? NetworkImage(user!.avatarUrl!)
                                      : null,
                                  child: user?.avatarUrl == null
                                      ? user != null
                                          ? Text(
                                              user.initials.substring(0, 1),
                                              style: TextStyle(
                                                color: theme.colorScheme.primary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            )
                                          : Icon(
                                              Icons.person_outline,
                                              color: theme.colorScheme.primary,
                                              size: 20,
                                            )
                                      : null,
                                ),
                              ),
                            )
                          : Row(
                              children: [
                                // Avatar with initials or icon
                                CircleAvatar(
                                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                                  backgroundImage: user?.avatarUrl != null
                                      ? NetworkImage(user!.avatarUrl!)
                                      : null,
                                  child: user?.avatarUrl == null
                                      ? user != null
                                          ? Text(
                                              user.initials,
                                              style: TextStyle(
                                                color: theme.colorScheme.primary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            )
                                          : Icon(
                                              Icons.person_outline,
                                              color: theme.colorScheme.primary,
                                            )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Show loading state or user name
                                      userState.isLoading
                                          ? const SizedBox(
                                              height: 12,
                                              width: 100,
                                              child: LinearProgressIndicator(),
                                            )
                                          : Text(
                                              user?.displayName ?? 'User Account',
                                              style: theme.textTheme.bodyMedium?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                      Text(
                                        user?.email ?? 'Loading...',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: _handleSignOut,
                                  icon: const Icon(
                                    Icons.logout,
                                    size: 20,
                                  ),
                                  tooltip: 'Sign Out',
                                ),
                              ],
                            ),
                    );
                  },
                ),
              ],
            ),
          ),
          ),

          // Main Content Area
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isInSettingsMenu) {
      switch (_selectedIndex) {
        case 0: // Back - should not show content
          return Container();
        case 1: // Connectors
          return _buildConnectorsContent();
        case 2: // Addons
          return _buildAddonsContent();
        default:
          return Container();
      }
    } else {
      switch (_selectedIndex) {
        case 0:
          return _AIAssistantChat(
            onConversationStateChanged: _updateConversationState,
            // Use a stable key based on conversation state
            key: ValueKey('chat_$_isInConversation'),
          );
        case 1:
          return _buildComingSoonContent('AI Agents', Icons.smart_toy_outlined);
        case 2: // Settings - should not show content, handled by menu switch
          return Container();
        default:
          return _AIAssistantChat(
            onConversationStateChanged: _updateConversationState,
            key: ValueKey('chat_$_isInConversation'),
          );
      }
    }
  }

  Widget _buildComingSoonContent(String title, IconData icon) {
    final theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.surface.withValues(alpha: 0.3),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                icon,
                size: 64,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Coming Soon',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'This feature will be available in a future update',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectorsContent() {
    final theme = Theme.of(context);
    final workspaceState = ref.watch(workspaceProvider);

    return Container(
      color: theme.colorScheme.surface.withValues(alpha: 0.3),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.hub,
                size: 32,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Connectors',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Connect your workspace to external services',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Current Workspace Info
          if (workspaceState.currentWorkspace != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.business,
                    color: theme.colorScheme.primary.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Workspace',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      Text(
                        workspaceState.currentWorkspace!.workspaceName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Coming Soon Message
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      Icons.hub_outlined,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Connectors',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Coming Soon',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Connect to Slack, Discord, Telegram, and more',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Integrations will be available in a future update',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddonsContent() {
    final theme = Theme.of(context);
    final addonState = ref.watch(addonProvider);
    final workspaceState = ref.watch(workspaceProvider);

    return Container(
      color: theme.colorScheme.surface.withValues(alpha: 0.3),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.extension,
                size: 32,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Addons',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Manage workspace addons and features',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Current Workspace Info
          if (workspaceState.currentWorkspace != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.business,
                    color: theme.colorScheme.primary.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Workspace',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      Text(
                        workspaceState.currentWorkspace!.workspaceName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Active Addon
          if (addonState.activeAddon != null) ...[
            Text(
              'Active Addon',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.1),
                    theme.colorScheme.primary.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.check_circle,
                      color: theme.colorScheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          addonState.activeAddon!.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          addonState.activeAddon!.description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],

          // Available Addons List
          Text(
            'Available Addons',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),

          if (addonState.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (addonState.availableAddons.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.2),
                ),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 48,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No addons available',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 300,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.5,
                ),
                itemCount: addonState.availableAddons.length,
                itemBuilder: (context, index) {
                  final addon = addonState.availableAddons[index];
                  final isActive = addon.id == addonState.activeAddon?.id;

                  return Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isActive
                            ? theme.colorScheme.primary
                            : theme.dividerColor.withValues(alpha: 0.2),
                        width: isActive ? 2 : 1,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: isActive
                            ? null
                            : () {
                                ref.read(addonProvider.notifier).activateAddon(addon.id);
                              },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.extension,
                                    color: isActive
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      addon.name,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: isActive
                                            ? theme.colorScheme.primary
                                            : null,
                                      ),
                                    ),
                                  ),
                                  if (isActive)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'Active',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              Text(
                                addon.description,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          // Info message
          if (!addonState.isLoading && addonState.availableAddons.isNotEmpty) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Each workspace has at least one addon activated. The UI and features change based on the selected addon.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NavigationItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  _NavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

// AI Assistant Chat Widget with new centered initial design
class _AIAssistantChat extends ConsumerStatefulWidget {
  final Function(bool)? onConversationStateChanged;

  const _AIAssistantChat({
    super.key,
    this.onConversationStateChanged,
  });

  @override
  ConsumerState<_AIAssistantChat> createState() => _AIAssistantChatState();
}

class _AIAssistantChatState extends ConsumerState<_AIAssistantChat> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _hasStartedConversation = false;
  bool _isChatSidebarVisible = false; // Start with sidebar collapsed
  String _selectedModel = 'GPT-4';
  final List<String> _availableModels = ['GPT-4', 'GPT-3.5', 'Claude', 'Gemini'];
  late String _mainPromptText;
  bool _lastReportedState = false; // Track last reported state to parent

  void _resetChat() {
    // Generate new prompt only once during reset
    final newPrompt = _getMainPrompt();
    setState(() {
      _hasStartedConversation = false;
      _isChatSidebarVisible = false;
      _messageController.clear();
      _mainPromptText = newPrompt;
    });
    // Focus the input field after reset
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
    // Notify parent that we're no longer in a conversation only if state changed
    if (mounted && _lastReportedState != false) {
      _lastReportedState = false;
      widget.onConversationStateChanged?.call(false);
    }
  }

  @override
  void initState() {
    super.initState();
    // Set the random greeting once when the widget is initialized
    _mainPromptText = _getMainPrompt();

    // Check if there are existing messages in the state
    final assistantState = ref.read(flowAssistantProvider);
    if (assistantState.messages.isNotEmpty) {
      _hasStartedConversation = true;
    }

    _lastReportedState = _hasStartedConversation;

    // Focus the input field when the widget is first built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasStartedConversation) {
        _focusNode.requestFocus();
      }
      // Notify parent about initial conversation state
      if (mounted) {
        widget.onConversationStateChanged?.call(_hasStartedConversation);
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendInitialMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    // Initialize session if not already done
    final assistantState = ref.read(flowAssistantProvider);
    if (assistantState.currentSession == null) {
      final availableFlows = ref.read(availableFlowsProvider);
      if (availableFlows.isNotEmpty) {
        await ref.read(flowAssistantProvider.notifier).initializeSession(
          flowId: availableFlows.first.id,
        );
      }
    }

    setState(() {
      _hasStartedConversation = true;
      _isChatSidebarVisible = false; // Keep sidebar hidden when starting conversation
    });

    // Notify parent that we're now in a conversation only if state changed
    if (_lastReportedState != true) {
      _lastReportedState = true;
      widget.onConversationStateChanged?.call(true);
    }

    _messageController.clear();
    await ref.read(flowAssistantProvider.notifier).sendMessage(message);

    // Scroll to bottom after sending
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    _messageController.clear();
    await ref.read(flowAssistantProvider.notifier).sendMessage(message);

    // Scroll to bottom after sending
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }


  String _getMainPrompt() {
    final hour = DateTime.now().hour;
    // Get user name from provider - only if widget is mounted
    String userName = 'there';
    if (mounted) {
      final userState = ref.read(userProvider);
      userName = userState.user?.username?.split(' ').first ?? 'there';
    }

    final prompts = [
      'How can I help you today?',
      'What\'s on your mind, $userName?',
      'What would you like to explore today?',
      'Ready to create something amazing?',
    ];

    if (hour < 12) {
      prompts.add('Good morning, $userName! How can I assist you?');
    } else if (hour < 17) {
      prompts.add('Good afternoon, $userName! What can I do for you?');
    } else {
      prompts.add('Good evening, $userName! How may I help you?');
    }

    // Return a random prompt
    final random = DateTime.now().millisecondsSinceEpoch % prompts.length;
    return prompts[random];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final assistantState = ref.watch(flowAssistantProvider);

    // Check if conversation has started (either from state or from messages)
    final hasMessages = assistantState.messages.isNotEmpty;
    final showChatView = _hasStartedConversation || hasMessages;

    // Update parent about conversation state only if it actually changed
    if (_lastReportedState != showChatView) {
      _lastReportedState = showChatView;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onConversationStateChanged?.call(showChatView);
        }
      });
    }

    if (!showChatView) {
      // Initial centered view
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surface.withValues(alpha: 0.95),
            ],
          ),
        ),
        child: Column(
          children: [
            // Spacer for top area
            const SizedBox(height: 60),

            // Centered content
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.50,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                        // FlowHunt Logo/Icon
                        Container(
                          width: 80,
                          height: 80,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                theme.colorScheme.primary.withValues(alpha: 0.1),
                                theme.colorScheme.primary.withValues(alpha: 0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: SvgPicture.asset(
                            'assets/icons/flowhunt-logo.svg',
                            colorFilter: ColorFilter.mode(
                              theme.colorScheme.primary,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Dynamic Title (set once in initState)
                        Text(
                          _mainPromptText,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 40),

                        // Clean input field - textarea with icons inside
                        Container(
                          decoration: BoxDecoration(
                            color: theme.brightness == Brightness.light
                                ? Colors.grey.shade100
                                : Colors.grey.shade900,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              // Text area
                              TextField(
                                controller: _messageController,
                                focusNode: _focusNode,
                                decoration: InputDecoration(
                                  hintText: 'Reply to Flowii',
                                  hintStyle: TextStyle(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                    fontSize: 15,
                                  ),
                                  filled: false,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                  contentPadding: const EdgeInsets.only(
                                    left: 16,
                                    right: 16,
                                    top: 16,
                                    bottom: 12,
                                  ),
                                ),
                                onSubmitted: (_) => _sendInitialMessage(),
                                onChanged: (_) => setState(() {}),
                                textInputAction: TextInputAction.send,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontSize: 15,
                                ),
                                autofocus: true,
                                maxLines: 3,
                                minLines: 3,
                              ),
                              // Icons row at bottom
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Attachment button at left
                                    IconButton(
                                      onPressed: () {},
                                      icon: Icon(
                                        Icons.add_circle_outline,
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                        size: 22,
                                      ),
                                      tooltip: 'Add attachment',
                                    ),
                                    // Send button at right
                                    Container(
                                      height: 32,
                                      width: 32,
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: IconButton(
                                        onPressed: _messageController.text.trim().isNotEmpty
                                            ? _sendInitialMessage
                                            : null,
                                        icon: Icon(
                                          Icons.arrow_upward,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        padding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 40),

                        // Suggestion chips
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: [
                            _buildSuggestionChip(
                              'Help me build an AI agent',
                              Icons.smart_toy_outlined,
                              theme,
                            ),
                            _buildSuggestionChip(
                              'Explain integrations',
                              Icons.hub_outlined,
                              theme,
                            ),
                            _buildSuggestionChip(
                              'Show me examples',
                              Icons.lightbulb_outline,
                              theme,
                            ),
                          ],
                        ),
                      ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Chat view (after conversation started)
    return Row(
      children: [
        // Chat history sidebar (collapsed by default)
        if (_isChatSidebarVisible)
          Container(
            width: 260,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.5),
            border: Border(
              right: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.1),
              ),
            ),
          ),
          child: Column(
            children: [
              // New Chat Button
              Container(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ref.read(flowAssistantProvider.notifier).clearSession();
                      _resetChat();
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New Chat'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              // Search bar
              Container(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search conversations...',
                    prefixIcon: Icon(
                      Icons.search,
                      size: 20,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ),
              // Chat history list
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    _buildChatHistoryItem(
                      'Current Conversation',
                      'Just now',
                      true,
                      theme,
                    ),
                    _buildChatHistoryItem(
                      'Previous chat about AI agents',
                      '2 hours ago',
                      false,
                      theme,
                    ),
                    _buildChatHistoryItem(
                      'Integration setup help',
                      'Yesterday',
                      false,
                      theme,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Main chat area
        Expanded(
          child: Container(
            color: theme.colorScheme.surface.withValues(alpha: 0.3),
            child: Column(
              children: [
                // Simplified header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border(
                      bottom: BorderSide(
                        color: theme.dividerColor.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.auto_awesome,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Assistant',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Always here to help',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Model indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _selectedModel,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Toggle sidebar button
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _isChatSidebarVisible = !_isChatSidebarVisible;
                          });
                        },
                        icon: Icon(
                          _isChatSidebarVisible ? Icons.menu_open : Icons.menu,
                          size: 24,
                        ),
                        tooltip: _isChatSidebarVisible ? 'Hide sidebar' : 'Show sidebar',
                      ),
                    ],
                  ),
                ),

                // Error Banner
                if (assistantState.error != null)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: theme.colorScheme.error,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            assistantState.error!,
                            style: TextStyle(
                              color: theme.colorScheme.error,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            ref.read(flowAssistantProvider.notifier).retryLastMessage();
                          },
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Retry'),
                          style: TextButton.styleFrom(
                            foregroundColor: theme.colorScheme.error,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Messages Area
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          theme.colorScheme.surface.withValues(alpha: 0.0),
                          theme.colorScheme.surface.withValues(alpha: 0.3),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.5,
                        ),
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          itemCount: assistantState.messages.length,
                          itemBuilder: (context, index) {
                            final message = assistantState.messages[index];
                            final isLastMessage = index == assistantState.messages.length - 1;
                            return _buildModernMessageBubble(message, theme, isLastMessage);
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                // Clean input area - centered textarea with icons inside
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.5,
                      ),
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.light
                            ? Colors.grey.shade100
                            : Colors.grey.shade900,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          // Text area
                          TextField(
                            controller: _messageController,
                            focusNode: _focusNode,
                            decoration: InputDecoration(
                              hintText: 'Reply to Flowii',
                              hintStyle: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                fontSize: 15,
                              ),
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              focusedErrorBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.only(
                                left: 16,
                                right: 16,
                                top: 16,
                                bottom: 12,
                              ),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                            onChanged: (_) => setState(() {}),
                            textInputAction: TextInputAction.send,
                            maxLines: 3,
                            minLines: 3,
                            keyboardType: TextInputType.multiline,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 15,
                            ),
                          ),
                          // Icons row at bottom
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Attachment button at left
                                IconButton(
                                  onPressed: () {},
                                  icon: Icon(
                                    Icons.add_circle_outline,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                    size: 22,
                                  ),
                                  tooltip: 'Add attachment',
                                ),
                                // Send button at right
                                Container(
                                  height: 32,
                                  width: 32,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    onPressed: _messageController.text.trim().isNotEmpty
                                        ? _sendMessage
                                        : null,
                                    icon: Icon(
                                      Icons.arrow_upward,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionChip(String label, IconData icon, ThemeData theme) {
    return InkWell(
      onTap: () {
        _messageController.text = label;
        _sendInitialMessage();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.dividerColor.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatHistoryItem(String title, String time, bool isActive, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isActive ? theme.colorScheme.primary.withValues(alpha: 0.1) : null,
              borderRadius: BorderRadius.circular(8),
              border: isActive
                  ? Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    )
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, VoidCallback onTap, ThemeData theme) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.dividerColor.withValues(alpha: 0.2),
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernMessageBubble(ChatMessage message, ThemeData theme, bool isLastMessage) {
    final isUser = message.type == MessageType.human;
    final isError = message.type == MessageType.error;
    final isLoading = message.type == MessageType.loading;

    return Padding(
      padding: EdgeInsets.only(bottom: isLastMessage ? 8 : 20),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Message header
          if (!isUser)
            Padding(
              padding: const EdgeInsets.only(left: 48, bottom: 6),
              child: Row(
                children: [
                  Text(
                    'AI Assistant',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '• now',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          // Message content
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) ...[
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: CircleAvatar(
                    backgroundColor: isError
                        ? theme.colorScheme.error.withValues(alpha: 0.1)
                        : theme.colorScheme.surface,
                    radius: 16,
                    child: isError
                        ? Icon(
                            Icons.error_outline,
                            color: theme.colorScheme.error,
                            size: 18,
                          )
                        : SvgPicture.asset(
                            'assets/icons/flowhunt-logo.svg',
                            width: 20,
                            height: 20,
                            colorFilter: ColorFilter.mode(
                              theme.colorScheme.primary,
                              BlendMode.srcIn,
                            ),
                          ),
                  ),
                ),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? theme.colorScheme.primary
                        : isError
                            ? theme.colorScheme.error.withValues(alpha: 0.1)
                            : theme.brightness == Brightness.light
                                ? Colors.grey.shade100
                                : theme.colorScheme.surface.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: isUser ? [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ] : null,
                  ),
                  child: isLoading
                      ? _buildTypingIndicator(theme)
                      : isUser
                          ? SelectableText(
                              message.content,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            )
                          : FHMarkdown(
                              content: message.content,
                              onSendMessage: (msg) {
                                _messageController.text = msg;
                                _sendMessage();
                              },
                            ),
                ),
              ),
              if (isUser && false) ...[
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  child: CircleAvatar(
                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                    radius: 16,
                    child: Text(
                      'Y',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          // Action buttons for AI messages
          if (!isUser && !isLoading && !isError)
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 8),
              child: Row(
                children: [
                  _buildMessageActionButton(
                    icon: Icons.copy_rounded,
                    tooltip: 'Copy',
                    onTap: () {
                      // Copy message to clipboard
                      Clipboard.setData(ClipboardData(text: message.content));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Message copied to clipboard'),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                          margin: const EdgeInsets.all(8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                    },
                    theme: theme,
                  ),
                  const SizedBox(width: 4),
                  _buildMessageActionButton(
                    icon: Icons.thumb_up_outlined,
                    tooltip: 'Good response',
                    onTap: () {
                      // Handle thumbs up feedback
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Thanks for your feedback!'),
                          duration: const Duration(seconds: 2),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          margin: const EdgeInsets.all(8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                    },
                    theme: theme,
                  ),
                  const SizedBox(width: 4),
                  _buildMessageActionButton(
                    icon: Icons.thumb_down_outlined,
                    tooltip: 'Poor response',
                    onTap: () {
                      // Handle thumbs down feedback
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Thanks for your feedback. We\'ll improve!'),
                          duration: const Duration(seconds: 2),
                          backgroundColor: Colors.orange,
                          behavior: SnackBarBehavior.floating,
                          margin: const EdgeInsets.all(8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                    },
                    theme: theme,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Tooltip(
          message: tooltip,
          child: Container(
            padding: const EdgeInsets.all(6),
            child: Icon(
              icon,
              size: 18,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageAction(IconData icon, String tooltip, VoidCallback onTap, ThemeData theme) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(6),
        child: Icon(
          icon,
          size: 16,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.6),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.4),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(ChatMessage message, ThemeData theme) {
    final isUser = message.type == MessageType.human;
    final isError = message.type == MessageType.error;
    final isLoading = message.type == MessageType.loading;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              backgroundColor: isError
                  ? theme.colorScheme.error.withValues(alpha: 0.1)
                  : theme.colorScheme.primary.withValues(alpha: 0.1),
              radius: 18,
              child: Icon(
                isError ? Icons.error_outline : Icons.smart_toy,
                color: isError
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.65,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: isUser
                    ? theme.colorScheme.primary
                    : isError
                        ? theme.colorScheme.error.withValues(alpha: 0.1)
                        : theme.colorScheme.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: !isUser && !isError
                    ? Border.all(
                        color: theme.dividerColor.withValues(alpha: 0.2),
                      )
                    : null,
              ),
              child: isLoading
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Thinking...',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    )
                  : SelectableText(
                      message.content,
                      style: TextStyle(
                        color: isUser
                            ? Colors.white
                            : isError
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSurface,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 12),
            CircleAvatar(
              backgroundColor: theme.colorScheme.secondary.withValues(alpha: 0.1),
              radius: 18,
              child: Icon(
                Icons.person,
                color: theme.colorScheme.secondary,
                size: 20,
              ),
            ),
          ],
        ],
      ),
    );
  }
}