# ADR 0005: Katalog ćwiczeń

- Status: zaakceptowana (2026-10-19)
- Odwracalność: trudna ⚠ (schemat danych), źródło katalogu łatwa

## Kontekst

MVP ma mieć 100–150 popularnych ćwiczeń z ręcznie sprawdzonymi polskimi nazwami. Weryfikacja źródeł (2026-10-19):

- **yuhonas/free-exercise-db**: repozytorium na Unlicense (domena publiczna), ponad 800 ćwiczeń. Dane pochodzą z `wrkout/exercises.json`, także na Unlicense. Pochodzenie zdjęć nie jest opisane, więc ich nie używamy.
- **wger**: dane ćwiczeń na licencjach Creative Commons per wpis, w dużej części CC-BY-SA. Wymaga atrybucji, a share-alike objęłoby pochodną bazę seedów.

## Decyzja

- Źródło: free-exercise-db (ok. 120 wybranych pozycji) plus własne wpisy. Bez wger w MVP. Bez zdjęć.
- Każdy rekord zapisuje `origin_ref`, `license`, `license_author`. Ekran „Licencje i źródła” w ustawieniach.
- Nazwy: polska nazwa w `name`, angielska jako alias. Lokalizacja nazw ćwiczeń po MVP (backlog).
- Opis techniki: 2–4 krótkie wskazówki po polsku, pisane ręcznie (bez tłumaczenia maszynowego), do przeglądu przez właściciela.
- Aliasy i mięśnie przechowywane jako JSON w wierszu `exercises` plus znormalizowane pole `search_text` (małe litery, bez diakrytyków). Jeden rekord to jedna jednostka synchronizacji, a katalog jest mały, więc filtrowanie działa w pamięci.
- Ćwiczenia jednostronne: w MVP jedna seria oznacza obie strony z tymi samymi wartościami. Pole `side` zostaje na przyszłe logowanie L/P.

## Konsekwencje

- Brak obowiązków share-alike dla pliku seed.
- Filtrowanie po mięśniu w SQL wymagałoby `json_each`; przy obecnej skali niepotrzebne.
- Przegląd polskich nazw i wskazówek to ręczna praca właściciela w Etapie 2.
