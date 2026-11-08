/// Output of the `smokeTest` Genkit flow (`supabase/functions/ai/flows/smoke_test.ts`).
///
/// [exerciseCount] is counted through the caller's RLS-scoped client, so it
/// matching the exercises the user can see proves their session reached
/// Postgres; [message] coming back at all proves the model call works.
class SmokeTestResult {
  const SmokeTestResult({required this.uid, required this.exerciseCount, required this.message});

  final String uid;
  final int exerciseCount;
  final String message;

  factory SmokeTestResult.fromJson(Map<String, dynamic> json) => SmokeTestResult(
        uid: json['uid'] as String,
        exerciseCount: (json['exerciseCount'] as num).toInt(),
        message: json['message'] as String,
      );
}
