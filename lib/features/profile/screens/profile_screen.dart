import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/external_link.dart';
import '../../../core/utils/one_rep_max_formula.dart';
import '../../../core/utils/owner_name.dart';
import '../../admin/providers/current_roles_provider.dart';
import '../../ai/providers/ai_smoke_test_provider.dart';
import '../../ai/utils/genkit_call.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/profile_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final tokens = Theme.of(context).extension<NomorexTokens>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: tokens?.secondaryButtonStyle,
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Log out'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(authProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentAuthUserProvider);
    final profileAsync = ref.watch(profileProvider);
    final unit = ref.watch(unitPreferenceProvider);
    final formula = ref.watch(oneRepMaxFormulaProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final memberSince = user != null && user.createdAt.isNotEmpty
        ? formatDate(DateTime.parse(user.createdAt))
        : '—';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => _confirmSignOut(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('PROFILE INFORMATION', style: NomorexTokens.of(context).eyebrow),
                  const SizedBox(height: 12),
                  _ProfileField(label: 'User ID', value: user?.id ?? '—', copyable: true),
                  const SizedBox(height: 16),
                  _ProfileField(label: 'Email', value: user?.email ?? '—'),
                  const SizedBox(height: 16),
                  _ProfileField(label: 'Member since', value: memberSince),
                  const SizedBox(height: 28),
                  Text('DISPLAY NAME', style: NomorexTokens.of(context).eyebrow),
                  const SizedBox(height: 12),
                  const _DisplayNameField(),
                  const SizedBox(height: 28),
                  Text('PREFERENCES', style: NomorexTokens.of(context).eyebrow),
                  const SizedBox(height: 12),
                  Text(
                    'Weight unit',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'both', label: Text('Both')),
                      ButtonSegment(value: 'kg', label: Text('kg')),
                      ButtonSegment(value: 'lbs', label: Text('lbs')),
                    ],
                    selected: {unit},
                    onSelectionChanged: profileAsync.isLoading
                        ? null
                        : (selection) =>
                            ref.read(profileProvider.notifier).setUnitPreference(selection.first),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '1RM formula',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<OneRepMaxFormula>(
                    key: const Key('profile_1rm_formula'),
                    segments: const [
                      ButtonSegment(value: OneRepMaxFormula.brzycki, label: Text('Brzycki')),
                      ButtonSegment(value: OneRepMaxFormula.epley, label: Text('Epley')),
                      ButtonSegment(value: OneRepMaxFormula.lander, label: Text('Lander')),
                    ],
                    selected: {formula},
                    onSelectionChanged: profileAsync.isLoading
                        ? null
                        : (selection) =>
                            ref.read(profileProvider.notifier).setOneRepMaxFormula(selection.first),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Used to estimate your 1RM from multi-rep PRs. Brzycki is most '
                    'accurate at low reps; Epley holds up to 10.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  if (profileAsync.hasError) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Failed to update preference: ${profileAsync.error}',
                      style: TextStyle(color: colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 28),
                  if (isAdmin) ...[
                    Text('ADMIN', style: NomorexTokens.of(context).eyebrow),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      key: const Key('profile_admin_button'),
                      style: NomorexTokens.of(context).secondaryButtonStyle,
                      icon: const Icon(Icons.admin_panel_settings_outlined),
                      label: const Text('Admin'),
                      onPressed: () => context.push(AppConstants.routeAdmin),
                    ),
                    const SizedBox(height: 28),
                  ],
                  Text('ABOUT', style: NomorexTokens.of(context).eyebrow),
                  const SizedBox(height: 4),
                  const _PrivacyPolicyLink(),
                  // Debug builds only: a diagnostic for the Genkit edge
                  // function, not a user feature.
                  if (kDebugMode) ...[
                    const SizedBox(height: 24),
                    Text('DEVELOPER', style: NomorexTokens.of(context).eyebrow),
                    const SizedBox(height: 8),
                    const _AiSmokeTestSection(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the public privacy policy (web/privacy.html) in the browser. Apple
/// and Google both require it to be reachable from inside the app as well as
/// from the store listing.
class _PrivacyPolicyLink extends ConsumerWidget {
  const _PrivacyPolicyLink();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        key: const Key('profile_privacy_policy'),
        style: TextButton.styleFrom(padding: EdgeInsets.zero),
        icon: const Icon(Icons.open_in_new, size: 18),
        label: const Text('Privacy policy'),
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          final opened = await ref.read(externalLinkOpenerProvider)(
            Uri.parse(AppConstants.privacyPolicyUrl),
          );
          if (!opened) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text("Couldn't open the privacy policy. It's at ${AppConstants.privacyPolicyUrl}"),
              ),
            );
          }
        },
      ),
    );
  }
}

