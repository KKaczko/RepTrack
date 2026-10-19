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

## Implementacja (Etap 2)

- **Źródło prawdy:** `tool/seed/catalog_pl.yaml` (118 pozycji: 115 z free-exercise-db z commita `f00c92c`, 3 opracowania własne). Plik zawiera polskie nazwy, aliasy, wskazówki i jawne poprawki danych źródła (mięśnie, sprzęt, kierunek siły).
- **Budowanie:** `tool/seed/build_seed.dart` łączy katalog z danymi źródła, waliduje kody na enumach domeny i zapisuje `assets/seed/exercises.json`. Instrukcja jest w `docs/development.md`.
- **Identyfikatory:** stałe UUIDv7 w `tool/seed/ids.json` (klucz → id), generowane raz dla nowego klucza. Klucza nie wolno zmieniać.
- **Wersje:** plik ma `seedVersion`, a każda pozycja `rev`, czyli wersję seeda, w której się ostatnio zmieniła. Skrypt odmówi zapisu zmienionej treści bez podbicia `seed_version`.
- **Synchronizacja przy starcie** (`ExerciseSeeder`, jedna transakcja): gdy `seedVersion` jest wyższy niż zapisany w `settings.seed_version`, nowe pozycje są dodawane, a pozycje z nowszym `rev` aktualizowane. Zmodyfikowane przez użytkownika (`user_modified`) są pomijane, archiwizacja zostaje zachowana, a niczego się nie usuwa. Błąd seeda nie blokuje startu aplikacji.
- **Edycja ćwiczenia wbudowanego** ustawia `user_modified`. Wbudowanego nie można usunąć, tylko zarchiwizować. Własne nieużyte można usunąć (miękko).
- **Wyszukiwanie** dopasowuje fragmenty nazwy i aliasów bez polskich znaków, z rankingiem: początek nazwy, potem fragment nazwy, potem alias. Nie rozpoznaje odmiany („ławka” nie znajdzie „na ławce”, „ławce” już tak); ulepszenie jest w backlogu.
- **Filtry:** mięśnie główne, sprzęt, kategoria, wbudowane lub własne, tylko zarchiwizowane. W obrębie grupy wybrane wartości łączy „lub”, a grupy między sobą „i”.
