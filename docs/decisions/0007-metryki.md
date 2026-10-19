# ADR 0007: Metryki: 1RM, objętość, rekordy

- Status: zaakceptowana (2026-10-19)
- Odwracalność: łatwa (metryki są liczone, nie zapisywane)

## Kontekst

Specyfikacja: szacowany 1RM wzorem Epleya z serii roboczych do 10 powtórzeń, objętość bez rozgrzewek, rekordy „najcięższa seria dla danej liczby powtórzeń” i najlepszy e1RM. Nie określa zachowania dla ćwiczeń z masą ciała ani dla 1 powtórzenia.

## Decyzja

- **e1RM:** `ciężar × (1 + powtórzenia / 30)` dla serii roboczych z 2–10 powtórzeniami. Dla 1 powtórzenia e1RM = sam ciężar (Epley zawyżałby wynik o 3,3%).
- **Objętość:** ciężar × powtórzenia, bez serii rozgrzewkowych. Ciężar brany tak, jak został wpisany: dla `per_hand` nie mnożymy przez 2.
- **Rekord „ciężar dla N powtórzeń”:** najcięższa seria robocza z co najmniej N powtórzeniami.
- **Tryby obciążenia:**
  - `external`: e1RM, rekordy ciężaru, objętość.
  - `weighted_bodyweight`: jak wyżej, liczone z dociążenia.
  - `bodyweight`: rekord powtórzeń, bez metryk ciężaru.
  - `assisted`: bez metryk ciężaru (ciężar to wspomaganie).
- **Treningi w tygodniu:** tydzień od poniedziałku, liczony z `local_date`.

## Implementacja (Etap 5)

- `lib/features/progress/domain/metrics.dart`: `e1rmTrend` (najlepszy e1RM na trening), `volumeTrend` (objętość ćwiczenia na trening), `datedRecords` (rekordy z dniem pierwszego osiągnięcia; remis nie przesuwa daty).
- `lib/features/history/domain/history_queries.dart`: wykonania ćwiczenia, poprzednie wykonanie przed danym treningiem, porównanie, treningi w tygodniu i kolejność szablonów według ostatniego użycia.
- Wszystko liczone w pamięci na liście zakończonych treningów (`watchCompleted`). Strumień porównuje odcisk zakończonych sesji (liczbę i najnowsze `updated_at` sesji, ćwiczeń i serii), więc zapisy aktywnego treningu nie przeładowują historii.
- Wykres objętości pokazuje 12 ostatnich treningów, a wykres tygodni 12 ostatnich tygodni.

## Konsekwencje

- Śledzenie masy ciała użytkownika (potrzebne do metryk dla ćwiczeń z masą ciała) trafia do backlogu.
