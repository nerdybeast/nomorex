import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/list_group.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../models/admin_user.dart';
import '../providers/admin_users_provider.dart';
import '../widgets/admin_gate.dart';
import '../widgets/admin_page_controls.dart';
import '../widgets/admin_user_details.dart';

/// Every user, searchable and paginated: a table on wide screens, a list on a
/// phone. Tapping a user opens their details and roles.
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  static const _debounce = Duration(milliseconds: 300);

  String _search = '';
  int _page = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String text) {
    _timer?.cancel();
    _timer = Timer(_debounce, () {
      if (!mounted) return;
      final search = text.trim();
      if (search == _search) return;
      setState(() {
        _search = search;
        _page = 0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Users')),
      body: AdminGate(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      key: const Key('admin_users_search'),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search by email or name',
                      ),
                      onChanged: _onSearchChanged,
                    ),
                    const SizedBox(height: 16),
                    _UsersResults(search: _search, page: _page, onPage: (page) => setState(() => _page = page)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UsersResults extends ConsumerWidget {
  const _UsersResults({required this.search, required this.page, required this.onPage});

  final String search;
  final int page;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = adminUsersProvider(search: search, page: page);
    final result = ref.watch(provider);
    final theme = Theme.of(context);

    return switch (result) {
      AsyncValue(:final value?) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (value.items.isEmpty && value.page == 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  search.isEmpty ? 'No users yet.' : 'No users match "$search".',
                  key: const Key('admin_users_empty'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: NomorexTokens.of(context).fg2),
                ),
              )
            else if (isMobile(context))
              _UserList(users: value.items)
            else
              _UserTable(users: value.items),
            const SizedBox(height: 8),
            AdminPageControls(page: value, onPage: onPage),
          ],
        ),
      AsyncError() => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Couldn't load users.", style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: 12),
            FilledButton(
              style: NomorexTokens.of(context).secondaryButtonStyle,
              onPressed: () => ref.invalidate(provider),
              child: const Text('Try again'),
            ),
          ],
        ),
      _ => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
    };
  }
}

String _roleLabel(AdminUser user) => user.roles.isEmpty ? '—' : user.roles.join(', ');

String _lastSignIn(AdminUser user) =>
    user.lastSignInAt == null ? 'Never' : formatDate(user.lastSignInAt!.toLocal());

class _UserTable extends StatelessWidget {
  const _UserTable({required this.users});

  final List<AdminUser> users;

  @override
  Widget build(BuildContext context) {
    final palette = NomorexTokens.of(context).palette;
    return Material(
      color: palette.bg1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NomorexSizes.radiusLg),
        side: BorderSide(color: palette.borderSubtle),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              key: const Key('admin_users_table'),
              showCheckboxColumn: false,
              columns: const [
                DataColumn(label: Text('Email')),
                DataColumn(label: Text('Name')),
                DataColumn(label: Text('Roles')),
                DataColumn(label: Text('Joined')),
                DataColumn(label: Text('Last sign-in')),
              ],
              rows: [
                for (final user in users)
                  DataRow(
                    key: ValueKey('admin_user_${user.id}'),
                    onSelectChanged: (_) => showAdminUserDetails(context, user),
                    cells: [
                      DataCell(Text(user.email)),
                      DataCell(Text(user.displayName ?? '—')),
                      DataCell(Text(_roleLabel(user))),
                      DataCell(Text(formatDate(user.createdAt.toLocal()))),
                      DataCell(Text(_lastSignIn(user))),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserList extends StatelessWidget {
  const _UserList({required this.users});

  final List<AdminUser> users;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg3 = NomorexTokens.of(context).fg3;
    return ListGroup(
      key: const Key('admin_users_list'),
      children: [
        for (final user in users)
          Semantics(
            button: true,
            child: GroupableTile(
              key: ValueKey('admin_user_${user.id}'),
              onTap: () => showAdminUserDetails(context, user),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.email, style: theme.textTheme.titleSmall),
                  if (user.displayName != null) Text(user.displayName!, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (user.roles.isNotEmpty) _roleLabel(user),
                      'Joined ${formatDate(user.createdAt.toLocal())}',
                      'Last sign-in ${_lastSignIn(user)}',
                    ].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(color: fg3),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
