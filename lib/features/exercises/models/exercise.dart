class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.isPredefined,
    this.userId,
  });

  final String id;
  final String name;
  final bool isPredefined;
  final String? userId;

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
        id: json['id'] as String,
        name: json['name'] as String,
        isPredefined: json['is_predefined'] as bool,
        userId: json['user_id'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Exercise && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => name;
}
