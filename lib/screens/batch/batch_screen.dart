import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:desktop_drop/desktop_drop.dart';

import '../../sdk/models/flow.dart';
import '../../sdk/models/batch_task.dart';
import '../../providers/workspace_provider.dart';
import '../../providers/flow_provider.dart';

class BatchScreen extends ConsumerStatefulWidget {
  const BatchScreen({super.key});

  @override
  ConsumerState<BatchScreen> createState() => _BatchScreenState();
}

class _BatchScreenState extends ConsumerState<BatchScreen> {
  final Logger _logger = Logger();
  int _currentStep = 0;
  FlowResponse? _selectedFlow;
  final List<BatchTask> _tasks = [];
  int _parallelExecutions = 5;
  bool _isExecuting = false;
  bool _useSingleton = true; // Singleton mode is default
  bool _writeOutputToFile = true; // Write output to file option (enabled by default)
  String _outputDirectory = Directory.current.path; // Default to current directory
  bool _isDragging = false; // Track drag over state

  @override
  void initState() {
    super.initState();
    _loadSavedOutputDirectory();
    _logger.i('🎯 BatchScreen initialized - DropTarget will be enabled');
  }

  Future<void> _loadSavedOutputDirectory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDirectory = prefs.getString('batch_output_directory');

      if (savedDirectory != null && savedDirectory.isNotEmpty) {
        // Verify the directory still exists
        final dir = Directory(savedDirectory);
        if (await dir.exists()) {
          setState(() {
            _outputDirectory = savedDirectory;
          });
          _logger.i('Loaded saved output directory: $savedDirectory');
        } else {
          _logger.w('Saved directory no longer exists: $savedDirectory, using default');
        }
      } else {
        _logger.d('No saved output directory, using default: ${Directory.current.path}');
      }
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to load saved output directory',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _saveOutputDirectory(String directory) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('batch_output_directory', directory);
      _logger.i('Saved output directory preference: $directory');
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to save output directory preference',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final workspaceState = ref.watch(workspaceProvider);

