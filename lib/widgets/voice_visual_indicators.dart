import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/voice/models/vad_state.dart';
import '../core/voice/models/speaker_profile.dart';
import '../providers/advanced_voice_provider.dart';

/// Visual indicators for voice features including VAD states and speaker identification
class VoiceVisualIndicators extends ConsumerWidget {
  const VoiceVisualIndicators({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voiceState = ref.watch(advancedVoiceInputProvider);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // VAD Status Indicator
          _VadStatusIndicator(vadState: voiceState.vadState),
          
          const SizedBox(height: 8),
          
          // Audio Level Indicator
          _AudioLevelIndicator(
            level: voiceState.audioLevel,
            vadResult: voiceState.vadResult,
          ),
          
          const SizedBox(height: 8),
          
          // Speaker Identification Indicator
          if (voiceState.voiceSettings.speakerSettings.enabled)
            _SpeakerIndicator(
              speaker: voiceState.currentSpeaker,
              confidence: voiceState.speakerConfidence,
            ),
          
          const SizedBox(height: 8),
          
          // Language Indicator
          _LanguageIndicator(
            currentLanguage: voiceState.currentLanguage,
            languageDetection: voiceState.languageDetection,
          ),
          
          const SizedBox(height: 8),
          
          // Recent Commands Indicator
          if (voiceState.commandProcessingEnabled && voiceState.recentCommands.isNotEmpty)
            _RecentCommandsIndicator(commands: voiceState.recentCommands),
        ],
      ),
    );
  }
}

/// VAD (Voice Activity Detection) status indicator
class _VadStatusIndicator extends StatelessWidget {
  final VadState vadState;
  
  const _VadStatusIndicator({required this.vadState});

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = _getVadIndicatorData(vadState);
    
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
  
  (Color, IconData, String) _getVadIndicatorData(VadState state) {
    switch (state) {
      case VadState.idle:
        return (Colors.grey, Icons.mic_off, 'Idle');
      case VadState.listening:
        return (Colors.blue, Icons.hearing, 'Listening');
      case VadState.voiceDetected:
        return (Colors.orange, Icons.record_voice_over, 'Voice Detected');
      case VadState.recording:
        return (Colors.red, Icons.fiber_manual_record, 'Recording');
      case VadState.processing:
        return (Colors.purple, Icons.settings_voice, 'Processing');
      case VadState.waitingForSilence:
        return (Colors.amber, Icons.pause, 'Waiting for Silence');
      case VadState.error:
        return (Colors.red, Icons.error, 'Error');
    }
  }
}

/// Audio level visualization with VAD information
class _AudioLevelIndicator extends StatelessWidget {
  final double level;
  final VadResult? vadResult;
  
  const _AudioLevelIndicator({required this.level, this.vadResult});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Audio Level',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        Stack(
          children: [
            // Background bar
            Container(
              width: double.infinity,
              height: 8,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            // Audio level bar
            FractionallySizedBox(
              widthFactor: level,
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: _getAudioLevelColor(level),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            // Voice threshold indicator
            if (vadResult != null)
              Positioned(
                left: MediaQuery.of(context).size.width * 0.3, // Assuming 30% threshold
                child: Container(
                  width: 2,
                  height: 8,
                  color: Colors.yellow,
                ),
              ),
          ],
        ),
        if (vadResult != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                'Voice: ${vadResult!.isVoiceActive ? "Active" : "Inactive"}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: vadResult!.isVoiceActive ? Colors.green : Colors.grey,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Confidence: ${(vadResult!.confidence * 100).toInt()}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ],
    );
  }
  
  Color _getAudioLevelColor(double level) {
    if (level < 0.3) return Colors.green;
    if (level < 0.7) return Colors.orange;
    return Colors.red;
  }
}

/// Speaker identification indicator
class _SpeakerIndicator extends StatelessWidget {
  final SpeakerProfile? speaker;
  final double confidence;
  
  const _SpeakerIndicator({this.speaker, required this.confidence});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.person,
          size: 16,
          color: speaker != null ? Color(speaker!.colorCode) : Colors.grey,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                speaker?.name ?? 'Unknown Speaker',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: speaker != null ? Color(speaker!.colorCode) : Colors.grey,
                ),
              ),
              if (speaker != null)
                Text(
                  'Confidence: ${(confidence * 100).toInt()}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                ),
            ],
          ),
        ),
        if (speaker != null)
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Color(speaker!.colorCode),
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }
}

