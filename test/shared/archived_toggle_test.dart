import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nomorex/core/theme/app_theme.dart';
import 'package:nomorex/shared/widgets/archived_toggle.dart';

void main() {
  // Web and desktop default to compact density, which used to leave the search
  // field shorter than the Archived toggle beside it.
  for (final platform in [TargetPlatform.macOS, TargetPlatform.iOS]) {
    testWidgets('search field and Archived toggle are the same height on $platform', (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Row(
              children: [
                const Expanded(
                  child: TextField(
                    key: Key('search'),
                    decoration: InputDecoration(hintText: 'Search', prefixIcon: Icon(Icons.search), isDense: true),
                  ),
                ),
                ArchivedToggle(key: const Key('toggle'), selected: false, count: 0, onChanged: (_) {}),
              ],
            ),
          ),
        ),
      );
      final search = tester.getSize(find.byKey(const Key('search'))).height;
      final toggle = tester.getSize(find.byKey(const Key('toggle'))).height;
      expect(search, toggle);
    });
  }
}
