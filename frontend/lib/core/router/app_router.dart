import 'package:go_router/go_router.dart';
import 'package:pry_app/features/auth/presentation/screens/auth_screen.dart';
import 'package:pry_app/features/home/presentation/screens/home_screen.dart';
import 'package:pry_app/features/home/presentation/screens/category_screen.dart';
import 'package:pry_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:pry_app/features/placement/presentation/screens/placement_screen.dart';
import 'package:pry_app/features/trainers/presentation/screens/vocabulary_trainer.dart';
import 'package:pry_app/features/trainers/presentation/screens/grammar_trainer.dart';
import 'package:pry_app/features/trainers/presentation/screens/listening_trainer.dart';
import 'package:pry_app/features/trainers/presentation/screens/speaking_trainer.dart';
import 'package:pry_app/features/exam/presentation/screens/exam_screen.dart';
import 'package:pry_app/features/games/presentation/screens/match_game_screen.dart';
import 'package:pry_app/features/games/presentation/screens/sprint_game_screen.dart';
import 'package:pry_app/features/qalqan/presentation/screens/qalqan_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/qalqan',
  routes: [
    GoRoute(path: '/qalqan', builder: (context, state) => const QalqanScreen()),
    GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
    GoRoute(
      path: '/placement',
      builder: (context, state) => const PlacementScreen(),
    ),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/category/:categoryId',
      builder: (context, state) {
        final categoryId = int.parse(state.pathParameters['categoryId']!);
        final categoryName = state.uri.queryParameters['name'] ?? 'Category';
        return CategoryScreen(
          categoryId: categoryId,
          categoryName: categoryName,
        );
      },
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/lesson/vocabulary/:lessonId',
      builder: (context, state) {
        final lessonId = int.parse(state.pathParameters['lessonId']!);
        final topicName = state.uri.queryParameters['topic'] ?? 'Lesson';
        return VocabularyTrainer(lessonId: lessonId, topicName: topicName);
      },
    ),
    GoRoute(
      path: '/lesson/grammar/:lessonId',
      builder: (context, state) {
        final lessonId = int.parse(state.pathParameters['lessonId']!);
        final topicName = state.uri.queryParameters['topic'] ?? 'Lesson';
        return GrammarTrainer(lessonId: lessonId, topicName: topicName);
      },
    ),
    GoRoute(
      path: '/lesson/listening/:lessonId',
      builder: (context, state) {
        final lessonId = int.parse(state.pathParameters['lessonId']!);
        final topicName = state.uri.queryParameters['topic'] ?? 'Lesson';
        return ListeningTrainer(lessonId: lessonId, topicName: topicName);
      },
    ),
    GoRoute(
      path: '/lesson/speaking/:lessonId',
      builder: (context, state) {
        final lessonId = int.parse(state.pathParameters['lessonId']!);
        final topicName = state.uri.queryParameters['topic'] ?? 'Lesson';
        return SpeakingTrainer(lessonId: lessonId, topicName: topicName);
      },
    ),
    GoRoute(path: '/exam', builder: (context, state) => const ExamScreen()),
    GoRoute(
      path: '/game/match/:phaseId',
      builder: (context, state) {
        final phaseId = int.parse(state.pathParameters['phaseId']!);
        return MatchGameScreen(phaseId: phaseId);
      },
    ),
    GoRoute(
      path: '/game/sprint/:phaseId',
      builder: (context, state) {
        final phaseId = int.parse(state.pathParameters['phaseId']!);
        return SprintGameScreen(phaseId: phaseId);
      },
    ),
  ],
);
