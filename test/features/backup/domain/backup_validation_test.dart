import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:reptrack/features/backup/domain/backup_summary.dart';
import 'package:reptrack/features/backup/domain/backup_validation.dart';

const _t = '2026-10-19T16:00:00.000Z';

Map<String, Object?> _sync(String id) => {
  'id': id,
  'createdAt': _t,
  'updatedAt': _t,
  'deletedAt': null,
};

Map<String, Object?> _session(String id, String status) => {
  ..._sync(id),
  'status': status,
  'startedAt': _t,
  'endedAt': status == 'completed' ? _t : null,
  'timeZone': 'Europe/Warsaw',
  'localDate': '2026-10-19',
  'templateId': 'tpl',
  'templateNameSnapshot': 'Push A',
  'title': 'Push A',
  'notes': null,
  'wellbeing': 4,
  'restEndsAt': null,
};

/// Minimalna poprawna kopia: ćwiczenie, szablon z serią, zakończony trening.
Map<String, Object?> _backup() => {
  'format': 'reptrack-backup',
  'formatVersion': 1,
  'appVersion': '1.0.0+1',
  'exportedAt': _t,
  'exercises': [
    {
      ..._sync('ex'),
      'name': 'Wyciskanie',
      'aliases': ['bench press'],
      'searchText': 'wyciskanie bench press',
      'primaryMuscles': ['chest'],
      'secondaryMuscles': ['triceps'],
      'equipment': 'barbell',
      'category': 'strength',
      'mechanic': null,
      'force': 'push',
      'instructions': null,
      'measureWeight': true,
      'measureReps': true,
      'measureDuration': false,
      'measureDistance': false,
      'loadMode': 'external',
      'weightSemantics': 'total',
      'isUnilateral': false,
      'imageRef': null,
      'source': 'user',
      'originRef': null,
      'license': null,
      'licenseAuthor': null,
      'seedVersion': null,
      'userModified': false,
      'archivedAt': null,
    },
  ],
  'templates': [
    {
      ..._sync('tpl'),
      'name': 'Push A',
      'description': null,
      'archivedAt': null,
    },
  ],
  'templateExercises': [
    {
      ..._sync('te'),
      'templateId': 'tpl',
      'exerciseId': 'ex',
      'position': 0,
      'targetKind': 'reps',
      'targetMin': 8,
      'targetMax': 12,
      'targetWeightG': null,
      'restSeconds': 120,
      'defaultSetType': 'working',
      'note': null,
      'groupId': null,
    },
  ],
  'templateSets': [
    {
      ..._sync('ts'),
      'templateExerciseId': 'te',
      'position': 0,
      'setType': null,
      'targetMin': null,
      'targetMax': null,
      'targetWeightG': null,
      'restSeconds': null,
    },
  ],
  'workoutSessions': [_session('s1', 'completed')],
  'sessionExercises': [
    {
      ..._sync('se'),
      'sessionId': 's1',
      'exerciseId': 'ex',
      'position': 0,
      'templateExerciseId': 'te',
      'exerciseNameSnapshot': 'Wyciskanie',
      'measureWeightSnapshot': true,
      'measureRepsSnapshot': true,
      'measureDurationSnapshot': false,
      'measureDistanceSnapshot': false,
      'loadModeSnapshot': 'external',
      'weightSemanticsSnapshot': 'total',
      'isUnilateralSnapshot': false,
      'note': null,
      'groupId': null,
    },
  ],
  'sessionSets': [
    {
      ..._sync('ss'),
      'sessionExerciseId': 'se',
      'position': 0,
      'setType': 'working',
      'targetKind': 'reps',
      'targetMin': 8,
      'targetMax': 12,
      'targetWeightG': null,
      'restSeconds': null,
      'weightG': 80000,
      'reps': 10,
      'durationS': null,
      'distanceM': null,
      'effortScale': 'rir',
      'effortTenths': 20,
      'side': null,
      'completedAt': _t,
    },
  ],
  'settings': [
    {'key': 'weight_unit', 'value': 'kg', 'updatedAt': _t},
  ],
};

List<String> _problems(Map<String, Object?> backup) {
  try {
    readBackup(jsonEncode(backup));
    return const [];
  } on BackupInvalidException catch (e) {
    return e.problems;
  }
}

Map<String, Object?> _row(Map<String, Object?> backup, String table) =>
    (backup[table]! as List).first as Map<String, Object?>;

