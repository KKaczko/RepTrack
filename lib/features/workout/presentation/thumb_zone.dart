import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../../core/domain/training.dart';
import '../../../core/domain/units.dart';
import '../../../core/l10n/formatters.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/ticker_builder.dart';
import '../domain/rest_timer.dart';
import '../domain/set_hints.dart';
import '../domain/workout_session.dart';
import 'workout_labels.dart';

/// Główny przycisk strefy kciuka.
final class PrimaryAction {
  const PrimaryAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.emphasized = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  /// Wypełniony akcentem; inaczej obrysowany (np. „Cofnij serię”).
  final bool emphasized;
}

/// Strefa kciuka (docs/ux.md): timer przerwy, steppery wybranej serii,
/// wysiłek i główny przycisk. Główny przycisk nie zmienia położenia, gdy
/// pojawia się timer przerwy.
class ThumbZone extends StatelessWidget {
  const ThumbZone({
    required this.exercise,
    required this.set,
    required this.hint,
    required this.unit,
    required this.effortScale,
    required this.restEndsAt,
    required this.primary,
    required this.onStep,
    required this.onEditValue,
    required this.onEffort,
    required this.onRestAdjust,
    required this.onRestSkip,
    super.key,
  });

  final SessionExercise? exercise;
  final SessionSet? set;
  final SetHint? hint;
  final WeightUnit unit;
  final EffortScale? effortScale;
  final DateTime? restEndsAt;
  final PrimaryAction primary;
  final void Function(SetField field, int direction) onStep;
  final ValueChanged<SetField> onEditValue;
  final ValueChanged<int?> onEffort;
  final ValueChanged<Duration> onRestAdjust;
  final VoidCallback onRestSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exercise = this.exercise;
    final set = this.set;
    final hint = this.hint;
    final fields = exercise == null
        ? const <SetField>[]
        : measuredFields(exercise.measurementSnapshot);
    final scale = effortScale;

    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.s,
            AppSpacing.gutter,
            AppSpacing.m,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (restEndsAt case final endsAt?)
                RestBar(
                  endsAt: endsAt,
                  onAdjust: onRestAdjust,
                  onSkip: onRestSkip,
                ),
              if (set != null && hint != null)
                for (var i = 0; i < fields.length; i += 2)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.s),
                    child: Row(
                      children: [
                        for (final (j, field) in fields.skip(i).take(2).indexed)
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                left: j == 0 ? 0 : AppSpacing.s,
                              ),
                              child: _FieldStepper(
                                field: field,
                                set: set,
                                hint: hint,
                                unit: unit,
                                onStep: (direction) => onStep(field, direction),
                                onTap: () => onEditValue(field),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              if (set != null && scale != null)
                _EffortChips(scale: scale, set: set, onSelected: onEffort),
              SizedBox(
                height: AppSizes.primaryAction,
                child: primary.emphasized
                    ? FilledButton.icon(
                        onPressed: primary.onPressed,
                        icon: Icon(primary.icon),
                        label: Text(primary.label),
                      )
                    : OutlinedButton.icon(
                        onPressed: primary.onPressed,
                        icon: Icon(primary.icon),
                        label: Text(primary.label),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldStepper extends StatelessWidget {
  const _FieldStepper({
    required this.field,
    required this.set,
    required this.hint,
    required this.unit,
    required this.onStep,
    required this.onTap,
  });

  final SetField field;
  final SessionSet set;
  final SetHint hint;
  final WeightUnit unit;
  final ValueChanged<int> onStep;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = context.appColors;
    final locale = Localizations.localeOf(context).toString();
    final entered = setValue(set, field);
    final hinted = hintValue(hint, field);
    final value = entered ?? hinted?.value;
    final isHint = entered == null;
    final name = l10n.fieldLabel(field);
    final label = field == SetField.weight
        ? '$name (${weightUnitLabel(unit)})'
        : name;
    final spoken = value == null
        ? name
        : isHint && hinted?.source == HintSource.progression
        ? l10n.workoutProgressionHintSemantics(
            name,
            l10n.fieldValueWithUnit(field, value, unit, locale),
          )
        : isHint
        ? l10n.workoutHintSemantics(
            name,
            l10n.fieldValueWithUnit(field, value, unit, locale),
          )
        : l10n.workoutValueSemantics(
            name,
            l10n.fieldValueWithUnit(field, value, unit, locale),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Material(
          color: colors.surfaceRaised,
          borderRadius: BorderRadius.circular(AppRadius.s),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: AppSizes.stepper,
            child: Row(
              children: [
                _StepButton(
                  icon: Icons.remove_rounded,
                  tooltip: l10n.workoutDecrease(name),
                  onPressed: () => onStep(-1),
                ),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: spoken,
                    excludeSemantics: true,
                    child: InkWell(
                      key: ValueKey('workout-value-${field.name}'),
                      onTap: onTap,
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            value == null
                                ? '—'
                                : l10n.fieldValue(field, value, unit, locale),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontFeatures: AppTheme.tabularFigures,
                              fontWeight: isHint
                                  ? FontWeight.w400
                                  : FontWeight.w700,
                              color: isHint ? colors.textHint : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _StepButton(
                  icon: Icons.add_rounded,
                  tooltip: l10n.workoutIncrease(name),
                  onPressed: () => onStep(1),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: AppSizes.minTouch,
    height: AppSizes.stepper,
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        shape: const RoundedRectangleBorder(),
        minimumSize: const Size(AppSizes.minTouch, AppSizes.stepper),
      ),
    ),
  );
}

class _EffortChips extends StatelessWidget {
  const _EffortChips({
    required this.scale,
    required this.set,
    required this.onSelected,
  });

  final EffortScale scale;
  final SessionSet set;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final choices = switch (scale) {
      EffortScale.rir => rirChoices,
      EffortScale.rpe => rpeChoices,
    };
    final current = set.effortScale == scale ? set.effortTenths : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: Row(
        children: [
          Text(
            l10n.effortScaleLabel(scale),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final tenths in choices)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: ChoiceChip(
                        showCheckmark: false,
                        visualDensity: VisualDensity.compact,
                        labelPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                        ),
                        label: Text(formatDecimal(tenths / 10, locale)),
                        tooltip: l10n.workoutEffortLabel(
                          l10n.effortScaleLabel(scale),
                        ),
                        selected: current == tenths,
                        onSelected: (_) =>
                            onSelected(current == tenths ? null : tenths),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pasek przerwy: odliczanie, ±15 s i pominięcie. Po końcu przerwy na
/// ekranie telefon wibruje; przy zablokowanym ekranie alarm daje
/// powiadomienie (ADR 0009).
class RestBar extends ConsumerStatefulWidget {
  const RestBar({
    required this.endsAt,
    required this.onAdjust,
    required this.onSkip,
    super.key,
  });

  final DateTime endsAt;
  final ValueChanged<Duration> onAdjust;
  final VoidCallback onSkip;

  @override
  ConsumerState<RestBar> createState() => _RestBarState();
}

class _RestBarState extends ConsumerState<RestBar> {
  /// Koniec przerwy, której odliczanie było widoczne.
  DateTime? _running;

  @override
  Widget build(BuildContext context) => TickerBuilder(
    builder: (context) {
      final now = ref.read(clockProvider).nowUtc();
      final left = restRemaining(widget.endsAt, now);
      if (left == Duration.zero) {
        if (_running == widget.endsAt) {
          _running = null;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => HapticFeedback.vibrate(),
          );
        }
        return const SizedBox.shrink();
      }
      _running = widget.endsAt;
      return _buildBar(context, left);
    },
  );

  Widget _buildBar(BuildContext context, Duration left) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = context.appColors;
    final seconds = (left.inMilliseconds + 999) ~/ 1000;
    const compact = ButtonStyle(
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: AppSpacing.s),
      ),
      minimumSize: WidgetStatePropertyAll(
        Size(AppSizes.minTouch, AppSizes.minTouch),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, color: colors.accentFill),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: Semantics(
              liveRegion: false,
              label: '${l10n.workoutRest} ${formatClock(seconds)}',
              excludeSemantics: true,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '${l10n.workoutRest} '),
                    TextSpan(
                      text: formatClock(seconds),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFeatures: AppTheme.tabularFigures,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Tooltip(
            message: l10n.workoutRestMinus,
            child: TextButton(
              style: compact,
              onPressed: () => widget.onAdjust(-restAdjustStep),
              child: const Text('−15'),
            ),
          ),
          Tooltip(
            message: l10n.workoutRestPlus,
            child: TextButton(
              style: compact,
              onPressed: () => widget.onAdjust(restAdjustStep),
              child: const Text('+15'),
            ),
          ),
          TextButton(
            style: compact,
            onPressed: widget.onSkip,
            child: Text(l10n.workoutRestSkip),
          ),
        ],
      ),
    );
  }
}
