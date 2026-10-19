import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../../core/platform/device_services.dart';
import '../../../core/platform/rest_notifications.dart';
import '../../exercises/data/exercise_providers.dart';
import '../../templates/domain/template.dart';
import '../domain/session_builder.dart';
import '../domain/workout_repository.dart';
import '../domain/workout_session.dart';
import 'drift_workout_repository.dart';

/// Publiczne providery funkcji „trening” (docs/architecture.md).
final workoutRepositoryProvider = Provider<WorkoutRepository>(
  (ref) => DriftWorkoutRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(clockProvider),
  ),
);

/// Aktywna sesja z bazy; null, gdy nie trwa żaden trening.
final activeSessionProvider = StreamProvider<WorkoutSession?>(
  (ref) => ref.watch(workoutRepositoryProvider).watchActive(),
);

/// Zakończone treningi od najnowszego (historia, progres, ekran Start).
final completedSessionsProvider = StreamProvider<List<WorkoutSession>>(
  (ref) => ref.watch(workoutRepositoryProvider).watchCompleted(),
);

/// Zatwierdzone serie ostatniego wykonania ćwiczenia poza bieżącą sesją
/// (ADR 0006). Klucz: (id ćwiczenia, id bieżącej sesji).
final previousSetsProvider = FutureProvider.autoDispose
    .family<List<SessionSet>, (String, String)>(
      (ref, key) => ref
          .watch(workoutRepositoryProvider)
          .lastCompletedSets(key.$1, excludeSessionId: key.$2),
    );

final workoutStarterProvider = Provider<WorkoutStarter>(WorkoutStarter.new);

/// Rozpoczynanie treningu z szablonu albo pustego. Sesja zapisuje strefę
/// czasową telefonu z chwili startu (spec. 4).
final class WorkoutStarter {
  WorkoutStarter(this._ref);

  final Ref _ref;

  /// Zwraca false, gdy trwa już inny trening (najwyżej jeden aktywny).
  Future<bool> startFromTemplate(Template template) async {
    // Odczyt z repozytorium, nie z `exerciseCatalogProvider.future`:
    // Riverpod 3 wstrzymuje provider bez słuchaczy, więc przyszła wartość
    // nie nadeszłaby, gdy żaden ekran nie obserwuje katalogu (np. Start).
    final catalog = await _ref
        .read(exerciseRepositoryProvider)
        .findAll(includeArchived: true);
    final exercises = {for (final e in catalog) e.id: e};
    return _start(
      (zone, now) => buildSessionFromTemplate(
        template: template,
        exercises: exercises,
        ids: _ref.read(idGeneratorProvider),
        startedAt: now,
        timeZone: zone,
      ),
    );
  }

  /// Zwraca false, gdy trwa już inny trening.
  Future<bool> startEmpty() => _start(
    (zone, now) => buildEmptySession(
      ids: _ref.read(idGeneratorProvider),
      startedAt: now,
      timeZone: zone,
    ),
  );

  Future<bool> _start(
    WorkoutSession Function(String zone, DateTime now) build,
  ) async {
    final repo = _ref.read(workoutRepositoryProvider);
    if (await repo.findActive() != null) return false;
    final zone = await _ref.read(deviceTimeZoneProvider).current();
    try {
      await repo.save(build(zone, _ref.read(clockProvider).nowUtc()));
    } on ActiveSessionExistsException {
      return false;
    }
    // Zgoda na powiadomienia przerwy (Android 13+); odmowa nie blokuje
    // treningu, timer działa wtedy tylko w aplikacji.
    try {
      await _ref.read(restNotificationsProvider).requestPermission();
    } on Object {
      // Brak zgody albo platformy bez powiadomień.
    }
    return true;
  }
}
