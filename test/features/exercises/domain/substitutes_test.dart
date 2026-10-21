import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/features/exercises/data/seed_catalog.dart';
import 'package:reptrack/features/exercises/domain/exercise.dart';
import 'package:reptrack/features/exercises/domain/substitutes.dart';

void main() {
  // Prawdziwa biblioteka ćwiczeń z seeda: propozycje mają mieć sens na
  // danych, które zobaczy użytkownik.
  final catalog = parseSeedCatalog(File(seedAssetPath).readAsStringSync())
      .exercises;
  Exercise named(String name) => catalog.firstWhere((e) => e.name == name);

  test('zajęta maszyna do wyciskania: wyciskania innym sprzętem na górze', () {
    final machine = named('Wyciskanie na maszynie siedząc');
    final names = [
      for (final s in suggestSubstitutes(machine, catalog)) s.exercise.name,
    ];

    expect(
      names.take(6),
      containsAll([
        'Wyciskanie sztangi na ławce płaskiej',
        'Wyciskanie hantli na ławce płaskiej',
        'Wyciskanie na suwnicy Smitha na ławce płaskiej',
      ]),
    );
    expect(names, contains('Pompki'));
    // Izolacja (rozpiętki) niżej niż wyciskania wielostawowe albo wcale.
    final fly = names.indexOf('Rozpiętki na maszynie');
    expect(
      fly == -1 || fly > names.indexOf('Wyciskanie hantli na ławce płaskiej'),
      isTrue,
    );
  });

  test('tylko wspólny mięsień główny i ta sama grupa kategorii', () {
    final machine = named('Wyciskanie na maszynie siedząc');
    for (final s in suggestSubstitutes(machine, catalog, limit: 50)) {
      expect(
        s.exercise.primaryMuscles.any(machine.primaryMuscles.contains),
        isTrue,
        reason: s.exercise.name,
      );
      expect(s.exercise.category, isNot(ExerciseCategory.cardio));
    }
  });

  test('przypięte pierwsze, w obie strony i bez zarchiwizowanych', () {
    final machine = named('Wyciskanie na maszynie siedząc');
    final pushUps = named('Pompki');
    final dips = catalog.firstWhere(
      (e) => e.name.startsWith('Pompki na poręczach'),
    );
    final pins = <SubstitutePin>[
      (exerciseId: pushUps.id, substituteId: machine.id),
      (exerciseId: machine.id, substituteId: dips.id),
    ];

    final pinned = pinnedFor(machine.id, pins);
    expect(pinned, [pushUps.id, dips.id]);

    final result = suggestSubstitutes(machine, catalog, pinned: pinned);
    expect([for (final s in result.take(2)) s.exercise.id], pinned);
    expect(result.take(2).every((s) => s.pinned), isTrue);
    // Przypięty nie powtarza się wśród propozycji.
    expect(result.where((s) => s.exercise.id == pushUps.id), hasLength(1));

    final archived = suggestSubstitutes(machine, [
      for (final e in catalog)
        e.id == dips.id ? e.copyWith(archivedAt: DateTime.utc(2026)) : e,
    ], pinned: pinned);
    expect(archived.any((s) => s.exercise.id == dips.id), isFalse);
  });

  test('powody: mięśnie, ruch, sprzęt, historia', () {
    final machine = named('Wyciskanie na maszynie siedząc');
    final dumbbell = named('Wyciskanie hantli na ławce płaskiej');

    final result = suggestSubstitutes(machine, catalog, used: {dumbbell.id});
    final reasons = result.byExerciseId(dumbbell.id)!.reasons;

    expect(reasons, {
      SubstituteReason.sameMuscles,
      SubstituteReason.sameMovement,
      SubstituteReason.otherEquipment,
      SubstituteReason.doneBefore,
    });
    // Historia podnosi ćwiczenie w kolejności.
    final without = suggestSubstitutes(machine, catalog);
    expect(
      result.indexWhere((s) => s.exercise.id == dumbbell.id),
      lessThanOrEqualTo(
        without.indexWhere((s) => s.exercise.id == dumbbell.id),
      ),
    );
  });

  test('cardio podpowiada cardio', () {
    final run = catalog.firstWhere(
      (e) => e.category == ExerciseCategory.cardio,
    );
    final result = suggestSubstitutes(run, catalog);
    expect(
      result.every((s) => s.exercise.category == ExerciseCategory.cardio),
      isTrue,
    );
  });
}
