class BatchTask {
  final String id;
  final Map<String, dynamic> flowInput;
  final String? filename;
  String status; // pending, running, completed, failed
  String? result;
  String? error;
  double? credits; // Credits used (from API result)
  String? rawOutput; // Raw API response for debugging
  DateTime? startTime;
  DateTime? endTime;
  bool shouldCancel = false; // Flag to signal task cancellation

  BatchTask({
    required this.id,
    required this.flowInput,
    this.filename,
    this.status = 'pending',
    this.result,
    this.error,
    this.credits,
    this.rawOutput,
    this.startTime,
    this.endTime,
    this.shouldCancel = false,
  });

  // Calculate duration if both start and end times are available
  Duration? get duration {
    if (startTime != null && endTime != null) {
      return endTime!.difference(startTime!);
    }
    return null;
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'flow_input': flowInput,
    'filename': filename,
    'status': status,
    'result': result,
    'error': error,
    'credits': credits,
    'raw_output': rawOutput,
    'start_time': startTime?.toIso8601String(),
    'end_time': endTime?.toIso8601String(),
  };

  factory BatchTask.fromJson(Map<String, dynamic> json) => BatchTask(
    id: json['id'] as String,
    flowInput: json['flow_input'] as Map<String, dynamic>,
    filename: json['filename'] as String?,
    status: json['status'] as String? ?? 'pending',
    result: json['result'] as String?,
    error: json['error'] as String?,
    credits: json['credits'] as double?,
    rawOutput: json['raw_output'] as String?,
    startTime: json['start_time'] != null ? DateTime.parse(json['start_time'] as String) : null,
    endTime: json['end_time'] != null ? DateTime.parse(json['end_time'] as String) : null,
  );
}
