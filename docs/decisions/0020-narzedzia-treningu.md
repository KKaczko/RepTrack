# ADR 0020: Narzędzia treningu na siłowni

- Status: zaakceptowana (2026-10-21, plan rundy „Trening na siłowni” zatwierdzony przez właściciela)
- Odwracalność: łatwa (nowe klucze ustawień bez migracji, bez zmian schematu i formatu backupu)

## Kontekst

Pierwsza runda rozwoju po wydaniu 1.0 ([rozwój i premium](../future/rozwoj-i-premium.md)) skupia się na tym, co dzieje się na siłowni. W backlogu były osobne kroki ciężaru dla sprzętu, deload, własne przerwy i przypomnienie o niezatwierdzonych seriach. Do tego dwa narzędzia, które mają dobre aplikacje treningowe: kalkulator talerzy i rozgrzewka jednym tapnięciem.

## Decyzja

- **Kroki ciężaru dla sprzętu:**
  - `equipment_weight_steps` (kod sprzętu → krok w jednostce wyświetlania) dla hantli, kettlebell, maszyn, wyciągów, suwnicy Smitha i gryfu łamanego;
  - sztanga używa kroku ogólnego;
  - `weightStepFor(sprzęt, ustawienia)` używają stepper ciężaru, progresja i rozgrzewka;
  - sprzęt pochodzi z katalogu ćwiczeń;
  - zmiana jednostki czyści kroki dla sprzętu.
- **Kalkulator talerzy:**
  - `platesPerSide` liczy zachłannie od największego talerza, bez limitu sztuk, i zwraca talerze na stronę oraz resztę, której nie da się złożyć;
  - ustawienia `bar_weights` (domyślnie sztanga 20 kg / 45 lb, gryf łamany 10 kg / 20 lb) i `plates` (domyślne zestawy kg i lb);
  - w treningu dla sztangi i gryfu łamanego jest linia „Na stronę: 25 + 15 · gryf 20 kg” z ciężaru wybranej serii;
  - dotknięcie linii (albo Ustawienia → Trening) otwiera ekran „Gryf i talerze”.
- **Rozgrzewka:**
  - `warmupPlan` daje 40% × 8, 60% × 5, 80% × 3 ciężaru pierwszej serii roboczej, w dół do kroku sprzętu, nie mniej niż gryf i bez powtórzeń;
  - przycisk „Rozgrzewka” pojawia się tylko przed pierwszą zatwierdzoną serią i tylko bez istniejących rozgrzewek;
  - serie (przerwa 60 s) trafiają na początek ćwiczenia; komunikat ma „Cofnij”.
- **Deload** (uzupełnienie ADR 0017):
  - warunek: w dwóch ostatnich wykonaniach przy tym samym ciężarze choć jedna seria robocza poniżej dolnej granicy;
  - podpowiedź: ciężar × 0,9 w dół do kroku i dolna granica powtórzeń;
  - nie dotyczy wspomagania;
  - `recentCompletedSets` daje dwa ostatnie wykonania z zatwierdzonymi seriami.
- **Własne przerwy:**
  - „Inna…” w wyborze przerwy w szablonie i w domyślnej przerwie;
  - czas jako `m:ss` albo w sekundach (`parseClock`), od 0:05 do 15:00.
- **Niezatwierdzone serie:** „Zakończ trening” z menu pyta „N niezatwierdzonych serii” z opcjami „Wróć do treningu” i „Zakończ mimo to”. Seria nigdy nie zatwierdza się sama.

## Konsekwencje

- Kalkulator zakłada nieograniczoną liczbę talerzy każdego nominału. Siłownia z jedną parą „25” wymaga odznaczenia albo ręcznej korekty.
- Rozgrzewka działa przed pierwszą serią. Później trzeba ją dodać ręcznie („Dodaj serię”, typ rozgrzewkowa).
- Ustawienia trafiają do kopii jak dotąd; starsze kopie bez nowych kluczy dostają wartości domyślne.
