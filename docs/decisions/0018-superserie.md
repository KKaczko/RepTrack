# ADR 0018: Superserie

- Status: zaakceptowana (2026-10-21, plan zatwierdzony przez właściciela)
- Odwracalność: łatwa (istniejąca kolumna `group_id`, bez zmian schematu i formatu backupu)

## Kontekst

`group_id` w `template_exercises` i `session_exercises` jest w schemacie od początku (spec. sekcja 2, backlog), ale nie było interfejsu. Zewnętrzny przegląd wskazał superserie jako podstawową funkcję trackerów, ważniejszą od kolejnych ekranów statystyk.

## Decyzja

- **Model:** superseria to co najmniej dwa ćwiczenia stojące obok siebie z tym samym `group_id`. Domena w `lib/core/domain/exercise_groups.dart` działa na liście `groupId` w kolejności, wspólnie dla szablonów i treningów:
  - `linkWithNext` łączy ćwiczenie z następnym; gdy następne jest w innej grupie, grupy się łączą;
  - `unlinkAt` odłącza ćwiczenie; gdy odłączenie dzieli grupę, druga część dostaje nowy `group_id`;
  - `normalizeGroupIds` po zmianie kolejności albo usunięciu rozbija niespójną grupę, a ćwiczenie samo w grupie traci `group_id`;
  - `groupLabels` daje oznaczenia A1, A2, B1….
- **Szablon:** w menu ⋮ karty ćwiczenia są „Połącz w superserię z następnym” i „Odłącz od superserii”. Plakietka „A1” stoi przed nazwą.
- **Trening:**
  - te same akcje w menu ⋮ treningu;
  - nagłówek ćwiczenia ma plakietkę, „Superseria A · razem z: …” i ⓘ do hasła słowniczka „Superseria”;
  - **kolej** (`supersetTurn`) ma ćwiczenie grupy z najmniejszą liczbą zatwierdzonych serii, a przy remisie wcześniejsze. Gdy kolej ma inne ćwiczenie, a serii nie wybrano ręcznie, główny przycisk to „Dalej: X ▶”. To świadome tapnięcie zamiast samoczynnego przewijania (zasada z `docs/ux.md`); ręcznie wybrana seria ma pierwszeństwo;
  - **przerwa** włącza się dopiero po rundzie: gdy kolej wraca na początek grupy albo grupa jest skończona (`supersetRoundContinues`), z czasem przerwy ostatniej zatwierdzonej serii. Przy nierównej liczbie serii, gdy jedno ćwiczenie się skończy, drugie działa jak zwykłe.

  Kolej i przerwa wynikają ze stanu treningu, więc działają też po wznowieniu.
- **„Zaktualizuj szablon”** przenosi superserie z treningu (nowa zmiana „Zmienione superserie”).
- **Oznaczenia A1/A2** są w szczegółach treningu i w podglądzie szablonu w planie. Eksport CSV i Markdown się nie zmienia.

## Konsekwencje

- Kopie zapasowe i stare dane działają bez zmian, bo `group_id` było już w formacie.
- Rozgrzewki liczą się do kolejki jak inne serie. Kto chce rozgrzewki poza superserią, robi je jako osobne ćwiczenie albo wybiera serię ręcznie.
