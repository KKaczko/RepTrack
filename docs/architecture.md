# Architektura

Status: Etap 0 (plan), zatwierdzony 2026-10-19. Źródło wymagań: [spec/reptrack-prompt-v2.md](spec/reptrack-prompt-v2.md).

## Stos

Flutter + Dart, Drift (SQLite), Riverpod 3, go_router, freezed (encje domeny), `flutter gen-l10n`. Bez Firebase, analityki, reklam i backendu. Uzasadnienie wyboru stanu i nawigacji: [ADR 0002](decisions/0002-stan-nawigacja-di.md).

## Warstwy w każdej funkcji (feature-first)

- `domain/`: czysty Dart. Encje, value objects, interfejsy repozytoriów i czyste funkcje (dziedziczenie serii, kopiowanie szablonu do sesji, podpowiedzi, metryki). Zakaz importu `package:flutter` i `drift` pilnuje test architektury, który skanuje importy.
- `data/`: implementacje repozytoriów na Drift i mapery wiersz ↔ encja. Każda operacja zapisu to jedna transakcja.
- `presentation/`: ekrany, widgety, kontrolery Riverpod.

## Przepływ danych

- Baza jest jedynym źródłem prawdy. UI obserwuje strumienie Drift (`watch`), a każda akcja użytkownika to transakcja w repozytorium. Strumień emituje nowy stan, więc nie ma osobnego stanu w pamięci, który mógłby zginąć przy ubiciu procesu.
- Repozytoria są interfejsami w domenie. Przyszła synchronizacja dodaje implementację (np. dekorator z kolejką zmian) bez zmian w logice treningowej.
- Zależności między funkcjami (pilnuje ich `test/architecture/feature_boundaries_test.dart`):
  - wolno importować cudze `domain/` i publiczne providery (`data/*_providers.dart`), np. katalog ćwiczeń w edytorze szablonów;
  - nie wolno importować implementacji repozytoriów ani `presentation/` innej funkcji;
  - ekrany innych funkcji (np. wybór ćwiczeń) otwiera się przez trasy routera w `lib/app/`, który jako jedyny łączy wszystkie funkcje.
- `history` i `progress` korzystają z `workout/domain`.

## Wstrzykiwanie zależności

Riverpod providers. Testy podmieniają `appDatabaseProvider` na bazę w pamięci, `clockProvider` na stały zegar, a `idGeneratorProvider` na deterministyczny.

## Struktura katalogów

```
lib/
  main.dart
  app/           app.dart (MaterialApp.router), router.dart, bootstrap.dart (DB, seed, strefa, powiadomienia)
  core/
    database/    app_database.dart, tables/, converters/, migracje (stepByStep)
    domain/      ids.dart (UUIDv7), clock.dart, local_date.dart, units.dart, text_normalize.dart
    theme/       tokens.dart (kolory, typografia, odstępy, promienie), app_theme.dart
    widgets/     wspólne komponenty (NumberStepper, AppCard, EmptyState…)
    l10n/        app_pl.arb, app_en.arb (+ wygenerowane)
  features/
    exercises/   domain | data | presentation
    templates/   domain | data | presentation
    workout/     domain | data | presentation   (aktywna sesja, timer przerwy)
    history/     presentation (+ domain: porównanie sesji)
    progress/    domain (1RM, objętość, rekordy) | presentation (wykresy)
    backup/      domain (format, migracje formatu, CSV, MD) | data | presentation
    settings/    domain | data | presentation
    home/        presentation
assets/          seed/exercises.json, fonts/ (Inter, OFL)
drift_schemas/   zrzuty schematu per wersja (commitowane)
test/            lustro lib/ + test/architecture/ + test/migrations/
tool/            check.sh, seed/ (skrypt budujący seed z free-exercise-db + nadpisania PL)
docs/            dokumentacja, decisions/ (ADR), backlog.md
```

## Powiązane dokumenty

- [Model danych](data-model.md)
- [UX: mapa ekranów i aktywny trening](ux.md)
- [Plan etapów, testy i ryzyka](roadmap.md)
- [Decyzje (ADR)](decisions/README.md)
- [Backlog poza MVP](backlog.md)
