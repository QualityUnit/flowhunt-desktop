class BatchTask {
  final String id;
  final Map<String, dynamic> flowInput;
  final Map<String, String> rowData; // All CSV column data: column_name -> value
  final String? filename;
  String status; // pending, waiting, queued, done, failed, skipped
  String? result;
  String? error;
  double? credits; // Credits used (from API result)
  String? rawOutput; // Raw API response for debugging
  String? taskId; // API task ID from flow execution
  Set<String> processedEventIds = {}; // Track processed event IDs to avoid duplicates
  DateTime? startTime;
  DateTime? endTime;
  bool shouldCancel = false; // Flag to signal task cancellation

  BatchTask({
    required this.id,
    required this.flowInput,
    this.rowData = const {},
    this.filename,
    this.status = 'pending',
    this.result,
    this.error,
    this.credits,
    this.rawOutput,
    this.taskId,
    this.startTime,
    this.endTime,
    this.shouldCancel = false,
  });

  // Calculate duration if start time is available
  // If task is still running (no end time), calculate duration up to now
  Duration? get duration {
    if (startTime == null) return null;

    final end = endTime ?? DateTime.now();
    return end.difference(startTime!);
  }

  // Format duration as human-readable string
  String get durationFormatted {
    final d = duration;
    if (d == null) return '-';

    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m ${d.inSeconds.remainder(60)}s';
    } else if (d.inMinutes > 0) {
      return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    } else {
      return '${d.inSeconds}s';
    }
  }

  // Format duration as decimal seconds with 1 decimal place
  String get durationDecimal {
    final d = duration;
    if (d == null) return '-';

    final seconds = d.inMilliseconds / 1000.0;
    return '${seconds.toStringAsFixed(1)}s';
  }

  // Format all row data as "column name: value" separated by newlines
  String formatRowDataAsInput() {
    if (rowData.isEmpty) {
      return flowInput['input']?.toString() ?? '';
    }

    return rowData.entries
        .where((entry) => entry.key.toLowerCase() != 'filename') // Exclude filename column
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
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'flow_input': flowInput,
    'row_data': rowData,
    'filename': filename,
    'status': status,
    'result': result,
    'error': error,
    'credits': credits,
    'raw_output': rawOutput,
    'task_id': taskId,
    'start_time': startTime?.toIso8601String(),
    'end_time': endTime?.toIso8601String(),
  };

  factory BatchTask.fromJson(Map<String, dynamic> json) => BatchTask(
    id: json['id'] as String,
    flowInput: json['flow_input'] as Map<String, dynamic>,
    rowData: json['row_data'] != null
        ? Map<String, String>.from(json['row_data'] as Map)
        : {},
    filename: json['filename'] as String?,
    status: json['status'] as String? ?? 'pending',
    result: json['result'] as String?,
    error: json['error'] as String?,
    credits: json['credits'] as double?,
    rawOutput: json['raw_output'] as String?,
    taskId: json['task_id'] as String?,
    startTime: json['start_time'] != null ? DateTime.parse(json['start_time'] as String) : null,
    endTime: json['end_time'] != null ? DateTime.parse(json['end_time'] as String) : null,
  );
}
