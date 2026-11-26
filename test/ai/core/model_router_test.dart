import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/ai/core/ai_provider.dart';
import 'package:nomorex/features/ai/core/ai_task.dart';

void main() {
  const ready = OnDeviceStatus(OnDeviceAvailability.ready, modelName: 'apple/foundation');

  group('routeTask', () {
    for (final cloud in [null, ...CloudAiProvider.values]) {
      for (final onDevice in [
        OnDeviceStatus.unsupported,
        const OnDeviceStatus(OnDeviceAvailability.downloading),
        const OnDeviceStatus(OnDeviceAvailability.disabled),
        ready,
      ]) {
        final state = 'key: ${cloud?.id ?? 'none'}, on device: ${onDevice.availability.name}';

        test('import uses the cloud key only ($state)', () {
          final route = routeTask(AiTask.import, cloud: cloud, onDevice: onDevice);
          if (cloud == null) {
            expect(route, isNull);
          } else {
            expect(route!.provider, cloud.id);
            expect(route.cloud, cloud);
            expect(route.modelName, '${kCloudNamespaces[cloud]}/${kCloudModels[cloud]![ModelTier.standard]}');
          }
        });

        test('small tasks use the on-device model only ($state)', () {
          for (final task in [AiTask.suggestTitle, AiTask.suggestDescription, AiTask.suggestExercises]) {
            final route = routeTask(task, cloud: cloud, onDevice: onDevice);
            if (onDevice == ready) {
              expect(route, const AiRoute(provider: 'on_device', modelName: 'apple/foundation'));
              expect(route!.onDevice, isTrue);
            } else {
              expect(route, isNull, reason: 'a key alone never runs ${task.name}');
            }
          }
        });
      }
    }

    test('a ready status without a model name is not ready', () {
      expect(
        routeTask(AiTask.suggestTitle, onDevice: const OnDeviceStatus(OnDeviceAvailability.ready)),
        isNull,
      );
    });

    test('model names use each plugin namespace', () {
      expect(routeTask(AiTask.import, cloud: CloudAiProvider.anthropic)!.modelName, 'anthropic/claude-sonnet-5-5');
      expect(routeTask(AiTask.import, cloud: CloudAiProvider.openai)!.modelName, startsWith('openai/'));
      expect(routeTask(AiTask.import, cloud: CloudAiProvider.gemini)!.modelName, startsWith('googleai/'));
    });
  });

  test('provider ids match what ai_import_save_result accepts', () {
    expect(CloudAiProvider.values.map((p) => p.id), unorderedEquals(['anthropic', 'openai', 'gemini']));
    expect(AiRoute.onDeviceId, 'on_device');
    expect(CloudAiProvider.fromId('gemini'), CloudAiProvider.gemini);
    expect(CloudAiProvider.fromId('hosted'), isNull);
  });
}