/// Language detection and current language indicator
class _LanguageIndicator extends StatelessWidget {
  final String currentLanguage;
  final dynamic languageDetection; // LanguageDetectionResult?
  
  const _LanguageIndicator({
    required this.currentLanguage,
    this.languageDetection,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.language,
          size: 16,
          color: Colors.blue,
        ),
        const SizedBox(width: 8),
        Text(
          _getLanguageDisplayName(currentLanguage),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        if (languageDetection != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              'Auto',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 10,
                color: Colors.green,
              ),
            ),
          ),
        ],
      ],
    );
  }
  
  String _getLanguageDisplayName(String code) {
    switch (code) {
      case 'en': return 'English';
      case 'es': return 'Español';
      case 'fr': return 'Français';
      case 'de': return 'Deutsch';
      case 'zh': return '中文';
      case 'ja': return '日本語';
      default: return code.toUpperCase();
    }
  }
}

/// Recent voice commands indicator
class _RecentCommandsIndicator extends StatelessWidget {
  final List<dynamic> commands; // List<VoiceCommandMatch>
  
  const _RecentCommandsIndicator({required this.commands});

  @override
  Widget build(BuildContext context) {
    final recentCommand = commands.last;
    
    return Row(
      children: [
        Icon(
          Icons.keyboard_voice,
          size: 16,
          color: Colors.green,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Last Command: ${_getCommandDisplayName(recentCommand.command.type.toString())}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Confidence: ${(recentCommand.confidence * 100).toInt()}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            commands.length.toString(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 10,
              color: Colors.green,
            ),
          ),
        ),
      ],
    );
  }
  
  String _getCommandDisplayName(String commandType) {
    final type = commandType.split('.').last;
    return type.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => ' ${match.group(0)}',
    ).trim();
  }
}

/// Compact voice status indicator for minimal UI
class CompactVoiceIndicator extends ConsumerWidget {
  const CompactVoiceIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voiceState = ref.watch(advancedVoiceInputProvider);
    
    if (!voiceState.isInitialized) {
      return const SizedBox.shrink();
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // VAD State
        _buildStatusDot(context, voiceState.vadState),
        
        const SizedBox(width: 4),
        
        // Speaker indicator
        if (voiceState.currentSpeaker != null) ...[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Color(voiceState.currentSpeaker!.colorCode),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
        ],
        
        // Language indicator
        Text(
          voiceState.currentLanguage.toUpperCase(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  Widget _buildStatusDot(BuildContext context, VadState state) {
    final color = switch (state) {
      VadState.idle => Colors.grey,
      VadState.listening => Colors.blue,
      VadState.voiceDetected => Colors.orange,
      VadState.recording => Colors.red,
      VadState.processing => Colors.purple,
      VadState.waitingForSilence => Colors.amber,
      VadState.error => Colors.red,
    };
    
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Voice feature status summary widget
class VoiceFeatureStatus extends ConsumerWidget {
  const VoiceFeatureStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voiceState = ref.watch(advancedVoiceInputProvider);
    final settings = voiceState.voiceSettings;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Voice Features Status',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            _FeatureStatusRow(
              label: 'Voice Input',
              enabled: settings.voiceInputEnabled,
              status: voiceState.isInitialized ? 'Ready' : 'Initializing',
            ),
            
            _FeatureStatusRow(
              label: 'Voice Commands',
              enabled: settings.commandSettings.enabled,
              status: voiceState.recentCommands.isNotEmpty 
                  ? '${voiceState.recentCommands.length} recent' 
                  : 'No commands',
            ),
            
            _FeatureStatusRow(
              label: 'Speaker ID',
              enabled: settings.speakerSettings.enabled,
              status: voiceState.currentSpeaker?.name ?? 'No speaker',
            ),
            
            _FeatureStatusRow(
              label: 'Language Detection',
              enabled: settings.languagePreferences.autoDetectionEnabled,
              status: voiceState.currentLanguage.toUpperCase(),
            ),
            
            _FeatureStatusRow(
              label: 'Voice Activity Detection',
              enabled: settings.vadConfiguration.enabled,
              status: voiceState.vadState.toString().split('.').last,
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureStatusRow extends StatelessWidget {
  final String label;
  final bool enabled;
  final String status;
  
  const _FeatureStatusRow({
    required this.label,
    required this.enabled,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: enabled ? Colors.green : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              status,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: enabled ? null : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}