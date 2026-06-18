class PersonalBest {
  const PersonalBest({
    required this.id,
    required this.userId,
    required this.exerciseId,
    required this.exerciseName,
    required this.weightKg,
    required this.reps,
    required this.date,
    this.notes,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String exerciseId;
  final String exerciseName;
  final double weightKg;
  final int reps;
  final DateTime date;
  final String? notes;
  final DateTime updatedAt;

  factory PersonalBest.fromJson(Map<String, dynamic> json) {
    final exerciseMap = json['exercises'] as Map<String, dynamic>?;
    return PersonalBest(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      exerciseId: json['exercise_id'] as String,
      exerciseName: exerciseMap?['name'] as String? ?? '',
      weightKg: (json['weight_kg'] as num).toDouble(),
      reps: json['reps'] as int,
      date: DateTime.parse(json['date'] as String),
      notes: json['notes'] as String?,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