/// Debug-only "Test AI connection": runs the `smokeTest` Genkit flow, which
/// exercises the user's session, an RLS-scoped database read and a Claude
/// call. The button sits beside its description in a `Row` rather than in a
/// tile's `trailing`, so it stays its own semantics node (tappable by role
/// locators and screen readers).
class _AiSmokeTestSection extends ConsumerWidget {
  const _AiSmokeTestSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(aiSmokeTestProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Checks the AI backend: your session, database access and the Claude model.',
                style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              key: const Key('profile_ai_smoke_test_button'),
              // Theme buttons are full-width by default; size this one to its
              // label so it fits beside the description.
              style: NomorexTokens.of(context).secondaryButtonStyle.copyWith(
                minimumSize: const WidgetStatePropertyAll(Size(0, NomorexSizes.controlHeight)),
              ),
              onPressed: state.isLoading ? null : () => ref.read(aiSmokeTestProvider.notifier).run(),
              child: state.isLoading
                  ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Test AI connection'),
            ),
          ],
        ),
        switch (state) {
          AsyncData(:final value?) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${value.message}\n${value.exerciseCount} exercises visible to you.',
                key: const Key('profile_ai_smoke_test_result'),
              ),
            ),
          AsyncError(:final error) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                error is GenkitFlowException ? error.message : 'AI test failed: $error',
                key: const Key('profile_ai_smoke_test_error'),
                style: TextStyle(color: colorScheme.error),
              ),
            ),
          _ => const SizedBox.shrink(),
        },
      ],
    );
  }
}

/// Lets the user name themselves for the Community screen. Kept separate from
/// the unit toggle because it's a text field that has to be saved explicitly
/// rather than a selection that applies on tap.
class _DisplayNameField extends ConsumerStatefulWidget {
  const _DisplayNameField();

  @override
  ConsumerState<_DisplayNameField> createState() => _DisplayNameFieldState();
}

class _DisplayNameFieldState extends ConsumerState<_DisplayNameField> {
  final _controller = TextEditingController();
  bool _seeded = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(profileProvider.notifier).setDisplayName(_controller.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Display name saved.')),
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final profileAsync = ref.watch(profileProvider);

    // Seed the field once, on the first build where the profile has loaded, so
    // typing isn't clobbered by later rebuilds.
    if (!_seeded && profileAsync.hasValue) {
      _controller.text = profileAsync.value?.displayName ?? '';
      _seeded = true;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('profile_display_name'),
          controller: _controller,
          maxLength: 40,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: kAnonymousOwnerName,
            counterText: '',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Shown as the author on your public workouts and programs. '
          'Leave it blank to stay "$kAnonymousOwnerName".',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text('Failed to save: $_error', style: TextStyle(color: colorScheme.error)),
        ],
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('profile_display_name_save'),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save display name'),
        ),
      ],
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({required this.label, required this.value, this.copyable = false});

  final String label;
  final String value;
  final bool copyable;

  Future<void> _copyToClipboard(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('User ID copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: SelectableText(
                value,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (copyable)
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18),
                tooltip: 'Copy user ID',
                visualDensity: VisualDensity.compact,
                onPressed: () => _copyToClipboard(context),
              ),
          ],
        ),
      ],
    );
  }
}
