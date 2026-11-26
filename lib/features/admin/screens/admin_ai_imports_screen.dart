import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/toggle_card.dart';
import '../../ai/providers/ai_import_intake_provider.dart';
import '../providers/admin_ai_imports_provider.dart';
import '../utils/admin_error.dart';
import '../widgets/admin_gate.dart';

/// Turns the hosted AI imports (read on the project's account) on or off for
/// every user (`ai_import_limits.enabled`). Imports with a lifter's own key
/// don't depend on it.
class AdminAiImportsScreen extends ConsumerWidget {
  const AdminAiImportsScreen({super.key});

  Future<void> _change(BuildContext context, WidgetRef ref, bool enabled) async {
    if (!enabled) {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Turn off AI imports?',
        message: "Nobody will be able to start an import on NoMoreX's account. Lifters with their own AI key "
            'can still import, and everyone else is offered the AI assistant settings to add one. '
            'Imports already running still finish.',
        confirmLabel: 'Turn off',
      );
      if (!confirmed) return;
    }
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(adminAiImportsProvider.notifier).setEnabled(enabled);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(adminErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final limits = ref.watch(aiImportLimitsProvider);
    final saving = ref.watch(adminAiImportsProvider).isLoading;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('AI imports')),
      body: AdminGate(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: switch (limits) {
                  AsyncValue(:final value?) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ToggleCard(
                          key: const Key('admin_ai_imports_switch'),
                          title: 'AI imports',
                          subtitle: value.enabled
                              ? "On. Lifters without their own AI key import on NoMoreX's account."
                              : "Off. Nobody can start an import on NoMoreX's account.",
                          value: value.enabled,
                          onChanged: saving ? null : (enabled) => _change(context, ref, enabled),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Other devices pick up the change the next time the app opens or comes back '
                          'to the foreground. The daily and monthly caps still apply while imports are on.',
                          style: theme.textTheme.bodySmall?.copyWith(color: NomorexTokens.of(context).fg3),
                        ),
                      ],
                    ),
                  AsyncError() => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          "Couldn't load the AI import settings.",
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          style: NomorexTokens.of(context).secondaryButtonStyle,
                          onPressed: () => ref.invalidate(aiImportLimitsProvider),
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  _ => const Center(child: CircularProgressIndicator()),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
