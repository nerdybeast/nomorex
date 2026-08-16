import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/dark_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/owner_name.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/profile_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final tokens = Theme.of(context).extension<NomorexDarkTokens>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out'),
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
                  child: const Text('Log Out'),
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
    final colorScheme = Theme.of(context).colorScheme;
    final memberSince = user != null && user.createdAt.isNotEmpty
        ? formatDate(DateTime.parse(user.createdAt))
        : '—';

    return Scaffold(
      appBar: AppBar(
        title: const Text('PROFILE'),
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
                  Text('PROFILE INFORMATION', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _ProfileField(label: 'User ID', value: user?.id ?? '—', copyable: true),
                  const SizedBox(height: 16),
                  _ProfileField(label: 'Email', value: user?.email ?? '—'),
                  const SizedBox(height: 16),
                  _ProfileField(label: 'Member since', value: memberSince),
                  const SizedBox(height: 28),
                  Text('DISPLAY NAME', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  const _DisplayNameField(),
                  const SizedBox(height: 28),
                  Text('PREFERENCES', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Text(
                    'Weight unit',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'kg', label: Text('kg')),
                      ButtonSegment(value: 'lbs', label: Text('lbs')),
                      ButtonSegment(value: 'both', label: Text('Both')),
                    ],
                    selected: {unit},
                    onSelectionChanged: profileAsync.isLoading
                        ? null
                        : (selection) =>
                            ref.read(profileProvider.notifier).setUnitPreference(selection.first),
                  ),
                  if (profileAsync.hasError) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Failed to update preference: ${profileAsync.error}',
                      style: TextStyle(color: colorScheme.error),
                    ),
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
              : const Text('Save Display Name'),
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
