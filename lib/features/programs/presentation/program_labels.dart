import '../../../core/l10n/generated/app_localizations.dart';
import '../domain/program.dart';

/// Teksty gotowych programów (ADR 0019).
extension ProgramLabels on AppLocalizations {
  String programLevel(ProgramLevel level) => switch (level) {
    ProgramLevel.beginner => programLevelBeginner,
    ProgramLevel.intermediate => programLevelIntermediate,
  };

  String programEquipment(ProgramEquipment equipment) => switch (equipment) {
    ProgramEquipment.gym => programEquipmentGym,
    ProgramEquipment.dumbbells => programEquipmentDumbbells,
    ProgramEquipment.bodyweight => programEquipmentBodyweight,
  };

  /// „3× w tygodniu · siłownia · początkujący”.
  String programSummary(Program program) => programMeta(
    program.daysPerWeek,
    programEquipment(program.equipment),
    programLevel(program.level),
  );
}
