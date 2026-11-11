import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher.dart';

part 'external_link.g.dart';

/// Opens a web page outside the app (the browser, or an in-app browser tab
/// where the platform prefers one). Returns false when nothing could open it.
///
/// A provider so widget tests can override it: url_launcher goes through a
/// platform channel that tests don't have.
@riverpod
Future<bool> Function(Uri) externalLinkOpener(Ref ref) => (uri) async {
      try {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        return false;
      }
    };
