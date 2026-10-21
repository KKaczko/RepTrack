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

## Implementacja (Etap 6)

- Opis formatu i JSON Schema: [backup-format.md](../backup-format.md), [backup-format.schema.json](../backup-format.schema.json). Schemat jest generowany z opisu pól w kodzie, a test pilnuje zgodności.
- Eksport i import działają na surowych kolumnach schematu bazy według jawnej listy pól (`backup_format.dart`), niezależnie od encji domeny i klas Drift.
- Walidacja całego pliku przed zapisem: typy, kody, zakresy, daty, unikalność identyfikatorów, klucze obce, pomiar ćwiczenia, jedna aktywna sesja.
- Kopia bezpieczeństwa przed przywróceniem: `files/kopie`, 5 najnowszych, poza Android Auto Backup.
- Pliki zapisywane i otwierane przez systemowy wybór pliku (`file_picker` 13.1.0, MIT), udostępnianie przez systemowy arkusz (`share_plus` 13.3.1, BSD-3). Aplikacja nie prosi o uprawnienia do pamięci.
- CSV: kolumna „Notatka” to notatka treningu; RIR i RPE w osobnych kolumnach.
- Android Auto Backup: reguły obejmują tylko bazę; checkpoint WAL przy przejściu w tło.

## Poprawki z przeglądu (2026-10-21)

- Eksport czyta wszystkie tabele w jednej transakcji: zapis w trakcie (np. seria w trwającym treningu) czeka, więc kopia jest spójna.
- Przywracanie usuwa wiersze z powiadomieniem Drift (`UpdateKind.delete`), więc tabele puste po przywróceniu (np. plan) odświeżają ekrany bez restartu.
- Walidacja metadanych: `exportedAt` wymagany (czas UTC), `appVersion` tekstem, `units` (jeśli jest) równe `backupUnits`. Plik z innymi jednostkami jest odrzucany, bo wartości byłyby źle odczytane.
- Po przywróceniu przerwa poprzedniego treningu jest anulowana, a przerwa aktywnego treningu z kopii dostaje powiadomienie od nowa.

## Konsekwencje

- Zmiana formatu backupu wymaga nowej `formatVersion` i migracji przy imporcie.
- Przełącznik formatu CSV „międzynarodowy” (przecinek, kropka dziesiętna) trafia do backlogu.
