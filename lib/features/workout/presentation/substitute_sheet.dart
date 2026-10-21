import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../exercises/data/exercise_providers.dart';
import '../../exercises/domain/exercise.dart';
import '../../exercises/domain/substitutes.dart';
import '../../exercises/presentation/exercise_labels.dart';

/// Wybór w arkuszu zamienników: konkretne ćwiczenie albo pełna biblioteka.
sealed class SubstituteChoice {
  const SubstituteChoice();
}

final class SubstitutePicked extends SubstituteChoice {
  const SubstitutePicked(this.exercise);

  final Exercise exercise;
}

final class SubstituteLibrary extends SubstituteChoice {
  const SubstituteLibrary();
}

/// Arkusz zamienników (ADR 0016) nad dolną nawigacją: przypięte na górze,
/// potem propozycje; ★ przypina albo odpina od razu.
Future<SubstituteChoice?> showSubstituteSheet(
  BuildContext context, {
  required Exercise target,
  required List<Exercise> catalog,
  required Set<String> used,
}) => showModalBottomSheet<SubstituteChoice>(
  context: context,
  useRootNavigator: true,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (context) =>
      _SubstituteSheet(target: target, catalog: catalog, used: used),
);

class _SubstituteSheet extends ConsumerStatefulWidget {
  const _SubstituteSheet({
    required this.target,
    required this.catalog,
    required this.used,
  });

  final Exercise target;
  final List<Exercise> catalog;
  final Set<String> used;

  @override
  ConsumerState<_SubstituteSheet> createState() => _SubstituteSheetState();
}

class _SubstituteSheetState extends ConsumerState<_SubstituteSheet> {
  /// Kolejność z chwili otwarcia: ★ zmienia tylko oznaczenie, a wiersz nie
  /// ucieka na górę listy. Nowa kolejność obowiązuje przy kolejnym otwarciu.
  List<String>? _order;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final target = widget.target;
    final pins = ref.watch(substitutePinsProvider).value;
    final current = suggestSubstitutes(
      target,
      widget.catalog,
      pinned: pinnedFor(target.id, pins ?? const []),
      used: widget.used,
    );
    if (pins != null) _order ??= [for (final s in current) s.exercise.id];
    final order = _order;
    final substitutes = order == null
        ? current
        : [
            for (final id in order) ?current.byExerciseId(id),
            for (final s in current)
              if (!order.contains(s.exercise.id)) s,
          ];
    // Odpięty spoza propozycji znika z listy dopiero po zamknięciu.
    final shown = [
      for (final s in substitutes) s,
      if (order != null)
        for (final id in order)
          if (current.byExerciseId(id) == null)
            if (widget.catalog.firstWhereOrNull((e) => e.id == id)
                case final e?)
              (exercise: e, pinned: false, reasons: <SubstituteReason>{}),
    ];
    final repo = ref.read(substituteRepositoryProvider);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gutter,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.substitutesTitle(target.name),
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.substitutesHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (shown.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.gutter),
                      child: Text(l10n.substitutesEmpty),
                    ),
                  for (final substitute in shown)
                    ListTile(
                      title: Text(substitute.exercise.name),
                      subtitle: Text(l10n.substituteSubtitle(substitute)),
                      isThreeLine: true,
                      trailing: IconButton(
                        tooltip: substitute.pinned
                            ? l10n.substituteUnpin(substitute.exercise.name)
                            : l10n.substitutePin(substitute.exercise.name),
                        icon: Icon(
                          substitute.pinned
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: substitute.pinned
                              ? theme.colorScheme.primary
                              : null,
                        ),
                        onPressed: () => unawaited(
                          substitute.pinned
                              ? repo.unpin(target.id, substitute.exercise.id)
                              : repo.pin(target.id, substitute.exercise.id),
                        ),
                      ),
                      onTap: () =>
                          Navigator.of(context)
                              .pop(SubstitutePicked(substitute.exercise)),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s,
                AppSpacing.xs,
                AppSpacing.s,
                AppSpacing.s,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.search_rounded),
                  label: Text(l10n.substitutesLibrary),
                  onPressed: () =>
                      Navigator.of(context).pop(const SubstituteLibrary()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
