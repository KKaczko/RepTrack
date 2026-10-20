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

- `lib/features/progress/domain/metrics.dart`: `volumeTrend` (objętość ćwiczenia na dzień), `datedRecords` (rekordy z dniem pierwszego osiągnięcia; remis nie przesuwa daty). Trend e1RM zastąpił później `metricTrend` (niżej).
- `lib/features/history/domain/history_queries.dart`: wykonania ćwiczenia, poprzednie wykonanie przed danym treningiem, porównanie, treningi w tygodniu i kolejność szablonów według ostatniego użycia.
- Wszystko liczone w pamięci na liście zakończonych treningów (`watchCompleted`). Strumień porównuje odcisk zakończonych sesji (liczbę i najnowsze `updated_at` sesji, ćwiczeń i serii), więc zapisy aktywnego treningu nie przeładowują historii.
- Wykres objętości pokazuje 12 ostatnich dni z treningiem. Wykres tygodni pokazywał 12 ostatnich tygodni; od analizy okresu ma tyle tygodni, ile okres (najwyżej 52).

## Analiza okresu (2026-10-20, po wydaniu 1.0.0)

- **Okresy:** 4 tygodnie (28 dni), 3 miesiące (91), rok (364) i cała historia, liczone wstecz z dzisiejszym dniem. Wielokrotności 7 dni, żeby średnie tygodniowe się nie rozjeżdżały. Porównanie z okresem tej samej długości tuż przed; cała historia nie ma porównania.
- **Podsumowanie okresu:** treningi, zatwierdzone serie (z rozgrzewkami, jak na ekranie zakończenia), objętość bez rozgrzewek i suma czasu treningów. Treningi i serie porównujemy różnicą, objętość i czas procentem; bez danych w poprzednim okresie procentu nie liczymy.
- **Serie na partię mięśniową:** zatwierdzone serie robocze, 1 dla każdego mięśnia głównego i 0,5 dla pomocniczego, według bieżącego katalogu ćwiczeń. Wynik to średnia na tydzień okresu; dla całej historii tygodnie liczymy od tygodnia pierwszego treningu, co najmniej 4. Waga 0,5 to przyjęte uproszczenie, nie wynik z literatury.
- **Miara ćwiczenia:** według pomiaru i trybu obciążenia z ostatniego wykonania:
  - ciężar z powtórzeniami i metryki ciężaru (`external`, `weighted_bodyweight`): e1RM;
  - powtórzenia (masa ciała, wspomaganie): najwięcej powtórzeń w serii;
  - czas: najdłuższa seria.

  Sam dystans nie ma miary.
- **Zmiana w okresie:** od pierwszego do ostatniego dnia z wynikiem w okresie (najlepszy wynik dnia), w procentach. Przy jednym dniu jej nie ma.
- **Najlepsza seria:** najcięższa (przy remisie więcej powtórzeń) dla e1RM, najwięcej powtórzeń albo najdłuższa dla pozostałych.
- **Treningi z ćwiczeniem:** liczba wykonań w okresie; dwa treningi jednego dnia to dwa wykonania, ale jeden punkt na wykresie.
- Implementacja: `lib/features/progress/domain/progress_period.dart` (`periodRange`, `previousRange`, `summarizePeriod`, `weeklySetsPerMuscle`, `metricFor`, `metricTrend`, `exerciseProgress`), testy w `test/features/progress/domain/progress_period_test.dart`.

## Konsekwencje

- Śledzenie masy ciała użytkownika (potrzebne do metryk dla ćwiczeń z masą ciała) trafia do backlogu.
