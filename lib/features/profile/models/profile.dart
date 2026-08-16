class Profile {
  const Profile({required this.id, required this.unitPreference, this.displayName});

  final String id;
  final String unitPreference; // 'kg', 'lbs', or 'both'

  /// The name shown as the author on anything this user publishes. Null until
  /// the user sets one — render [ownerDisplayName] rather than this directly.
  final String? displayName;

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        unitPreference: json['unit_preference'] as String,
        displayName: json['display_name'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'unit_preference': unitPreference,
        'display_name': displayName,
      };

  Profile copyWith({String? unitPreference, String? displayName}) => Profile(
        id: id,
        unitPreference: unitPreference ?? this.unitPreference,
        displayName: displayName ?? this.displayName,
      );
}
