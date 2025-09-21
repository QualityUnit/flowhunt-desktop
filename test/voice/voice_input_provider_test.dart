import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:flowhunt_desktop/core/voice/voice_input_state.dart';
import 'package:flowhunt_desktop/core/voice/voice_recorder_service_simple.dart';
import 'package:flowhunt_desktop/providers/voice_input_provider.dart';

// Mock classes
class MockVoiceRecorderService extends Mock implements VoiceRecorderService {}

void main() {
  group('VoiceInputProvider', () {
    late MockVoiceRecorderService mockService;
    late ProviderContainer container;

    setUp(() {
      mockService = MockVoiceRecorderService();
      container = ProviderContainer(
        overrides: [
          voiceRecorderServiceProvider.overrideWithValue(mockService),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state should be idle with no permission', () {
      final state = container.read(voiceInputProvider);
      
      expect(state.status, VoiceInputStatus.idle);
      expect(state.hasPermission, false);
      expect(state.isInitialized, false);
      expect(state.transcription, '');
      expect(state.audioLevel, 0.0);
      expect(state.recordingDuration, Duration.zero);
      expect(state.savedFiles, isEmpty);
    });

    test('should initialize service on creation', () async {
      // Mock the service methods
      when(() => mockService.initialize()).thenAnswer((_) async {});
      when(() => mockService.hasPermission()).thenAnswer((_) async => false);
      when(() => mockService.getAvailableEngines()).thenReturn([SpeechEngine.osNative]);

      // Read the provider to trigger initialization
      container.read(voiceInputProvider);

      // Wait a bit for async initialization
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify service methods were called
      verify(() => mockService.initialize()).called(1);
      verify(() => mockService.hasPermission()).called(1);
      verify(() => mockService.getAvailableEngines()).called(1);
    });

    test('should request permission when requestPermission is called', () async {
      when(() => mockService.initialize()).thenAnswer((_) async {});
      when(() => mockService.hasPermission()).thenAnswer((_) async => false);
      when(() => mockService.getAvailableEngines()).thenReturn([SpeechEngine.osNative]);
      when(() => mockService.requestPermission()).thenAnswer((_) async => true);

      final notifier = container.read(voiceInputProvider.notifier);
      await notifier.requestPermission();

      verify(() => mockService.requestPermission()).called(1);
    });

    test('should start recording when permission is granted', () async {
      when(() => mockService.initialize()).thenAnswer((_) async {});
      when(() => mockService.hasPermission()).thenAnswer((_) async => true);
      when(() => mockService.getAvailableEngines()).thenReturn([SpeechEngine.osNative]);
      when(() => mockService.requestPermission()).thenAnswer((_) async => true);
      when(() => mockService.startRecording(engine: any(named: 'engine'), locale: any(named: 'locale')))
          .thenAnswer((_) async {});
      when(() => mockService.audioLevelStream).thenAnswer((_) => Stream.empty());
      when(() => mockService.transcriptionStream).thenAnswer((_) => Stream.empty());

      final notifier = container.read(voiceInputProvider.notifier);
      
      // Set permission first
      await notifier.requestPermission();
      
      // Start recording
      await notifier.startRecording();

      verify(() => mockService.startRecording(
        engine: SpeechEngine.osNative,
        locale: null,
      )).called(1);
    });

    test('should stop recording and return result', () async {
      when(() => mockService.initialize()).thenAnswer((_) async {});
      when(() => mockService.hasPermission()).thenAnswer((_) async => true);
      when(() => mockService.getAvailableEngines()).thenReturn([SpeechEngine.osNative]);
      when(() => mockService.stopRecording()).thenAnswer((_) async => RecordingFile(
        id: '1',
        audioPath: '',
        textPath: '/path/to/transcription.txt',
        filename: 'test_recording',
        createdAt: DateTime.now(),
        duration: const Duration(seconds: 5),
        transcription: 'Hello world',
        engine: SpeechEngine.osNative,
      ));

      final notifier = container.read(voiceInputProvider.notifier);
      await notifier.stopRecording();

      verify(() => mockService.stopRecording()).called(1);
    });

    test('should cancel recording', () async {
      when(() => mockService.initialize()).thenAnswer((_) async {});
      when(() => mockService.hasPermission()).thenAnswer((_) async => true);
      when(() => mockService.getAvailableEngines()).thenReturn([SpeechEngine.osNative]);
      when(() => mockService.cancelRecording()).thenAnswer((_) async {});

      final notifier = container.read(voiceInputProvider.notifier);
      await notifier.cancelRecording();

      verify(() => mockService.cancelRecording()).called(1);
    });

    test('convenience providers should return correct values', () {
      final container = ProviderContainer(
        overrides: [
          voiceInputProvider.overrideWith((ref) {
            return VoiceInputNotifier(mockService)
              ..state = const VoiceInputState(
                hasPermission: true,
                status: VoiceInputStatus.listening,
                transcription: 'Test transcription',
                audioLevel: 0.5,
                recordingDuration: Duration(seconds: 10),
              );
          }),
        ],
      );

      expect(container.read(hasVoicePermissionProvider), true);
      expect(container.read(isVoiceRecordingProvider), true);
      expect(container.read(voiceTranscriptionProvider), 'Test transcription');
      expect(container.read(voiceAudioLevelProvider), 0.5);
      expect(container.read(voiceRecordingDurationProvider), const Duration(seconds: 10));
      expect(container.read(canStartVoiceRecordingProvider), false); // Can't start when already recording

      container.dispose();
    });
  });
}