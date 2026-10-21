import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../data/program_providers.dart';
import '../domain/program.dart';
import 'program_labels.dart';

/// Biblioteka gotowych programów z filtrami (ADR 0019).
class ProgramsScreen extends ConsumerStatefulWidget {
  const ProgramsScreen({super.key});

  @override
  ConsumerState<ProgramsScreen> createState() => _ProgramsScreenState();
}

class _ProgramsScreenState extends ConsumerState<ProgramsScreen> {
  int? _days;
  ProgramEquipment? _equipment;
  ProgramLevel? _level;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final programs = ref.watch(programLibraryProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.programsTitle)),
      body: switch (programs) {
        AsyncData(:final value) => _list(context, value),
        AsyncError(:final error) => Center(child: Text('$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _list(BuildContext context, List<Program> programs) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final days = {for (final p in programs) p.daysPerWeek}.toList()..sort();
    final shown = [
      for (final p in programs)
        if ((_days == null || p.daysPerWeek == _days) &&
            (_equipment == null || p.equipment == _equipment) &&
            (_level == null || p.level == _level))
          p,
    ];
    Widget filter<T>(
      String title,
      List<T> values,
      T? selected,
      String Function(T) label,
      ValueChanged<T?> onChanged,
    ) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.s,
            runSpacing: AppSpacing.xs,
            children: [
              for (final value in values)
                FilterChip(
                  label: Text(label(value)),
                  selected: value == selected,
                  onSelected: (on) =>
                      setState(() => onChanged(on ? value : null)),
                ),
            ],
          ),
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      children: [
        filter<int>(
          l10n.programsFilterDays,
          days,
          _days,
          l10n.programsDays,
          (v) => _days = v,
        ),
        filter<ProgramEquipment>(
          l10n.programsFilterEquipment,
          ProgramEquipment.values,
          _equipment,
          l10n.programEquipment,
          (v) => _equipment = v,
        ),
        filter<ProgramLevel>(
          l10n.programsFilterLevel,
          ProgramLevel.values,
          _level,
          l10n.programLevel,
          (v) => _level = v,
        ),
        const SizedBox(height: AppSpacing.s),
        if (shown.isEmpty)
          EmptyState(
            icon: Icons.filter_alt_off_outlined,
            title: l10n.programsEmpty,
            message: '',
          ),
        for (final program in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => context.push(AppRoutes.programDetail(program.id)),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.l),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        program.name.of(l10n.localeName),
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l10n.programSummary(program),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        program.description.of(l10n.localeName),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
