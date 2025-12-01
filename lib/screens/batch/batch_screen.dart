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
import 'package:csv/csv.dart';

import '../../sdk/models/flow.dart';
import '../../sdk/models/batch_task.dart';
import '../../providers/workspace_provider.dart';
import '../../providers/flow_provider.dart';

enum ExecutionMode {
  singleton,
  normal,
}

enum TimeoutPolicy {
  retry,
  markAsError,
}

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
  ExecutionMode _executionMode = ExecutionMode.normal; // Normal mode is default
  bool _writeOutputToFile = true; // Write output to file option (enabled by default)
  bool _overwriteExistingFiles = false; // Overwrite existing files option (disabled by default)
  String _outputDirectory = Directory.current.path; // Default to current directory
  bool _isDragging = false; // Track drag over state
  int _taskTimeoutSeconds = 3600; // Task timeout in seconds (default: 3600 = 60 minutes)
  TimeoutPolicy _timeoutPolicy = TimeoutPolicy.markAsError; // Default: mark as error on timeout

  // Sorting state for Execute step
  String _sortColumn = 'row'; // row, status, credits, input, filename
  bool _sortAscending = true;

  // Sorting state for Input Data step
  String _inputDataSortColumn = 'row';
  bool _inputDataSortAscending = true;

  // Filtering state
  final Set<String> _statusFilter = {}; // Empty = show all

  // Search state
  final TextEditingController _inputDataSearchController = TextEditingController();
  final TextEditingController _executeSearchController = TextEditingController();
  String _inputDataSearchQuery = '';
  String _executeSearchQuery = '';

  // Column widths state for resizing
  final Map<String, double> _columnWidths = {};

  // Horizontal scroll controllers for tables
  final ScrollController _inputTableHorizontalScrollController = ScrollController();
  final ScrollController _executeTableHorizontalScrollController = ScrollController();

  // CSV columns state
  List<String> _csvColumns = []; // Track CSV column names for display

  // Helper method to check if a status indicates task completion (success)
  bool _isSuccessStatus(String? status) {
    if (status == null) return false;
    final upperStatus = status.toUpperCase();
    return upperStatus == 'SUCCESS' ||
           upperStatus == 'DONE' ||
           upperStatus == 'COMPLETED' ||
           upperStatus == 'CACHED';
  }

  // Helper method to get color for status
  Color _getStatusColor(String status) {
    final upperStatus = status.toUpperCase();
    if (upperStatus == 'SUCCESS' || upperStatus == 'DONE' || upperStatus == 'COMPLETED' || upperStatus == 'CACHED') {
      return Colors.green;
    } else if (upperStatus == 'FAILED' || upperStatus == 'ERROR') {
      return Colors.red;
    } else if (upperStatus == 'PENDING') {
      return Colors.orange;
    } else {
      return Colors.blue; // RUNNING, PROCESSING, etc.
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSavedOutputDirectory();
    _logger.i('🎯 BatchScreen initialized - DropTarget will be enabled');
  }

  @override
  void dispose() {
    _inputDataSearchController.dispose();
    _executeSearchController.dispose();
    _inputTableHorizontalScrollController.dispose();
    _executeTableHorizontalScrollController.dispose();
    super.dispose();
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
      loading: () => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading flows...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
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
                    child: DropdownButton<ExecutionMode>(
                      value: _executionMode,
                      underline: const SizedBox(),
                      isDense: true,
                      items: const [
                        DropdownMenuItem(
                          value: ExecutionMode.singleton,
                          child: Text('Singleton'),
                        ),
                        DropdownMenuItem(
                          value: ExecutionMode.normal,
                          child: Text('Normal'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _executionMode = value);
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
                  color: _executionMode != ExecutionMode.normal
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
                          _executionMode == ExecutionMode.singleton
                              ? Icons.check_circle
                              : Icons.info_outline,
                          size: 16,
                          color: _executionMode != ExecutionMode.normal
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _executionMode == ExecutionMode.singleton
                              ? 'Singleton Mode'
                              : 'Normal Mode',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: _executionMode != ExecutionMode.normal
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _executionMode == ExecutionMode.singleton
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

        // Timeout settings
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
                    Icons.timer_outlined,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Timeout Settings',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Task timeout duration
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Task Timeout:',
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
                      value: _taskTimeoutSeconds,
                      underline: const SizedBox(),
                      isDense: true,
                      items: [
                        const DropdownMenuItem<int>(
                          value: 300,
                          child: Text('5 minutes'),
                        ),
                        const DropdownMenuItem<int>(
                          value: 600,
                          child: Text('10 minutes'),
                        ),
                        const DropdownMenuItem<int>(
                          value: 1800,
                          child: Text('30 minutes'),
                        ),
                        const DropdownMenuItem<int>(
                          value: 3600,
                          child: Text('60 minutes'),
                        ),
                        const DropdownMenuItem<int>(
                          value: 7200,
                          child: Text('120 minutes'),
                        ),
                        const DropdownMenuItem<int>(
                          value: 10800,
                          child: Text('180 minutes'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _taskTimeoutSeconds = value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'per task',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Timeout policy
              Row(
                children: [
                  Icon(
                    Icons.policy_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Timeout Policy:',
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
                    child: DropdownButton<TimeoutPolicy>(
                      value: _timeoutPolicy,
                      underline: const SizedBox(),
                      isDense: true,
                      items: const [
                        DropdownMenuItem(
                          value: TimeoutPolicy.markAsError,
                          child: Text('Mark as Error'),
                        ),
                        DropdownMenuItem(
                          value: TimeoutPolicy.retry,
                          child: Text('Retry'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _timeoutPolicy = value);
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
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      _timeoutPolicy == TimeoutPolicy.retry
                          ? Icons.refresh
                          : Icons.error_outline,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _timeoutPolicy == TimeoutPolicy.retry
                            ? 'Tasks will be automatically retried if they exceed the timeout duration.'
                            : 'Tasks will be marked as failed if they exceed the timeout duration.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
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
                      const SizedBox(height: 16),
                      // Overwrite existing files option
                      Row(
                        children: [
                          Icon(
                            Icons.refresh,
                            size: 16,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Overwrite existing files',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                          Switch(
                            value: _overwriteExistingFiles,
                            onChanged: (value) {
                              setState(() => _overwriteExistingFiles = value);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _overwriteExistingFiles
                              ? theme.colorScheme.errorContainer.withValues(alpha: 0.2)
                              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              _overwriteExistingFiles ? Icons.warning_amber : Icons.info_outline,
                              size: 14,
                              color: _overwriteExistingFiles
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _overwriteExistingFiles
                                    ? 'Existing files will be overwritten. Tasks with existing files will be re-executed.'
                                    : 'Tasks with existing output files will be skipped and marked as "skipped" to avoid duplicate work.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
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
    final sortedAndFilteredTasks = _getInputDataSortedTasks();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Action buttons and search
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
              const Spacer(),
              // Search field
              SizedBox(
                width: 250,
                child: TextField(
                  controller: _inputDataSearchController,
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _inputDataSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              setState(() {
                                _inputDataSearchController.clear();
                                _inputDataSearchQuery = '';
                              });
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _inputDataSearchQuery = value.toLowerCase();
                    });
                  },
                ),
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
                child: Builder(
                  builder: (context) {
                    // Calculate total content width based on column widths
                    double totalWidth = (_columnWidths['input_row'] ?? 50) + 48 + 32; // row + actions + padding
                    if (_csvColumns.isNotEmpty) {
                      for (final col in _csvColumns) {
                        totalWidth += _columnWidths['input_$col'] ?? 200;
                      }
                    } else {
                      totalWidth += _columnWidths['input_flowInput'] ?? 300;
                    }

                    return Column(
                      children: [
                        // Scrollable table
                        Scrollbar(
                          controller: _inputTableHorizontalScrollController,
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            controller: _inputTableHorizontalScrollController,
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: totalWidth,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                        // Row number column
                                        _buildResizableColumnHeader(
                                          columnKey: 'input_row',
                                          label: '#',
                                          theme: theme,
                                          defaultWidth: 50,
                                          sortColumn: 'row',
                                          isInputDataTable: true,
                                        ),
                                        // Dynamic CSV column headers
                                        if (_csvColumns.isNotEmpty)
                                          ..._csvColumns.asMap().entries.map((entry) => _buildResizableColumnHeader(
                                            columnKey: 'input_${entry.value}',
                                            label: entry.value,
                                            theme: theme,
                                            defaultWidth: 200,
                                            sortColumn: entry.value,
                                            isInputDataTable: true,
                                          ))
                                        else
                                          _buildResizableColumnHeader(
                                            columnKey: 'input_flowInput',
                                            label: 'Flow Input',
                                            theme: theme,
                                            defaultWidth: 300,
                                            sortColumn: 'input',
                                            isInputDataTable: true,
                                          ),
                                        const SizedBox(width: 48),
                                      ],
                                    ),
                                  ),
                                  // Table rows
                                  SizedBox(
                                    height: 400,
                                    child: ListView.builder(
                                      itemCount: sortedAndFilteredTasks.length,
                                      itemBuilder: (context, index) {
                                        final task = sortedAndFilteredTasks[index];
                                        final originalIndex = _tasks.indexOf(task);
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
                                              // Row number
                                              SizedBox(
                                                width: _columnWidths['input_row'] ?? 50,
                                                child: Text(
                                                  '${originalIndex + 1}',
                                                  style: theme.textTheme.bodyMedium?.copyWith(
                                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                                  ),
                                                ),
                                              ),
                                              // Dynamic CSV column values
                                              if (_csvColumns.isNotEmpty)
                                                ..._csvColumns.map((columnName) => SizedBox(
                                                  width: _columnWidths['input_$columnName'] ?? 200,
                                                  child: InkWell(
                                                    onTap: () => _editTaskColumnValue(originalIndex, columnName),
                                                    child: Padding(
                                                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                                      child: Text(
                                                        task.rowData[columnName] ?? '-',
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ),
                                                ))
                                              else
                                                SizedBox(
                                                  width: _columnWidths['input_flowInput'] ?? 300,
                                                  child: InkWell(
                                                    onTap: () => _editTaskInput(originalIndex),
                                                    child: Padding(
                                                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                                      child: Text(
                                                        task.flowInput['input']?.toString() ?? '',
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              SizedBox(
                                                width: 48,
                                                child: IconButton(
                                                  icon: const Icon(Icons.delete_outline),
                                                  onPressed: () {
                                                    setState(() => _tasks.removeAt(originalIndex));
                                                  },
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
                          ),
                        ),
                      ],
                    );
                  },
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
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _tasks.isNotEmpty ? _exportToCsv : null,
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('Export CSV'),
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
                  _buildStatusChip('Skipped', _getTaskCountByStatus('skipped'), Colors.orange),
                  _buildStatusChip('Failed', _getTaskCountByStatus('failed'), Colors.red),
                  if (_statusFilter.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _statusFilter.clear();
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.outline.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.clear,
                              size: 12,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Clear Filters',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (_isExecuting) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.sync_outlined,
                            size: 12,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Max: $_parallelExecutions',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Search field for Execute step
        Row(
          children: [
            SizedBox(
              width: 300,
              child: TextField(
                controller: _executeSearchController,
                decoration: InputDecoration(
                  hintText: 'Search tasks...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _executeSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            setState(() {
                              _executeSearchController.clear();
                              _executeSearchQuery = '';
                            });
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _executeSearchQuery = value.toLowerCase();
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Execution monitoring table
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Builder(
            builder: (context) {
              // Calculate total content width based on column widths
              double totalWidth = (_columnWidths['exec_row'] ?? 50) +
                  (_columnWidths['exec_status'] ?? 70) +
                  (_columnWidths['exec_time'] ?? 150) +
                  (_columnWidths['exec_credits'] ?? 100) +
                  (_columnWidths['exec_output'] ?? 80) +
                  48 + 32; // delete button + padding
              if (_csvColumns.isNotEmpty) {
                for (final col in _csvColumns) {
                  totalWidth += _columnWidths['exec_$col'] ?? 150;
                }
              } else {
                totalWidth += _columnWidths['exec_input'] ?? 200;
              }

              return Scrollbar(
                controller: _executeTableHorizontalScrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _executeTableHorizontalScrollController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: totalWidth,
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
                              _buildResizableColumnHeader(
                                columnKey: 'exec_row',
                                label: '#',
                                theme: theme,
                                defaultWidth: 50,
                                sortColumn: 'row',
                                isInputDataTable: false,
                              ),
                              _buildResizableColumnHeader(
                                columnKey: 'exec_status',
                                label: 'Status',
                                theme: theme,
                                defaultWidth: 70,
                                sortColumn: 'status',
                                isInputDataTable: false,
                              ),
                              // Dynamic CSV column headers
                              if (_csvColumns.isNotEmpty)
                                ..._csvColumns.asMap().entries.map((entry) => _buildResizableColumnHeader(
                                  columnKey: 'exec_${entry.value}',
                                  label: entry.value,
                                  theme: theme,
                                  defaultWidth: 150,
                                  sortColumn: entry.value,
                                  isInputDataTable: false,
                                ))
                              else
                                _buildResizableColumnHeader(
                                  columnKey: 'exec_input',
                                  label: 'Input Value',
                                  theme: theme,
                                  defaultWidth: 200,
                                  sortColumn: 'input',
                                  isInputDataTable: false,
                                ),
                              _buildResizableColumnHeader(
                                columnKey: 'exec_time',
                                label: 'Time',
                                theme: theme,
                                defaultWidth: 150,
                                isInputDataTable: false,
                              ),
                              _buildResizableColumnHeader(
                                columnKey: 'exec_credits',
                                label: 'Credits',
                                theme: theme,
                                defaultWidth: 100,
                                sortColumn: 'credits',
                                isInputDataTable: false,
                              ),
                              _buildResizableColumnHeader(
                                columnKey: 'exec_output',
                                label: 'Output',
                                theme: theme,
                                defaultWidth: 80,
                                isInputDataTable: false,
                              ),
                              SizedBox(
                                width: 48,
                                child: Text(
                                  '',
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
                          child: Builder(
                            builder: (context) {
                              final sortedTasks = _getSortedTasks();
                              return ListView.builder(
                                itemCount: sortedTasks.length,
                                itemBuilder: (context, index) {
                                  final task = sortedTasks[index];
                                  final originalIndex = _tasks.indexOf(task);
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
                                          width: _columnWidths['exec_row'] ?? 50,
                                          child: Text(
                                            '${originalIndex + 1}',
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: _columnWidths['exec_status'] ?? 70,
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
                                              if (task.status == 'done' || task.status == 'failed' || task.status == 'skipped') ...[
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
                                        // Dynamic CSV column values
                                        if (_csvColumns.isNotEmpty)
                                          ..._csvColumns.map((columnName) => SizedBox(
                                            width: _columnWidths['exec_$columnName'] ?? 150,
                                            child: InkWell(
                                              onTap: () => _editTaskColumnValue(originalIndex, columnName),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                                child: Text(
                                                  task.rowData[columnName] ?? '-',
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: theme.textTheme.bodyMedium,
                                                ),
                                              ),
                                            ),
                                          ))
                                        else
                                          SizedBox(
                                            width: _columnWidths['exec_input'] ?? 200,
                                            child: InkWell(
                                              onTap: () => _editTaskInput(originalIndex),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                                child: Text(
                                                  task.flowInput['input']?.toString() ?? '',
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: theme.textTheme.bodyMedium,
                                                ),
                                              ),
                                            ),
                                          ),
                                        SizedBox(
                                          width: _columnWidths['exec_time'] ?? 150,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Start - End time
                                              Text(
                                                task.startTime != null
                                                  ? '${task.startTime!.hour.toString().padLeft(2, '0')}:${task.startTime!.minute.toString().padLeft(2, '0')}:${task.startTime!.second.toString().padLeft(2, '0')} - ${task.endTime != null ? '${task.endTime!.hour.toString().padLeft(2, '0')}:${task.endTime!.minute.toString().padLeft(2, '0')}:${task.endTime!.second.toString().padLeft(2, '0')}' : '...'}'
                                                  : '-',
                                                style: theme.textTheme.bodySmall,
                                                overflow: TextOverflow.ellipsis,
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
                                        SizedBox(
                                          width: _columnWidths['exec_credits'] ?? 100,
                                          child: Text(
                                            task.credits != null
                                              ? task.credits!.toStringAsFixed(6)
                                              : '-',
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ),
                                        SizedBox(
                                          width: _columnWidths['exec_output'] ?? 80,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
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
                                        // Delete button
                                        SizedBox(
                                          width: 48,
                                          child: IconButton(
                                            icon: Icon(
                                              Icons.delete_outline,
                                              size: 18,
                                              color: task.status == 'queued'
                                                  ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
                                                  : theme.colorScheme.error.withValues(alpha: 0.7),
                                            ),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                              minWidth: 32,
                                              minHeight: 32,
                                            ),
                                            tooltip: task.status == 'queued' ? 'Cannot delete running task' : 'Delete task',
                                            onPressed: task.status == 'queued'
                                                ? null
                                                : () {
                                                    setState(() => _tasks.removeAt(originalIndex));
                                                  },
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
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
    );
  }

  Widget _buildStatusChip(String label, int count, Color color) {
    final statusKey = label.toLowerCase();
    final isActive = _statusFilter.contains(statusKey);

    return InkWell(
      onTap: () {
        setState(() {
          if (isActive) {
            _statusFilter.remove(statusKey);
          } else {
            _statusFilter.add(statusKey);
          }
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.2) : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
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
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BatchTask task, ThemeData theme) {
    // Build tooltip text
    String tooltipText = task.status;
    if (task.taskId != null && task.status == 'queued') {
      tooltipText = 'Task ID: ${task.taskId}';
    }

    // Show rotating loading indicator for queued tasks
    if (task.status == 'queued') {
      return Tooltip(
        message: tooltipText,
        child: const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        ),
      );
    }

    // Show static colored dot for other statuses
    Color dotColor;
    switch (task.status) {
      case 'pending':
      case 'waiting':
        dotColor = Colors.grey;
        break;
      case 'done':
        dotColor = Colors.green;
        break;
      case 'skipped':
        dotColor = Colors.orange;
        break;
      case 'failed':
        dotColor = Colors.red;
        break;
      default:
        dotColor = theme.colorScheme.onSurface.withValues(alpha: 0.5);
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

  void _sortTasks(String column) {
    setState(() {
      if (_sortColumn == column) {
        // Toggle sort direction if same column
        _sortAscending = !_sortAscending;
      } else {
        // New column, default to ascending
        _sortColumn = column;
        _sortAscending = true;
      }
    });
  }

  List<BatchTask> _getSortedTasks() {
    // First filter by status
    var tasks = _statusFilter.isEmpty
        ? List<BatchTask>.from(_tasks)
        : _tasks.where((task) => _statusFilter.contains(task.status)).toList();

    // Apply search filter
    if (_executeSearchQuery.isNotEmpty) {
      tasks = tasks.where((task) {
        // Search in row data (CSV columns)
        final rowDataMatch = task.rowData.values.any(
          (value) => value.toLowerCase().contains(_executeSearchQuery)
        );
        // Search in flow input
        final inputMatch = task.flowInput['input']?.toString().toLowerCase().contains(_executeSearchQuery) ?? false;
        // Search in status
        final statusMatch = task.status.toLowerCase().contains(_executeSearchQuery);
        // Search in result/error
        final resultMatch = task.result?.toLowerCase().contains(_executeSearchQuery) ?? false;
        final errorMatch = task.error?.toLowerCase().contains(_executeSearchQuery) ?? false;

        return rowDataMatch || inputMatch || statusMatch || resultMatch || errorMatch;
      }).toList();
    }

    // Sort tasks
    tasks.sort((a, b) {
      int comparison = 0;

      switch (_sortColumn) {
        case 'row':
          // Sort by original index
          comparison = _tasks.indexOf(a).compareTo(_tasks.indexOf(b));
          break;
        case 'status':
          // Status priority: queued > waiting > pending > done > failed > skipped
          final statusOrder = {
            'queued': 0,
            'waiting': 1,
            'pending': 2,
            'done': 3,
            'failed': 4,
            'skipped': 5,
          };
          final aOrder = statusOrder[a.status] ?? 99;
          final bOrder = statusOrder[b.status] ?? 99;
          comparison = aOrder.compareTo(bOrder);
          break;
        case 'credits':
          final aCredits = a.credits ?? 0;
          final bCredits = b.credits ?? 0;
          comparison = aCredits.compareTo(bCredits);
          break;
        case 'input':
          final aInput = a.flowInput['input']?.toString() ?? '';
          final bInput = b.flowInput['input']?.toString() ?? '';
          comparison = aInput.compareTo(bInput);
          break;
        case 'filename':
          final aFilename = a.filename ?? '';
          final bFilename = b.filename ?? '';
          comparison = aFilename.compareTo(bFilename);
          break;
        default:
          // Sort by CSV column
          if (_csvColumns.contains(_sortColumn)) {
            final aValue = a.rowData[_sortColumn] ?? '';
            final bValue = b.rowData[_sortColumn] ?? '';
            comparison = aValue.compareTo(bValue);
          }
          break;
      }

      return _sortAscending ? comparison : -comparison;
    });

    return tasks;
  }

  // Sorting for Input Data step
  void _sortInputDataTasks(String column) {
    setState(() {
      if (_inputDataSortColumn == column) {
        _inputDataSortAscending = !_inputDataSortAscending;
      } else {
        _inputDataSortColumn = column;
        _inputDataSortAscending = true;
      }
    });
  }

  // Get sorted and filtered tasks for Input Data step
  List<BatchTask> _getInputDataSortedTasks() {
    var tasks = List<BatchTask>.from(_tasks);

    // Apply search filter
    if (_inputDataSearchQuery.isNotEmpty) {
      tasks = tasks.where((task) {
        // Search in row data (CSV columns)
        final rowDataMatch = task.rowData.values.any(
          (value) => value.toLowerCase().contains(_inputDataSearchQuery)
        );
        // Search in flow input
        final inputMatch = task.flowInput['input']?.toString().toLowerCase().contains(_inputDataSearchQuery) ?? false;

        return rowDataMatch || inputMatch;
      }).toList();
    }

    // Sort tasks
    tasks.sort((a, b) {
      int comparison = 0;

      switch (_inputDataSortColumn) {
        case 'row':
          comparison = _tasks.indexOf(a).compareTo(_tasks.indexOf(b));
          break;
        case 'input':
          final aInput = a.flowInput['input']?.toString() ?? '';
          final bInput = b.flowInput['input']?.toString() ?? '';
          comparison = aInput.compareTo(bInput);
          break;
        default:
          // Sort by CSV column
          if (_csvColumns.contains(_inputDataSortColumn)) {
            final aValue = a.rowData[_inputDataSortColumn] ?? '';
            final bValue = b.rowData[_inputDataSortColumn] ?? '';
            comparison = aValue.compareTo(bValue);
          }
          break;
      }

      return _inputDataSortAscending ? comparison : -comparison;
    });

    return tasks;
  }

  // Resizable column header with sorting support
  Widget _buildResizableColumnHeader({
    required String columnKey,
    required String label,
    required ThemeData theme,
    required double defaultWidth,
    String? sortColumn,
    bool isInputDataTable = false,
  }) {
    final currentWidth = _columnWidths[columnKey] ?? defaultWidth;
    final isActive = sortColumn != null &&
        (isInputDataTable ? _inputDataSortColumn == sortColumn : _sortColumn == sortColumn);
    final sortAscending = isInputDataTable ? _inputDataSortAscending : _sortAscending;

    return SizedBox(
      width: currentWidth,
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: sortColumn != null
                  ? () {
                      if (isInputDataTable) {
                        _sortInputDataTasks(sortColumn);
                      } else {
                        _sortTasks(sortColumn);
                      }
                    }
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isActive
                              ? theme.colorScheme.primary
                              : theme.textTheme.titleSmall?.color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (sortColumn != null) ...[
                      const SizedBox(width: 4),
                      Icon(
                        isActive
                            ? (sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                            : Icons.unfold_more,
                        size: 16,
                        color: isActive
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          // Resize handle
          MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                setState(() {
                  final newWidth = (currentWidth + details.delta.dx).clamp(50.0, 500.0);
                  _columnWidths[columnKey] = newWidth;
                });
              },
              child: Container(
                width: 8,
                height: 24,
                alignment: Alignment.center,
                child: Container(
                  width: 2,
                  height: 16,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
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

    // Temporarily set _isExecuting to allow task execution
    final wasExecuting = _isExecuting;
    setState(() {
      _isExecuting = true;
      // Reset task status and all fields for fresh retry
      task.status = 'waiting';
      task.result = null;
      task.error = null;
      task.startTime = null;
      task.endTime = null;
      task.taskId = null;
      task.shouldCancel = false; // Reset cancel flag
      task.credits = null;
      task.rawOutput = null;
      task.processedEventIds.clear();
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
      // Mark task as failed immediately for better UI feedback
      if (task.status == 'queued') {
        task.status = 'failed';
        task.endTime = DateTime.now();
        task.error = 'Task cancelled by user';
      }
    });
  }

  void _showOutputDialog(BatchTask task) {
    final controller = TextEditingController(text: task.error ?? task.result ?? '');
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => DefaultTabController(
        length: 4,
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
                  child: Row(
                    children: [
                      if (task.filename != null) ...[
                        Text(
                          'Filename: ${task.filename}',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(width: 16),
                      ],
                      Text(
                        'Status: ',
                        style: theme.textTheme.bodySmall,
                      ),
                      _buildStatusBadge(task, theme),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Tab Bar
                TabBar(
                  tabs: const [
                    Tab(text: 'Input'),
                    Tab(text: 'Output'),
                    Tab(text: 'Raw Output'),
                    Tab(text: 'Status Log'),
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
                      // Input Tab
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: task.flowInput['input']?.toString() ?? ''));
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
                                  task.flowInput['input']?.toString() ?? 'No input available',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Output Tab
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
                      // Status Log Tab
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: task.statusHistory.isEmpty
                              ? Center(
                                  child: Text(
                                    'No status logs available',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                                  ),
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: theme.colorScheme.outline.withValues(alpha: 0.5),
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: SingleChildScrollView(
                                    child: DataTable(
                                      columnSpacing: 16,
                                      headingRowHeight: 40,
                                      dataRowMinHeight: 36,
                                      dataRowMaxHeight: 60,
                                      columns: const [
                                        DataColumn(label: Text('Time')),
                                        DataColumn(label: Text('Status')),
                                        DataColumn(label: Text('Raw Response')),
                                      ],
                                      rows: task.statusHistory.map((entry) {
                                        final timeStr = '${entry.timestamp.hour.toString().padLeft(2, '0')}:'
                                            '${entry.timestamp.minute.toString().padLeft(2, '0')}:'
                                            '${entry.timestamp.second.toString().padLeft(2, '0')}.'
                                            '${entry.timestamp.millisecond.toString().padLeft(3, '0')}';
                                        return DataRow(
                                          cells: [
                                            DataCell(Text(timeStr, style: theme.textTheme.bodySmall)),
                                            DataCell(
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: _getStatusColor(entry.status).withValues(alpha: 0.2),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  entry.status,
                                                  style: theme.textTheme.bodySmall?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: _getStatusColor(entry.status),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              InkWell(
                                                onTap: () {
                                                  // Show raw response in a dialog
                                                  showDialog(
                                                    context: context,
                                                    builder: (ctx) => AlertDialog(
                                                      title: Text('Raw Response - $timeStr'),
                                                      content: SizedBox(
                                                        width: 600,
                                                        height: 400,
                                                        child: SingleChildScrollView(
                                                          child: SelectableText(
                                                            entry.rawResponse ?? 'No raw response',
                                                            style: theme.textTheme.bodySmall?.copyWith(
                                                              fontFamily: 'monospace',
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      actions: [
                                                        TextButton.icon(
                                                          onPressed: () {
                                                            Clipboard.setData(ClipboardData(text: entry.rawResponse ?? ''));
                                                            ScaffoldMessenger.of(ctx).showSnackBar(
                                                              const SnackBar(content: Text('Copied to clipboard')),
                                                            );
                                                          },
                                                          icon: const Icon(Icons.copy, size: 16),
                                                          label: const Text('Copy'),
                                                        ),
                                                        TextButton(
                                                          onPressed: () => Navigator.of(ctx).pop(),
                                                          child: const Text('Close'),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.visibility, size: 16, color: theme.colorScheme.primary),
                                                    const SizedBox(width: 4),
                                                    Text('View', style: TextStyle(color: theme.colorScheme.primary)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
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

      // Try reading with UTF-8 first, fallback to Latin-1 if that fails
      List<String> lines;
      try {
        lines = await file.readAsLines();
        _logger.d('CSV file read successfully with UTF-8 encoding');
      } catch (e) {
        _logger.w('UTF-8 decoding failed, trying Latin-1 encoding: $e');
        lines = await file.readAsLines(encoding: latin1);
        _logger.d('CSV file read successfully with Latin-1 encoding');
      }

      _logger.d('CSV file lines: ${lines.length}');

      // Auto-detect delimiter from first line
      String delimiter = ',';
      if (lines.isNotEmpty) {
        final firstLine = lines[0];
        final commaCount = ','.allMatches(firstLine).length;
        final semicolonCount = ';'.allMatches(firstLine).length;
        final tabCount = '\t'.allMatches(firstLine).length;
        final pipeCount = '|'.allMatches(firstLine).length;

        // Find the delimiter with the highest count
        final delimiterCounts = {
          ',': commaCount,
          ';': semicolonCount,
          '\t': tabCount,
          '|': pipeCount,
        };

        // Get delimiter with max count (must be at least 1)
        var maxCount = 0;
        delimiterCounts.forEach((delim, count) {
          if (count > maxCount) {
            maxCount = count;
            delimiter = delim;
          }
        });

        _logger.d('Auto-detected CSV delimiter: "$delimiter" (comma=$commaCount, semicolon=$semicolonCount, tab=$tabCount, pipe=$pipeCount)');
      }

      // Parse CSV with proper quote handling for multiline values
      final rows = <List<String>>[];
      final fullContent = lines.join('\n');

      var currentRow = <String>[];
      var currentCell = StringBuffer();
      var insideQuotes = false;
      var i = 0;

      while (i < fullContent.length) {
        final char = fullContent[i];

        if (char == '"') {
          // Check if this is an escaped quote (doubled quote)
          if (insideQuotes && i + 1 < fullContent.length && fullContent[i + 1] == '"') {
            currentCell.write('"');
            i += 2; // Skip both quotes
            continue;
          }
          insideQuotes = !insideQuotes;
          i++;
        } else if (!insideQuotes && char == delimiter) {
          // End of cell
          currentRow.add(currentCell.toString().trim());
          currentCell.clear();
          i++;
        } else if (!insideQuotes && char == '\n') {
          // End of row
          if (currentCell.isNotEmpty || currentRow.isNotEmpty) {
            currentRow.add(currentCell.toString().trim());
            if (currentRow.any((cell) => cell.isNotEmpty)) {
              rows.add(currentRow);
            }
            currentRow = <String>[];
            currentCell.clear();
          }
          i++;
        } else {
          currentCell.write(char);
          i++;
        }
      }

      // Add last cell and row if any
      if (currentCell.isNotEmpty || currentRow.isNotEmpty) {
        currentRow.add(currentCell.toString().trim());
        if (currentRow.any((cell) => cell.isNotEmpty)) {
          rows.add(currentRow);
        }
      }

      _logger.d('CSV parsed: ${rows.length} rows');
      if (rows.isNotEmpty && rows.length <= 3) {
        for (var i = 0; i < rows.length; i++) {
          _logger.d('Row $i: ${rows[i]}');
        }
      }

      if (rows.isEmpty) {
        _logger.w('CSV file is empty');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('CSV file is empty')),
          );
        }
        return;
      }

      // Always treat first row as header row
      if (rows.length < 2) {
        _logger.w('CSV file needs at least 2 rows (header + data)');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('CSV file needs at least a header row and one data row')),
          );
        }
        return;
      }

      final headers = rows[0].map((h) => h.toString()).toList();
      final dataRows = rows.skip(1).toList();

      _logger.d('CSV headers: $headers');
      _logger.d('Processing ${dataRows.length} data rows');

      // Find filename column index (if exists)
      final filenameColumnIndex = headers.indexWhere(
        (h) => h.toLowerCase() == 'filename'
      );

      // Store all CSV columns for display
      final csvColumns = headers.toList();

      // Add filename column if it doesn't exist and write to file is enabled
      if (_writeOutputToFile && filenameColumnIndex < 0) {
        csvColumns.add('filename');
        _logger.d('Added filename column to CSV columns');
      }

      final uuid = const Uuid();
      final newTasks = <BatchTask>[];

      for (final row in dataRows) {
        // Create a map of column name -> value for all columns
        final rowData = <String, String>{};
        for (var i = 0; i < headers.length && i < row.length; i++) {
          final header = headers[i];
          rowData[header] = row[i].toString();
        }

        // Get filename from the filename column if it exists
        String? filename;
        if (filenameColumnIndex >= 0 && filenameColumnIndex < row.length) {
          filename = row[filenameColumnIndex].toString();
        }

        // Generate random filename if write output to file is enabled and filename is missing
        if (_writeOutputToFile && (filename == null || filename.isEmpty)) {
          filename = '${uuid.v4()}.md';
          _logger.d('Generated random filename: $filename');
        }

        // Add filename to rowData if write to file is enabled
        if (_writeOutputToFile && filename != null) {
          rowData['filename'] = filename;
        }

        _logger.d('Processing row: rowData=$rowData, filename="$filename"');

        // Format all row data as "column name: value" separated by newlines
        // Sanitize column names to avoid special characters that might cause parsing issues
        final formattedInput = rowData.entries
            .where((entry) => entry.key.toLowerCase() != 'filename')
            .map((entry) {
              // Sanitize column name: remove problematic characters
              final sanitizedColumnName = entry.key
                  .replaceAll('{', '')
                  .replaceAll('}', '')
                  .replaceAll('[', '')
                  .replaceAll(']', '')
                  .replaceAll('"', '')
                  .replaceAll("'", '')
                  .trim();
              return '$sanitizedColumnName: ${entry.value}';
            })
            .join('\n');

        newTasks.add(BatchTask(
          id: uuid.v4(),
          flowInput: {'input': formattedInput},
          rowData: rowData,
          filename: filename,
        ));
      }

      setState(() {
        _tasks.addAll(newTasks);
        // Update CSV columns if this is the first import or if tasks were empty
        if (_csvColumns.isEmpty && csvColumns.isNotEmpty) {
          _csvColumns = csvColumns;
        }
      });

      _logger.i('Successfully imported ${newTasks.length} tasks from CSV (total rows in CSV: ${dataRows.length})');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported ${newTasks.length} tasks from CSV'),
          ),
        );
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

      // Try reading with UTF-8 first, fallback to Latin-1 if that fails
      List<String> lines;
      try {
        lines = await file.readAsLines();
        _logger.d('CSV file read successfully with UTF-8 encoding');
      } catch (e) {
        _logger.w('UTF-8 decoding failed, trying Latin-1 encoding: $e');
        lines = await file.readAsLines(encoding: latin1);
        _logger.d('CSV file read successfully with Latin-1 encoding');
      }

      _logger.d('CSV file lines: ${lines.length}');

      // Auto-detect delimiter from first line
      String delimiter = ',';
      if (lines.isNotEmpty) {
        final firstLine = lines[0];
        final commaCount = ','.allMatches(firstLine).length;
        final semicolonCount = ';'.allMatches(firstLine).length;
        final tabCount = '\t'.allMatches(firstLine).length;
        final pipeCount = '|'.allMatches(firstLine).length;

        // Find the delimiter with the highest count
        final delimiterCounts = {
          ',': commaCount,
          ';': semicolonCount,
          '\t': tabCount,
          '|': pipeCount,
        };

        // Get delimiter with max count (must be at least 1)
        var maxCount = 0;
        delimiterCounts.forEach((delim, count) {
          if (count > maxCount) {
            maxCount = count;
            delimiter = delim;
          }
        });

        _logger.d('Auto-detected CSV delimiter: "$delimiter" (comma=$commaCount, semicolon=$semicolonCount, tab=$tabCount, pipe=$pipeCount)');
      }

      // Parse CSV with proper quote handling for multiline values
      final rows = <List<String>>[];
      final fullContent = lines.join('\n');

      var currentRow = <String>[];
      var currentCell = StringBuffer();
      var insideQuotes = false;
      var i = 0;

      while (i < fullContent.length) {
        final char = fullContent[i];

        if (char == '"') {
          // Check if this is an escaped quote (doubled quote)
          if (insideQuotes && i + 1 < fullContent.length && fullContent[i + 1] == '"') {
            currentCell.write('"');
            i += 2; // Skip both quotes
            continue;
          }
          insideQuotes = !insideQuotes;
          i++;
        } else if (!insideQuotes && char == delimiter) {
          // End of cell
          currentRow.add(currentCell.toString().trim());
          currentCell.clear();
          i++;
        } else if (!insideQuotes && char == '\n') {
          // End of row
          if (currentCell.isNotEmpty || currentRow.isNotEmpty) {
            currentRow.add(currentCell.toString().trim());
            if (currentRow.any((cell) => cell.isNotEmpty)) {
              rows.add(currentRow);
            }
            currentRow = <String>[];
            currentCell.clear();
          }
          i++;
        } else {
          currentCell.write(char);
          i++;
        }
      }

      // Add last cell and row if any
      if (currentCell.isNotEmpty || currentRow.isNotEmpty) {
        currentRow.add(currentCell.toString().trim());
        if (currentRow.any((cell) => cell.isNotEmpty)) {
          rows.add(currentRow);
        }
      }

      _logger.d('CSV parsed: ${rows.length} rows');
      if (rows.isNotEmpty && rows.length <= 3) {
        for (var i = 0; i < rows.length; i++) {
          _logger.d('Row $i: ${rows[i]}');
        }
      }

      if (rows.isEmpty) {
        _logger.w('CSV file is empty');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('CSV file is empty')),
          );
        }
        return;
      }

      // Always treat first row as header row
      if (rows.length < 2) {
        _logger.w('CSV file needs at least 2 rows (header + data)');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('CSV file needs at least a header row and one data row')),
          );
        }
        return;
      }

      final headers = rows[0].map((h) => h.toString()).toList();
      final dataRows = rows.skip(1).toList();

      _logger.d('CSV headers: $headers');
      _logger.d('Processing ${dataRows.length} data rows');

      // Find filename column index (if exists)
      final filenameColumnIndex = headers.indexWhere(
        (h) => h.toLowerCase() == 'filename'
      );

      // Store all CSV columns for display
      final csvColumns = headers.toList();

      // Add filename column if it doesn't exist and write to file is enabled
      if (_writeOutputToFile && filenameColumnIndex < 0) {
        csvColumns.add('filename');
        _logger.d('Added filename column to CSV columns');
      }

      final uuid = const Uuid();
      final newTasks = <BatchTask>[];

      for (final row in dataRows) {
        // Create a map of column name -> value for all columns
        final rowData = <String, String>{};
        for (var i = 0; i < headers.length && i < row.length; i++) {
          final header = headers[i];
          rowData[header] = row[i].toString();
        }

        // Get filename from the filename column if it exists
        String? filename;
        if (filenameColumnIndex >= 0 && filenameColumnIndex < row.length) {
          filename = row[filenameColumnIndex].toString();
        }

        // Generate random filename if write output to file is enabled and filename is missing
        if (_writeOutputToFile && (filename == null || filename.isEmpty)) {
          filename = '${uuid.v4()}.md';
          _logger.d('Generated random filename: $filename');
        }

        // Add filename to rowData if write to file is enabled
        if (_writeOutputToFile && filename != null) {
          rowData['filename'] = filename;
        }

        _logger.d('Processing row: rowData=$rowData, filename="$filename"');

        // Format all row data as "column name: value" separated by newlines
        // Sanitize column names to avoid special characters that might cause parsing issues
        final formattedInput = rowData.entries
            .where((entry) => entry.key.toLowerCase() != 'filename')
            .map((entry) {
              // Sanitize column name: remove problematic characters
              final sanitizedColumnName = entry.key
                  .replaceAll('{', '')
                  .replaceAll('}', '')
                  .replaceAll('[', '')
                  .replaceAll(']', '')
                  .replaceAll('"', '')
                  .replaceAll("'", '')
                  .trim();
              return '$sanitizedColumnName: ${entry.value}';
            })
            .join('\n');

        newTasks.add(BatchTask(
          id: uuid.v4(),
          flowInput: {'input': formattedInput},
          rowData: rowData,
          filename: filename,
        ));
      }

      setState(() {
        _tasks.addAll(newTasks);
        // Update CSV columns if this is the first import or if tasks were empty
        if (_csvColumns.isEmpty && csvColumns.isNotEmpty) {
          _csvColumns = csvColumns;
        }
      });

      _logger.i('Successfully imported ${newTasks.length} tasks from CSV (total rows in CSV: ${dataRows.length})');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported ${newTasks.length} tasks from CSV'),
          ),
        );
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
            // Create new task with updated input but preserve all execution state
            _tasks[index] = BatchTask(
              id: task.id,
              flowInput: {'input': value},
              rowData: task.rowData,
              filename: task.filename,
              status: task.status,
              result: task.result,
              error: task.error,
              credits: task.credits,
              rawOutput: task.rawOutput,
              taskId: task.taskId,
              startTime: task.startTime,
              endTime: task.endTime,
              shouldCancel: task.shouldCancel,
            )..processedEventIds = task.processedEventIds;
          });
        },
      ),
    );
  }

  void _editTaskColumnValue(int index, String columnName) {
    final task = _tasks[index];

    showDialog(
      context: context,
      builder: (context) => _EditFieldDialog(
        title: 'Edit Column Value',
        fieldName: columnName,
        initialValue: task.rowData[columnName] ?? '',
        onSave: (value) {
          setState(() {
            // Update the column value in rowData
            final updatedRowData = Map<String, String>.from(task.rowData);
            updatedRowData[columnName] = value;

            // Regenerate the formatted input for the flow
            // Sanitize column names to avoid special characters that might cause parsing issues
            final formattedInput = updatedRowData.entries
                .where((entry) => entry.key.toLowerCase() != 'filename')
                .map((entry) {
                  // Sanitize column name: remove problematic characters
                  final sanitizedColumnName = entry.key
                      .replaceAll('{', '')
                      .replaceAll('}', '')
                      .replaceAll('[', '')
                      .replaceAll(']', '')
                      .replaceAll('"', '')
                      .replaceAll("'", '')
                      .trim();
                  return '$sanitizedColumnName: ${entry.value}';
                })
                .join('\n');

            // Update filename if the edited column is the filename column
            String? updatedFilename = task.filename;
            if (columnName.toLowerCase() == 'filename') {
              updatedFilename = value.isEmpty ? null : value;
            }

            // Create new task with updated rowData and flowInput but preserve all execution state
            _tasks[index] = BatchTask(
              id: task.id,
              flowInput: {'input': formattedInput},
              rowData: updatedRowData,
              filename: updatedFilename,
              status: task.status,
              result: task.result,
              error: task.error,
              credits: task.credits,
              rawOutput: task.rawOutput,
              taskId: task.taskId,
              startTime: task.startTime,
              endTime: task.endTime,
              shouldCancel: task.shouldCancel,
            )..processedEventIds = task.processedEventIds;
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
    // Skip tasks that are already 'done' to avoid re-execution (Resume functionality)
    setState(() {
      _isExecuting = true;
      for (var task in _tasks) {
        // Only reset tasks that are not already completed successfully
        if (task.status != 'done') {
          task.status = 'waiting';
          task.result = null;
          task.error = null;
        }
      }
    });

    final tasksToExecute = _tasks.where((task) => task.status != 'done' && task.status != 'skipped').length;
    final tasksAlreadyDone = _tasks.where((task) => task.status == 'done').length;
    final tasksSkipped = _tasks.where((task) => task.status == 'skipped').length;

    _logger.i('Starting batch execution (Resume mode)');
    _logger.i('Flow: ${_selectedFlow!.name} (${_selectedFlow!.flowId})');
    _logger.i('Total tasks: ${_tasks.length}');
    _logger.i('Tasks to execute: $tasksToExecute');
    _logger.i('Tasks already done: $tasksAlreadyDone');
    _logger.i('Tasks skipped: $tasksSkipped');
    _logger.i('Execution mode: ${_executionMode.name}');
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

    // Filter out tasks that are already done or skipped (Resume functionality)
    final tasksToExecute = _tasks.where((task) => task.status != 'done' && task.status != 'skipped').toList();

    if (tasksToExecute.isEmpty) {
      _logger.i('All tasks already completed, nothing to execute');
      setState(() => _isExecuting = false);
      return;
    }

    _logger.i('Starting task queue execution with ${tasksToExecute.length} tasks, max concurrent: $_parallelExecutions');

    // Task queue management
    final taskQueue = List<BatchTask>.from(tasksToExecute);
    final Map<String, BatchTask> runningTasks = {}; // taskId -> BatchTask
    final Map<String, int> pollAttempts = {}; // taskId -> attempt count
    int queueIndex = 0;

    // Helper function to start a task and add it to running tasks
    // Returns true if task was actually scheduled (not skipped)
    Future<bool> scheduleTask(BatchTask task) async {
      final taskId = await _startTask(task, flowService, workspaceId);
      if (taskId != null && _isExecuting) {
        runningTasks[taskId] = task;
        pollAttempts[taskId] = 0;
        _logger.d('Scheduled task ${task.id} with taskId: $taskId');
        return true;
      }
      return false; // Task was skipped or failed to start
    }

    // Start initial batch of tasks IN PARALLEL
    // Keep starting tasks until we have _parallelExecutions actually running
    while (runningTasks.length < _parallelExecutions && queueIndex < taskQueue.length && _isExecuting) {
      final batchSize = _parallelExecutions - runningTasks.length;
      final batchEnd = (queueIndex + batchSize).clamp(0, taskQueue.length);
      final batch = taskQueue.sublist(queueIndex, batchEnd);

      // Start batch in parallel
      final futures = batch.map((task) => scheduleTask(task)).toList();
      await Future.wait(futures);

      queueIndex = batchEnd;
      _logger.d('After batch: ${runningTasks.length} running, queueIndex: $queueIndex');
    }

    _logger.i('Scheduled ${runningTasks.length} initial tasks in parallel (may have skipped some)');

    // Round-robin polling loop
    const pollInterval = Duration(seconds: 2);
    final maxAttempts = (_taskTimeoutSeconds / 2).round(); // Calculate based on timeout setting
    final runningTaskIds = runningTasks.keys.toList();
    int currentPollIndex = 0;

    while (runningTasks.isNotEmpty && _isExecuting) {
      await Future.delayed(pollInterval);

      // Yield to UI thread to prevent blocking
      await Future.microtask(() {});

      if (runningTaskIds.isEmpty) break;

      // Dynamic adjustment: start tasks to fill up to parallel limit
      // We need to account for skipped tasks, so start more than we need
      if (runningTasks.length < _parallelExecutions && queueIndex < taskQueue.length && _isExecuting) {
        final slotsToFill = _parallelExecutions - runningTasks.length;
        // Try to start extra tasks to account for potential skips (2x)
        final tasksToTry = (slotsToFill * 2).clamp(0, taskQueue.length - queueIndex);
        _logger.d('Parallel limit is $_parallelExecutions, currently ${runningTasks.length} running, trying to start $tasksToTry tasks');

        // Start additional tasks in parallel (some may be skipped)
        final batchEnd = (queueIndex + tasksToTry).clamp(0, taskQueue.length);
        final batch = taskQueue.sublist(queueIndex, batchEnd);

        // Fire off all in parallel without awaiting
        for (final task in batch) {
          scheduleTask(task).then((scheduled) {
            if (scheduled) {
              final taskId = task.taskId;
              if (taskId != null && !runningTaskIds.contains(taskId)) {
                runningTaskIds.add(taskId);
                _logger.i('Started task ${task.id} (${runningTasks.length}/$_parallelExecutions running)');
              }
            }
          });
        }

        queueIndex = batchEnd;
      } else if (runningTasks.length > _parallelExecutions) {
        // User decreased the parallel limit - log it but don't kill running tasks
        _logger.d('Parallel limit decreased to $_parallelExecutions (${runningTasks.length} tasks still running, will not start new tasks until count drops)');
      }

      // Round-robin: check one task at a time
      final taskIdToCheck = runningTaskIds[currentPollIndex % runningTaskIds.length];
      final task = runningTasks[taskIdToCheck];

      if (task == null || task.shouldCancel) {
        // Task was removed or cancelled
        if (task != null && task.shouldCancel) {
          _logger.i('Task ${task.id} cancelled, removing from running tasks');
        }
        runningTasks.remove(taskIdToCheck);
        runningTaskIds.remove(taskIdToCheck);
        pollAttempts.remove(taskIdToCheck);

        // Start next tasks from queue to fill available slots
        // Try multiple tasks to account for potential skips
        if (runningTasks.length < _parallelExecutions && queueIndex < taskQueue.length) {
          final slotsAvailable = _parallelExecutions - runningTasks.length;
          final tasksToTry = (slotsAvailable * 2).clamp(0, taskQueue.length - queueIndex);
          final batchEnd = (queueIndex + tasksToTry).clamp(0, taskQueue.length);

          for (int i = queueIndex; i < batchEnd; i++) {
            final nextTask = taskQueue[i];
            scheduleTask(nextTask).then((scheduled) {
              if (scheduled && nextTask.taskId != null && !runningTaskIds.contains(nextTask.taskId!)) {
                runningTaskIds.add(nextTask.taskId!);
              }
            });
          }
          queueIndex = batchEnd;
        }
        continue;
      }

      pollAttempts[taskIdToCheck] = (pollAttempts[taskIdToCheck] ?? 0) + 1;
      final attempts = pollAttempts[taskIdToCheck]!;

      // Check if task timed out
      if (attempts >= maxAttempts) {
        if (_timeoutPolicy == TimeoutPolicy.retry) {
          // Retry policy: Reset task and re-queue it
          setState(() {
            task.status = 'pending';
            task.endTime = null;
            task.startTime = null;
            task.taskId = null;
            task.error = null;
          });

          // Add task back to queue for retry
          taskQueue.add(task);

          runningTasks.remove(taskIdToCheck);
          runningTaskIds.remove(taskIdToCheck);
          pollAttempts.remove(taskIdToCheck);
        } else {
          // Mark as error policy: Mark task as failed
          _logger.e('Task ${task.id} timed out after $attempts attempts');
          setState(() {
            task.status = 'failed';
            task.endTime = DateTime.now();
            task.error = 'Task timed out after ${maxAttempts * 2} seconds';
          });
          runningTasks.remove(taskIdToCheck);
          runningTaskIds.remove(taskIdToCheck);
          pollAttempts.remove(taskIdToCheck);
        }

        // Start next tasks from queue to fill available slots
        // Try multiple tasks to account for potential skips
        if (runningTasks.length < _parallelExecutions && queueIndex < taskQueue.length) {
          final slotsAvailable = _parallelExecutions - runningTasks.length;
          final tasksToTry = (slotsAvailable * 2).clamp(0, taskQueue.length - queueIndex);
          final batchEnd = (queueIndex + tasksToTry).clamp(0, taskQueue.length);

          for (int i = queueIndex; i < batchEnd; i++) {
            final nextTask = taskQueue[i];
            scheduleTask(nextTask).then((scheduled) {
              if (scheduled && nextTask.taskId != null && !runningTaskIds.contains(nextTask.taskId!)) {
                runningTaskIds.add(nextTask.taskId!);
              }
            });
          }
          queueIndex = batchEnd;
        }
        continue;
      }

      // Poll task status
      try {
        if (attempts == 1 || attempts % 10 == 0) {
          _logger.i('Polling task ${task.id} (attempt $attempts)');
        }

        // Task status polling for singleton/normal modes
        final statusResponse = await flowService.checkTaskStatus(
          flowId: _selectedFlow!.flowId!,
          taskId: taskIdToCheck,
          workspaceId: workspaceId,
        );

        _logger.d('Task ${task.id} status: ${statusResponse.status}');

        // Record status check in history
        task.statusHistory.add(StatusLogEntry(
          timestamp: DateTime.now(),
          status: statusResponse.status ?? 'UNKNOWN',
          rawResponse: jsonEncode(statusResponse.toJson()),
        ));

        if (_isSuccessStatus(statusResponse.status)) {
          setState(() {
            task.status = 'done';
            task.endTime = DateTime.now();
            task.result = statusResponse.aiAnswer ??
                         statusResponse.errorMessage ??
                         'Task $taskIdToCheck - ${statusResponse.status}';
            task.credits = statusResponse.credits;
            task.rawOutput = jsonEncode(statusResponse.toJson());
          });
          _logger.i('Task ${task.id} completed after $attempts polls');

          // Automatically write output to file if enabled
          await _writeTaskOutputToFile(task);

          // Remove from running tasks
          runningTasks.remove(taskIdToCheck);
          runningTaskIds.remove(taskIdToCheck);
          pollAttempts.remove(taskIdToCheck);

          // Start next task from queue only if we're under the parallel limit
          if (queueIndex < taskQueue.length && _isExecuting && runningTasks.length < _parallelExecutions) {
            final nextTask = taskQueue[queueIndex];
            final nextTaskId = await _startTask(nextTask, flowService, workspaceId);
            if (nextTaskId != null) {
              runningTasks[nextTaskId] = nextTask;
              runningTaskIds.add(nextTaskId);
              pollAttempts[nextTaskId] = 0;
            }
            queueIndex++;
          }
        } else if (statusResponse.status == 'FAILED' || statusResponse.status == 'ERROR') {
          setState(() {
            task.status = 'failed';
            task.endTime = DateTime.now();
            task.error = statusResponse.errorMessage ?? 'Task failed: ${statusResponse.status}';
            task.rawOutput = jsonEncode(statusResponse.toJson());
          });
          _logger.e('Task ${task.id} failed after $attempts polls');

          // Remove from running tasks
          runningTasks.remove(taskIdToCheck);
          runningTaskIds.remove(taskIdToCheck);
          pollAttempts.remove(taskIdToCheck);

          // Start next task from queue only if we're under the parallel limit
          if (queueIndex < taskQueue.length && _isExecuting && runningTasks.length < _parallelExecutions) {
            final nextTask = taskQueue[queueIndex];
            final nextTaskId = await _startTask(nextTask, flowService, workspaceId);
            if (nextTaskId != null) {
              runningTasks[nextTaskId] = nextTask;
              runningTaskIds.add(nextTaskId);
              pollAttempts[nextTaskId] = 0;
            }
            queueIndex++;
          }
        } else if (statusResponse.status == 'PENDING') {
          // Task still pending, continue polling
          if (mounted) {
            setState(() {});
          }
        } else {
          // Unexpected status - log warning and continue polling
          // This handles statuses like RUNNING, PROCESSING, etc.
          _logger.w('Unexpected status for task ${task.id}: ${statusResponse.status}, continuing to poll');
          if (mounted) {
            setState(() {});
          }
        }
      } catch (e, stackTrace) {
        _logger.e('Error polling task ${task.id}', error: e, stackTrace: stackTrace);
      }

      // Move to next task in round-robin
      currentPollIndex++;
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

  // Helper method to start a task and return its taskId
  Future<String?> _startTask(BatchTask task, dynamic flowService, String workspaceId) async {
    try {
      // Check if file already exists and skip if overwrite is disabled
      if (_writeOutputToFile && !_overwriteExistingFiles && task.filename != null) {
        final outputPath = '$_outputDirectory/${task.filename}';
        final outputFile = File(outputPath);

        if (await outputFile.exists()) {
          _logger.i('Skipping task ${task.id} - output file already exists: ${task.filename}');
          setState(() {
            task.status = 'skipped';
            task.result = 'File already exists';
          });
          return null;
        }
      }

      setState(() {
        task.status = 'queued';
        task.startTime = DateTime.now();
      });

      _logger.d('Starting task ${task.id}: ${task.flowInput}');

      // Convert 'input' to 'human_input' for API compatibility
      final apiFlowInput = {
        'human_input': task.flowInput['input'],
      };

      // Invoke the flow - this returns immediately with task_id and PENDING status
      final initialResponse = _executionMode == ExecutionMode.singleton
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

      _logger.i('Task ${task.id} started with ID: $taskId, status: ${initialResponse.status}');

      // Record initial status in history
      task.statusHistory.add(StatusLogEntry(
        timestamp: DateTime.now(),
        status: initialResponse.status ?? 'UNKNOWN',
        rawResponse: jsonEncode(initialResponse.toJson()),
      ));

      // If status is already completed (SUCCESS/COMPLETED/CACHED/FAILED) or result is available, handle immediately
      if (initialResponse.status != 'PENDING' || initialResponse.result != null) {
        if (_isSuccessStatus(initialResponse.status)) {
          setState(() {
            task.status = 'done';
            task.endTime = DateTime.now();
            task.result = initialResponse.aiAnswer ??
                         initialResponse.errorMessage ??
                         'Task $taskId - ${initialResponse.status}';
            task.credits = initialResponse.credits;
            task.rawOutput = jsonEncode(initialResponse.toJson());
          });
          _logger.i('Task ${task.id} completed immediately');

          // Automatically write output to file if enabled
          await _writeTaskOutputToFile(task);

          return null; // Task already completed, no need to poll
        } else if (initialResponse.status == 'FAILED' || initialResponse.status == 'ERROR') {
          setState(() {
            task.status = 'failed';
            task.endTime = DateTime.now();
            task.error = initialResponse.errorMessage ?? 'Task failed: ${initialResponse.status}';
            task.rawOutput = jsonEncode(initialResponse.toJson());
          });
          _logger.e('Task ${task.id} failed immediately');
          return null; // Task already failed, no need to poll
        }
      }

      return taskId; // Return taskId for polling
    } catch (e, stackTrace) {
      _logger.e('Failed to start task ${task.id}', error: e, stackTrace: stackTrace);
      setState(() {
        task.status = 'failed';
        task.endTime = DateTime.now();
        task.error = e.toString();
      });
      return null;
    }
  }

  Future<void> _executeTask(
    BatchTask task,
    dynamic flowService,
    String workspaceId,
  ) async {
    if (!_isExecuting) return;

    // Skip tasks that are already done (Resume functionality)
    if (task.status == 'done') {
      _logger.d('Skipping task ${task.id} - already completed');
      return;
    }

    // Check if file already exists and skip if overwrite is disabled
    if (_writeOutputToFile && !_overwriteExistingFiles && task.filename != null) {
      final outputPath = '$_outputDirectory/${task.filename}';
      final outputFile = File(outputPath);

      if (await outputFile.exists()) {
        _logger.i('Skipping task ${task.id} - output file already exists: ${task.filename}');
        setState(() {
          task.status = 'skipped';
          task.result = 'File already exists';
        });
        return;
      }
    }

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
      _logger.i('Execution mode: ${_executionMode.name}');
      _logger.i('Workspace ID: $workspaceId');
      _logger.i('Flow ID: ${_selectedFlow!.flowId}');
      _logger.i('Flow Name: ${_selectedFlow!.name}');
      _logger.i('API Parameters: $apiFlowInput');
      _logger.i('Stream Response: false');

      // Construct the URL that will be called (for debugging)
      final endpoint = _executionMode == ExecutionMode.singleton
        ? '/api/v1/flows/${_selectedFlow!.flowId}/invoke-singleton'
        : '/api/v1/flows/${_selectedFlow!.flowId}/invoke';
      _logger.i('API Endpoint: $endpoint');
      _logger.i('=======================');

      // Invoke the flow - this returns immediately with task_id and PENDING status
      final initialResponse = _executionMode == ExecutionMode.singleton
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

      // Record initial status in history
      task.statusHistory.add(StatusLogEntry(
        timestamp: DateTime.now(),
        status: initialResponse.status ?? 'UNKNOWN',
        rawResponse: jsonEncode(initialResponse.toJson()),
      ));

      // If status is already completed (SUCCESS/COMPLETED/CACHED/FAILED) or result is available, no need to poll
      if (initialResponse.status != 'PENDING' || initialResponse.result != null) {
        if (_isSuccessStatus(initialResponse.status)) {
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

          // Automatically write output to file if enabled
          await _writeTaskOutputToFile(task);

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
      final maxAttempts = (_taskTimeoutSeconds / 2).round(); // Calculate based on timeout setting
      int attempts = 0;

      while (attempts < maxAttempts && _isExecuting && !task.shouldCancel) {
        await Future.delayed(pollInterval);

        // Yield to UI thread to prevent blocking
        await Future.microtask(() {});

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

        // Record status check in history
        task.statusHistory.add(StatusLogEntry(
          timestamp: DateTime.now(),
          status: statusResponse.status ?? 'UNKNOWN',
          rawResponse: jsonEncode(statusResponse.toJson()),
        ));

        if (_isSuccessStatus(statusResponse.status)) {
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

          // Automatically write output to file if enabled
          await _writeTaskOutputToFile(task);

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
        // Append cancellation info to raw output without replacing result
        String? currentRawOutput = task.rawOutput;
        Map<String, dynamic> cancellationInfo = {
          'cancelled_at': DateTime.now().toIso8601String(),
          'reason': 'Task cancelled by user',
        };

        if (currentRawOutput != null && currentRawOutput.isNotEmpty) {
          task.rawOutput = '$currentRawOutput\n\n--- CANCELLED ---\n${jsonEncode(cancellationInfo)}';
        } else {
          task.rawOutput = jsonEncode(cancellationInfo);
        }

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
        throw Exception('Task $taskId timed out after $_taskTimeoutSeconds seconds');
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

  Future<void> _writeTaskOutputToFile(BatchTask task) async {
    if (!_writeOutputToFile || _outputDirectory.isEmpty) {
      return;
    }

    if (task.filename == null || task.result == null) {
      return;
    }

    try {
      final filePath = '$_outputDirectory/${task.filename}';
      final file = File(filePath);

      // Create parent directories if they don't exist
      await file.parent.create(recursive: true);

      // Write the result
      await file.writeAsString(task.result!);

      _logger.d('Automatically wrote output to: $filePath');
    } catch (e, stackTrace) {
      _logger.e('Failed to write output file for task ${task.id}', error: e, stackTrace: stackTrace);
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

  Future<void> _exportToCsv() async {
    if (_tasks.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No tasks to export')),
        );
      }
      return;
    }

    try {
      // Get the currently displayed tasks (with search/filter applied)
      final tasksToExport = _getSortedTasks();

      // Build CSV headers
      final List<String> headers = ['#'];

      // Add CSV column headers or Input Value
      if (_csvColumns.isNotEmpty) {
        headers.addAll(_csvColumns);
      } else {
        headers.add('Input Value');
      }

      // Add fixed columns
      headers.addAll(['Status', 'Start Time', 'End Time', 'Duration', 'Credits', 'Output', 'Error']);

      // Build CSV rows
      final List<List<dynamic>> rows = [headers];

      for (final task in tasksToExport) {
        final originalIndex = _tasks.indexOf(task);
        final List<dynamic> row = [originalIndex + 1];

        // Add CSV column values or Input Value
        if (_csvColumns.isNotEmpty) {
          for (final column in _csvColumns) {
            row.add(task.rowData[column] ?? '');
          }
        } else {
          row.add(task.flowInput['input']?.toString() ?? '');
        }

        // Add fixed column values
        row.add(task.status);
        row.add(task.startTime != null
            ? '${task.startTime!.hour.toString().padLeft(2, '0')}:${task.startTime!.minute.toString().padLeft(2, '0')}:${task.startTime!.second.toString().padLeft(2, '0')}'
            : '');
        row.add(task.endTime != null
            ? '${task.endTime!.hour.toString().padLeft(2, '0')}:${task.endTime!.minute.toString().padLeft(2, '0')}:${task.endTime!.second.toString().padLeft(2, '0')}'
            : '');
        row.add(task.durationDecimal);
        row.add(task.credits?.toStringAsFixed(6) ?? '');
        row.add(task.result ?? '');
        row.add(task.error ?? '');

        rows.add(row);
      }

      // Convert to CSV string
      const converter = ListToCsvConverter();
      final csvString = converter.convert(rows);

      // Let user pick save location
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Tasks to CSV',
        fileName: 'batch_export_${DateTime.now().millisecondsSinceEpoch}.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null) {
        _logger.d('Export cancelled by user');
        return;
      }

      // Write the file
      final file = File(result);
      await file.writeAsString(csvString);

      _logger.i('Exported ${tasksToExport.length} tasks to CSV: $result');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported ${tasksToExport.length} tasks to CSV')),
        );
      }
    } catch (e, stackTrace) {
      _logger.e('Failed to export CSV', error: e, stackTrace: stackTrace);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting CSV: $e'),
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
        width: 600,
        constraints: const BoxConstraints(maxHeight: 500),
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
              Flexible(
                child: SingleChildScrollView(
                  child: TextFormField(
                    controller: _controller,
                    autofocus: true,
                    minLines: 3,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(
                      labelText: widget.fieldName,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignLabelWithHint: true,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '${widget.fieldName} cannot be empty';
                      }
                      return null;
                    },
                  ),
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
