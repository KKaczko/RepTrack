import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/domain/coded_enum.dart';
import '../../../core/domain/local_date.dart';

part 'plan.freezed.dart';

/// Plan treningów (ADR 0015): plan tygodniowy w wersjach i wpisy na
/// pojedyncze daty, które zastępują plan tygodniowy danego dnia.

/// Rodzaj wpisu na datę.
enum PlannedKind implements CodedEnum {
  /// Trening z szablonu.
  workout('workout'),

  /// Dzień wolny: sam zastępuje plan tygodniowy (pominięcie dnia).
  rest('rest');

  const PlannedKind(this.code);

  @override
  final String code;
}

/// Wersja planu tygodniowego, obowiązująca od [startsOn] do [endsOn]
/// włącznie (null: bez końca). Edycja działającego planu zamyka wersję
/// i zaczyna nową, więc przeszłe dni zachowują swój plan.
@freezed
abstract class WeeklyPlan with _$WeeklyPlan {
  const factory WeeklyPlan({
    required String id,
    required LocalDate startsOn,
    LocalDate? endsOn,
    @Default(<WeeklyPlanDay>[]) List<WeeklyPlanDay> days,
  }) = _WeeklyPlan;

  const WeeklyPlan._();

  bool covers(LocalDate date) =>
      date.compareTo(startsOn) >= 0 &&
      (endsOn == null || date.compareTo(endsOn!) <= 0);
}

/// Trening w dniu tygodnia ([weekday] 1 = poniedziałek … 7 = niedziela).
@freezed
abstract class WeeklyPlanDay with _$WeeklyPlanDay {
  const factory WeeklyPlanDay({
    required String id,
    required int weekday,
    required String templateId,
    required int position,
  }) = _WeeklyPlanDay;
}

/// Wpis na datę: trening z szablonu albo dzień wolny.
@freezed
abstract class PlannedDay with _$PlannedDay {
  const factory PlannedDay({
    required String id,
    required LocalDate date,
    required PlannedKind kind,
    String? templateId,
    required int position,
    String? note,
  }) = _PlannedDay;
}

/// Cały plan: wersje planu tygodniowego i wpisy na daty (bez usuniętych).
typedef PlanState = ({List<WeeklyPlan> weekly, List<PlannedDay> days});

const PlanState emptyPlan = (weekly: [], days: []);
