import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/external_link.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/list_group.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../shell/widgets/breadcrumb_title.dart';
import '../core/ai_provider.dart';
import '../core/ai_settings_provider.dart';
import '../core/ai_task.dart';
import '../core/model_router_provider.dart';
import '../providers/ai_key_check_provider.dart';
import '../utils/ai_provider_info.dart';

/// Profile → AI assistant (#186): what runs on this device, and which cloud
/// provider reads imports with the lifter's own key.
class AiAssistantScreen extends ConsumerWidget {
  const AiAssistantScreen({super.key});

  static const maxWidth = 640.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = NomorexTokens.of(context);
    final settings = ref.watch(aiSettingsProvider);
    // Null until this build can ask the device (Stages 7 and 8).
    final checksOnDevice = ref.watch(onDeviceAvailabilityProvider) != null;
    return Scaffold(
      appBar: AppBar(title: const BreadcrumbTitle(title: 'AI assistant')),
      body: SafeArea(
        child: ListView(
          key: const Key('ai_assistant_list'),
          padding: contentPadding(context, top: 20, bottom: 40, maxWidth: maxWidth),
          children: [
            Text(
              'Choose who helps with names, descriptions, exercise suggestions and imports.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: tokens.palette.fg2),
            ),
            const SizedBox(height: 24),
            if (checksOnDevice) ...[const _OnDeviceGroup(), const SizedBox(height: 24)],
            switch (settings) {
              AsyncData(:final value) => _ImportsGroup(settings: value),
              AsyncError() => const _KeyStorageUnavailable(),
              _ => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
            },
            const SizedBox(height: 24),
            _SharingGroup(provider: settings.value?.provider, showsOnDevice: checksOnDevice),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// On this device
// ---------------------------------------------------------------------------

class _OnDeviceGroup extends ConsumerWidget {
  const _OnDeviceGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(onDeviceAvailabilityProvider) ?? OnDeviceStatus.unsupported;
    final label = onDeviceModelLabel();
    final tokens = NomorexTokens.of(context);
    final where = kIsWeb ? ' in this browser' : '';

    final (IconData icon, String title, String body, Widget? trailing, Widget? below) = switch (status.availability) {
      _ when label == null => (
        Icons.phonelink_erase_outlined,
        'No on-device model here',
        "This device can't run one, so suggestions stay hidden. Imports still work with your own key.",
        null,
        null,
      ),
      OnDeviceAvailability.ready => (
        _deviceIcon,
        label,
        'Suggests names, descriptions and exercises$where. Free and private, and it works offline.',
        const _Pill(icon: Icons.check, label: 'Ready'),
        null,
      ),
      OnDeviceAvailability.downloading => (
        _deviceIcon,
        label,
        "Your device is downloading its on-device model. Suggestions appear when it's done.",
        null,
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: LinearProgressIndicator(
            key: const Key('ai_on_device_progress'),
            value: status.downloadProgress,
            semanticsLabel: 'Model download',
          ),
        ),
      ),
      OnDeviceAvailability.disabled => (
        _deviceIcon,
        '$label is off',
        'Turn it on in Settings to get suggested names, descriptions and exercises.',
        null,
        null,
      ),
      OnDeviceAvailability.unsupported => (
        Icons.phonelink_erase_outlined,
        'No on-device model here',
        "This device can't run one, so suggestions stay hidden. Imports still work with your own key.",
        null,
        null,
      ),
    };

    return ListGroup(
      header: const ListGroupHeader(title: 'On this device'),
      children: [
        Padding(
          key: const Key('ai_on_device_status'),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconTile(icon: icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(body, style: tokens.bodySmall),
                    ?below,
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing],
            ],
          ),
        ),
      ],
    );
  }

  static IconData get _deviceIcon => kIsWeb ? Icons.computer_outlined : Icons.smartphone_outlined;
}

// ---------------------------------------------------------------------------
// Imports
// ---------------------------------------------------------------------------

class _KeyStorageUnavailable extends StatelessWidget {
  const _KeyStorageUnavailable();

  @override
  Widget build(BuildContext context) {
    return ListGroup(
      header: const ListGroupHeader(title: 'Imports'),
      children: [
        Padding(
          key: const Key('ai_key_storage_unavailable'),
          padding: const EdgeInsets.all(16),
          child: Text(
            "This device can't save API keys, so imports with your own key aren't available here. "
            'On Linux, this needs a keyring such as GNOME Keyring, unlocked.',
            style: NomorexTokens.of(context).bodySmall,
          ),
        ),
      ],
    );
  }
}

class _ImportsGroup extends ConsumerWidget {
  const _ImportsGroup({required this.settings});

