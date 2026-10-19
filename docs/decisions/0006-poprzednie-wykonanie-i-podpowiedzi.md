# ADR 0006: Poprzednie wykonanie, podpowiedzi i nazwy w historii

- Status: zaakceptowana (2026-10-19)
- Odwracalność: łatwa

## Kontekst

Aktywny trening pokazuje wynik poprzedniego wykonania przy każdej serii i wstępnie wypełnia pola podpowiedziami. Jedno tapnięcie zatwierdza podpowiedź, ale seria nigdy nie jest oznaczana jako wykonana automatycznie.

## Decyzja

- **Poprzednie wykonanie:** ostatnia zakończona sesja zawierająca to ćwiczenie, niezależnie od szablonu. Serie robocze dopasowane po kolejności wśród roboczych, rozgrzewkowe wśród rozgrzewkowych.
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
