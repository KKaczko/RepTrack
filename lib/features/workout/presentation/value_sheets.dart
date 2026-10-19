import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/formatters.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';

/// Najwyższa liczba powtórzeń w siatce; większe wpisuje się z klawiatury.
const _gridMax = 30;

/// Wybór powtórzeń jednym tapnięciem z siatki albo z klawiatury
/// („Inna wartość”). Zwraca null, gdy użytkownik zamknie arkusz.
Future<int?> showRepsPicker(
  BuildContext context, {
  int? current,
  String? title,
}) => showModalBottomSheet<int>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => _RepsPicker(current: current, title: title),
);

class _RepsPicker extends StatefulWidget {
  const _RepsPicker({required this.current, required this.title});

  final int? current;
  final String? title;

  @override
  State<_RepsPicker> createState() => _RepsPickerState();
}

class _RepsPickerState extends State<_RepsPicker> {
  final _other = TextEditingController();

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  void _submitOther() {
    final value = parseCount(_other.text);
    if (value != null) Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = context.appColors;
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
              widget.title ?? l10n.workoutRepsPickerTitle,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.m),
            GridView.count(
              crossAxisCount: 6,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.s,
              crossAxisSpacing: AppSpacing.s,
              childAspectRatio: 1.1,
              children: [
                for (var n = 1; n <= _gridMax; n++)
                  Material(
                    color: n == widget.current
                        ? colors.accentFill
                        : colors.surfaceRaised,
                    borderRadius: BorderRadius.circular(AppRadius.s),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.s),
                      onTap: () => Navigator.of(context).pop(n),
                      child: Center(
                        child: Text(
                          '$n',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontFeatures: AppTheme.tabularFigures,
                            color: n == widget.current
                                ? colors.onAccentFill
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.l),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _other,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submitOther(),
                    decoration: InputDecoration(
                      labelText: l10n.workoutOtherValue,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                FilledButton(
                  onPressed: _submitOther,
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

/// Wpis wartości z klawiatury. Zwraca wpisany tekst (do sparsowania przez
/// wywołującego) albo null po zamknięciu arkusza.
Future<String?> showValueInput(
  BuildContext context, {
  required String title,
  required String initial,
  required bool decimal,
  String? suffix,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => _ValueInput(
    title: title,
    initial: initial,
    decimal: decimal,
    suffix: suffix,
  ),
);

class _ValueInput extends StatefulWidget {
  const _ValueInput({
    required this.title,
    required this.initial,
    required this.decimal,
    required this.suffix,
  });

  final String title;
  final String initial;
  final bool decimal;
  final String? suffix;

  @override
  State<_ValueInput> createState() => _ValueInputState();
}

class _ValueInputState extends State<_ValueInput> {
  late final _controller = TextEditingController(text: widget.initial)
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initial.length,
    );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.gutter + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.m),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  keyboardType: TextInputType.numberWithOptions(
                    decimal: widget.decimal,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(widget.decimal ? '[0-9.,]' : '[0-9]'),
                    ),
                  ],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (value) => Navigator.of(context).pop(value),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontFeatures: AppTheme.tabularFigures,
                  ),
                  decoration: InputDecoration(suffixText: widget.suffix),
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(_controller.text),
                child: Text(l10n.workoutValueDone),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
