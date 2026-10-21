import 'package:flutter/material.dart';

import '../l10n/formatters.dart';
import '../l10n/generated/app_localizations.dart';

/// Najkrótsza i najdłuższa własna przerwa (ADR 0020).
const customRestMinSeconds = 5;
const customRestMaxSeconds = 15 * 60;

/// Okno „Inna przerwa”: czas jako „m:ss” albo w sekundach, od 0:05 do
/// 15:00. Zwraca sekundy albo null po anulowaniu.
Future<int?> showRestInputDialog(BuildContext context, {int? initial}) =>
    showDialog<int>(
      context: context,
      builder: (context) => _RestInputDialog(initial: initial),
    );

class _RestInputDialog extends StatefulWidget {
  const _RestInputDialog({this.initial});

  final int? initial;

  @override
  State<_RestInputDialog> createState() => _RestInputDialogState();
}

class _RestInputDialogState extends State<_RestInputDialog> {
  late final _controller = TextEditingController(
    text: widget.initial == null ? '' : formatClock(widget.initial!),
  );
  bool _invalid = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final seconds = parseClock(_controller.text);
    if (seconds == null ||
        seconds < customRestMinSeconds ||
        seconds > customRestMaxSeconds) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop(seconds);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.restCustomTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.datetime,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: l10n.restCustomHint,
          errorText: _invalid ? l10n.restCustomInvalid : null,
          errorMaxLines: 2,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(onPressed: _submit, child: Text(l10n.commonSave)),
      ],
    );
  }
}
