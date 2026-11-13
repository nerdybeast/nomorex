import 'package:flutter/material.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../program_edit_screen.dart';
import 'program_edit_overview_screen.dart';

/// `/programs/:id/edit`: on a phone, the overview of the drill-down editor
/// (program, then week, then day); wider, the one-page [ProgramEditScreen].
/// Decided on every build, so resizing a window switches between them.
class ProgramEditEntry extends StatelessWidget {
  const ProgramEditEntry({super.key, required this.programId});

  final String programId;

  @override
  Widget build(BuildContext context) => isMobile(context)
      ? ProgramEditOverviewScreen(programId: programId)
      : ProgramEditScreen(programId: programId);
}
