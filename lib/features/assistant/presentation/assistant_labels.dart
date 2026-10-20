import '../../../core/l10n/generated/app_localizations.dart';
import '../domain/assistant.dart';

/// Teksty błędów asystenta.
extension AssistantLabels on AppLocalizations {
  String assistantFailure(AssistantException error) => switch (error.kind) {
    AssistantFailureKind.notConfigured => assistantErrorNotConfigured,
    AssistantFailureKind.unreachable => assistantErrorUnreachable,
    AssistantFailureKind.modelMissing => assistantErrorModelMissing,
    AssistantFailureKind.timeout => assistantErrorTimeout,
    AssistantFailureKind.server => assistantErrorServer(error.detail ?? '—'),
  };
}
