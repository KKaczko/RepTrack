import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/core/domain/local_date.dart';
import 'package:reptrack/core/domain/training.dart';
import 'package:reptrack/core/domain/units.dart';
import 'package:reptrack/features/backup/domain/workout_export.dart';
import 'package:reptrack/features/workout/domain/session_editing.dart';
import 'package:reptrack/features/workout/domain/workout_session.dart';

import '../../../support/workout_fixtures.dart';

const _labels = ExportLabels(
  title: 'RepTrack: treningi',
  unitsLine: 'Jednostki: ciężar w kg, czas w sekundach, dystans w metrach.',
  date: 'Data',
  time: 'Godzina',
  workout: 'Trening',
  template: 'Szablon',
  exercise: 'Ćwiczenie',
  set: 'Seria',
  setTypeHeader: 'Typ serii',
  weight: 'Ciężar (kg)',
  reps: 'Powtórzenia',
  duration: 'Czas (s)',
  distance: 'Dystans (m)',
  rir: 'RIR',
  rpe: 'RPE',
  notes: 'Notatka',
  sets: 'Serie',
  start: 'Start',
  workoutDuration: 'czas',
  wellbeing: 'samopoczucie',
  setTypes: {
    SetType.warmup: 'rozgrzewkowa',
    SetType.working: 'robocza',
    SetType.drop: 'drop set',
    SetType.amrap: 'AMRAP',
  },
  untitledWorkout: 'Trening',
  decimalSeparator: ',',
);

/// Dwa treningi: 5 i 12 października; drugi z notatką ze średnikiem,
/// cudzysłowem i RIR przy pierwszej serii roboczej.
List<WorkoutSession> _sessions() {
  final first = finishedPush('a', DateTime.utc(2026, 10, 5, 16), [(82500, 10)]);
  var second = finishedPush('b', DateTime.utc(2026, 10, 12, 16), [
    (85000, 8),
    (85000, 7),
  ]);
  final bench = sortedExercises(second).first;
  second = updateSet(
    second,
    bench.id,
    sortedSets(bench)[1].id,
    (s) => s.copyWith(effortScale: EffortScale.rir, effortTenths: 20),
  ).copyWith(notes: 'Ciężko; "dobra" forma', wellbeing: 4);
  return [second, first];
}

void main() {
  test('wiersze: tylko zatwierdzone serie, od najstarszego, z filtrami', () {
    final all = exportRows(_sessions(), const ExportFilter());
    expect([for (final r in all) r.set.weightG], [82500, 85000, 85000]);

    final october12 = exportRows(
      _sessions(),
      const ExportFilter(from: LocalDate(2026, 10, 10)),
    );
    expect(october12, hasLength(2));

    final pullUpsOnly = exportRows(
      _sessions(),
      const ExportFilter(exerciseIds: {'pullup'}),
    );
    expect(pullUpsOnly, isEmpty);
  });

  test('CSV: BOM, średnik, przecinek dziesiętny, cudzysłowy, CRLF', () {
    final csv = exportCsv(
      exportRows(_sessions(), const ExportFilter()),
      labels: _labels,
      unit: WeightUnit.kg,
      exerciseNames: const {'bench': 'Wyciskanie sztangi'},
    );

    expect(csv.startsWith('﻿'), isTrue);
    final lines = csv.substring(1).split('\r\n');
    expect(
      lines[0],
      'Data;Godzina;Trening;Szablon;Ćwiczenie;Seria;Typ serii;Ciężar (kg);'
      'Powtórzenia;Czas (s);Dystans (m);RIR;RPE;Notatka',
    );
    expect(
      lines[1],
      '2026-10-05;18:00;Push A;Push A;Wyciskanie sztangi;2;robocza;82,5;10;'
      ';;;;',
    );
    expect(
      lines[2],
      '2026-10-12;18:00;Push A;Push A;Wyciskanie sztangi;2;robocza;85;8;;;2;;'
      '"Ciężko; ""dobra"" forma"',
    );
    expect(lines.last, isEmpty);
  });

  test('CSV w funtach przelicza ciężar', () {
    final csv = exportCsv(
      exportRows(_sessions(), const ExportFilter()),
      labels: _labels,
      unit: WeightUnit.lb,
      exerciseNames: const {},
    );
    // 82,5 kg = 181,88 lb.
    expect(csv, contains(';181,88;'));
  });

  test('Markdown per trening: jednostki, tabele i ucieczka znaków', () {
    final md = exportMarkdown(
      exportRows(_sessions(), const ExportFilter()),
      labels: _labels,
      unit: WeightUnit.kg,
      exerciseNames: const {'bench': 'Wyciskanie | sztanga'},
    );

    expect(md, startsWith('# RepTrack: treningi\n\nJednostki: ciężar w kg'));
    expect(md, contains('## 2026-10-12 · Push A'));
    expect(
      md,
      contains('Start 18:00 · czas 50 min · Szablon Push A · samopoczucie 4/5'),
    );
    expect(md, contains(r'### Wyciskanie \| sztanga'));
    expect(
      md,
      contains('| Seria | Typ serii | Ciężar (kg) | Powtórzenia | RIR |'),
    );
    expect(md, contains('| 2 | robocza | 85 | 8 | 2 |'));
    expect(md, contains('| 2 | robocza | 82,5 | 10 |'));
  });

  test('Markdown per ćwiczenie: wiersz na trening', () {
    final md = exportMarkdown(
      exportRows(_sessions(), const ExportFilter()),
      labels: _labels,
      unit: WeightUnit.kg,
      exerciseNames: const {'bench': 'Wyciskanie'},
      layout: MarkdownLayout.perExercise,
    );

    expect(md, contains('## Wyciskanie'));
    expect(md, contains('| Data | Trening | Serie |'));
    expect(md, contains('| 2026-10-05 | Push A | 82,5×10 |'));
    expect(md, contains('| 2026-10-12 | Push A | 85×8 @RIR 2, 85×7 |'));
  });
}