  final AiSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!settings.keyStorageAvailable) return const _KeyStorageUnavailable();
    final tokens = NomorexTokens.of(context);
    final selected = settings.provider;
    return ListGroup(
      header: ListGroupHeader(
        title: 'Imports',
        trailing: Text('Read with your own key', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.fg3)),
      ),
      children: [
        RadioGroup<CloudAiProvider>(
          groupValue: selected,
          onChanged: (p) {
            if (p != null) ref.read(aiSettingsProvider.notifier).selectProvider(p);
          },
          child: Column(
            children: [
              for (final p in CloudAiProvider.values) ...[
                if (p != CloudAiProvider.values.first) const Divider(),
                RadioListTile<CloudAiProvider>(
                  key: Key('ai_provider_${p.id}'),
                  value: p,
                  title: Text(p.label),
                  subtitle: Text(p.summary),
                  secondary: settings.savedKeys.contains(p)
                      ? const _Pill(icon: Icons.key_outlined, label: 'Key saved')
                      : null,
                ),
              ],
            ],
          ),
        ),
        if (selected != null)
          _KeyPanel(key: ValueKey(selected), provider: selected, saved: settings.savedKeys.contains(selected)),
      ],
    );
  }
}

class _KeyPanel extends ConsumerStatefulWidget {
  const _KeyPanel({super.key, required this.provider, required this.saved});

  final CloudAiProvider provider;
  final bool saved;

  @override
  ConsumerState<_KeyPanel> createState() => _KeyPanelState();
}

class _KeyPanelState extends ConsumerState<_KeyPanel> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  CloudAiProvider get _provider => widget.provider;

  Future<void> _remove() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove ${_provider.label} key?',
      message: "It's deleted from this device. Imports with ${_provider.label} stop until you add a key again.",
      confirmLabel: 'Remove key',
    );
    if (confirmed) {
      _controller.clear();
      await ref.read(aiKeyCheckProvider.notifier).remove(_provider);
    }
  }

  Future<void> _openGetKey() async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await ref.read(externalLinkOpenerProvider)(_provider.getKeyUrl);
    if (!opened) {
      messenger.showSnackBar(SnackBar(content: Text("Couldn't open the link. It's at ${_provider.getKeyUrl}")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    final check = ref.watch(aiKeyCheckProvider)[_provider];
    final running = check is KeyCheckRunning;
    final textTheme = Theme.of(context).textTheme;

    final getKey = TextButton.icon(
      key: const Key('ai_get_key'),
      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
      onPressed: _openGetKey,
      iconAlignment: IconAlignment.end,
      icon: const Icon(Icons.open_in_new, size: 16),
      label: Text(_provider.getKeyLabel, overflow: TextOverflow.ellipsis),
    );

    final field = widget.saved
        ? _SavedKeyField(provider: _provider)
        : TextField(
            key: const Key('ai_key_field'),
            controller: _controller,
            enabled: !running,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.visiblePassword,
            style: tokens.weight,
            // Keys are long, and a stray space from a paste breaks them.
            inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
            decoration: InputDecoration(hintText: _provider.keyHint),
            onSubmitted: (_) => ref.read(aiKeyCheckProvider.notifier).saveAndTest(_provider, _controller.text),
          );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text('${_provider.label} API key', style: textTheme.labelLarge),
          ),
          const SizedBox(height: 6),
          field,
          const SizedBox(height: 6),
          Text(
            kIsWeb
                ? 'Saved in this browser only. NoMoreX never sees it.'
                : 'Saved on this device only. NoMoreX never sees it.',
            style: textTheme.bodySmall?.copyWith(color: tokens.fg3),
          ),
          const SizedBox(height: 12),
          if (widget.saved)
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton(
                  key: const Key('ai_test_key'),
                  style: tokens.secondaryButtonStyle,
                  onPressed: running ? null : () => ref.read(aiKeyCheckProvider.notifier).test(_provider),
                  child: const Text('Test key'),
                ),
                TextButton(
                  key: const Key('ai_remove_key'),
                  style: TextButton.styleFrom(foregroundColor: tokens.palette.dangerText),
                  onPressed: running ? null : _remove,
                  child: const Text('Remove key'),
                ),
              ],
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                key: const Key('ai_save_key'),
                onPressed: running
                    ? null
                    : () => ref.read(aiKeyCheckProvider.notifier).saveAndTest(_provider, _controller.text),
                child: const Text('Save and test key'),
              ),
            ),
          if (check != null) ...[const SizedBox(height: 10), _CheckResult(check: check)],
          const SizedBox(height: 4),
          Align(alignment: Alignment.centerLeft, child: getKey),
          if (_provider == CloudAiProvider.gemini) ...[
            const SizedBox(height: 8),
            const _GeminiFreeTierNote(),
          ],
        ],
      ),
    );
  }
}

