import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';

class NomorexApp extends StatelessWidget {
  const NomorexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NoMoreX',
      theme: AppTheme.light(),
      home: const Scaffold(
        body: Center(child: Text('Loading...')),
      ),
    );
  }
}
