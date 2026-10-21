# ADR 0016: Ćwiczenia zastępcze i kroki stepperów ⚠

- Status: zaakceptowana (2026-10-21, plan zatwierdzony przez właściciela)
- Odwracalność: trudna ⚠
  - schemat bazy v3 z nową tabelą `exercise_substitutes` (istniejące bez zmian);
  - format backupu v3 (nowa tablica, migracja plików v1 i v2).

## Kontekst

Gdy w trakcie treningu maszyna jest zajęta, właściciel chce jednym przyciskiem zobaczyć ćwiczenia, którymi można ją zastąpić. Do tej pory była tylko „Zamień ćwiczenie” w menu ⋮, czyli wybór z całej biblioteki bez podpowiedzi.

Decyzje właściciela:
- zamienniki automatyczne i własne (przypięte do ćwiczenia);
- przycisk w treningu i sekcja na ekranie ćwiczenia;
- przy okazji kroki czasu i dystansu w ustawieniach. Do tej pory tylko krok ciężaru dało się zmienić, a 5 s i 100 m były wpisane w kod.

## Decyzja

- **Propozycje automatyczne** liczy czysta funkcja `suggestSubstitutes` (`lib/features/exercises/domain/substitutes.dart`) na wczytanym katalogu, bez zapisu w bazie.
  - Kandydat musi:
    - nie być celem ani zarchiwizowanym ćwiczeniem;
    - mieć zgodną grupę kategorii (siłowe razem; cardio osobno; mobilność osobno);
    - mieć co najmniej jeden wspólny mięsień główny.
  - Punkty:
    - podobieństwo mięśni głównych (Jaccard) ×40;
    - wspólne pomocnicze ×10;
    - ten sam kierunek siły +15;
    - ta sama mechanika +10;
    - ten sam sposób pomiaru ciężaru i powtórzeń +10;
    - inny sprzęt niż cel +10 (zajęta maszyna);
    - ćwiczenie robione wcześniej +8.

    Remis rozstrzyga nazwa (bez polskich znaków). Najwyżej 12 pozycji.
  - Powody pokazywane przy pozycji: te same mięśnie, ten sam ruch, inny sprzęt, robione wcześniej.
- **Przypięte zamienniki** (`exercise_substitutes`): jedna para działa w obie strony.
  - Przypięte są zawsze na górze, w kolejności przypięcia.
  - Odpięcie to miękkie usunięcie (ADR 0003).
  - Ponowne przypięcie tej samej pary w dowolnej kolejności nie tworzy duplikatu.
- **Trening:**
  - przycisk „Zamiennik” pod nagłówkiem ćwiczenia otwiera arkusz nad dolną nawigacją;
  - ★ przypina i odpina od razu, ale kolejność listy zostaje do zamknięcia arkusza, żeby wiersz nie uciekał spod palca;
  - wybór podmienia ćwiczenie tą samą ścieżką co „Zamień ćwiczenie”, z potwierdzeniem przy zatwierdzonych seriach;
  - „Wybierz z całej biblioteki” otwiera dotychczasowy wybór.
- **Ekran ćwiczenia:** sekcja „Zamienniki” w zakładce Info pokazuje przypięte i do 5 propozycji. Dotknięcie otwiera ekran zamiennika.
- **Kroki stepperów:**
  - `duration_step_seconds`: domyślnie 5; opcje 1, 5, 10, 15, 30, 60;
  - `distance_step_meters`: domyślnie 100; opcje 10, 25, 50, 100, 250, 500, 1000.

  Oba są w ustawieniach obok kroku ciężaru. Nowe klucze nie wymagają migracji, a niepoprawna wartość daje domyślną (ADR 0010).

## Konsekwencje

- **Baza v3:** migracja v2 → v3 tworzy tabelę i dwa indeksy (`exercise_id`, `substitute_id`). Testy obejmują v1 → v3 i v2 → v3 na danych (`test/drift/app_database/migration_test.dart`).
- **Backup v3:** pliki v1 i v2 dostają pustą tablicę `exerciseSubstitutes` (`migrateBackupV2ToV3`, łańcuch 1 → 2 → 3).
- **Jakość propozycji zależy od danych katalogu.** Ćwiczenie własne bez mięśni głównych nie dostaje propozycji automatycznych, ale można mu przypiąć zamienniki.
- **Przed instalacją tej wersji na telefonie** trzeba zrobić kopię w aplikacji (Ustawienia → Kopia i eksport), tak jak przy każdej zmianie schematu.
