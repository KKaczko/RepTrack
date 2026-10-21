import '../../../core/domain/units.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../backup/presentation/export_labels.dart';
import '../../exercises/presentation/exercise_labels.dart';
import '../../history/presentation/history_labels.dart';
import '../../plan/presentation/plan_labels.dart';
import '../domain/assistant_context.dart';

/// Teksty kontekstu asystenta w języku aplikacji.
AssistantContextLabels assistantContextLabels(
  AppLocalizations l10n,
  WeightUnit unit, {
  String? locale,
}) => AssistantContextLabels(
  export: exportLabels(l10n, unit, title: l10n.assistantCtxRecent),
  title: l10n.assistantCtxTitle,
  intro: l10n.assistantCtxIntro,
  summary: l10n.assistantCtxSummary,
  before: l10n.assistantCtxBefore,
  workouts: l10n.progressWorkouts,
  sets: l10n.progressSets,
  volume: l10n.progressVolume,
  time: l10n.progressTime,
  duration: l10n.duration,
  muscles: l10n.assistantCtxMuscles,
  musclesNone: l10n.assistantCtxMusclesNone,
  muscle: l10n.muscle,
  exercises: l10n.assistantCtxExercises,
  e1rm: l10n.progressE1rm,
  maxReps: l10n.progressMaxReps,
  maxDuration: l10n.progressMaxDuration,
  repsUnit: l10n.workoutUnitReps,
  change: l10n.progressChange,
  bestSet: l10n.progressBestSet,
  exerciseWorkouts: l10n.progressExerciseWorkouts,
  last: l10n.assistantCtxLast,
  session: l10n.assistantCtxSession,
  compare: l10n.assistantCtxCompare,
  previous: l10n.assistantCtxPrevious,
  now: l10n.assistantCtxNow,
  firstTime: l10n.assistantCtxFirstTime,
  records: l10n.assistantCtxRecords,
  noRecords: l10n.assistantCtxNoRecords,
  repsAtLeast: l10n.recordsRepsAtLeast,
  template: l10n.assistantCtxTemplate,
  plan: l10n.assistantCtxPlan,
  rest: l10n.templateRestSummary,
  history: l10n.assistantCtxHistory,
  noHistory: l10n.assistantCtxNoHistory,
  planSection: l10n.assistantCtxPlanSection,
  planWeek: l10n.assistantCtxPlanWeek,
  planStreak: l10n.assistantCtxPlanStreak,
  planUpcoming: l10n.assistantCtxPlanUpcoming,
  planWeekly: l10n.assistantCtxPlanWeekly,
  planRest: l10n.assistantCtxPlanRest,
  planExtra: l10n.assistantCtxPlanExtra,
  planStatus: l10n.planStatus,
  weekday: (weekday) => weekdayName(weekday, locale ?? l10n.localeName),
  templates: l10n.assistantCtxTemplates,
  noWorkouts: l10n.assistantCtxNoWorkouts,
);
