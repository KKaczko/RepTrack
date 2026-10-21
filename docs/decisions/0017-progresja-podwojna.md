# ADR 0017: Automatyczna progresja podwójna

- Status: zaakceptowana (2026-10-21, plan zatwierdzony przez właściciela)
- Odwracalność: łatwa (liczona w locie, bez zmian schematu; ustawienie `auto_progression`)

## Kontekst

RepTrack zapisywał wykonanie i pokazywał postęp, ale nie mówił, co zrobić w następnym treningu. Zewnętrzny przegląd wskazał to jako największy brak wobec aplikacji typu Alpha Progression. Prosty lokalny silnik progresji podwójnej (double progression) nie potrzebuje AI ani serwera.

Decyzja właściciela (2026-10-21): progresja jest wbudowana w podpowiedź, a nie pokazywana jako osobna karta do zastosowania.

## Decyzja

- **Reguła** (`progressionFor` w `lib/features/workout/domain/progression.dart`). Dotyczy tylko serii roboczych z celem powtórzeń w ćwiczeniu, które mierzy ciężar i powtórzenia. Ciężar rośnie o krok z ustawień, gdy w poprzednim wykonaniu (ADR 0006) każda bieżąca seria robocza ma dopasowaną serię przy tym samym ciężarze i spełniony jest jeden z warunków:
  - **góra zakresu:** każda seria ma powtórzenia ≥ górnej granicy celu;
  - **duży zapas:** każda seria jest w zakresie i ma zapisane RIR ≥ 3 albo RPE ≤ 7, więc progresja uwzględnia wysiłek.
- **Nowa podpowiedź serii roboczych:**
  - ciężar to następny punkt siatki kroku (`stepValue`, działa dla kg i lb, a ciężar spoza siatki trafia na najbliższy wyższy punkt);
  - powtórzenia to dolna granica zakresu;
  - przy wspomaganiu wspomaganie maleje o krok, a przy zerze nie ma porady;
  - masa ciała z dociążeniem może zacząć od 0 + krok.

  Rozgrzewki zostają jak ostatnio.
- **Bez porady**, czyli z podpowiedzią jak dotąd:
  - inne ciężary w seriach;
  - brak wyniku którejś serii;
  - cel czasu;
  - ćwiczenie bez ciężaru;
  - wynik poniżej góry bez dużego zapasu.

  Zmniejszania ciężaru (deload) nie ma: wymaga historii kilku treningów i zostaje na później.
- **Podpowiedź:**
  - nowe źródło `HintSource.progression`; wartość wpisana dalej wygrywa;
  - zatwierdzenie jednym tapnięciem jak zawsze, seria nigdy nie zatwierdza się sama;
  - kontroler liczy tę samą poradę przy zatwierdzeniu, niezależnie od stanu ekranu.
- **Interfejs:**
  - pod planem ćwiczenia jest etykieta ze strzałką „+2,5 kg · ostatnio 3 × 12 przy 80 kg” (wariant „…, z zapasem”, przy wspomaganiu „2,5 kg mniej wspomagania”) i ⓘ do nowego hasła słowniczka „Progresja podwójna”;
  - czytnik ekranu mówi „Ciężar: 82,5 kg, podpowiedź z progresji”.
- **Ustawienie** „Automatyczna progresja” (Ustawienia → Trening, `auto_progression`, domyślnie włączone).

## Konsekwencje

- Dane katalogu i szablonu decydują o jakości: bez celu powtórzeń w szablonie (np. pusty trening) nie ma progresji.
- Dostępne obciążenia to jeden krok na całą aplikację. Osobne kroki dla hantli i maszyn są w backlogu.
- Asystent AI dalej może proponować trening opisowo (ADR 0014); progresja w podpowiedzi działa bez niego.
