import '../../../core/domain/ids.dart';
import '../../../core/domain/local_date.dart';
import '../../../core/domain/training.dart';
import '../../exercises/domain/exercise.dart';
import '../../plan/domain/plan.dart';
import '../../plan/domain/plan_schedule.dart';
import '../../templates/domain/template.dart';
import 'program.dart';

/// Wynik dodania programu: nowe szablony i zmiana planu tygodniowego.
typedef ProgramInstall = ({List<Template> templates, WeeklyEdit plan});

/// Problemy programu wobec biblioteki ćwiczeń: brakujące ćwiczenie, cel
/// niepasujący do pomiaru, plan wskazujący nieistniejący trening.
/// Pusta lista oznacza program gotowy do dodania.
List<String> validateProgram(
  Program program,
  Map<String, Exercise> exercisesByKey,
) {
  final problems = <String>[];
  if (program.schedule.isEmpty) problems.add('${program.id}: pusty plan');
  for (final MapEntry(key: weekday, value: key) in program.schedule.entries) {
    if (weekday < 1 || weekday > 7) {
      problems.add('${program.id}: dzień $weekday');
    }
    if (program.workout(key) == null) {
      problems.add('${program.id}: brak treningu $key');
    }
  }
  for (final workout in program.workouts) {
    if (workout.exercises.isEmpty) {
      problems.add('${program.id}/${workout.key}: brak ćwiczeń');
    }
    for (final e in workout.exercises) {
      final where = '${program.id}/${workout.key}/${e.exerciseKey}';
      final exercise = exercisesByKey[e.exerciseKey];
      if (exercise == null) {
        problems.add('$where: brak ćwiczenia w bibliotece');
        continue;
      }
      final m = exercise.measurement;
      final fits = switch (e.targetKind) {
        TargetKind.reps => m.reps,
        TargetKind.duration => m.duration,
      };
      if (!fits) problems.add('$where: cel nie pasuje do pomiaru');
      if (e.sets < 1 || e.targetMin < 1 || e.targetMin > e.targetMax) {
        problems.add('$where: serie albo zakres');
      }
    }
  }
  return problems;
}

/// Szablony programu (nowe identyfikatory, nazwy w [languageCode]) i plan
/// tygodniowy od [today] z dniami programu. Istniejący plan tygodniowy
/// zostaje zastąpiony od dziś jak przy edycji (ADR 0015), a dotychczasowe
/// szablony zostają.
ProgramInstall installProgram(
  Program program, {
  required Map<String, Exercise> exercisesByKey,
  required String languageCode,
  required List<WeeklyPlan> plans,
  required LocalDate today,
  required IdGenerator ids,
}) {
  final templateIds = <String, String>{};
  final templates = <Template>[];
  for (final workout in program.workouts) {
    final templateId = ids.newId();
    templateIds[workout.key] = templateId;
    final groups = <String, String>{};
    templates.add(
      Template(
        id: templateId,
        name: workout.name.of(languageCode),
        description: program.name.of(languageCode),
        exercises: [
          for (final (position, e) in workout.exercises.indexed)
            TemplateExercise(
              id: ids.newId(),
              exerciseId: exercisesByKey[e.exerciseKey]!.id,
              position: position,
              targetKind: e.targetKind,
              targetMin: e.targetMin,
              targetMax: e.targetMax,
              restSeconds: e.restSeconds,
              groupId: e.superset == null
                  ? null
                  : groups.putIfAbsent(e.superset!, ids.newId),
              sets: [
                for (var i = 0; i < e.sets; i++)
                  TemplateSet(id: ids.newId(), position: i),
              ],
            ),
        ],
      ),
    );
  }
  final plan = editWeeklyPlan(
    plans: plans,
    days: {
      for (final MapEntry(key: weekday, value: key) in program.schedule.entries)
        weekday: [templateIds[key]!],
    },
    today: today,
    ids: ids,
  );
  return (templates: templates, plan: plan);
}
