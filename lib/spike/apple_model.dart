// SPIKE (#183): a Genkit model backed by Apple Foundation Models over a MethodChannel.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:genkit/genkit.dart';

const onDeviceChannel = MethodChannel('nomorex/on_device_llm');

Future<Map<String, Object?>> onDeviceStatus() async {
  try {
    final r = await onDeviceChannel.invokeMapMethod<String, Object?>('status');
    return r ?? {'state': 'noResponse'};
  } on MissingPluginException {
    return {'state': 'noBridge'};
  }
}

/// Last raw bridge result, so the harness can show token counts and schema gaps.
Map<String, Object?>? lastAppleResult;

Model defineAppleModel(Genkit ai) => ai.defineModel(
  name: 'apple/foundation',
  info: ModelInfo(
    label: 'Apple Foundation Models (on device)',
    supports: {
      'multiturn': false,
      'media': true,
      'systemRole': true,
      'tools': false,
      'constrained': 'all',
      'output': ['text', 'json'],
    },
  ),
  fn: (req, ctx) async {
    final system = StringBuffer();
    final prompt = StringBuffer();
    Uint8List? image;
    for (final m in req.messages) {
      for (final p in m.content) {
        if (p.isText) {
          (m.role == Role.system ? system : prompt).writeln(p.text);
        } else if (p.isMedia) {
          final url = p.media!.url;
          final comma = url.indexOf(',');
          if (image != null) throw GenkitException('Only one image', status: StatusCode.invalidArgument);
          image = base64Decode(url.substring(comma + 1));
        }
      }
    }
    final schema = req.output?.schema;
    // ML Kit only has compile-time (@Generable) structured output, so on Android the schema goes in the prompt.
    if (schema != null && defaultTargetPlatform == TargetPlatform.android) {
      prompt.writeln('\nRespond with only a JSON object matching this JSON schema, no code fences:\n${jsonEncode(schema)}');
    }
    final cfg = req.config ?? const {};
    final Map<String, Object?> r;
    try {
      r = (await onDeviceChannel.invokeMapMethod<String, Object?>('generate', {
        'system': system.isEmpty ? null : system.toString().trim(),
        'prompt': prompt.toString().trim(),
        'schema': schema == null ? null : jsonEncode(schema),
        'image': image,
        'temperature': (cfg['temperature'] as num?)?.toDouble(),
        'maxTokens': cfg['maxOutputTokens'] as int?,
      }))!;
    } on PlatformException catch (e) {
      throw GenkitException(
        '${e.code}: ${e.message}',
        status: e.code == 'tooLong' ? StatusCode.invalidArgument : StatusCode.unavailable,
      );
    }
    lastAppleResult = r;
    return ModelResponse(
      finishReason: FinishReason.stop,
      message: Message(role: Role.model, content: [TextPart(text: r['text'] as String? ?? '')]),
      usage: GenerationUsage(inputTokens: r['inputTokens'] as int?, outputTokens: r['outputTokens'] as int?),
    );
  },
);
