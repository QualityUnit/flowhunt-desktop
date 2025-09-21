import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/flow_assistant_provider.dart';
import '../../sdk/models/flow_assistant.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  final List<_NavigationItem> _navigationItems = [
    _NavigationItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: 'Home',
    ),
    _NavigationItem(
      icon: Icons.smart_toy_outlined,
      selectedIcon: Icons.smart_toy,
      label: 'AI Agents',
    ),
    _NavigationItem(
      icon: Icons.schedule_outlined,
      selectedIcon: Icons.schedule,
      label: 'Triggers',
    ),
    _NavigationItem(
      icon: Icons.hub_outlined,
      selectedIcon: Icons.hub,
      label: 'Integrations',
    ),
    _NavigationItem(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: 'Settings',
    ),
  ];

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
      // Clear user data
      ref.read(userProvider.notifier).clear();
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
          Container(
            width: 280,
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
                // App Header
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        padding: const EdgeInsets.all(8),
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
                  ),
                ),

                const Divider(height: 1),

                // Navigation Items
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _navigationItems.length,
                    itemBuilder: (context, index) {
                      final item = _navigationItems[index];
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
                              setState(() {
                                _selectedIndex = index;
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.colorScheme.primary.withValues(alpha: 0.1)
                                    : null,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected ? item.selectedIcon : item.icon,
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                    size: 24,
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    item.label,
                                    style: TextStyle(
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurface.withValues(alpha: 0.8),
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      fontSize: 15,
                                    ),
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

                const Divider(height: 1),

                // User Profile Section
                Consumer(
                  builder: (context, ref, _) {
                    final userState = ref.watch(userProvider);
                    final user = userState.user;

                    return Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
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
                            icon: const Icon(Icons.logout),
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

          // Main Content Area
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _AIAssistantChat();
      case 1:
        return _buildComingSoonContent('AI Agents', Icons.smart_toy_outlined);
      case 2:
        return _buildComingSoonContent('Triggers', Icons.schedule_outlined);
      case 3:
        return _buildComingSoonContent('Integrations', Icons.hub_outlined);
      case 4:
        return _buildComingSoonContent('Settings', Icons.settings_outlined);
      default:
        return _AIAssistantChat();
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
  const _AIAssistantChat();

  @override
  ConsumerState<_AIAssistantChat> createState() => _AIAssistantChatState();
}

class _AIAssistantChatState extends ConsumerState<_AIAssistantChat> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _hasStartedConversation = false;
  String _selectedModel = 'GPT-4';
  final List<String> _availableModels = ['GPT-4', 'GPT-3.5', 'Claude', 'Gemini'];
  late String _mainPromptText;

  @override
  void initState() {
    super.initState();
    // Set the random greeting once when the widget is initialized
    _mainPromptText = _getMainPrompt();
    // Focus the input field when the widget is first built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
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
    });

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
    // Get user name from provider
    final userState = ref.read(userProvider);
    final userName = userState.user?.username?.split(' ').first ?? 'there';
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
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

                        // Input field with actions
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              TextField(
                                controller: _messageController,
                                focusNode: _focusNode,
                                decoration: InputDecoration(
                                  hintText: 'Ask me anything...',
                                  filled: true,
                                  fillColor: theme.colorScheme.surface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(16),
                                      topRight: Radius.circular(16),
                                      bottomLeft: Radius.circular(0),
                                      bottomRight: Radius.circular(0),
                                    ),
                                    borderSide: BorderSide(
                                      color: theme.dividerColor.withValues(alpha: 0.1),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(16),
                                      topRight: Radius.circular(16),
                                      bottomLeft: Radius.circular(0),
                                      bottomRight: Radius.circular(0),
                                    ),
                                    borderSide: BorderSide(
                                      color: theme.dividerColor.withValues(alpha: 0.1),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(16),
                                      topRight: Radius.circular(16),
                                      bottomLeft: Radius.circular(0),
                                      bottomRight: Radius.circular(0),
                                    ),
                                    borderSide: BorderSide(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.5),
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 20,
                                  ),
                                ),
                                onSubmitted: (_) => _sendInitialMessage(),
                                onChanged: (_) => setState(() {}),
                                textInputAction: TextInputAction.send,
                                style: theme.textTheme.bodyLarge,
                                autofocus: true,
                                maxLines: 10,
                                minLines: 2,
                              ),
                              // Always show the action bar
                              Container(
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surface,
                                    border: Border(
                                      left: BorderSide(
                                        color: theme.dividerColor.withValues(alpha: 0.1),
                                      ),
                                      right: BorderSide(
                                        color: theme.dividerColor.withValues(alpha: 0.1),
                                      ),
                                      bottom: BorderSide(
                                        color: theme.dividerColor.withValues(alpha: 0.1),
                                      ),
                                    ),
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(16),
                                      bottomRight: Radius.circular(16),
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: Row(
                                    children: [
                                      // Plus button for attachments
                                      IconButton(
                                        onPressed: () {
                                          // TODO: Implement attachment
                                        },
                                        icon: Icon(
                                          Icons.add_circle_outline,
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                        ),
                                        tooltip: 'Add attachment',
                                      ),
                                      const SizedBox(width: 8),
                                      // Model selector
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: theme.dividerColor.withValues(alpha: 0.2),
                                          ),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: _selectedModel,
                                            items: _availableModels.map((model) {
                                              return DropdownMenuItem(
                                                value: model,
                                                child: Text(
                                                  model,
                                                  style: theme.textTheme.bodySmall,
                                                ),
                                              );
                                            }).toList(),
                                            onChanged: (value) {
                                              setState(() {
                                                _selectedModel = value!;
                                              });
                                            },
                                            isDense: true,
                                            icon: Icon(
                                              Icons.arrow_drop_down,
                                              size: 20,
                                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                            ),
                                            style: TextStyle(
                                              color: theme.colorScheme.onSurface,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      // Send button with up arrow
                                      Container(
                                        height: 32,
                                        width: 32,
                                        decoration: BoxDecoration(
                                          color: _messageController.text.trim().isNotEmpty
                                              ? theme.colorScheme.primary
                                              : theme.colorScheme.primary.withValues(alpha: 0.3),
                                          shape: BoxShape.circle,
                                        ),
                                        child: IconButton(
                                          onPressed: _messageController.text.trim().isNotEmpty
                                              ? _sendInitialMessage
                                              : null,
                                          icon: const Icon(
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
          ],
        ),
      );
    }

    // Chat view (after conversation started)
    return Container(
      color: theme.colorScheme.surface.withValues(alpha: 0.3),
      child: Column(
        children: [
          // Chat Header - simplified without greeting
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.colorScheme.surface,
            child: Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'AI Assistant',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                // New Chat Button
                OutlinedButton.icon(
                  onPressed: () {
                    ref.read(flowAssistantProvider.notifier).clearSession();
                    setState(() {
                      _hasStartedConversation = false;
                      _messageController.clear();
                    });
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Chat'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Error Banner
          if (assistantState.error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: theme.colorScheme.error.withValues(alpha: 0.1),
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
                  IconButton(
                    onPressed: () {
                      ref.read(flowAssistantProvider.notifier).retryLastMessage();
                    },
                    icon: const Icon(Icons.refresh),
                    iconSize: 20,
                    color: theme.colorScheme.error,
                    tooltip: 'Retry',
                  ),
                ],
              ),
            ),

          // Messages Area
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(24),
              itemCount: assistantState.messages.length,
              itemBuilder: (context, index) {
                final message = assistantState.messages[index];
                return _buildMessageBubble(message, theme);
              },
            ),
          ),

          // Input Area at bottom with actions
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Action bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: theme.dividerColor.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Plus button for attachments
                      IconButton(
                        onPressed: () {
                          // TODO: Implement attachment
                        },
                        icon: Icon(
                          Icons.add_circle_outline,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          size: 20,
                        ),
                        tooltip: 'Add attachment',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Model selector
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.psychology,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedModel,
                                items: _availableModels.map((model) {
                                  return DropdownMenuItem(
                                    value: model,
                                    child: Text(
                                      model,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedModel = value!;
                                  });
                                },
                                isDense: true,
                                icon: Icon(
                                  Icons.arrow_drop_down,
                                  size: 18,
                                  color: theme.colorScheme.primary,
                                ),
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Text input area
                Container(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            border: Border.all(
                              color: theme.dividerColor.withValues(alpha: 0.2),
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: TextField(
                            controller: _messageController,
                            focusNode: _focusNode,
                            decoration: InputDecoration(
                              hintText: 'Type your message...',
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                            onChanged: (_) => setState(() {}),
                            textInputAction: TextInputAction.send,
                            maxLines: 5,
                            minLines: 1,
                            keyboardType: TextInputType.multiline,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Send button with up arrow
                      Container(
                        height: 36,
                        width: 36,
                        decoration: BoxDecoration(
                          color: _messageController.text.trim().isNotEmpty
                              ? theme.colorScheme.primary
                              : theme.colorScheme.primary.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: _messageController.text.trim().isNotEmpty
                              ? _sendMessage
                              : null,
                          icon: const Icon(
                            Icons.arrow_upward,
                            color: Colors.white,
                            size: 18,
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
        ],
      ),
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