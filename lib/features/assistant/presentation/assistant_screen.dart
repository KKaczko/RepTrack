import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/domain/local_date.dart';
import '../../../core/domain/units.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/empty_state.dart';
import '../../exercises/data/exercise_providers.dart';
import '../../exercises/domain/exercise.dart';
import '../../history/presentation/history_labels.dart';
import '../../plan/data/plan_providers.dart';
import '../../plan/domain/plan.dart';
import '../../settings/data/settings_providers.dart';
import '../../templates/data/template_providers.dart';
import '../../templates/domain/template.dart';
import '../../workout/data/workout_providers.dart';
import '../../workout/domain/workout_session.dart';
import '../data/assistant_providers.dart';
import '../domain/assistant.dart';
import '../domain/assistant_context.dart';
import '../domain/context_budget.dart';
import 'assistant_context_labels.dart';
import 'assistant_labels.dart';
import 'assistant_markdown.dart';

/// Asystent AI (ADR 0014): rozmowa z modelem na serwerze Ollama właściciela.
/// Z [sessionId] zaczyna od komentarza do treningu, z [templateId] od
/// propozycji następnego treningu. Rozmowa nie jest zapisywana.
class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({this.sessionId, this.templateId, super.key});

  final String? sessionId;
  final String? templateId;

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

/// Wypowiedź w rozmowie. Pytanie ma osobno tekst widoczny ([shown])
/// i treść wysyłaną do modelu ([sent], np. polecenie z danymi szablonu).
final class _Turn {
  _Turn.user({required this.shown, required this.sent}) : fromUser = true;

  _Turn.reply() : fromUser = false, shown = '', sent = '';

  final bool fromUser;
  String shown;
  final String sent;
  bool stopped = false;
  AssistantException? error;
}

