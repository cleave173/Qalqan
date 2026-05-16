import 'package:go_router/go_router.dart';
import 'package:qalqan_app/features/auth/presentation/screens/auth_screen.dart';
import 'package:qalqan_app/features/qalqan/presentation/screens/qalqan_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/auth',
  routes: [
    GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
    GoRoute(path: '/qalqan', builder: (context, state) => const QalqanScreen()),
  ],
);
