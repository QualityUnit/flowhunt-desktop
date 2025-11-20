import 'package:flutter/material.dart';
import '../sdk/models/workspace.dart';

class SearchableWorkspaceSelector extends StatefulWidget {
  final List<WorkspaceRole> workspaces;
  final WorkspaceRole? currentWorkspace;
  final ValueChanged<WorkspaceRole> onChanged;

  const SearchableWorkspaceSelector({
    super.key,
    required this.workspaces,
    required this.currentWorkspace,
    required this.onChanged,
  });

  @override
  State<SearchableWorkspaceSelector> createState() => _SearchableWorkspaceSelectorState();
}

class _SearchableWorkspaceSelectorState extends State<SearchableWorkspaceSelector> {
  void _showWorkspacePicker() {
    showDialog(
      context: context,
      builder: (context) => _WorkspacePickerDialog(
        workspaces: widget.workspaces,
        currentWorkspace: widget.currentWorkspace,
        onChanged: widget.onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: _showWorkspacePicker,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
              Icons.business_outlined,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: widget.currentWorkspace != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.currentWorkspace!.workspaceName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.currentWorkspace!.role != 'M')
                          Text(
                            widget.currentWorkspace!.roleDisplayName,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: widget.currentWorkspace!.isOwner || widget.currentWorkspace!.isAdmin
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 10,
                            ),
                          ),
                      ],
                    )
                  : Text(
                      'Select workspace',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
            ),
            Icon(
              Icons.arrow_drop_down,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspacePickerDialog extends StatefulWidget {
  final List<WorkspaceRole> workspaces;
  final WorkspaceRole? currentWorkspace;
  final ValueChanged<WorkspaceRole> onChanged;

  const _WorkspacePickerDialog({
    required this.workspaces,
    required this.currentWorkspace,
    required this.onChanged,
  });

  @override
  State<_WorkspacePickerDialog> createState() => _WorkspacePickerDialogState();
}

class _WorkspacePickerDialogState extends State<_WorkspacePickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  List<WorkspaceRole> _filteredWorkspaces = [];

  @override
  void initState() {
    super.initState();
    _filteredWorkspaces = widget.workspaces;
    _searchController.addListener(_filterWorkspaces);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _filterWorkspaces() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredWorkspaces = widget.workspaces;
      } else {
        _filteredWorkspaces = widget.workspaces.where((workspace) {
          return workspace.workspaceName.toLowerCase().contains(query) ||
                 workspace.ownerName.toLowerCase().contains(query) ||
                 workspace.ownerEmail.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.business_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Select Workspace',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search field
            TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search workspaces...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.colorScheme.surface,
              ),
            ),
            const SizedBox(height: 16),

            // Workspace count
            Text(
              '${_filteredWorkspaces.length} workspace${_filteredWorkspaces.length != 1 ? 's' : ''}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),

            // Workspace list
            Flexible(
              child: _filteredWorkspaces.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 48,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No workspaces found',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredWorkspaces.length,
                      itemBuilder: (context, index) {
                        final workspace = _filteredWorkspaces[index];
                        final isSelected = workspace.workspaceId == widget.currentWorkspace?.workspaceId;

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              widget.onChanged(workspace);
                              Navigator.of(context).pop();
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.colorScheme.primary.withValues(alpha: 0.1)
                                    : null,
                                borderRadius: BorderRadius.circular(8),
                                border: isSelected
                                    ? Border.all(
                                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                        width: 1,
                                      )
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected ? Icons.business : Icons.business_outlined,
                                    size: 20,
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          workspace.workspaceName,
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                            color: isSelected
                                                ? theme.colorScheme.primary
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Text(
                                              workspace.roleDisplayName,
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: workspace.isOwner || workspace.isAdmin
                                                    ? theme.colorScheme.primary
                                                    : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                                fontSize: 11,
                                              ),
                                            ),
                                            Text(
                                              ' • ',
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                                fontSize: 11,
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                workspace.ownerName,
                                                style: theme.textTheme.bodySmall?.copyWith(
                                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                                  fontSize: 11,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(
                                      Icons.check_circle,
                                      size: 20,
                                      color: theme.colorScheme.primary,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
