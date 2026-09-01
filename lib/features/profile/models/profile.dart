import '../../../core/utils/one_rep_max_formula.dart';

class Profile {
  const Profile({
    required this.id,
    required this.unitPreference,
    required this.oneRepMaxFormula,
    this.displayName,
  });

  final String id;
  final String unitPreference; // 'kg', 'lbs', or 'both'

  /// The name shown as the author on anything this user publishes. Null until
  /// the user sets one — render [ownerDisplayName] rather than this directly.
  final String? displayName;

  /// Which formula estimates this user's 1RM from their multi-rep PRs.
  final OneRepMaxFormula oneRepMaxFormula;

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        unitPreference: json['unit_preference'] as String,
        displayName: json['display_name'] as String?,
        oneRepMaxFormula:
            oneRepMaxFormulaFromDb(json['one_rep_max_formula'] as String?),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'unit_preference': unitPreference,
        'display_name': displayName,
        'one_rep_max_formula': oneRepMaxFormulaToDb(oneRepMaxFormula),
      };

  Profile copyWith({
    String? unitPreference,
    String? displayName,
    OneRepMaxFormula? oneRepMaxFormula,
  }) =>
      Profile(
        id: id,
        unitPreference: unitPreference ?? this.unitPreference,
        displayName: displayName ?? this.displayName,
        oneRepMaxFormula: oneRepMaxFormula ?? this.oneRepMaxFormula,
      );
}
