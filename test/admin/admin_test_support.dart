import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:nomorex/features/admin/models/app_roles.dart';
import 'package:nomorex/features/admin/providers/admin_ai_imports_provider.dart';
import 'package:nomorex/features/admin/providers/current_roles_provider.dart';
import 'package:nomorex/features/ai/models/ai_import_limits.dart';
import 'package:nomorex/features/ai/providers/ai_import_intake_provider.dart';

/// Overrides the signed-in user's roles.
Override rolesOverride(Set<String> roles) => currentUserRolesProvider.overrideWith((ref) async => roles);

const adminRoles = {AppRoles.admin};

/// The import limits, with [enabled] read from [FakeAiImportsServer] so a
/// re-read after a change sees the new value, as it would from the server.
List<Override> aiImportsOverrides(FakeAiImportsServer server) => [
      aiImportLimitsProvider.overrideWith((ref) async => AiImportLimits(
            maxImages: 8,
            maxPdfPages: 10,
            maxImageBytes: 7000000,
            maxPdfBytes: 20000000,
            enabled: server.enabled,
          )),
      adminAiImportsProvider.overrideWith(() => FakeAdminAiImportsNotifier(server)),
    ];

class FakeAiImportsServer {
  FakeAiImportsServer({this.enabled = true});

  bool enabled;
  final calls = <bool>[];

  /// Thrown by the next call instead of saving, when set.
  Object? error;
}

class FakeAdminAiImportsNotifier extends AdminAiImportsNotifier {
  FakeAdminAiImportsNotifier(this.server);

  final FakeAiImportsServer server;

  @override
  Future<void> callSetEnabled(bool enabled) async {
    server.calls.add(enabled);
    final error = server.error;
    if (error != null) throw error;
    server.enabled = enabled;
  }
}
