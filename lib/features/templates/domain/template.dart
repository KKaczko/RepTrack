import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/domain/training.dart';

part 'template.freezed.dart';

/// Szablon treningu (plan). Zmiany szablonu nigdy nie modyfikują sesji.
@freezed
abstract class Template with _$Template {
  const factory Template({
    required String id,
    required String name,
    String? description,
    DateTime? archivedAt,
    @Default(<TemplateExercise>[]) List<TemplateExercise> exercises,
  }) = _Template;

  const Template._();

  bool get isArchived => archivedAt != null;
}

/// Ćwiczenie w szablonie ze wspólnym celem dla wszystkich serii.
///
/// Liczba serii to długość [sets] (ADR 0004). Wartości wspólne obowiązują
/// każdą serię, której pole w [TemplateSet] jest równe null.
@freezed
abstract class TemplateExercise with _$TemplateExercise {
  const factory TemplateExercise({
    required String id,
    required String exerciseId,
    required int position,
    @Default(TargetKind.reps) TargetKind targetKind,
    int? targetMin,
    int? targetMax,
    int? targetWeightG,
    int? restSeconds,
    @Default(SetType.working) SetType defaultSetType,
    String? note,
    String? groupId,
    @Default(<TemplateSet>[]) List<TemplateSet> sets,
  }) = _TemplateExercise;

  const TemplateExercise._();

  int get setCount => sets.length;
}

/// Seria szablonu. Pole równe null dziedziczy wartość z [TemplateExercise].
/// Cel ([targetMin], [targetMax]) jest nadpisywany zawsze w parze.
@freezed
abstract class TemplateSet with _$TemplateSet {
  const factory TemplateSet({
    required String id,
    required int position,
    SetType? setType,
    int? targetMin,
    int? targetMax,
    int? targetWeightG,
    int? restSeconds,
  }) = _TemplateSet;

  const TemplateSet._();

  bool get overridesTarget => targetMin != null || targetMax != null;

  bool get hasOverrides =>
      setType != null ||
      overridesTarget ||
      targetWeightG != null ||
      restSeconds != null;
}
