import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

/// Informuje, że trwa już inny trening (najwyżej jeden aktywny). Zwraca
/// true, gdy użytkownik chce przejść do trwającego treningu.
Future<bool> showActiveWorkoutDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final goToActive = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.workoutAlreadyActiveTitle),
      content: Text(l10n.workoutAlreadyActiveMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.workoutGoToActive),
        ),
      ],
    ),
  );
  return goToActive ?? false;
}
