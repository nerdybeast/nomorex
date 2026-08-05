/// One user's "run" of a program, created when they hit Start. Owns the
/// batch of materialized workouts (`workouts.program_instance_id`).
class ProgramInstance {
  const ProgramInstance({
    required this.id,
    required this.programId,
    required this.userId,
    required this.startedAt,
    required this.status,
    this.programName,
  });

  final String id;
  final String programId;
  final String? programName;
  final String userId;
  final DateTime startedAt;
  final String status; // 'active' | 'completed' | 'abandoned'

  factory ProgramInstance.fromJson(Map<String, dynamic> json) {
    final programMap = json['programs'] as Map<String, dynamic>?;
    return ProgramInstance(
      id: json['id'] as String,
      programId: json['program_id'] as String,
      programName: programMap?['name'] as String?,
      userId: json['user_id'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      status: json['status'] as String,
    );
  }
}
