import '../domain/glossary.dart';
import 'generated/app_localizations.dart';

/// Teksty słowniczka.
extension GlossaryLabels on AppLocalizations {
  String glossaryGroup(GlossaryGroup group) => switch (group) {
    GlossaryGroup.basics => glossaryGroupBasics,
    GlossaryGroup.effort => glossaryGroupEffort,
    GlossaryGroup.metrics => glossaryGroupMetrics,
    GlossaryGroup.progress => glossaryGroupProgress,
  };

  String glossaryTermTitle(GlossaryTerm term) => switch (term) {
    GlossaryTerm.rep => glossaryRepTitle,
    GlossaryTerm.set => glossarySetTitle,
    GlossaryTerm.warmupSet => glossaryWarmupTitle,
    GlossaryTerm.workingSet => glossaryWorkingTitle,
    GlossaryTerm.muscleRoles => glossaryMusclesTitle,
    GlossaryTerm.loadMode => glossaryLoadModeTitle,
    GlossaryTerm.rir => glossaryRirTitle,
    GlossaryTerm.rpe => glossaryRpeTitle,
    GlossaryTerm.oneRepMax => glossaryOneRmTitle,
    GlossaryTerm.estimatedOneRepMax => glossaryE1rmTitle,
    GlossaryTerm.volume => glossaryVolumeTitle,
    GlossaryTerm.record => glossaryRecordTitle,
    GlossaryTerm.bestSet => glossaryBestSetTitle,
    GlossaryTerm.setsPerMuscle => glossarySetsPerMuscleTitle,
    GlossaryTerm.periodChange => glossaryPeriodChangeTitle,
    GlossaryTerm.progressiveOverload => glossaryOverloadTitle,
    GlossaryTerm.superset => glossarySupersetTitle,
    GlossaryTerm.doubleProgression => glossaryDoubleProgressionTitle,
  };

  String glossaryTermBody(GlossaryTerm term) => switch (term) {
    GlossaryTerm.rep => glossaryRepBody,
    GlossaryTerm.set => glossarySetBody,
    GlossaryTerm.warmupSet => glossaryWarmupBody,
    GlossaryTerm.workingSet => glossaryWorkingBody,
    GlossaryTerm.muscleRoles => glossaryMusclesBody,
    GlossaryTerm.loadMode => glossaryLoadModeBody,
    GlossaryTerm.rir => glossaryRirBody,
    GlossaryTerm.rpe => glossaryRpeBody,
    GlossaryTerm.oneRepMax => glossaryOneRmBody,
    GlossaryTerm.estimatedOneRepMax => glossaryE1rmBody,
    GlossaryTerm.volume => glossaryVolumeBody,
    GlossaryTerm.record => glossaryRecordBody,
    GlossaryTerm.bestSet => glossaryBestSetBody,
    GlossaryTerm.setsPerMuscle => glossarySetsPerMuscleBody,
    GlossaryTerm.periodChange => glossaryPeriodChangeBody,
    GlossaryTerm.progressiveOverload => glossaryOverloadBody,
    GlossaryTerm.superset => glossarySupersetBody,
    GlossaryTerm.doubleProgression => glossaryDoubleProgressionBody,
  };
}