void main() {
  test('poprawna kopia przechodzi walidację', () {
    expect(_problems(_backup()), isEmpty);
  });

  test('plik nie-JSON i obcy JSON są odrzucane', () {
    expect(
      () => readBackup('{nie json'),
      throwsA(isA<BackupInvalidException>()),
    );
    expect(
      () => readBackup(jsonEncode({'format': 'inna-aplikacja'})),
      throwsA(isA<BackupInvalidException>()),
    );
  });

  test('plik z nowszej wersji aplikacji jest odrzucany', () {
    final backup = _backup()..['formatVersion'] = 2;
    expect(
      () => readBackup(jsonEncode(backup)),
      throwsA(
        isA<BackupTooNewException>().having((e) => e.formatVersion, 'v', 2),
      ),
    );
  });

  test('typy, kody, daty i zakresy pól', () {
    final backup = _backup();
    _row(backup, 'sessionSets')['reps'] = '10';
    _row(backup, 'exercises')['category'] = 'yoga';
    _row(backup, 'workoutSessions')['wellbeing'] = 7;
    _row(backup, 'templates')['createdAt'] = '2026-10-19 16:00';
    _row(backup, 'exercises')['primaryMuscles'] = ['chest', 'wings'];
    _row(backup, 'workoutSessions')['localDate'] = '2026-02-30';

    final problems = _problems(backup);

    expect(problems, hasLength(6));
    expect(problems.any((p) => p.contains('sessionSets[0].reps')), isTrue);
    expect(problems.any((p) => p.contains('nieznany kod yoga')), isTrue);
    expect(problems.any((p) => p.contains('więcej niż 5')), isTrue);
    expect(problems.any((p) => p.contains('wings')), isTrue);
    expect(problems.any((p) => p.contains('2026-02-30')), isTrue);
  });

  test('brak tablicy i brak wymaganego pola', () {
    final backup = _backup()..remove('templateSets');
    _row(backup, 'exercises').remove('name');

    final problems = _problems(backup);

    expect(problems, contains('templateSets: brak tablicy.'));
    expect(problems, contains('exercises[0].name: brak wartości.'));
  });

  test('powtórzony identyfikator i zerwany klucz obcy', () {
    final backup = _backup();
    (backup['templates']! as List).add({
      ..._sync('tpl'),
      'name': 'Kopia',
      'description': null,
      'archivedAt': null,
    });
    expect(_problems(backup).single, contains('powtórzony identyfikator tpl'));

    final broken = _backup();
    _row(broken, 'sessionExercises')['exerciseId'] = 'nie-ma';
    expect(
      _problems(broken).single,
      'sessionExercises[0].exerciseId: brak exercises o id nie-ma.',
    );
  });

  test('zasady modelu: pomiar ćwiczenia i jedna aktywna sesja', () {
    final backup = _backup();
    _row(backup, 'exercises')
      ..['measureWeight'] = false
      ..['measureReps'] = false;
    (backup['workoutSessions']! as List)
      ..add(_session('s2', 'active'))
      ..add(_session('s3', 'active'));

    final problems = _problems(backup);

    expect(problems.any((p) => p.contains('bez żadnego pola pomiaru')), isTrue);
    expect(problems.any((p) => p.contains('więcej niż jeden aktywny')), isTrue);
  });

  test('starszy format przechodzi przez migracje do bieżącego', () {
    // Wersja „1” z kluczem `workouts` zamiast `workoutSessions`, czytana tak,
    // jakby bieżąca była wersja 2 z migracją 1 → 2.
    final old = _backup();
    old['workouts'] = old.remove('workoutSessions');
    Map<String, Object?> rename(Map<String, Object?> b) =>
        b..['workoutSessions'] = b.remove('workouts');

    final migrated = readBackup(
      jsonEncode(old),
      migrations: {1: rename},
      currentVersion: 2,
    );

    expect(migrated['formatVersion'], 2);
    expect(migrated['workoutSessions'], hasLength(1));
    expect(
      () =>
          readBackup(jsonEncode(old), migrations: const {}, currentVersion: 2),
      throwsA(isA<BackupInvalidException>()),
    );
  });

  test('podsumowanie kopii do potwierdzenia', () {
    final backup = _backup();
    (backup['workoutSessions']! as List).add(_session('s2', 'active'));

    final summary = summarizeBackup(readBackup(jsonEncode(backup)));

    expect(summary.workouts, 1);
    expect(summary.templates, 1);
    expect(summary.ownExercises, 1);
    expect(summary.hasActiveWorkout, isTrue);
    expect(summary.exportedAt, DateTime.utc(2026, 10, 19, 16));
  });
}
