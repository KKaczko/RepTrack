import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:reptrack/app/app.dart';
import 'package:reptrack/app/bootstrap.dart';
import 'package:reptrack/core/database/app_database.dart';
import 'package:reptrack/core/database/database_providers.dart';
import 'package:reptrack/core/domain/clock.dart';
import 'package:reptrack/core/domain/ids.dart';
import 'package:reptrack/core/domain/local_date.dart';
import 'package:reptrack/core/platform/rest_notifications.dart';
import 'package:reptrack/features/exercises/data/drift_exercise_repository.dart';
import 'package:reptrack/features/templates/data/drift_template_repository.dart';
import 'package:reptrack/features/templates/domain/template.dart';
import 'package:reptrack/features/templates/domain/template_editing.dart';
import 'package:reptrack/features/workout/data/drift_workout_repository.dart';
import 'package:reptrack/features/workout/domain/workout_session.dart';

/// Test na urządzeniu (Etap 7): biblioteka z zasobów aplikacji, natywny
/// SQLite Androida i pełny przebieg treningu. Baza w pamięci, więc dane
/// aplikacji na telefonie zostają nietknięte.
///
///     flutter test integration_test -d <urządzenie>
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('szablon → trening → historia na urządzeniu', (tester) async {
    ensureTimeZonesLoaded();
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final db = AppDatabase(
      NativeDatabase.memory(setup: AppDatabase.configureConnection),
    );
    await seedExerciseLibrary(db, rootBundle);
    final catalog = await DriftExerciseRepository(
      db,
      const SystemClock(),
    ).findAll();
    final bench = catalog.firstWhere(
      (e) => e.name == 'Wyciskanie sztangi na ławce płaskiej',
    );
    await DriftTemplateRepository(db, const SystemClock()).save(
      addExercises(const Template(id: 'tpl', name: 'Push A'), [
        bench,
      ], const UuidV7Generator()),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          restNotificationsProvider.overrideWithValue(
            const NoopRestNotifications(),
          ),
        ],
        child: const RepTrackApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Start → pierwsza seria: 2 tapnięcia.
    await tester.tap(find.text('Rozpocznij: Push A'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Zwiększ: Ciężar'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Zatwierdź serię 1'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Przerwa'), findsOneWidget);
    await tester.tap(find.text('Pomiń'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Opcje treningu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zakończ trening'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zakończ i zapisz'));
    await tester.pumpAndSettle();

    expect(find.text('Trening zapisany'), findsOneWidget);
    final sessions = await DriftWorkoutRepository(
      db,
      const SystemClock(),
    ).watchCompleted().first;
    expect(sessions.single.status, SessionStatus.completed);
    expect(
      sessions.single.exercises.single.sets.where((s) => s.isCompleted),
      hasLength(1),
    );

    await tester.tap(find.text('Historia'));
    await tester.pumpAndSettle();
    expect(find.text('Push A'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await db.close();
  });
}
