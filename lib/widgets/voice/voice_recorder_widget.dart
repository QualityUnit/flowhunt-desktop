import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/voice/voice_input_state.dart';
import '../../providers/voice_input_provider.dart';

/// A widget that provides voice recording functionality with visual feedback
class VoiceRecorderWidget extends ConsumerStatefulWidget {
  final Function(String transcription)? onTranscription;
  final Function(RecordingFile file)? onRecordingComplete;
  final VoidCallback? onRecordingStart;
  final VoidCallback? onRecordingStop;
  final bool compact;
  final double size;
  
  const VoiceRecorderWidget({
    super.key,
    this.onTranscription,
    this.onRecordingComplete,
    this.onRecordingStart,
    this.onRecordingStop,
    this.compact = false,
    this.size = 40.0,
  });

  @override
  ConsumerState<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends ConsumerState<VoiceRecorderWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rippleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rippleAnimation;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _rippleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rippleController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final voiceState = ref.watch(voiceInputProvider);
    
    // Listen to state changes and trigger callbacks
    ref.listen<VoiceInputState>(voiceInputProvider, (previous, current) {
      _handleStateChange(previous, current);
    });
    
    // Handle animations based on state
    _updateAnimations(voiceState);
    
    if (widget.compact) {
      return _buildCompactRecorder(theme, voiceState);
    } else {
      return _buildFullRecorder(theme, voiceState);
    }
  }

  Widget _buildCompactRecorder(ThemeData theme, VoiceInputState state) {
    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _getButtonColor(theme, state),
          border: state.isRecording ? Border.all(
            color: theme.colorScheme.primary,
            width: 2,
          ) : null,
        ),
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: state.isRecording ? _pulseAnimation.value : 1.0,
              child: Icon(
                _getIcon(state),
                color: _getIconColor(theme, state),
                size: widget.size * 0.5,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFullRecorder(ThemeData theme, VoiceInputState state) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Recording status and duration
        if (state.isRecording || state.isProcessing) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (state.isRecording) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (state.isProcessing) ...[
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  _getStatusText(state),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        
        // Audio level visualization
        if (state.isRecording) ...[
          _buildAudioLevelVisualizer(theme, state),
          const SizedBox(height: 16),
        ],
        
        // Main recording button
        GestureDetector(
          onTap: _handleTap,
          child: AnimatedBuilder(
            animation: _rippleAnimation,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Ripple effect
                  if (state.isRecording) ...[
                    Container(
                      width: widget.size * 2 * _rippleAnimation.value,
                      height: widget.size * 2 * _rippleAnimation.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.primary.withOpacity(
                          (1 - _rippleAnimation.value) * 0.3,
                        ),
                      ),
                    ),
                  ],
                  
                  // Main button
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: state.isRecording ? _pulseAnimation.value : 1.0,
                        child: Container(
                          width: widget.size,
                          height: widget.size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _getButtonColor(theme, state),
                            border: Border.all(
                              color: theme.colorScheme.primary,
                              width: state.isRecording ? 3 : 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary.withOpacity(0.3),
                                blurRadius: state.isRecording ? 10 : 5,
                                spreadRadius: state.isRecording ? 2 : 0,
                              ),
                            ],
                          ),
                          child: Icon(
                            _getIcon(state),
                            color: _getIconColor(theme, state),
                            size: widget.size * 0.5,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
        
        // Transcription preview
        if (state.transcription.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.dividerColor.withOpacity(0.2),
              ),
            ),
            child: Text(
              state.transcription,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        
        // Error display
        if (state.hasError) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  color: theme.colorScheme.error,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    state.error!.message,
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAudioLevelVisualizer(ThemeData theme, VoiceInputState state) {
    return SizedBox(
      height: 40,
      width: 200,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(20, (index) {
          final normalizedIndex = index / 19;
          final barHeight = _getBarHeight(normalizedIndex, state.audioLevel);
          
          return AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 3,
            height: barHeight,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(
                barHeight / 40 * 0.8 + 0.2,
              ),
              borderRadius: BorderRadius.circular(1.5),
            ),
          );
        }),
      ),
    );
  }

  double _getBarHeight(double normalizedIndex, double audioLevel) {
    // Create a wave pattern based on the audio level
    final wave = sin(normalizedIndex * pi * 2);
    final baseHeight = 4.0;
    final maxHeight = 40.0;
    
    // Apply audio level influence
    final levelInfluence = audioLevel * 0.8 + 0.2;
    final waveInfluence = (wave + 1) / 2; // Normalize to 0-1
    
    return baseHeight + (maxHeight - baseHeight) * levelInfluence * waveInfluence;
  }

  void _handleTap() {
    final state = ref.read(voiceInputProvider);
    final notifier = ref.read(voiceInputProvider.notifier);
    
    if (state.isRecording) {
      notifier.stopRecording();
      widget.onRecordingStop?.call();
    } else if (state.canStartRecording) {
      notifier.startRecording();
      widget.onRecordingStart?.call();
    } else if (!state.hasPermission) {
      notifier.requestPermission();
    }
  }

  void _handleStateChange(VoiceInputState? previous, VoiceInputState current) {
    // Handle transcription updates
    if (current.transcription.isNotEmpty && 
        current.transcription != previous?.transcription) {
      widget.onTranscription?.call(current.transcription);
    }
    
    // Handle recording completion
    if (current.status == VoiceInputStatus.completed &&
        previous?.status != VoiceInputStatus.completed &&
        current.savedFiles.isNotEmpty) {
      widget.onRecordingComplete?.call(current.savedFiles.last);
    }
  }

  void _updateAnimations(VoiceInputState state) {
    if (state.isRecording) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
      if (!_rippleController.isAnimating) {
        _rippleController.repeat();
      }
    } else {
      _pulseController.stop();
      _rippleController.stop();
      _pulseController.reset();
      _rippleController.reset();
    }
  }

  Color _getButtonColor(ThemeData theme, VoiceInputState state) {
    if (state.isRecording) {
      return theme.colorScheme.error.withOpacity(0.1);
    } else if (state.isProcessing) {
      return theme.colorScheme.primary.withOpacity(0.1);
    } else if (!state.canStartRecording) {
      return theme.colorScheme.onSurface.withOpacity(0.1);
    } else {
      return theme.colorScheme.primary.withOpacity(0.1);
    }
  }

  Color _getIconColor(ThemeData theme, VoiceInputState state) {
    if (state.isRecording) {
      return theme.colorScheme.error;
    } else if (state.isProcessing) {
      return theme.colorScheme.primary;
    } else if (!state.canStartRecording) {
      return theme.colorScheme.onSurface.withOpacity(0.5);
    } else {
      return theme.colorScheme.primary;
    }
  }

  IconData _getIcon(VoiceInputState state) {
    if (state.isRecording) {
      return Icons.stop;
    } else if (state.isProcessing) {
      return Icons.hourglass_empty;
    } else if (!state.hasPermission) {
      return Icons.mic_off;
    } else {
      return Icons.mic;
    }
  }

  String _getStatusText(VoiceInputState state) {
    if (state.isRecording) {
      final duration = state.recordingDuration;
      final minutes = duration.inMinutes;
      final seconds = duration.inSeconds % 60;
      return 'Recording ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else if (state.isProcessing) {
      return 'Processing...';
    }
    return '';
  }
}