    return Container(
      color: theme.colorScheme.surface.withValues(alpha: 0.3),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 32,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Batch Processing',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Execute flows in batch with parallel processing',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Stepper
          Expanded(
            child: Stepper(
              currentStep: _currentStep,
              onStepTapped: (step) {
                // Allow navigation to any step by clicking on the step title
                setState(() => _currentStep = step);
              },
              onStepContinue: _currentStep < 3 ? () {
                if (_currentStep == 0 && _selectedFlow == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a flow')),
                  );
                  return;
                }
                if (_currentStep == 2 && _tasks.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please add tasks')),
                  );
                  return;
                }
                setState(() => _currentStep++);
              } : null,
              onStepCancel: _currentStep > 0 ? () {
                setState(() => _currentStep--);
              } : null,
              controlsBuilder: (context, details) {
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    children: [
                      if (_currentStep < 3)
                        ElevatedButton(
                          onPressed: details.onStepContinue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Continue'),
                        ),
                      if (_currentStep > 0) ...[
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: details.onStepCancel,
                          child: const Text('Back'),
                        ),
                      ],
                    ],
                  ),
                );
              },
              steps: [
                Step(
                  title: const Text('Select Flow'),
                  content: _buildFlowSelectionStep(workspaceState),
                  isActive: _currentStep >= 0,
                  state: _currentStep > 0 ? StepState.complete : StepState.indexed,
                ),
                Step(
                  title: const Text('Configuration'),
                  content: _buildConfigurationStep(),
                  isActive: _currentStep >= 1,
                  state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                ),
                Step(
                  title: const Text('Input Data'),
                  content: _buildInputDataStep(),
                  isActive: _currentStep >= 2,
                  state: _currentStep > 2 ? StepState.complete : StepState.indexed,
                ),
                Step(
                  title: const Text('Execute'),
                  content: _buildExecutionStep(),
                  isActive: _currentStep >= 3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowSelectionStep(WorkspaceState workspaceState) {
    final theme = Theme.of(context);

    if (workspaceState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (workspaceState.error != null) {
      return Text('Error: ${workspaceState.error}');
    }

    final workspaceId = workspaceState.currentWorkspace?.workspaceId;
    if (workspaceId == null) {
      return const Text('No workspace selected');
    }

    final flowsAsync = ref.watch(flowsProvider(workspaceId));

    return flowsAsync.when(
      data: (flows) {
        _logger.i('Batch screen received ${flows.length} flows');

        if (flows.isEmpty) {
          _logger.w('No flows received from API');
          return const Text('No flows available');
        }

        final validFlows = flows.where((flow) => flow.name != null && flow.flowId != null).toList();
        _logger.i('Valid flows for display: ${validFlows.length}');

        if (validFlows.isEmpty) {
          _logger.w('All flows have null name or flowId');
          for (final flow in flows) {
            _logger.w('Flow data: flowId=${flow.flowId}, name=${flow.name}');
          }
          return const Text('No valid flows available (all flows have missing data)');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select a flow to execute in batch:',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () => _showFlowPicker(context, validFlows),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selectedFlow?.name ?? 'Select a flow...',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: _selectedFlow == null
                              ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),
            ),
            if (_selectedFlow != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Flow ID
                    Row(
                      children: [
                        Icon(
                          Icons.tag,
                          size: 16,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Flow ID: ',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            _selectedFlow!.flowId ?? 'N/A',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Description (if available)
                    if (_selectedFlow!.description != null && _selectedFlow!.description!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedFlow!.description!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.error.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Text(
                  'Error loading flows',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                // Invalidate the provider to retry
                ref.invalidate(flowsProvider(workspaceId));
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigurationStep() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Configure batch execution settings',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 24),

        // Singleton mode toggle
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.settings_outlined,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Execution Mode:',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<bool>(
                      value: _useSingleton,
                      underline: const SizedBox(),
                      isDense: true,
                      items: const [
                        DropdownMenuItem(
                          value: true,
                          child: Text('Single Execution'),
                        ),
                        DropdownMenuItem(
                          value: false,
                          child: Text('Normal'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _useSingleton = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _useSingleton
                      ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _useSingleton ? Icons.check_circle : Icons.info_outline,
                          size: 16,
                          color: _useSingleton
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _useSingleton ? 'Singleton Mode' : 'Normal Mode',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: _useSingleton
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _useSingleton
                          ? 'Each task is executed only once for the given input. If the same input is queued multiple times, it will be executed only once.'
                          : 'Each task is executed independently. The same input can be executed multiple times in parallel.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Parallel executions setting
              Row(
                children: [
                  Icon(
                    Icons.sync_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Parallel Executions:',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: DropdownButton<int>(
                      value: _parallelExecutions,
                      underline: const SizedBox(),
                      isDense: true,
                      items: List.generate(50, (index) => index + 1)
                          .map((value) => DropdownMenuItem<int>(
                                value: value,
                                child: Text(
                                  value.toString(),
                                  style: theme.textTheme.bodySmall,
                                ),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _parallelExecutions = value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'task${_parallelExecutions > 1 ? 's' : ''} at a time',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Write output to file option
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _writeOutputToFile ? Icons.save_outlined : Icons.save_as_outlined,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Write Output to File',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Switch(
                    value: _writeOutputToFile,
                    onChanged: (value) {
                      setState(() => _writeOutputToFile = value);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _writeOutputToFile
                      ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _writeOutputToFile ? Icons.check_circle : Icons.info_outline,
                          size: 16,
                          color: _writeOutputToFile
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _writeOutputToFile ? 'Enabled' : 'Disabled',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: _writeOutputToFile
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _writeOutputToFile
                          ? 'Flow output will be saved to files. Filename column is required for each task.'
                          : 'Flow output will not be saved to files. Filename column is not needed.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                    if (_writeOutputToFile) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Output Directory',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _selectOutputDirectory,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: theme.colorScheme.outline.withValues(alpha: 0.3),
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.folder_outlined,
                                size: 18,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _outputDirectory,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.edit_outlined,
                                size: 16,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputDataStep() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Action buttons
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _importFromCSV,
              icon: const Icon(Icons.upload_file),
              label: const Text('Import from CSV'),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _addManualTask,
              icon: const Icon(Icons.add),
              label: const Text('Add Task'),
            ),
            if (_tasks.isNotEmpty) ...[
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: () {
                  setState(() => _tasks.clear());
                },
                icon: const Icon(Icons.clear),
                label: const Text('Clear All'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 24),

        // Tasks table with drag and drop support
        DropTarget(
          onDragEntered: (details) {
            _logger.i('🎯 DRAG ENTERED - File drag detected!');
            setState(() => _isDragging = true);
          },
          onDragUpdated: (details) {
            _logger.d('🎯 DRAG UPDATED - Position: ${details.localPosition}');
          },
          onDragExited: (details) {
            _logger.i('🎯 DRAG EXITED - File drag left');
            setState(() => _isDragging = false);
          },
          onDragDone: (details) async {
            setState(() => _isDragging = false);
            _logger.i('🎯 DRAG DONE - Files dropped: ${details.files.length}');

            for (var file in details.files) {
              _logger.d('  - Dropped file: ${file.path}');
            }

            // Find CSV files
            final csvFiles = details.files.where((file) => file.path.toLowerCase().endsWith('.csv')).toList();

            if (csvFiles.isEmpty) {
              _logger.w('No CSV files in dropped files');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please drop a CSV file')),
                );
              }
              return;
            }

            // Import the first CSV file
            final csvFile = csvFiles.first;
            _logger.i('Importing dropped CSV file: ${csvFile.path}');
            await _importFromCSVFile(csvFile.path);
          },
          child: _tasks.isEmpty
            ? Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _isDragging
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline.withValues(alpha: 0.3),
                    width: _isDragging ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: _isDragging
                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.1)
                    : null,
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        _isDragging ? Icons.upload_file : Icons.table_chart_outlined,
                        size: 48,
                        color: _isDragging
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isDragging
                          ? 'Drop CSV file here to import'
                          : 'No tasks added yet',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: _isDragging
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          fontWeight: _isDragging ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      if (!_isDragging) ...[
                        const SizedBox(height: 8),
                        Text(
                          'or drag & drop a CSV file',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            : Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _isDragging
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline.withValues(alpha: 0.3),
                    width: _isDragging ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: _isDragging
                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.1)
                    : null,
                ),
                child: Column(
              children: [
                // Table header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Flow Input',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (_writeOutputToFile)
                        Expanded(
                          child: Text(
                            'Filename',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                // Table rows
                SizedBox(
                  height: 400,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _tasks.length,
                    itemBuilder: (context, index) {
                      final task = _tasks[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: theme.colorScheme.outline.withValues(alpha: 0.2),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: InkWell(
                                onTap: () => _editTaskInput(index),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    task.flowInput['input']?.toString() ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                            if (_writeOutputToFile)
                              Expanded(
                                child: InkWell(
                                  onTap: () => _editTaskFilename(index),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      task.filename ?? '-',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () {
                                setState(() => _tasks.removeAt(index));
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExecutionStep() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Control buttons and status
        Wrap(
          spacing: 16,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  onPressed: _isExecuting ? _stopExecution : _startExecution,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isExecuting
                      ? theme.colorScheme.error
                      : Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  icon: Icon(_isExecuting ? Icons.stop : Icons.play_arrow),
                  label: Text(_isExecuting ? 'Stop' : 'Start'),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _canWriteToFiles() ? _writeOutputsToFiles : null,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Write to Files'),
                ),
              ],
            ),
            // Status summary
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildStatusChip('Waiting', _getTaskCountByStatus('waiting'), Colors.grey),
                  _buildStatusChip('Queued', _getTaskCountByStatus('queued'), Colors.blue),
                  _buildStatusChip('Done', _getTaskCountByStatus('done'), Colors.green),
                  _buildStatusChip('Failed', _getTaskCountByStatus('failed'), Colors.red),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Execution monitoring table
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              // Table header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 50,
                      child: Text(
                        '#',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Input Value',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (_writeOutputToFile)
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Filename',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        'Status',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Time',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Credits',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Output',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Table rows
              SizedBox(
                height: 400,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _tasks.length,
                  itemBuilder: (context, index) {
                    final task = _tasks[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: theme.colorScheme.outline.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 50,
                            child: Text(
                              '${index + 1}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: InkWell(
                              onTap: () => _editTaskInput(index),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  task.flowInput['input']?.toString() ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ),
                          ),
                          if (_writeOutputToFile)
                            Expanded(
                              flex: 2,
                              child: InkWell(
                                onTap: () => _editTaskFilename(index),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Text(
                                    task.filename ?? '-',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                              ),
                            ),
                          SizedBox(
                            width: 50,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildStatusBadge(task, theme),
                                const SizedBox(width: 4),
                                if (task.status == 'waiting' || task.status == 'pending') ...[
                                  IconButton(
                                    icon: const Icon(Icons.play_arrow, size: 16),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 20,
                                      minHeight: 20,
                                    ),
                                    tooltip: 'Start task',
                                    onPressed: () => _startSingleTask(task),
                                  ),
                                ],
                                if (task.status == 'queued') ...[
                                  IconButton(
                                    icon: const Icon(Icons.stop, size: 16),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 20,
                                      minHeight: 20,
                                    ),
                                    tooltip: 'Stop task',
                                    onPressed: () => _stopSingleTask(task),
                                  ),
                                ],
                                if (task.status == 'done' || task.status == 'failed') ...[
                                  IconButton(
                                    icon: const Icon(Icons.refresh, size: 16),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 20,
                                      minHeight: 20,
                                    ),
                                    tooltip: 'Retry task',
                                    onPressed: () => _retryTask(task),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Start - End time
                                Text(
                                  task.startTime != null
                                    ? '${task.startTime!.hour.toString().padLeft(2, '0')}:${task.startTime!.minute.toString().padLeft(2, '0')}:${task.startTime!.second.toString().padLeft(2, '0')} - ${task.endTime != null ? '${task.endTime!.hour.toString().padLeft(2, '0')}:${task.endTime!.minute.toString().padLeft(2, '0')}:${task.endTime!.second.toString().padLeft(2, '0')}' : '...'}'
                                    : '-',
                                  style: theme.textTheme.bodySmall,
                                ),
                                // Duration on second line
                                Text(
                                  task.durationDecimal,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Text(
                              task.credits != null
                                ? task.credits!.toStringAsFixed(6)
                                : '-',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Row(
                              children: [
                                // View icon - shown if there's any output (result or error)
                                if (task.result != null || task.error != null) ...[
                                  IconButton(
                                    icon: Icon(
                                      Icons.visibility_outlined,
                                      size: 16,
                                      color: task.error != null
                                        ? theme.colorScheme.error
                                        : theme.colorScheme.primary,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 24,
                                      minHeight: 24,
                                    ),
                                    tooltip: task.error != null ? 'View error' : 'View output',
                                    onPressed: () => _showOutputDialog(task),
                                  ),
                                ],
                                // Save to file icon - shown if write to file is enabled and task succeeded
                                if (task.status == 'done' && task.result != null && _writeOutputToFile) ...[
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.save_outlined, size: 16),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 24,
                                      minHeight: 24,
                                    ),
                                    tooltip: 'Write to file',
                                    onPressed: () => _writeTaskToFile(task),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String label, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$label: $count',
          style: TextStyle(fontSize: 12, color: color),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(BatchTask task, ThemeData theme) {
    Color dotColor;

    switch (task.status) {
      case 'pending':
      case 'waiting':
        dotColor = Colors.grey;
        break;
      case 'queued':
        dotColor = Colors.blue;
        break;
      case 'done':
        dotColor = Colors.green;
        break;
      case 'failed':
        dotColor = Colors.red;
        break;
      default:
        dotColor = theme.colorScheme.onSurface.withValues(alpha: 0.5);
    }

    // Build tooltip text
    String tooltipText = task.status;
    if (task.taskId != null && task.status == 'queued') {
      tooltipText = 'Task ID: ${task.taskId}';
    }

    return Tooltip(
      message: tooltipText,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: dotColor,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  int _getTaskCountByStatus(String status) {
    return _tasks.where((task) => task.status == status).length;
  }

  bool _canWriteToFiles() {
    return _writeOutputToFile &&
           _tasks.any((task) => task.status == 'done' && task.result != null);
  }

  Future<void> _retryTask(BatchTask task) async {
    _logger.i('Retrying task ${task.id}');

    final workspaceState = ref.read(workspaceProvider);
    final workspaceId = workspaceState.currentWorkspace?.workspaceId;

    if (workspaceId == null || _selectedFlow == null) {
      _logger.e('Missing workspace ID or flow');
      return;
    }

    final flowService = ref.read(flowServiceProvider);

    // Reset task status
    setState(() {
      task.status = 'waiting';
      task.result = null;
      task.error = null;
    });

    // Execute the task
    await _executeTask(task, flowService, workspaceId);
  }

  Future<void> _startSingleTask(BatchTask task) async {
    _logger.i('Starting single task ${task.id}');

    final workspaceState = ref.read(workspaceProvider);
    final workspaceId = workspaceState.currentWorkspace?.workspaceId;

    if (workspaceId == null || _selectedFlow == null) {
      _logger.e('Missing workspace ID or flow');
      return;
    }

    final flowService = ref.read(flowServiceProvider);

    // Temporarily set _isExecuting to allow single task execution
    final wasExecuting = _isExecuting;
    setState(() {
      _isExecuting = true;
    });

    try {
      // Execute the task
      await _executeTask(task, flowService, workspaceId);
    } finally {
      // Restore previous execution state
      if (!wasExecuting) {
        setState(() {
          _isExecuting = false;
        });
      }
    }
  }

  void _stopSingleTask(BatchTask task) {
    _logger.i('Stopping single task ${task.id}');
    setState(() {
      task.shouldCancel = true;
    });
  }

  void _showOutputDialog(BatchTask task) {
    final controller = TextEditingController(text: task.error ?? task.result ?? '');
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => DefaultTabController(
        length: 2,
        child: Dialog(
          child: Container(
            width: 700,
            constraints: const BoxConstraints(maxHeight: 700),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(
                  children: [
                    Icon(
                      task.error != null ? Icons.error_outline : Icons.info_outline,
                      color: task.error != null
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        task.error != null ? 'Task Error' : 'Task Output',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Task info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Input: ${task.flowInput['input']?.toString() ?? ''}',
                        style: theme.textTheme.bodySmall,
                      ),
                      if (task.filename != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Filename: ${task.filename}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'Status: ',
                            style: theme.textTheme.bodySmall,
                          ),
                          _buildStatusBadge(task, theme),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Tab Bar
                TabBar(
                  tabs: const [
                    Tab(text: 'Extracted Value'),
                    Tab(text: 'Raw Output'),
                  ],
                  labelColor: theme.colorScheme.primary,
                  unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  indicatorColor: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                // Tab Views
                SizedBox(
                  height: 400,
                  child: TabBarView(
                    children: [
                      // Extracted Value Tab
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: controller.text));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Copied to clipboard'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.copy, size: 16),
                                label: const Text('Copy'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: TextField(
                              controller: controller,
                              maxLines: null,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                hintText: 'Output will appear here...',
                              ),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Raw Output Tab
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: task.rawOutput ?? ''));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Copied to clipboard'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.copy, size: 16),
                                label: const Text('Copy'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: theme.colorScheme.outline.withValues(alpha: 0.5),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: SingleChildScrollView(
                                child: SelectableText(
                                  task.rawOutput ?? 'No raw output available',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Save the edited output
                        setState(() {
                          if (task.error != null) {
                            task.error = controller.text;
                          } else {
                            task.result = controller.text;
                          }
                        });
                        Navigator.of(context).pop();

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Output updated')),
                        );
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('Save'),
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
    );
  }

  Future<void> _writeTaskToFile(BatchTask task) async {
    if (task.filename == null || task.result == null) {
      _logger.w('Cannot write task to file: missing filename or result');
      return;
    }

    try {
      final filePath = '$_outputDirectory/${task.filename}';
      final file = File(filePath);

      // Create parent directories if they don't exist
      await file.parent.create(recursive: true);

      // Write the result
      await file.writeAsString(task.result!);

      _logger.i('Wrote task output to: $filePath');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to ${task.filename}')),
        );
      }
    } catch (e, stackTrace) {
      _logger.e('Failed to write task to file', error: e, stackTrace: stackTrace);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error writing file: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _importFromCSV() async {
    _logger.d('Starting CSV import...');

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.single.path == null) {
        _logger.d('CSV import cancelled by user');
        return;
      }

      final filePath = result.files.single.path!;
      _logger.i('Reading CSV file: $filePath');

      final file = File(filePath);
      final lines = await file.readAsLines();

      _logger.d('CSV file lines: ${lines.length}');

      // Parse CSV manually line by line (simple comma split for basic CSV)
      final rows = <List<String>>[];
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        // Simple split by comma (works for most CSVs without quoted commas)
        final cells = line.split(',').map((e) => e.trim()).toList();
        rows.add(cells);

        if (i < 3) {
          _logger.d('Line $i: $cells');
        }
      }

      _logger.d('CSV parsed: ${rows.length} rows');

      if (rows.isEmpty) {
        _logger.w('CSV file is empty');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('CSV file is empty')),
          );
        }
        return;
      }

      // Skip header row if present (check if first cell looks like a header)
      final hasHeader = rows.isNotEmpty &&
          (rows[0][0].toString().toLowerCase().contains('input') ||
           rows[0][0].toString().toLowerCase().contains('flow'));
      final dataRows = hasHeader && rows.length > 1
          ? rows.skip(1).toList()
          : rows;

      _logger.d('Processing ${dataRows.length} data rows (after skipping header)');

      final uuid = const Uuid();
      final newTasks = <BatchTask>[];

      for (final row in dataRows) {
        final flowInput = row.isNotEmpty ? row[0].toString() : '';
        final filename = _writeOutputToFile && row.length > 1 ? row[1].toString() : null;

        _logger.d('Processing row: flowInput="$flowInput", filename="$filename"');

        // Validate filename if write output to file is enabled
        if (_writeOutputToFile && (filename == null || filename.isEmpty)) {
          _logger.w('Skipping row with missing filename: $flowInput');
          continue;
        }

        newTasks.add(BatchTask(
          id: uuid.v4(),
          flowInput: {'input': flowInput},
          filename: filename,
        ));
      }

      setState(() {
        _tasks.addAll(newTasks);
      });

      _logger.i('Successfully imported ${newTasks.length} tasks from CSV (total rows in CSV: ${dataRows.length})');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported ${newTasks.length} tasks from CSV'),
          ),
        );

        // Show warning if some rows were skipped
        if (_writeOutputToFile && newTasks.length < dataRows.length) {
          final skipped = dataRows.length - newTasks.length;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Warning: $skipped row(s) skipped due to missing filename'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to import CSV',
        error: e,
        stackTrace: stackTrace,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing CSV: $e')),
        );
      }
    }
  }

  Future<void> _importFromCSVFile(String filePath) async {
    _logger.i('Importing CSV from file path: $filePath');

    try {
      final file = File(filePath);
      final lines = await file.readAsLines();

      _logger.d('CSV file lines: ${lines.length}');

      // Parse CSV manually line by line (simple comma split for basic CSV)
      final rows = <List<String>>[];
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        // Simple split by comma (works for most CSVs without quoted commas)
        final cells = line.split(',').map((e) => e.trim()).toList();
        rows.add(cells);

        if (i < 3) {
          _logger.d('Line $i: $cells');
        }
      }

      _logger.d('CSV parsed: ${rows.length} rows');

      if (rows.isEmpty) {
        _logger.w('CSV file is empty');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('CSV file is empty')),
          );
        }
        return;
      }

      // Skip header row if present (check if first cell looks like a header)
      final hasHeader = rows.isNotEmpty &&
          (rows[0][0].toString().toLowerCase().contains('input') ||
           rows[0][0].toString().toLowerCase().contains('flow'));
      final dataRows = hasHeader && rows.length > 1
          ? rows.skip(1).toList()
          : rows;

      _logger.d('Processing ${dataRows.length} data rows (after skipping header)');

      final uuid = const Uuid();
      final newTasks = <BatchTask>[];

      for (final row in dataRows) {
        final flowInput = row.isNotEmpty ? row[0].toString() : '';
        final filename = _writeOutputToFile && row.length > 1 ? row[1].toString() : null;

        _logger.d('Processing row: flowInput="$flowInput", filename="$filename"');

        // Validate filename if write output to file is enabled
        if (_writeOutputToFile && (filename == null || filename.isEmpty)) {
          _logger.w('Skipping row with missing filename: $flowInput');
          continue;
        }

        newTasks.add(BatchTask(
          id: uuid.v4(),
          flowInput: {'input': flowInput},
          filename: filename,
        ));
      }

      setState(() {
        _tasks.addAll(newTasks);
      });

      _logger.i('Successfully imported ${newTasks.length} tasks from CSV (total rows in CSV: ${dataRows.length})');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported ${newTasks.length} tasks from CSV'),
          ),
        );

        // Show warning if some rows were skipped
        if (_writeOutputToFile && newTasks.length < dataRows.length) {
          final skipped = dataRows.length - newTasks.length;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Warning: $skipped row(s) skipped due to missing filename'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to import CSV from file: $filePath',
        error: e,
        stackTrace: stackTrace,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing CSV: $e')),
        );
      }
    }
  }

  void _showFlowPicker(BuildContext context, List<FlowResponse> flows) {
    showDialog(
      context: context,
      builder: (context) => _FlowPickerDialog(
        flows: flows,
        selectedFlow: _selectedFlow,
        onFlowSelected: (flow) {
          setState(() => _selectedFlow = flow);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Future<void> _selectOutputDirectory() async {
    _logger.d('Opening directory picker');
    try {
      final selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Output Directory',
        initialDirectory: _outputDirectory,
      );

      if (selectedDirectory != null) {
        setState(() {
          _outputDirectory = selectedDirectory;
        });
        _logger.i('Output directory changed to: $selectedDirectory');

        // Save the preference for next time
        await _saveOutputDirectory(selectedDirectory);
      } else {
        _logger.d('Directory selection cancelled');
      }
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to select output directory',
        error: e,
        stackTrace: stackTrace,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting directory: $e')),
        );
      }
    }
  }

  void _addManualTask() {
    _logger.d('Adding manual task');
    showDialog(
      context: context,
      builder: (context) => _AddTaskDialog(
        requireFilename: _writeOutputToFile,
        onTaskAdded: (flowInput, filename) {
          final uuid = const Uuid();
          setState(() {
            _tasks.add(BatchTask(
              id: uuid.v4(),
              flowInput: {'input': flowInput},
              filename: filename,
            ));
          });
          _logger.i('Manual task added. Total tasks: ${_tasks.length}');
        },
      ),
    );
  }

  void _editTaskInput(int index) {
    final task = _tasks[index];

    showDialog(
      context: context,
      builder: (context) => _EditFieldDialog(
        title: 'Edit Flow Input',
        fieldName: 'Flow Input',
        initialValue: task.flowInput['input']?.toString() ?? '',
        onSave: (value) {
          setState(() {
            _tasks[index] = BatchTask(
              id: task.id,
              flowInput: {'input': value},
              filename: task.filename,
            );
          });
        },
      ),
    );
  }

  void _editTaskFilename(int index) {
    final task = _tasks[index];

    showDialog(
      context: context,
      builder: (context) => _EditFieldDialog(
        title: 'Edit Filename',
        fieldName: 'Filename',
        initialValue: task.filename ?? '',
        onSave: (value) {
          setState(() {
            _tasks[index] = BatchTask(
              id: task.id,
              flowInput: task.flowInput,
              filename: value.isEmpty ? null : value,
            );
          });
        },
      ),
    );
  }

  Future<void> _startExecution() async {
    if (_selectedFlow == null || _tasks.isEmpty) {
      _logger.w('Cannot execute: Flow or tasks missing');
      return;
    }

    // Initialize only pending/failed tasks to 'waiting' status
    // Skip tasks that are already 'done' or 'failed' to avoid re-execution
    setState(() {
      _isExecuting = true;
      for (var task in _tasks) {
        // Only reset tasks that are not already completed
        if (task.status != 'done' && task.status != 'failed') {
          task.status = 'waiting';
          task.result = null;
          task.error = null;
        }
      }
    });

    _logger.i('Starting batch execution');
    _logger.i('Flow: ${_selectedFlow!.name} (${_selectedFlow!.flowId})');
    _logger.i('Tasks: ${_tasks.length}');
    _logger.i('Execution mode: ${_useSingleton ? "Singleton" : "Normal"}');
    _logger.i('Parallel executions: $_parallelExecutions');

    // Execute tasks in parallel batches
    await _executeTasks();
  }

  Future<void> _executeTasks() async {
    final workspaceState = ref.read(workspaceProvider);
    final workspaceId = workspaceState.currentWorkspace?.workspaceId;

    if (workspaceId == null || _selectedFlow == null) {
      _logger.e('Missing workspace ID or flow');
      return;
    }

    final flowService = ref.read(flowServiceProvider);
    int currentIndex = 0;

    while (currentIndex < _tasks.length && _isExecuting) {
      // Get next batch of tasks
      final batchEnd = (currentIndex + _parallelExecutions).clamp(0, _tasks.length);
      final batch = _tasks.sublist(currentIndex, batchEnd);

      // Execute batch in parallel
      await Future.wait(
        batch.map((task) => _executeTask(task, flowService, workspaceId)),
      );

      currentIndex = batchEnd;
    }

    if (_isExecuting) {
      setState(() => _isExecuting = false);
      _logger.i('Batch execution completed');

      if (mounted) {
        final doneCount = _getTaskCountByStatus('done');
        final failedCount = _getTaskCountByStatus('failed');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Execution completed: $doneCount succeeded, $failedCount failed'),
            backgroundColor: failedCount > 0
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.primary,
          ),
        );
      }
    }
  }

  Future<void> _executeTask(
    BatchTask task,
    dynamic flowService,
    String workspaceId,
  ) async {
    if (!_isExecuting) return;

    try {
      setState(() {
        task.status = 'queued';
        task.startTime = DateTime.now();
      });

      _logger.d('Executing task ${task.id}: ${task.flowInput}');

      // Convert 'input' to 'human_input' for API compatibility
      final apiFlowInput = {
        'human_input': task.flowInput['input'],
      };

      // Log API call details
      _logger.i('=== API Call Details ===');
      _logger.i('Execution mode: ${_useSingleton ? "Singleton" : "Normal"}');
      _logger.i('Workspace ID: $workspaceId');
      _logger.i('Flow ID: ${_selectedFlow!.flowId}');
      _logger.i('Flow Name: ${_selectedFlow!.name}');
      _logger.i('API Parameters: $apiFlowInput');
      _logger.i('Stream Response: false');

      // Construct the URL that will be called (for debugging)
      final endpoint = _useSingleton
        ? '/api/v1/flows/${_selectedFlow!.flowId}/invoke-singleton'
        : '/api/v1/flows/${_selectedFlow!.flowId}/invoke';
      _logger.i('API Endpoint: $endpoint');
      _logger.i('=======================');

      // Invoke the flow - this returns immediately with task_id and PENDING status
      final initialResponse = _useSingleton
        ? await flowService.invokeFlowSingleton(
            flowId: _selectedFlow!.flowId!,
            workspaceId: workspaceId,
            flowInput: apiFlowInput,
            streamResponse: false,
          )
        : await flowService.invokeFlow(
            flowId: _selectedFlow!.flowId!,
            workspaceId: workspaceId,
            flowInput: apiFlowInput,
            streamResponse: false,
          );

      final taskId = initialResponse.id;
      if (taskId == null) {
        throw Exception('No task ID returned from flow invocation');
      }

      // Store the task ID
      setState(() {
        task.taskId = taskId;
      });

      _logger.i('Flow invoked, task ID: $taskId, initial status: ${initialResponse.status}');

      // If status is already completed (SUCCESS/FAILED) or result is available, no need to poll
      if (initialResponse.status != 'PENDING' || initialResponse.result != null) {
        if (initialResponse.status == 'SUCCESS') {
          setState(() {
            task.status = 'done';
            task.endTime = DateTime.now();
            task.result = initialResponse.aiAnswer ??
                         initialResponse.errorMessage ??
                         'Task $taskId - ${initialResponse.status}';
            task.credits = initialResponse.credits;
            // Store raw API response
            task.rawOutput = jsonEncode(initialResponse.toJson());
          });
          _logger.i('Task ${task.id} completed immediately: $taskId');
          return;
        } else if (initialResponse.status == 'FAILED' || initialResponse.status == 'ERROR') {
          setState(() {
            task.status = 'failed';
            task.endTime = DateTime.now();
            task.error = initialResponse.errorMessage ?? 'Task failed: ${initialResponse.status}';
            // Store raw API response even for errors
            task.rawOutput = jsonEncode(initialResponse.toJson());
          });
          _logger.e('Task ${task.id} failed immediately: $taskId');
          return;
        }
      }

      // Poll for task completion
      _logger.d('Task $taskId is PENDING, starting polling...');
      const pollInterval = Duration(seconds: 2);
      const maxAttempts = 1800; // 60 minutes max (1800 * 2 seconds)
      int attempts = 0;

      while (attempts < maxAttempts && _isExecuting && !task.shouldCancel) {
        await Future.delayed(pollInterval);
        attempts++;

        // Log status check API call
        if (attempts == 1 || attempts % 10 == 0) {
          _logger.i('=== Status Check API Call ===');
          _logger.i('Attempt: $attempts');
          _logger.i('Workspace ID: $workspaceId');
          _logger.i('Flow ID: ${_selectedFlow!.flowId}');
          _logger.i('Task ID: $taskId');
          _logger.i('API Endpoint: /api/v1/flows/${_selectedFlow!.flowId}/tasks/$taskId');
          _logger.i('============================');
        }

        final statusResponse = await flowService.checkTaskStatus(
          flowId: _selectedFlow!.flowId!,
          taskId: taskId,
          workspaceId: workspaceId,
        );

        _logger.d('Poll attempt $attempts: Task $taskId status: ${statusResponse.status}');

        if (statusResponse.status == 'SUCCESS') {
          setState(() {
            task.status = 'done';
            task.endTime = DateTime.now();
            task.result = statusResponse.aiAnswer ??
                         statusResponse.errorMessage ??
                         'Task $taskId - ${statusResponse.status}';
            task.credits = statusResponse.credits;
            // Store raw API response
            task.rawOutput = jsonEncode(statusResponse.toJson());
          });
          _logger.i('Task ${task.id} completed after $attempts polls: $taskId');
          return;
        } else if (statusResponse.status == 'FAILED' || statusResponse.status == 'ERROR') {
          setState(() {
            task.status = 'failed';
            task.endTime = DateTime.now();
            task.error = statusResponse.errorMessage ?? 'Task failed: ${statusResponse.status}';
            // Store raw API response even for errors
            task.rawOutput = jsonEncode(statusResponse.toJson());
          });
          _logger.e('Task ${task.id} failed after $attempts polls: $taskId');
          return;
        } else if (statusResponse.status == 'PENDING') {
          // Task still pending, continue polling
          // Trigger UI update to refresh duration display
          if (mounted) {
            setState(() {});
          }
        } else {
          // Unexpected status - log warning and continue polling
          _logger.w('Unexpected status for task $taskId: ${statusResponse.status}');
          if (mounted) {
            setState(() {});
          }
        }
      }

      // Check if cancelled by user
      if (task.shouldCancel) {
        setState(() {
          task.status = 'failed';
          task.endTime = DateTime.now();
          task.error = 'Task cancelled by user';
        });
        _logger.w('Task ${task.id} cancelled by user: $taskId');
        return;
      }

      // Timeout after max attempts
      if (attempts >= maxAttempts) {
        throw Exception('Task $taskId timed out after ${maxAttempts * 2} seconds');
      }
    } catch (e, stackTrace) {
      _logger.e('Task ${task.id} failed', error: e, stackTrace: stackTrace);

      setState(() {
        task.status = 'failed';
        task.endTime = DateTime.now();
        task.error = e.toString();
      });
    }
  }

  void _stopExecution() {
    _logger.i('Stopping batch execution');
    setState(() => _isExecuting = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Execution stopped')),
      );
    }
  }

  Future<void> _writeOutputsToFiles() async {
    if (!_writeOutputToFile || _outputDirectory.isEmpty) {
      _logger.w('Write to files not configured');
      return;
    }

    final successfulTasks = _tasks.where(
      (task) => task.status == 'done' && task.result != null && task.filename != null,
    ).toList();

    if (successfulTasks.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No completed tasks with results to write')),
        );
      }
      return;
    }

    try {
      int written = 0;
      for (final task in successfulTasks) {
        final filePath = '$_outputDirectory/${task.filename}';
        final file = File(filePath);

        // Create parent directories if they don't exist
        await file.parent.create(recursive: true);

        // Write the result
        await file.writeAsString(task.result!);
        written++;

        _logger.d('Wrote output to: $filePath');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully wrote $written files to $_outputDirectory')),
        );
      }

      _logger.i('Wrote $written output files');
    } catch (e, stackTrace) {
      _logger.e('Failed to write output files', error: e, stackTrace: stackTrace);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error writing files: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}

class _FlowPickerDialog extends StatefulWidget {
  final List<FlowResponse> flows;
  final FlowResponse? selectedFlow;
  final ValueChanged<FlowResponse> onFlowSelected;

  const _FlowPickerDialog({
    required this.flows,
    required this.selectedFlow,
    required this.onFlowSelected,
  });

  @override
  State<_FlowPickerDialog> createState() => _FlowPickerDialogState();
}

class _FlowPickerDialogState extends State<_FlowPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<FlowResponse> _filteredFlows = [];

  @override
  void initState() {
    super.initState();
    _filteredFlows = widget.flows;
    _searchController.addListener(_filterFlows);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterFlows() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredFlows = widget.flows;
      } else {
        _filteredFlows = widget.flows.where((flow) {
          final name = flow.name?.toLowerCase() ?? '';
          final description = flow.description?.toLowerCase() ?? '';
          return name.contains(query) || description.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.search,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Select Flow',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Search field
                  TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search flows by name or description...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Flow list
            Flexible(
              child: _filteredFlows.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No flows found',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try a different search term',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredFlows.length,
                      itemBuilder: (context, index) {
                        final flow = _filteredFlows[index];
                        final isSelected = flow.flowId == widget.selectedFlow?.flowId;

                        return ListTile(
                          selected: isSelected,
                          leading: Icon(
                            isSelected ? Icons.check_circle : Icons.circle_outlined,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                          title: Text(
                            flow.name ?? 'Unnamed Flow',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                          subtitle: flow.description != null && flow.description!.isNotEmpty
                              ? Text(
                                  flow.description!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          onTap: () => widget.onFlowSelected(flow),
                        );
                      },
                    ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_filteredFlows.length} flow${_filteredFlows.length == 1 ? '' : 's'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddTaskDialog extends StatefulWidget {
  final bool requireFilename;
  final void Function(String flowInput, String? filename) onTaskAdded;

  const _AddTaskDialog({
    required this.requireFilename,
    required this.onTaskAdded,
  });

  @override
  State<_AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<_AddTaskDialog> {
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _filenameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _inputController.dispose();
    _filenameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.add_circle_outline,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Add Task',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _inputController,
                autofocus: true,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Flow Input',
                  hintText: 'Enter the input for the flow...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Flow input is required';
                  }
                  return null;
                },
              ),
              if (widget.requireFilename) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _filenameController,
                  decoration: InputDecoration(
                    labelText: 'Filename',
                    hintText: 'Enter the output filename...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (value) {
                    if (widget.requireFilename && (value == null || value.isEmpty)) {
                      return 'Filename is required when "Write output to file" is enabled';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        widget.onTaskAdded(
                          _inputController.text,
                          widget.requireFilename ? _filenameController.text : null,
                        );
                        Navigator.of(context).pop();
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Task'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditFieldDialog extends StatefulWidget {
  final String title;
  final String fieldName;
  final String initialValue;
  final void Function(String value) onSave;

  const _EditFieldDialog({
    required this.title,
    required this.fieldName,
    required this.initialValue,
    required this.onSave,
  });

  @override
  State<_EditFieldDialog> createState() => _EditFieldDialogState();
}

class _EditFieldDialogState extends State<_EditFieldDialog> {
  late TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.edit_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _controller,
                autofocus: true,
                maxLines: widget.fieldName == 'Flow Input' ? 3 : 1,
                decoration: InputDecoration(
                  labelText: widget.fieldName,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '${widget.fieldName} cannot be empty';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        widget.onSave(_controller.text);
                        Navigator.of(context).pop();
                      }
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
