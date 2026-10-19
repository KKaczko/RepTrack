// Buduje assets/seed/exercises.json z katalogu tool/seed/catalog_pl.yaml
// i danych free-exercise-db (ADR 0005).
//
//   dart run tool/seed/build_seed.dart --source <free-exercise-db/dist/exercises.json>
//
// Dane źródłowe pobierz z przypiętego commita (patrz [sourceCommit]).
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:reptrack/core/domain/coded_enum.dart';
import 'package:reptrack/core/domain/text_normalize.dart';
import 'package:reptrack/features/exercises/domain/exercise.dart';
import 'package:uuid/uuid.dart';
import 'package:yaml/yaml.dart';

const catalogPath = 'tool/seed/catalog_pl.yaml';
const idsPath = 'tool/seed/ids.json';
const outputPath = 'assets/seed/exercises.json';

const sourceName = 'free-exercise-db';
const sourceUrl = 'https://github.com/yuhonas/free-exercise-db';
const sourceCommit = 'f00c92c7dcf1216a928a52c3706c7ce8e2f71ed5';
const sourceLicense = 'Unlicense';
const sourceAuthor =
    'yuhonas/free-exercise-db (na podstawie wrkout/exercises.json)';
const ownAuthor = 'RepTrack';

const _equipmentMap = {
  'barbell': Equipment.barbell,
  'dumbbell': Equipment.dumbbell,
  'kettlebells': Equipment.kettlebell,
  'cable': Equipment.cable,
  'machine': Equipment.machine,
  'body only': Equipment.bodyweight,
  'bands': Equipment.bands,
  'medicine ball': Equipment.medicineBall,
  'exercise ball': Equipment.exerciseBall,
  'foam roll': Equipment.foamRoll,
  'e-z curl bar': Equipment.ezBar,
  'other': Equipment.other,
};

const _categoryMap = {
  'strength': ExerciseCategory.strength,
  'powerlifting': ExerciseCategory.strength,
  'olympic weightlifting': ExerciseCategory.olympic,
  'strongman': ExerciseCategory.strongman,
  'plyometrics': ExerciseCategory.plyometrics,
  'cardio': ExerciseCategory.cardio,
  'stretching': ExerciseCategory.mobility,
};

final class SeedBuildException implements Exception {
  SeedBuildException(this.message);

  final String message;

  @override
  String toString() => 'Błąd budowania seeda: $message';
}

void main(List<String> args) {
  final sourceIndex = args.indexOf('--source');
  if (sourceIndex < 0 || sourceIndex + 1 >= args.length) {
    stderr.writeln(
      'Użycie: dart run tool/seed/build_seed.dart --source <exercises.json>',
    );
    exitCode = 64;
    return;
  }
  try {
    build(sourcePath: args[sourceIndex + 1]);
  } on SeedBuildException catch (e) {
    stderr.writeln(e);
    exitCode = 1;
  }
}

