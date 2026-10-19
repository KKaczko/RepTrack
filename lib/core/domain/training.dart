/// Typy wspólne dla szablonów i sesji. Kody (`code`) są zapisywane w bazie
/// i backupie, więc nie wolno ich zmieniać (ADR 0013).
library;

import 'coded_enum.dart';

/// Typ serii. Serie rozgrzewkowe są wykluczone z objętości i rekordów.
enum SetType implements CodedEnum {
  warmup('warmup'),
  working('working'),
  drop('drop'),
  amrap('amrap');

  const SetType(this.code);

  @override
  final String code;
}

/// Rodzaj celu serii: zakres powtórzeń albo czasu (w sekundach).
enum TargetKind implements CodedEnum {
  reps('reps'),
  duration('duration');

  const TargetKind(this.code);

  @override
  final String code;
}

/// Skala wysiłku zapisywana przy serii.
enum EffortScale implements CodedEnum {
  rir('rir'),
  rpe('rpe');

  const EffortScale(this.code);

  @override
  final String code;
}
