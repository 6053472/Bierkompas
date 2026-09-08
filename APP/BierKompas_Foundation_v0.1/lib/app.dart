import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_gate.dart';

class BierKompasApp extends StatelessWidget {
  const BierKompasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BierKompas',
      theme: AppTheme.light(),
      home: const AuthGate(),
    );
  }
}