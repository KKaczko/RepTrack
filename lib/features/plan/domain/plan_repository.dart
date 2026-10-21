import '../../../core/domain/local_date.dart';
import 'plan.dart';

abstract interface class PlanRepository {
  /// Cały plan; nowa wartość po każdej zmianie.
  Stream<PlanState> watch();

  Future<PlanState> load();

  /// Zapisuje wersje planu tygodniowego (z dniami); wersje z [delete]
  /// usuwa (miękko).
  Future<void> saveWeekly({
    required List<WeeklyPlan> save,
    List<String> delete = const [],
  });

  /// Zastępuje wpisy dla [date]; pusta lista przywraca plan tygodniowy.
  Future<void> setDay(LocalDate date, List<PlannedDay> entries);

  /// Zastępuje wpisy kilku dat w jednej transakcji: przy błędzie żadna
  /// data się nie zmienia (np. przeniesienie treningu i jego cofnięcie).
  Future<void> setDays(Map<LocalDate, List<PlannedDay>> changes);
}
