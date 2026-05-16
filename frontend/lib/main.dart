import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pry_app/core/theme/app_theme.dart';
import 'package:pry_app/core/router/app_router.dart';

void main() {
  runApp(const ProviderScope(child: PryApp()));
}

class PryApp extends StatelessWidget {
  const PryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Qalqan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData,
      routerConfig: appRouter,
    );
  }
}
