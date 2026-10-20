import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Zmiana wartości kafelka względem poprzedniego okresu. Kierunek ma też
/// strzałkę i znak, więc nie zależy tylko od koloru.
final class StatDelta {
  const StatDelta({
    required this.direction,
    required this.text,
    required this.semantics,
  });

  /// 1 wzrost, -1 spadek, 0 bez zmian.
  final int direction;

  /// Krótki tekst, np. „+2” albo „−8%”.
  final String text;

  /// Opis dla czytnika ekranu, np. „Wzrost o 2”.
  final String semantics;
}

/// Kafelek liczby: etykieta, wartość i opcjonalna zmiana.
class StatTile extends StatelessWidget {
  const StatTile({
    required this.label,
    required this.value,
    this.delta,
    super.key,
  });

  final String label;
  final String value;
  final StatDelta? delta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final delta = this.delta;
    final (icon, color) = switch (delta?.direction) {
      1 => (Icons.arrow_upward_rounded, context.appColors.success),
      -1 => (Icons.arrow_downward_rounded, theme.colorScheme.error),
      _ => (Icons.remove_rounded, theme.colorScheme.onSurfaceVariant),
    };
    return Semantics(
      container: true,
      label: [label, value, ?delta?.semantics].join(', '),
      excludeSemantics: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (delta != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: AppSpacing.xxs),
                    Flexible(
                      child: Text(
                        delta.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontFeatures: AppTheme.tabularFigures,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kafelki w dwóch kolumnach; kafelki w rzędzie mają równą wysokość.
class StatGrid extends StatelessWidget {
  const StatGrid({required this.tiles, super.key});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < tiles.length; i += 2)
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : AppSpacing.s),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tiles[i]),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: i + 1 < tiles.length
                      ? tiles[i + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}
