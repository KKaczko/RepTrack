import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/domain/training.dart';
import '../../../core/domain/units.dart';
import '../../../core/l10n/formatters.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../exercises/domain/exercise.dart';
import '../../workout/domain/workout_session.dart';
import '../domain/session_corrections.dart';

/// Wynik edycji serii w historii.
sealed class SetEditResult {
  const SetEditResult();
}

final class SetEditSaved extends SetEditResult {
  const SetEditSaved(this.set);

  final SessionSet set;
}

final class SetEditRemoved extends SetEditResult {
  const SetEditRemoved();
}

/// Arkusz korekty serii zakończonego treningu: wartości, wysiłek,
/// zatwierdzenie i usunięcie. Puste pole czyści wartość.
Future<SetEditResult?> showSetEditSheet(
  BuildContext context, {
  required SessionSet set,
  required Measurement measurement,
  required WeightUnit unit,
  required EffortScale? effortScale,
  required WorkoutSession session,
}) => showModalBottomSheet<SetEditResult>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => _SetEditSheet(
    set: set,
    measurement: measurement,
    unit: unit,
    effortScale: effortScale,
    session: session,
  ),
);

class _SetEditSheet extends StatefulWidget {
  const _SetEditSheet({
    required this.set,
    required this.measurement,
    required this.unit,
    required this.effortScale,
    required this.session,
  });

  final SessionSet set;
  final Measurement measurement;
  final WeightUnit unit;
  final EffortScale? effortScale;
  final WorkoutSession session;

  @override
  State<_SetEditSheet> createState() => _SetEditSheetState();
}

class _SetEditSheetState extends State<_SetEditSheet> {
  final _weight = TextEditingController();
  late final _reps = TextEditingController(
    text: widget.set.reps?.toString() ?? '',
  );
  late final _duration = TextEditingController(
    text: widget.set.durationS?.toString() ?? '',
  );
  late final _distance = TextEditingController(
    text: widget.set.distanceM?.toString() ?? '',
  );
  final _effort = TextEditingController();
  late bool _logged = widget.set.isCompleted;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final locale = Localizations.localeOf(context).toString();
    final set = widget.set;
    if (set.weightG case final grams?) {
      _weight.text = formatWeightValue(grams, widget.unit, locale);
    }
    if (set.effortTenths case final tenths?) {
      _effort.text = formatDecimal(tenths / 10, locale);
    }
  }

  @override
  void dispose() {
    for (final c in [_weight, _reps, _duration, _distance, _effort]) {
      c.dispose();
    }
    super.dispose();
  }

  void _done() {
    final m = widget.measurement;
    final effort = parseDecimal(_effort.text);
    final scale = widget.effortScale;
    final hasEffort = effort != null && effort >= 0 && scale != null;
    final set = widget.set.copyWith(
      weightG: m.weight ? parseWeight(_weight.text, widget.unit) : null,
      reps: m.reps ? parseCount(_reps.text) : null,
      durationS: m.duration ? parseCount(_duration.text) : null,
      distanceM: m.distance ? parseCount(_distance.text) : null,
      effortScale: hasEffort ? scale : null,
      effortTenths: hasEffort ? (effort * 10).round() : null,
    );
    Navigator.of(context)
        .pop(SetEditSaved(setLogged(set, widget.session, logged: _logged)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final m = widget.measurement;
    final scale = widget.effortScale;

    Widget field(
      TextEditingController controller,
      String label, {
      bool decimal = false,
      String? suffix,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.m),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        inputFormatters: [
          FilteringTextInputFormatter.allow(
            RegExp(decimal ? '[0-9.,]' : '[0-9]'),
          ),
        ],
        decoration: InputDecoration(labelText: label, suffixText: suffix),
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.gutter + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.sessionEditSet(widget.set.position + 1),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.m),
            if (m.weight)
              field(
                _weight,
                l10n.measureWeight,
                decimal: true,
                suffix: weightUnitLabel(widget.unit),
              ),
            if (m.reps) field(_reps, l10n.measureReps),
            if (m.duration)
              field(
                _duration,
                l10n.measureDuration,
                suffix: l10n.workoutUnitSeconds,
              ),
            if (m.distance)
              field(
                _distance,
                l10n.measureDistance,
                suffix: l10n.workoutUnitMeters,
              ),
            if (scale != null)
              field(
                _effort,
                l10n.workoutEffortLabel(
                  scale == EffortScale.rpe ? l10n.effortRpe : l10n.effortRir,
                ),
                decimal: true,
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.sessionSetCompleted),
              value: _logged,
              onChanged: (value) => setState(() => _logged = value),
            ),
            const SizedBox(height: AppSpacing.s),
            // Przy dużej czcionce przyciski przechodzą jeden pod drugi.
            OverflowBar(
              alignment: MainAxisAlignment.spaceBetween,
              overflowAlignment: OverflowBarAlignment.end,
              overflowSpacing: AppSpacing.s,
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  onPressed: () =>
                      Navigator.of(context).pop(const SetEditRemoved()),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: Text(l10n.workoutRemoveSet),
                ),
                FilledButton(
                  onPressed: _done,
                  child: Text(l10n.workoutValueDone),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
