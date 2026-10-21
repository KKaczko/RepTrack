import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../../core/domain/training.dart';
import '../../../core/platform/rest_notifications.dart';
import '../../exercises/data/exercise_providers.dart';
import '../../exercises/domain/exercise.dart';
import '../../settings/data/settings_providers.dart';
import '../../settings/domain/app_settings.dart';
import '../../templates/data/template_providers.dart';
import '../../templates/domain/template.dart';
import '../data/workout_providers.dart';
import '../domain/progression.dart';
import '../domain/rest_timer.dart';
import '../domain/session_editing.dart' as editing;
import '../domain/session_editing.dart';
import '../domain/set_hints.dart';
import '../domain/template_sync.dart';
import '../domain/warmup.dart';
import '../domain/workout_repository.dart';
import '../domain/workout_session.dart';

final workoutControllerProvider = Provider<WorkoutController>(
  WorkoutController.new,
);

/// Operacje aktywnego treningu (spec. 5.3). Każda zmiana to odczyt sesji
/// z bazy, czysta funkcja domeny i zapis w jednej transakcji, więc po
/// ubiciu procesu nic nie ginie. Operacje wykonują się po kolei: szybkie
/// tapnięcia nie nadpisują sobie zmian.
final class WorkoutController {
  WorkoutController(this._ref);

  final Ref _ref;
  Future<void> _tail = Future.value();

  WorkoutRepository get _repo => _ref.read(workoutRepositoryProvider);

  DateTime get _now => _ref.read(clockProvider).nowUtc();

  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<WorkoutSession?> _mutate(
    WorkoutSession Function(WorkoutSession session) change,
  ) => _serial(() async {
    final session = await _repo.findActive();
    if (session == null) return null;
    final next = change(session);
    if (next != session) await _repo.save(next);
    return next;
  });

  /// Wpisuje wartość pola serii; null przywraca podpowiedź.
  Future<void> setValue(
    String exerciseId,
    String setId,
    SetField field,
    int? value,
  ) => _mutate(
    (s) => updateSet(
      s,
      exerciseId,
      setId,
      (set) => withSetValue(set, field, value),
    ),
  );

  /// Ustawia wysiłek serii; null czyści pole.
  Future<void> setEffort(
    String exerciseId,
    String setId,
    EffortScale scale,
    int? tenths,
  ) => _mutate(
    (s) => updateSet(
      s,
      exerciseId,
      setId,
      (set) => set.copyWith(
        effortScale: tenths == null ? null : scale,
        effortTenths: tenths,
      ),
    ),
  );

  /// Zatwierdza serię wartościami z podpowiedzi i startuje przerwę.
  /// Zwraca pola bez wartości, gdy serii nie da się zatwierdzić.
  Future<List<SetField>> confirm(String exerciseId, String setId) =>
      _serial(() async {
        final session = await _repo.findActive();
        final exercise = session?.exercises.firstWhereOrNull(
          (e) => e.id == exerciseId,
        );
        final set = exercise?.sets.firstWhereOrNull((s) => s.id == setId);
        if (session == null ||
            exercise == null ||
            set == null ||
            set.isCompleted) {
          return const <SetField>[];
        }
        final recent = await _repo.recentCompletedSets(
          exercise.exerciseId,
          excludeSessionId: session.id,
        );
        final previous = recent.firstOrNull ?? const <SessionSet>[];
        final measurement = exercise.measurementSnapshot;
        final settings = await _ref.read(settingsRepositoryProvider).load();
        final equipment =
            (await _ref
                    .read(exerciseRepositoryProvider)
                    .findById(exercise.exerciseId))
                ?.equipment;
        final hint = hintsForExercise(
          exercise,
          previous,
          progressionWeightG: settings.autoProgression
              ? progressionFor(
                  exercise,
                  previous,
                  step: weightStepFor(equipment, settings),
                  unit: settings.weightUnit,
                  earlierSets: recent.elementAtOrNull(1) ?? const [],
                )?.weightG
              : null,
        )[set.id]!;
        final missing = missingFields(hint, measurement);
        if (missing.isNotEmpty) return missing;

        final now = _now;
        var next = updateSet(
          session,
          exerciseId,
          setId,
          (s) => confirmSet(s, hint, measurement, now),
        );
        final rest = restAfter(set, settings.defaultRestSeconds);
        final anyLeft = nextExerciseToDo(next, exerciseId) != null;
        // W superserii przerwa przychodzi dopiero po rundzie (ADR 0018).
        final inRound = supersetRoundContinues(next, exerciseId);
        next = next.copyWith(
          restEndsAt: anyLeft && !inRound && rest > Duration.zero
              ? now.add(rest)
              : null,
        );
        await _repo.save(next);
        await _syncRest(next, exerciseId);
        return const <SetField>[];
      });

  /// Cofa zatwierdzenie serii; wpisane wartości zostają.
  Future<void> uncomplete(String exerciseId, String setId) =>
      _mutate((s) => updateSet(s, exerciseId, setId, uncompleteSet));

  Future<void> addSet(String exerciseId) => _mutate(
    (s) => editing.addSet(s, exerciseId, _ref.read(idGeneratorProvider)),
  );

