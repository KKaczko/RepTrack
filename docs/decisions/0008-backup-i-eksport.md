# ADR 0008: Backup, import i eksport

- Status: zaakceptowana (2026-10-19)
- Odwracalność: trudna ⚠ (format backupu)

## Kontekst

Pełny backup i eksport filtrowany to osobne funkcje. Backup musi przetrwać zmiany schematu bazy, więc jego wersja jest niezależna od wersji schematu.

## Decyzja

- **Backup JSON:** `formatVersion: 1`, `appVersion`, `exportedAt`, metadane jednostek, ustawienia i wszystkie encje (także zarchiwizowane i miękko usunięte). Płaskie tablice per tabela, klucze camelCase, czasy ISO 8601 UTC, ciężar w gramach. Mapowanie pisane ręcznie, niezależne od kształtu encji domeny. Opis w `docs/backup-format.md` z JSON Schema (Etap 6).
- **Import:** tryb „zastąp wszystko”. Walidacja całego pliku przed zapisem, migracja starszych wersji formatu, automatyczny backup bieżących danych przed zastąpieniem, jedna transakcja (wszystko albo nic). Plik z nowszej wersji aplikacji odrzucany z czytelnym komunikatem. Scalanie po MVP.
- **CSV:** średnik jako separator, UTF-8 z BOM, przecinek dziesiętny, jednostki w nagłówkach, jeden wiersz na serię. Bez BOM polski Excel psuje polskie znaki.
- **Markdown:** tabele per sesja lub per ćwiczenie z jawnymi jednostkami, schowek i share sheet.

## Konsekwencje

- Zmiana formatu backupu wymaga nowej `formatVersion` i migracji przy imporcie.
- Przełącznik formatu CSV „międzynarodowy” (przecinek, kropka dziesiętna) trafia do backlogu.
