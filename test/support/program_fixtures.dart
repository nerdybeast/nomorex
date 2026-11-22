import 'package:nomorex/features/programs/models/program_exercise.dart';
import 'package:nomorex/features/programs/models/program_session.dart';

/// A day's one session holding [exercises], for building a `ProgramDay` the
/// way most days are: `ProgramDay(..., sessions: soloSession('d1', [...]))`.
/// Its id is `'<dayId>-s1'`.
List<ProgramSession> soloSession(String dayId, List<ProgramExercise> exercises) =>
    [ProgramSession(id: '$dayId-s1', programDayId: dayId, position: 0, exercises: exercises)];