void build({required String sourcePath}) {
  final source = {
    for (final raw
        in jsonDecode(File(sourcePath).readAsStringSync()) as List<dynamic>)
      (raw as Map<String, dynamic>)['id'] as String: raw,
  };
  final catalog = loadYaml(File(catalogPath).readAsStringSync()) as YamlMap;
  final seedVersion = catalog['seed_version'] as int;
  final entries = (catalog['exercises'] as YamlList).cast<YamlMap>();

  final idsFile = File(idsPath);
  final ids = idsFile.existsSync()
      ? (jsonDecode(idsFile.readAsStringSync()) as Map<String, dynamic>)
            .cast<String, String>()
      : <String, String>{};

  final outputFile = File(outputPath);
  final previous = outputFile.existsSync()
      ? jsonDecode(outputFile.readAsStringSync()) as Map<String, dynamic>
      : null;
  final previousVersion = previous?['seedVersion'] as int? ?? 0;
  final previousById = {
    for (final e in (previous?['exercises'] as List<dynamic>? ?? []))
      (e as Map<String, dynamic>)['id'] as String: e,
  };

  if (seedVersion < previousVersion) {
    throw SeedBuildException(
      'seed_version $seedVersion jest niższy niż w $outputPath '
      '($previousVersion)',
    );
  }

  const uuid = Uuid();
  final seenKeys = <String>{};
  final seenNames = <String, String>{};
  final changed = <String>[];
  final output = <Map<String, Object?>>[];

  for (final entry in entries) {
    final key = _requireString(entry, 'key', '?');
    if (!seenKeys.add(key)) throw SeedBuildException('Powtórzony klucz $key');
    final sourceId = entry['source'] as String?;
    final src = sourceId == null ? null : source[sourceId];
    if (sourceId != null && src == null) {
      throw SeedBuildException('$key: brak $sourceId w danych źródłowych');
    }
    final id = ids.putIfAbsent(key, uuid.v7);

    final name = _requireString(entry, 'name', key);
    final normalized = normalizeForSearch(name);
    final clash = seenNames[normalized];
    if (clash != null) {
      throw SeedBuildException('$key: nazwa koliduje z $clash');
    }
    seenNames[normalized] = key;

    final aliases = _stringList(entry['aliases']);
    final cues = _stringList(entry['cues']);
    if (aliases.isEmpty) throw SeedBuildException('$key: brak aliasów');
    if (cues.length < 2 || cues.length > 4) {
      throw SeedBuildException('$key: wskazówek musi być 2–4');
    }

    final primary = entry['primary'] != null
        ? _codes(MuscleGroup.values, entry['primary'], key)
        : _sourceMuscles(src?['primaryMuscles'], key);
    if (primary.isEmpty) throw SeedBuildException('$key: brak mięśni głównych');
    final secondary =
        (entry['secondary'] != null
                ? _codes(MuscleGroup.values, entry['secondary'], key)
                : _sourceMuscles(src?['secondaryMuscles'], key))
            .where((m) => !primary.contains(m))
            .toList();

    final equipment = entry['equipment'] != null
        ? _code(Equipment.values, entry['equipment'], key)
        : _mapped(_equipmentMap, src?['equipment'], key, 'sprzęt');
    final category = entry['category'] != null
        ? _code(ExerciseCategory.values, entry['category'], key)
        : _mapped(_categoryMap, src?['category'], key, 'kategoria');
    if (category == null) throw SeedBuildException('$key: brak kategorii');
    final mechanic = _code(
      Mechanic.values,
      entry['mechanic'] ?? src?['mechanic'],
      key,
    );
    final force = _code(Force.values, entry['force'] ?? src?['force'], key);

    final measure = entry['measure'] == null
        ? const {'weight', 'reps'}
        : _stringList(entry['measure']).toSet();
    const allowedMeasure = {'weight', 'reps', 'duration', 'distance'};
    if (measure.isEmpty || !allowedMeasure.containsAll(measure)) {
      throw SeedBuildException('$key: niepoprawny pomiar $measure');
    }

    final record = <String, Object?>{
      'id': id,
      'key': key,
      'name': name,
      'aliases': aliases,
      'primaryMuscles': [for (final m in primary) m.code],
      'secondaryMuscles': [for (final m in secondary) m.code],
      'equipment': equipment?.code,
      'category': category.code,
      'mechanic': mechanic?.code,
      'force': force?.code,
      'instructions': cues.join('\n'),
      'measurement': {
        for (final field in ['weight', 'reps', 'duration', 'distance'])
          field: measure.contains(field),
      },
      'loadMode': _code(
        LoadMode.values,
        entry['load'] ?? LoadMode.external.code,
        key,
      )!.code,
      'weightSemantics': _code(
        WeightSemantics.values,
        entry['semantics'] ?? WeightSemantics.total.code,
        key,
      )!.code,
      'isUnilateral': entry['unilateral'] as bool? ?? false,
      'originRef': src != null ? '$sourceName:$sourceId' : 'reptrack:$key',
      'license': src != null ? sourceLicense : null,
      'licenseAuthor': src != null ? sourceAuthor : ownAuthor,
    };

    final before = previousById[id];
    final unchanged =
        before != null &&
        jsonEncode({...before}..remove('rev')) == jsonEncode(record);
    final rev = unchanged ? before['rev'] as int : seedVersion;
    if (!unchanged && before != null && seedVersion <= previousVersion) {
      throw SeedBuildException(
        '$key: treść zmieniona, podbij seed_version (obecnie $seedVersion)',
      );
    }
    if (!unchanged) changed.add(key);
    output.add({
      'id': id,
      'key': key,
      'rev': rev,
      ...record
        ..remove('id')
        ..remove('key'),
    });
  }

  const encoder = JsonEncoder.withIndent('  ');
  idsFile.writeAsStringSync(
    '${encoder.convert(Map.fromEntries(ids.entries.toList()..sort((a, b) => a.key.compareTo(b.key))))}\n',
  );
  outputFile
    ..createSync(recursive: true)
    ..writeAsStringSync(
      '${encoder.convert({
        'formatVersion': 1,
        'seedVersion': seedVersion,
        'source': {'name': sourceName, 'url': sourceUrl, 'commit': sourceCommit, 'license': sourceLicense},
        'exercises': output,
      })}\n',
    );

  print(
    'Zapisano ${output.length} ćwiczeń (seedVersion $seedVersion) do $outputPath.',
  );
  print('Zmienione albo nowe: ${changed.length}.');
}

String _requireString(YamlMap entry, String field, String key) {
  final value = entry[field];
  if (value is! String || value.trim().isEmpty) {
    throw SeedBuildException('$key: brak pola $field');
  }
  return value.trim();
}

List<String> _stringList(Object? raw) => raw == null
    ? const []
    : [for (final v in raw as List<dynamic>) (v as String).trim()];

T? _code<T extends CodedEnum>(List<T> values, Object? raw, String key) {
  if (raw == null) return null;
  final value = tryEnumFromCode(values, raw);
  if (value == null) throw SeedBuildException('$key: nieznany kod $raw');
  return value;
}

List<T> _codes<T extends CodedEnum>(List<T> values, Object? raw, String key) =>
    [for (final v in raw as List<dynamic>) _code(values, v, key)!];

List<MuscleGroup> _sourceMuscles(Object? raw, String key) => [
  for (final m in (raw as List<dynamic>? ?? []))
    _code(MuscleGroup.values, (m as String).replaceAll(' ', '_'), key)!,
];

T? _mapped<T>(Map<String, T> map, Object? raw, String key, String what) {
  if (raw == null) return null;
  final value = map[raw];
  if (value == null) throw SeedBuildException('$key: nieznany $what $raw');
  return value;
}
