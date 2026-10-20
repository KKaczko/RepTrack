#!/usr/bin/env bash
# Weryfikacja etapu jedną komendą (ADR 0011).
#
#   bash tool/check.sh               formatowanie, analiza, testy, build APK i AAB
#   bash tool/check.sh --skip-build  bez buildów (szybka pętla)
#
# Test na urządzeniu (poza check.sh, wymaga telefonu albo emulatora):
#   flutter test integration_test -d <urządzenie>
set -euo pipefail
cd "$(dirname "$0")/.."

skip_build=false
for arg in "$@"; do
  case "$arg" in
    --skip-build) skip_build=true ;;
    # Zgodność wstecz: AAB jest budowany zawsze od Etapu 7.
    --bundle) ;;
    *) echo "Nieznana opcja: $arg" >&2; exit 2 ;;
  esac
done

step() { printf '\n==> %s\n' "$1"; }

step "Zależności"
flutter pub get

step "Generowanie kodu (Drift, freezed)"
dart run build_runner build

step "Lokalizacja"
flutter gen-l10n

step "Formatowanie"
# Kod generowany jest w .gitignore, więc git ls-files go pomija.
mapfile -t dart_files < <(git ls-files --cached --others --exclude-standard -- '*.dart')
dart format --output=none --set-exit-if-changed "${dart_files[@]}"

step "Analiza statyczna"
flutter analyze --fatal-infos --fatal-warnings

step "Testy"
flutter test

if [[ "$skip_build" == false ]]; then
  step "Build release APK"
  flutter build apk --release
  step "Build release AAB"
  flutter build appbundle --release
fi

printf '\n✔ check.sh: wszystko zielone\n'
