import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../assistant/data/assistant_providers.dart';
import '../../assistant/domain/assistant.dart';
import '../../assistant/presentation/assistant_labels.dart';
import '../data/settings_providers.dart';
import '../domain/app_settings.dart';

/// Ustawienia asystenta AI (ADR 0014): serwer Ollama, model, test
/// połączenia i instrukcja przygotowania komputera.
class AssistantSettingsSection extends ConsumerWidget {
  const AssistantSettingsSection({required this.settings, super.key});

  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final server = settings.assistantUrl;
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.dns_outlined),
          title: Text(l10n.assistantServer),
          subtitle: Text(server ?? l10n.assistantServerNone),
          onTap: () => _editServer(context, ref),
        ),
        ListTile(
          leading: const Icon(Icons.smart_toy_outlined),
          title: Text(l10n.assistantModel),
          subtitle: Text(settings.assistantModel ?? l10n.assistantModelAuto),
          enabled: server != null,
          onTap: () => _chooseModel(context, ref),
        ),
        ListTile(
          leading: const Icon(Icons.wifi_tethering_rounded),
          title: Text(l10n.assistantTest),
          enabled: server != null,
          onTap: () => _test(context, ref),
        ),
        ListTile(
          leading: const Icon(Icons.help_outline_rounded),
          title: Text(l10n.assistantSetupHelp),
          onTap: () => _showHelp(context),
        ),
      ],
    );
  }

  Future<void> _save(WidgetRef ref, AppSettings settings) =>
      ref.read(settingsRepositoryProvider).save(settings);

  Future<void> _editServer(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<_ServerResult>(
      context: context,
      builder: (context) => _ServerDialog(initial: settings.assistantUrl),
    );
    if (result == null) return;
    await _save(ref, settings.copyWith(assistantUrl: result.url?.toString()));
  }

  Future<void> _chooseModel(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final server = Uri.parse(settings.assistantUrl!);
    final List<String> models;
    try {
      models = await ref.read(assistantClientProvider).models(server);
    } on AssistantException catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.assistantFailure(error))),
      );
      return;
    }
    if (!context.mounted) return;
    if (models.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.assistantModelNone)));
      return;
    }
    final current = pickModel(models, settings.assistantModel);
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.assistantModel),
        children: [
          for (final model in models)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(model),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: AppSizes.minTouch),
                child: Row(
                  children: [
                    Expanded(child: Text(model)),
                    if (model == current) const Icon(Icons.check_rounded),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
    if (picked != null) {
      await _save(ref, settings.copyWith(assistantModel: picked));
    }
  }

  Future<void> _test(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.assistantTesting)));
    final client = ref.read(assistantClientProvider);
    final server = Uri.parse(settings.assistantUrl!);
    String message;
    try {
      final version = await client.version(server);
      final models = await client.models(server);
      message = models.isEmpty
          ? l10n.assistantModelNone
          : l10n.assistantConnected(version, models.length);
    } on AssistantException catch (error) {
      message = l10n.assistantFailure(error);
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showHelp(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            0,
            AppSpacing.gutter,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.assistantSetupHelp,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.m),
              Text(
                l10n.assistantSetupBody,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wynik okna adresu: nowy adres albo null (wyłączenie asystenta).
typedef _ServerResult = ({Uri? url});

class _ServerDialog extends StatefulWidget {
  const _ServerDialog({required this.initial});

  final String? initial;

  @override
  State<_ServerDialog> createState() => _ServerDialogState();
}

class _ServerDialogState extends State<_ServerDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  bool _invalid = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final url = normalizeServerUrl(_controller.text);
    if (url == null) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop<_ServerResult>((url: url));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.assistantServer),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.url,
        autocorrect: false,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: l10n.assistantServerHint,
          errorText: _invalid ? l10n.assistantServerInvalid : null,
        ),
      ),
      actions: [
        if (widget.initial != null)
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop<_ServerResult>((url: null)),
            child: Text(l10n.assistantServerOff),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(onPressed: _submit, child: Text(l10n.commonSave)),
      ],
    );
  }
}
