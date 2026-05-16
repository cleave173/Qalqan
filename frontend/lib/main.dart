import 'package:flutter/material.dart';
import 'package:qalqan_app/core/router/app_router.dart';
import 'package:qalqan_app/core/theme/app_theme.dart';

void main() {
  runApp(const QalqanApp());
}

class QalqanApp extends StatelessWidget {
  const QalqanApp({super.key});

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