  Future<void> removeSet(String exerciseId, String setId) =>
      _mutate((s) => editing.removeSet(s, exerciseId, setId));

  /// Dodaje ćwiczenia na koniec; zwraca id pierwszego dodanego ćwiczenia sesji.
  Future<String?> addExercises(List<Exercise> exercises) async {
    String? firstId;
    await _mutate((s) {
      final before = s.exercises.length;
      final next = addExercisesToSession(
        s,
        exercises,
        _ref.read(idGeneratorProvider),
      );
      final added = sortedExercises(next).skip(before).firstOrNull;
      firstId = added?.id;
      return next;
    });
    return firstId;
  }

  Future<void> replaceExercise(String exerciseId, Exercise replacement) =>
      _mutate((s) => replaceExerciseInSession(s, exerciseId, replacement));

  Future<void> removeExercise(String exerciseId) =>
      _mutate((s) => removeExerciseFromSession(s, exerciseId));

  /// Dodaje serie rozgrzewkowe na początek ćwiczenia (ADR 0020); zwraca
  /// ich identyfikatory do „Cofnij”.
  Future<List<String>> addWarmups(
    String exerciseId,
    List<WarmupSet> plan,
  ) async {
    var added = const <String>[];
    await _mutate((s) {
      final result = editing.addWarmupSets(
        s,
        exerciseId,
        plan,
        _ref.read(idGeneratorProvider),
      );
      added = result.setIds;
      return result.session;
    });
    return added;
  }

  /// Usuwa kilka serii naraz (np. cofnięcie rozgrzewki).
  Future<void> removeSets(String exerciseId, Set<String> setIds) =>
      _mutate((s) => editing.removeSets(s, exerciseId, setIds));

  /// Łączy ćwiczenie z następnym w superserię (ADR 0018).
  Future<void> linkWithNext(String exerciseId) => _mutate(
    (s) => editing.linkExerciseWithNext(
      s,
      exerciseId,
      _ref.read(idGeneratorProvider),
    ),
  );

  /// Odłącza ćwiczenie od superserii.
  Future<void> unlink(String exerciseId) => _mutate(
    (s) =>
        editing.unlinkExercise(s, exerciseId, _ref.read(idGeneratorProvider)),
  );

  /// Przenosi ćwiczenie na docelowy indeks (semantyka `onReorderItem`).
  Future<void> moveExercise(int from, int to) =>
      _mutate((s) => moveExerciseInSession(s, from, to));

  /// Wydłuża albo skraca przerwę o [delta].
  Future<void> adjustRest(Duration delta, {String? currentExerciseId}) =>
      _serial(() async {
        final session = await _repo.findActive();
        if (session == null || session.restEndsAt == null) return;
        final next = session.copyWith(
          restEndsAt: adjustRestEnd(session.restEndsAt, _now, delta),
        );
        await _repo.save(next);
        await _syncRest(next, currentExerciseId);
      });

  Future<void> skipRest() => _serial(() async {
    final session = await _repo.findActive();
    if (session == null) return;
    if (session.restEndsAt != null) {
      await _repo.save(session.copyWith(restEndsAt: null));
    }
    await _cancelRest();
  });

  /// Kończy trening. Gdy podano [templateToUpdate], szablon przyjmuje
  /// strukturę treningu w tej samej transakcji.
  Future<void> finish({
    String? notes,
    int? wellbeing,
    Template? templateToUpdate,
  }) => _serial(() async {
    final session = await _repo.findActive();
    if (session == null) return;
    final finished = session.copyWith(
      status: SessionStatus.completed,
      endedAt: _now,
      restEndsAt: null,
      notes: notes == null || notes.trim().isEmpty ? null : notes.trim(),
      wellbeing: wellbeing,
    );
    await _ref.read(appDatabaseProvider).transaction(() async {
      if (templateToUpdate != null) {
        await _ref
            .read(templateRepositoryProvider)
            .save(
              applySessionToTemplate(
                templateToUpdate,
                session,
                _ref.read(idGeneratorProvider),
              ),
            );
      }
      await _repo.save(finished);
    });
    await _cancelRest();
  });

  /// Porzuca trening: nie trafi do historii.
  Future<void> discard() => _serial(() async {
    final session = await _repo.findActive();
    if (session == null) return;
    await _repo.discard(session.id);
    await _cancelRest();
  });

  Future<void> _syncRest(WorkoutSession session, String? exerciseId) async {
    final endsAt = session.restEndsAt;
    if (endsAt == null || !endsAt.isAfter(_now)) return _cancelRest();
    final next = nextExerciseToDo(session, exerciseId);
    await _guard(
      () => _ref
          .read(restNotificationsProvider)
          .startRest(
            endsAt: endsAt,
            nextName: next?.exerciseNameSnapshot ?? '',
          ),
    );
  }

  Future<void> _cancelRest() =>
      _guard(() => _ref.read(restNotificationsProvider).cancelRest());

  /// Błąd powiadomień nie może przerwać zapisu treningu.
  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (error, stack) {
      debugPrint('Powiadomienie przerwy: $error\n$stack');
    }
  }
}