/// Najwięcej wcześniejszych wypowiedzi wysyłanych modelowi.
const _historyTurns = 8;

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _turns = <_Turn>[];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  StreamSubscription<String>? _reply;
  bool _busy = false;

  /// Numer bieżącej odpowiedzi; spóźnione wyniki starszej są pomijane.
  int _generation = 0;

  /// Dane omawianego treningu (komentarz z trasy). Bez niego instrukcja
  /// systemowa ma przegląd liczony od nowa przy każdym pytaniu.
  String? _taskContext;
  bool _taskStarted = false;

  @override
  void dispose() {
    unawaited(_reply?.cancel());
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(appSettingsProvider).value;
    final history = ref.watch(completedSessionsProvider).value;
    final catalog = ref.watch(exercisesByIdProvider).value;
    final templates = ref.watch(templatesProvider).value;
    final Widget body;
    if (settings == null ||
        history == null ||
        catalog == null ||
        templates == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (settings.assistantUrl == null) {
      body = EmptyState(
        icon: Icons.smart_toy_outlined,
        title: l10n.assistantNotConfiguredTitle,
        message: l10n.assistantNotConfiguredBody,
        action: FilledButton.icon(
          icon: const Icon(Icons.settings_outlined),
          label: Text(l10n.assistantOpenSettings),
          onPressed: () => context.push(AppRoutes.settings),
        ),
      );
    } else {
      _scheduleTask(history, catalog, templates, settings.weightUnit);
      body = _chat(l10n, history, catalog, templates, settings.weightUnit);
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.assistantTitle)),
      body: body,
    );
  }

  Widget _chat(
    AppLocalizations l10n,
    List<WorkoutSession> history,
    Map<String, Exercise> catalog,
    List<Template> templates,
    WeightUnit unit,
  ) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final waiting =
        _busy && _turns.isNotEmpty && _turns.last.shown.trim().isEmpty;
    return SafeArea(
      top: false,
      child: Column(
        children: [
          Expanded(
            child: SelectionArea(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.all(AppSpacing.gutter),
                children: [
                  if (_turns.isEmpty) ..._suggestions(l10n, templates),
                  for (final turn in _turns)
                    if (turn.fromUser || turn.shown.isNotEmpty)
                      _Bubble(turn: turn),
                  if (waiting)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.m,
                      ),
                      child: Row(
                        children: [
                          const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: AppSpacing.m),
                          Expanded(
                            child: Text(l10n.assistantThinking, style: muted),
                          ),
                        ],
                      ),
                    ),
                  if (_turns.lastOrNull case final last?
                      when !last.fromUser && last.stopped)
                    Text(l10n.assistantStopped, style: muted),
                  if (_turns.lastOrNull?.error case final error?)
                    _ErrorRow(
                      message: l10n.assistantFailure(error),
                      onRetry: _retry,
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            child: Text(
              l10n.assistantDisclaimer,
              style: muted,
              textAlign: TextAlign.center,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.s,
              AppSpacing.s,
              AppSpacing.s,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _ask(),
                    decoration: InputDecoration(
                      hintText: l10n.assistantInputHint,
                    ),
                  ),
                ),
                if (_busy)
                  IconButton(
                    tooltip: l10n.assistantStop,
                    icon: const Icon(Icons.stop_circle_outlined),
                    onPressed: _stop,
                  )
                else
                  IconButton(
                    tooltip: l10n.assistantSend,
                    icon: const Icon(Icons.send_rounded),
                    onPressed: _ask,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _suggestions(AppLocalizations l10n, List<Template> templates) {
    Widget chip(String text, VoidCallback onPressed) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ActionChip(
          avatar: const Icon(Icons.auto_awesome_outlined, size: 18),
          label: Text(text),
          onPressed: onPressed,
        ),
      ),
    );
    return [
      for (final prompt in [
        l10n.assistantPromptMonth,
        l10n.assistantPromptMuscles,
        l10n.assistantPromptStrength,
        if (ref.read(planProvider).value case final plan?
            when plan.weekly.isNotEmpty || plan.days.isNotEmpty)
          l10n.assistantPromptPlan,
      ])
        chip(prompt, () => _send(shown: prompt, sent: prompt)),
      chip(l10n.assistantPromptNext, () => _pickTemplate(templates)),
    ];
  }

  // ---------------------------------------------------------------- zadania

  /// Zadanie z trasy (komentarz albo propozycja) rusza raz, gdy są dane.
  void _scheduleTask(
    List<WorkoutSession> history,
    Map<String, Exercise> catalog,
    List<Template> templates,
    WeightUnit unit,
  ) {
    if (_taskStarted) return;
    _taskStarted = true;
    final sessionId = widget.sessionId;
    final templateId = widget.templateId;
    if (sessionId == null && templateId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (sessionId != null) {
        _reviewSession(sessionId);
      } else if (templates.firstWhereOrNull((t) => t.id == templateId)
          case final template?) {
        _suggestNext(template);
      }
    });
  }

  void _reviewSession(String sessionId) {
    final l10n = AppLocalizations.of(context);
    final history = ref.read(completedSessionsProvider).value ?? const [];
    final session = history.firstWhereOrNull((s) => s.id == sessionId);
    if (session == null) return;
    final format = _format();
    _taskContext = sessionReviewContext(
      session: session,
      history: history,
      catalog: ref.read(exercisesByIdProvider).value ?? const {},
      format: format,
    );
    final locale = Localizations.localeOf(context).toString();
    _send(
      shown: l10n.assistantShownReview(
        session.title ?? l10n.workoutTitle,
        shortDate(session.localDate, locale),
      ),
      sent: l10n.assistantTaskReview,
    );
  }

  void _suggestNext(Template template) {
    final l10n = AppLocalizations.of(context);
    final data = nextWorkoutContext(
      template: template,
      history: ref.read(completedSessionsProvider).value ?? const [],
      catalog: ref.read(exercisesByIdProvider).value ?? const {},
      format: _format(),
    );
    _send(
      shown: l10n.assistantShownNext(template.name),
      sent: '${l10n.assistantTaskNext(template.name)}\n\n$data',
    );
  }

  Future<void> _pickTemplate(List<Template> templates) async {
    final l10n = AppLocalizations.of(context);
    final active = [
      for (final t in templates)
        if (!t.isArchived) t,
    ];
    if (active.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.assistantNoTemplates)));
      return;
    }
    final picked = await showModalBottomSheet<Template>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gutter,
              ),
              child: Text(
                l10n.assistantPickTemplate,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final template in active)
                    ListTile(
                      title: Text(template.name),
                      onTap: () => Navigator.of(context).pop(template),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) _suggestNext(picked);
  }

  // ---------------------------------------------------------------- rozmowa

  AssistantFormat _format() {
    final l10n = AppLocalizations.of(context);
    final unit =
        ref.read(appSettingsProvider).value?.weightUnit ?? WeightUnit.kg;
    final locale = Localizations.localeOf(context).toString();
    return (
      labels: assistantContextLabels(l10n, unit, locale: locale),
      unit: unit,
      locale: locale,
    );
  }

  /// Przegląd aktualnych danych do instrukcji systemowej, od
  /// najpełniejszego do najkrótszego wariantu (budżet kontekstu). Liczony
  /// przy każdym pytaniu, więc nowy trening albo zmiana planu w trakcie
  /// rozmowy od razu trafiają do modelu.
  Iterable<String> _overviews() sync* {
    final now = ref.read(clockProvider).nowUtc().toLocal();
    final history = ref.read(completedSessionsProvider).value ?? const [];
    final catalog = ref.read(exercisesByIdProvider).value ?? const {};
    final plan = ref.read(planProvider).value ?? emptyPlan;
    final templates = ref.read(templatesProvider).value ?? const <Template>[];
    final format = _format();
    for (final limits in assistantLimitLevels) {
      yield coachContext(
        history: history,
        catalog: catalog,
        today: LocalDate(now.year, now.month, now.day),
        format: format,
        plan: plan,
        templates: templates,
        limits: limits,
      );
    }
  }

  void _ask() {
    final text = _input.text.trim();
    if (text.isEmpty || _busy) return;
    _input.clear();
    _send(shown: text, sent: text);
  }

  void _send({required String shown, required String sent}) {
    if (_busy) return;
    setState(() {
      _turns
        ..add(_Turn.user(shown: shown, sent: sent))
        ..add(_Turn.reply());
    });
    unawaited(_run());
  }

  /// Ponowienie ostatniego pytania po błędzie.
  void _retry() {
    if (_busy || _turns.length < 2) return;
    setState(() {
      _turns
        ..removeLast()
        ..add(_Turn.reply());
    });
    unawaited(_run());
  }

  void _stop() {
    unawaited(_reply?.cancel());
    setState(() {
      _generation++;
      _reply = null;
      _busy = false;
      _turns.last.stopped = true;
    });
  }

  void _finish(int generation, [AssistantException? error]) {
    if (!mounted || generation != _generation) return;
    setState(() {
      _reply = null;
      _busy = false;
      if (error != null) _turns.last.error = error;
    });
  }

  Future<void> _run() async {
    final l10n = AppLocalizations.of(context);
    final reply = _turns.last;
    final settings = ref.read(appSettingsProvider).value;
    final url = settings?.assistantUrl;
    if (url == null) {
      setState(
        () => reply.error = const AssistantException(
          AssistantFailureKind.notConfigured,
        ),
      );
      return;
    }
    final server = Uri.parse(url);
    final client = ref.read(assistantClientProvider);
    final previous = _turns
        .sublist(0, _turns.length - 1)
        .where((t) => t.fromUser || (t.error == null && t.shown.isNotEmpty))
        .toList();
    final task = _taskContext;
    final messages = fitAssistantMessages(
      systemVariants: (task != null ? [task] : _overviews()).map(
        (data) => '${l10n.assistantSystem}\n\n$data',
      ),
      turns: [
        for (final turn in previous.skip(
          previous.length > _historyTurns ? previous.length - _historyTurns : 0,
        ))
          turn.fromUser
              ? (role: ChatRole.user, content: turn.sent)
              : (role: ChatRole.assistant, content: stripThinking(turn.shown)),
      ],
    );

    final generation = ++_generation;
    setState(() => _busy = true);
    try {
      requireAllowedServer(server);
      final model =
          settings!.assistantModel ??
          pickModel(await client.models(server), null);
      if (model == null) {
        throw const AssistantException(AssistantFailureKind.modelMissing);
      }
      if (!mounted || generation != _generation) return;
      _reply = client
          .chat(server, model: model, messages: messages)
          .listen(
            (chunk) {
              if (!mounted || generation != _generation) return;
              setState(() => reply.shown += chunk);
              _scrollToEnd();
            },
            onError: (Object error) => _finish(
              generation,
              error is AssistantException
                  ? error
                  : AssistantException(
                      AssistantFailureKind.server,
                      error.toString(),
                    ),
            ),
            onDone: () => _finish(generation),
            cancelOnError: true,
          );
      _scrollToEnd();
    } on AssistantException catch (error) {
      _finish(generation, error);
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.turn});

  final _Turn turn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fromUser = turn.fromUser;
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: AppSpacing.m,
          left: fromUser ? AppSpacing.xxl : 0,
          right: fromUser ? 0 : AppSpacing.xl,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.s,
        ),
        decoration: BoxDecoration(
          color: fromUser
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadius.s),
        ),
        child: fromUser
            ? Text(
                turn.shown,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              )
            : AssistantMarkdown(stripThinking(turn.shown)),
      ),
    );
  }
}

class _ErrorRow extends StatelessWidget {
  const _ErrorRow({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          TextButton.icon(
            icon: const Icon(Icons.refresh_rounded),
            label: Text(AppLocalizations.of(context).assistantRetry),
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
