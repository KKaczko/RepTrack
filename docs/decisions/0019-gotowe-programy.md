# ADR 0019: Gotowe programy i start bez szablonów

- Status: zaakceptowana (2026-10-21, plan zatwierdzony przez właściciela)
- Odwracalność: łatwa (asset w aplikacji, bez zmian schematu; seed v2 tylko dodaje ćwiczenia)

## Kontekst

Nowa osoba po instalacji widziała pusty Start („Utwórz szablon…”) i musiała sama układać szablony ze 118 ćwiczeń. Zewnętrzny przegląd wskazał, że sensowny trening powinien być możliwy w minutę, tak jak w aplikacjach z bibliotekami programów (Boostcamp, StrengthLog).

Decyzja właściciela (2026-10-21): karta na Starcie plus biblioteka programów, bez kreatora przy pierwszym uruchomieniu.

## Decyzja

- **Biblioteka** `assets/programs/programs.json` (format 1). Treść jest własna RepTrack, w PL i EN, bez nazw i treści cudzych programów. Plik zawiera:
  - ćwiczenia wskazane stabilnym kluczem seeda (np. `back_squat`);
  - serie, cel (powtórzenia albo sekundy), przerwę;
  - znacznik superserii (ADR 0018);
  - plan tygodnia (dzień → trening);
  - poziom (początkujący, średniozaawansowany) i sprzęt (siłownia, hantle, bez sprzętu).
- **Programy (7):**
  - FBW na start 3×;
  - Siła 5×5;
  - FBW 2× (mało czasu, z superseriami);
  - Góra/Dół 4×;
  - Push/Pull/Nogi 3×;
  - Hantle w domu 3×;
  - Masa ciała 3×.

  Plan tygodniowy ma stałe dni, więc programy A/B mają w tygodniu A, B, A. Opis to mówi.
- **Seed v2:** cztery własne ćwiczenia z masą ciała:
  - przysiad bez obciążenia;
  - wykroki w tył bez obciążenia;
  - mostek biodrowy bez obciążenia;
  - superman.

  `ExerciseSeeder` dodaje je przy aktualizacji (test v1 → v2).
- **Dodanie programu** (`installProgram`, `ProgramInstaller`):
  - szablony z nowymi identyfikatorami, z nazwami w języku aplikacji i nazwą programu w opisie;
  - plan tygodniowy od dziś przez `editWeeklyPlan` (ADR 0015): działający plan jest zamykany na wczoraj, po pytaniu „Zastąpić plan tygodnia?”;
  - szablony i plan w jednej transakcji; dotychczasowe szablony i historia zostają;
  - przed dodaniem walidacja (`validateProgram`) wobec biblioteki ćwiczeń.
- **Interfejs:**
  - Start bez szablonów pokazuje kartę „Zacznij od gotowego programu” z przyciskiem „Wybierz program”;
  - Szablony mają „Gotowe programy” w pasku i w pustym stanie;
  - lista z filtrami (dni w tygodniu, sprzęt, poziom);
  - podgląd z planem tygodnia, treningami, seriami i plakietkami superserii;
  - po „Dodaj program” aplikacja wraca na Start, gdzie jest „Dziś wg planu: …”.

## Konsekwencje

- Programy nie mają ciężarów startowych: pierwszy trening podpowiada ciężar z wcześniejszej serii, a dalej działa progresja podwójna (ADR 0017).
- Nowy program to zmiana pliku z testem (`test/features/programs/domain/program_test.dart` sprawdza klucze ćwiczeń, cele, plan, superserie i teksty PL/EN).
- Testy widżetów podają programy i klucze seeda z plików, bo odczyt z pakietu zasobów trwa poza zegarem testu.
