#!/usr/bin/env bash
# Weryfikacja etapu jedną komendą (ADR 0011).
#
#   bash tool/check.sh               formatowanie, analiza, testy i build release APK
#   bash tool/check.sh --skip-build  bez buildu APK (szybka pętla)
#   bash tool/check.sh --bundle      dodatkowo build AAB (od Etapu 7)
set -euo pipefail
cd "$(dirname "$0")/.."

skip_build=false
bundle=false
for arg in "$@"; do
  case "$arg" in
    --skip-build) skip_build=true ;;
    --bundle) bundle=true ;;
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
  if [[ "$bundle" == true ]]; then
    step "Build release AAB"
    flutter build appbundle --release
  fi
fi

printf '\n✔ check.sh: wszystko zielone\n'
