# ADR 0006: Poprzednie wykonanie, podpowiedzi i nazwy w historii

- Status: zaakceptowana (2026-10-19)
- Odwracalność: łatwa

## Kontekst

Aktywny trening pokazuje wynik poprzedniego wykonania przy każdej serii i wstępnie wypełnia pola podpowiedziami. Jedno tapnięcie zatwierdza podpowiedź, ale seria nigdy nie jest oznaczana jako wykonana automatycznie.

## Decyzja

- **Poprzednie wykonanie:** ostatnia zakończona sesja zawierająca to ćwiczenie z co najmniej jedną zatwierdzoną serią (od 2026-10-21; wcześniej trening z pominiętym ćwiczeniem przesłaniał starszy wynik), niezależnie od szablonu. Serie robocze dopasowane po kolejności wśród roboczych, rozgrzewkowe wśród rozgrzewkowych.
- **Podpowiedź** dla każdego pola, w kolejności:
  1. wartość wpisana przez użytkownika,
  2. poprzednie wykonanie,
  3. plan (ciężar docelowy; powtórzenia = dolna granica zakresu),
  4. brak.
- Podpowiedzi liczone dynamicznie przy renderowaniu, nie zapisywane w bazie. Zatwierdzenie kopiuje je do serii i ustawia `completed_at`.
- **Nazwa w historii:** aktualna nazwa ćwiczenia. Snapshot nazwy w `session_exercises` służy do audytu i eksportu.
- **Porównanie z poprzednim treningiem** (historia) używa tej samej reguły „ostatnia sesja z ćwiczeniem”.

## Konsekwencje

- Po wznowieniu sesji podpowiedzi są te same, bo zakończone sesje się nie zmieniają (chyba że użytkownik je edytuje).
- Brak kolumn na podpowiedzi w `session_sets`.

## Implementacja (Etap 4)

- `lib/features/workout/domain/set_hints.dart`: `matchPreviousSets`, `hintForSet`, `confirmSet` (jedyne miejsce, które ustawia `completed_at`).
- Dodatkowe, czwarte źródło podpowiedzi: wcześniejsza seria tego samego rodzaju (rozgrzewkowa albo robocza) w bieżącym treningu. Działa tylko, gdy brak wpisu, poprzedniego wykonania i planu, np. przy pierwszym wykonaniu ćwiczenia: po wpisaniu ciężaru w serii 1 kolejne serie zatwierdza się jednym tapnięciem (`hintsForExercise`). Brak tego źródła wyszedł przy sprawdzaniu na emulatorze.
- Dla masy ciała z dociążeniem i wspomagania brak ciężaru w podpowiedzi oznacza 0 (na samym końcu kolejności).
- Podpowiedzi są wyszarzone (kolor `textHint`, zwykła grubość), wpisane i zatwierdzone wartości mają pełny kontrast i pogrubienie. Czytnik ekranu dostaje „Ciężar: 80 kg, podpowiedź”.
- Zatwierdzenie w kontrolerze liczy podpowiedź od nowa z bazy, więc nie zależy od stanu ekranu.
- Test widżetu sprawdza, że wpisanie wartości i upływ czasu nie zatwierdzają serii.

## Progresja (2026-10-21)

Piąte źródło podpowiedzi: progresja podwójna ([ADR 0017](0017-progresja-podwojna.md)). Gdy poprzednie wykonanie doszło do góry zakresu (albo było w zakresie z dużym zapasem), serie robocze dostają ciężar o krok wyżej i dolną granicę powtórzeń zamiast wyniku z poprzedniego razu. Kolejność bez zmian: wartość wpisana wygrywa.