class _SavedKeyField extends ConsumerWidget {
  const _SavedKeyField({required this.provider});

  final CloudAiProvider provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = NomorexTokens.of(context);
    final masked = ref.watch(maskedAiKeyProvider(provider)).value ?? '••••••••••••';
    return InputDecorator(
      key: const Key('ai_saved_key'),
      decoration: const InputDecoration(enabled: false),
      child: Text(masked, style: tokens.weight.copyWith(color: tokens.palette.fg2), semanticsLabel: 'Saved key'),
    );
  }
}

class _CheckResult extends StatelessWidget {
  const _CheckResult({required this.check});

  final KeyCheck check;

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    final (Widget icon, String text, Color color) = switch (check) {
      KeyCheckRunning() => (
        const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        'Checking the key…',
        tokens.palette.fg2,
      ),
      KeyCheckPassed() => (Icon(Icons.check, size: 16, color: tokens.palette.fg1), 'Key works', tokens.palette.fg1),
      KeyCheckFailed(:final message) => (
        Icon(Icons.error_outline, size: 16, color: tokens.palette.dangerText),
        message,
        tokens.palette.dangerText,
      ),
    };
    return Semantics(
      liveRegion: true,
      child: Row(
        key: const Key('ai_key_check_result'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: icon),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: tokens.bodySmall.copyWith(color: color))),
        ],
      ),
    );
  }
}

class _GeminiFreeTierNote extends StatelessWidget {
  const _GeminiFreeTierNote();

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    return Container(
      key: const Key('ai_gemini_note'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.palette.bg0,
        border: Border.all(color: tokens.palette.borderSubtle),
        borderRadius: BorderRadius.circular(NomorexSizes.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: tokens.fg3),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "On Gemini's free tier, Google may use what you send to improve its products. "
              'Use a paid key if your programs are private.',
              style: tokens.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// What gets shared
// ---------------------------------------------------------------------------

class _SharingGroup extends StatelessWidget {
  const _SharingGroup({required this.provider, required this.showsOnDevice});

  final CloudAiProvider? provider;
  final bool showsOnDevice;

  @override
  Widget build(BuildContext context) {
    final p = provider;
    // What the import prompt sends: the files, and the exercise names it
    // matches against (the lifter's catalog).
    final importBody = p == null
        ? 'The photos or PDFs you pick and the names in your exercise list go straight from this device to '
              'the provider you choose. Never your PRs, logged sets, name or email.'
        : 'The photos or PDFs you pick and the names in your exercise list go straight from this device to '
              '${p.company}. Never your PRs, logged sets, name or email.';
    return ListGroup(
      header: const ListGroupHeader(title: 'What gets shared'),
      children: [
        if (showsOnDevice)
          const _ShareRow(
            icon: Icons.smartphone_outlined,
            title: 'Suggestions on this device',
            body: 'Nothing leaves your device.',
          ),
        _ShareRow(
          key: const Key('ai_sharing_imports'),
          icon: Icons.cloud_outlined,
          title: p == null ? 'Imports with your own key' : 'Imports with ${p.label}',
          body: importBody,
        ),
      ],
    );
  }
}

class _ShareRow extends StatelessWidget {
  const _ShareRow({super.key, required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: MergeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _IconTile(icon: icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(body, style: NomorexTokens.of(context).bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pieces
// ---------------------------------------------------------------------------

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = NomorexTokens.of(context).palette;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: palette.bg2,
        border: Border.all(color: palette.borderSubtle),
        borderRadius: BorderRadius.circular(NomorexSizes.radiusMd),
      ),
      child: Icon(icon, size: 18, color: palette.fg2),
    );
  }
}

/// A small outlined status marker ("Ready", "Key saved"). Not a button.
class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: tokens.palette.borderDefault),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: tokens.palette.fg2),
          const SizedBox(width: 4),
          Text(label, style: tokens.bodySmall.copyWith(fontSize: 12, height: 1)),
        ],
      ),
    );
  }
}
