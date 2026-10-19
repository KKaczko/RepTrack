# ADR 0011: Jakość kodu i kod generowany

- Status: zaakceptowana (2026-10-19)
- Odwracalność: łatwa

## Kontekst

Specyfikacja wymaga `dart analyze` bez ostrzeżeń, `flutter_lints` lub surowszego zestawu, formatowania `dart format` i jednej komendy weryfikującej etap.

## Decyzja

- Lint: `flutter_lints` + tryby językowe `strict-casts`, `strict-inference`, `strict-raw-types` + wybrane dodatkowe reguły. Analiza z `--fatal-infos`.
- Encje domeny przez `freezed` (czysty Dart, bez zależności od Fluttera).
- Kod generowany (`*.g.dart`, `*.freezed.dart`, wygenerowana lokalizacja) **poza repo**, tworzony przez `tool/check.sh`. Zrzuty schematu Drift (`drift_schemas/`) **w repo**, bo testy migracji ich wymagają.
- `tool/check.sh` (bash, działa w Git Bash): pub get, build_runner, gen-l10n, format, analyze, test, build release APK.
- Test architektury pilnuje, że `domain/` nie importuje Fluttera ani Drift.

## Konsekwencje

- Świeży checkout wymaga uruchomienia `tool/check.sh` (albo `build_runner`) przed pierwszym buildem.
- Brak szumu z kodu generowanego w diffach.
