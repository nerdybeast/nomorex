class Profile {
  const Profile({required this.id, required this.unitPreference});

  final String id;
  final String unitPreference; // 'kg', 'lbs', or 'both'

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        unitPreference: json['unit_preference'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'unit_preference': unitPreference,
      };

  Profile copyWith({String? unitPreference}) => Profile(
        id: id,
        unitPreference: unitPreference ?? this.unitPreference,
      );
}
