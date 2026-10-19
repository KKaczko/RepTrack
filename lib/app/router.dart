import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/exercises/presentation/exercise_detail_screen.dart';
import '../features/exercises/presentation/exercise_form_screen.dart';
import '../features/exercises/presentation/exercise_picker_screen.dart';
import '../features/exercises/presentation/exercises_screen.dart';
import '../features/history/presentation/exercise_progress_tabs.dart';
import '../features/history/presentation/history_screen.dart';
import '../features/history/presentation/session_compare_screen.dart';
import '../features/history/presentation/session_detail_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/settings/presentation/licenses_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/templates/presentation/template_editor_screen.dart';
import '../features/templates/presentation/templates_screen.dart';
import '../features/workout/presentation/finish_screen.dart';
import '../features/workout/presentation/workout_screen.dart';
import 'app_shell.dart';
import 'routes.dart';

/// Nawigacja (ADR 0002): cztery zakładki w [StatefulShellRoute], każda
/// z własnym stosem, oraz ekrany pełnoekranowe poza shellem. Formularze
/// otwierają się na głównym nawigatorze, bez dolnej nawigacji.
final routerProvider = Provider<GoRouter>((ref) {
  final rootKey = GlobalKey<NavigatorState>();
  final router = GoRouter(
    navigatorKey: rootKey,
    initialLocation: AppRoutes.home,
    routes: [
      StatefulShellRoute(
        builder: (context, state, shell) => AppShell(shell: shell),
        navigatorContainerBuilder: branchContainer,
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.templates,
                builder: (context, state) => const TemplatesScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: rootKey,
                    builder: (context, state) => const TemplateEditorScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: rootKey,
                    builder: (context, state) => TemplateEditorScreen(
                      templateId: state.pathParameters['id'],
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.history,
                builder: (context, state) => const HistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.exercises,
                builder: (context, state) => const ExercisesScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: rootKey,
                    builder: (context, state) => const ExerciseFormScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => ExerciseDetailScreen(
                      exerciseId: state.pathParameters['id']!,
                      extraTabs: exerciseProgressTabs(),
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        parentNavigatorKey: rootKey,
                        builder: (context, state) => ExerciseFormScreen(
                          exerciseId: state.pathParameters['id'],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'licenses',
            builder: (context, state) => const LicensesScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/sessions/:id',
        builder: (context, state) =>
            SessionDetailScreen(sessionId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'compare',
            builder: (context, state) =>
                SessionCompareScreen(sessionId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.exercisePicker,
        builder: (context, state) => ExercisePickerScreen(
          single: state.uri.queryParameters['single'] == 'true',
        ),
      ),
      GoRoute(
        path: AppRoutes.workout,
        builder: (context, state) => const WorkoutScreen(),
        routes: [
          GoRoute(
            path: 'finish',
            builder: (context, state) => const FinishWorkoutScreen(),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
