import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/date_formatter.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/profile_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

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
      appBar: AppBar(title: const Text('PROFILE')),
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
                  _InfoRow(label: 'User ID', value: user?.id ?? '—'),
                  const SizedBox(height: 8),
                  _InfoRow(label: 'Email', value: user?.email ?? '—'),
                  const SizedBox(height: 8),
                  _InfoRow(label: 'Member since', value: memberSince),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(label, style: TextStyle(color: colorScheme.onSurfaceVariant)),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
