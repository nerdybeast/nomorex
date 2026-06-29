import 'package:flutter/material.dart';
class EditWorkoutScreen extends StatelessWidget {
  const EditWorkoutScreen({super.key, required this.workoutId});
  final String? workoutId;
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Edit workout')));
}
