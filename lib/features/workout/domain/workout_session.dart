import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/domain/coded_enum.dart';
import '../../../core/domain/local_date.dart';
import '../../../core/domain/training.dart';
import '../../exercises/domain/exercise.dart';

part 'workout_session.freezed.dart';

/// Stan sesji. Najwyżej jedna sesja może być aktywna (wymusza to indeks
/// w bazie, który zależy od kodu `active`).
enum SessionStatus implements CodedEnum {
  active('active'),
  completed('completed'),
  discarded('discarded');

  const SessionStatus(this.code);

  @override
  final String code;
}

/// Strona ciała dla ćwiczeń jednostronnych. W MVP seria oznacza obie strony.
enum Side implements CodedEnum {
  both('both'),
  left('left'),
  right('right');

  const Side(this.code);

  @override
  final String code;
}

/// Rzeczywiste wykonanie treningu: niezależna kopia planu z chwili startu.
@freezed
abstract class WorkoutSession with _$WorkoutSession {
  const factory WorkoutSession({
    required String id,
    required SessionStatus status,
    required DateTime startedAt,
    DateTime? endedAt,

    /// Strefa IANA zapisana przy starcie sesji.
    required String timeZone,

    /// Lokalna data rozpoczęcia w [timeZone].
    required LocalDate localDate,
    String? templateId,
    String? templateNameSnapshot,
    String? title,
    String? notes,

    /// Samopoczucie w skali 1–5.
    int? wellbeing,

    /// Koniec bieżącej przerwy; pozwala odtworzyć timer po ubiciu procesu.
    DateTime? restEndsAt,
    @Default(<SessionExercise>[]) List<SessionExercise> exercises,
  }) = _WorkoutSession;

  const WorkoutSession._();

  bool get isActive => status == SessionStatus.active;
}

/// Ćwiczenie w sesji ze snapshotem nazwy i ustawień pomiaru z chwili dodania.
@freezed
abstract class SessionExercise with _$SessionExercise {
  const factory SessionExercise({
    required String id,
    required String exerciseId,
    required int position,
    String? templateExerciseId,
    required String exerciseNameSnapshot,
    required Measurement measurementSnapshot,
    required LoadMode loadModeSnapshot,
    required WeightSemantics weightSemanticsSnapshot,
    required bool isUnilateralSnapshot,
    String? note,
    String? groupId,
    @Default(<SessionSet>[]) List<SessionSet> sets,
  }) = _SessionExercise;
}

/// Seria w sesji: snapshot planu i wykonanie. Seria jest wykonana wtedy
/// i tylko wtedy, gdy [completedAt] nie jest null.
@freezed
abstract class SessionSet with _$SessionSet {
  const factory SessionSet({
    required String id,
    required int position,
    @Default(SetType.working) SetType setType,
    TargetKind? targetKind,
    int? targetMin,
    int? targetMax,
    int? targetWeightG,
    int? restSeconds,
    int? weightG,
    int? reps,
    int? durationS,
    int? distanceM,
    EffortScale? effortScale,

    /// Wysiłek w dziesiątych częściach, np. RPE 8,5 → 85.
    int? effortTenths,
    Side? side,
    DateTime? completedAt,
  }) = _SessionSet;

  const SessionSet._();

  bool get isCompleted => completedAt != null;
}
