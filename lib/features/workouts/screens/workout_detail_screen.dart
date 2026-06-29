import 'package:flutter/material.dart';
class WorkoutDetailScreen extends StatelessWidget {
  const WorkoutDetailScreen({super.key, required this.workoutId});
  final String workoutId;
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Workout detail')));
}
