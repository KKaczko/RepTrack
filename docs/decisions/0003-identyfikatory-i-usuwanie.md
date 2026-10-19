# ADR 0003: Identyfikatory i miękkie usuwanie

- Status: zaakceptowana (2026-10-19)
- Odwracalność: trudna ⚠

## Kontekst

Specyfikacja wymaga UUIDv7 generowanych na urządzeniu, kolumn `createdAt`, `updatedAt`, `deletedAt` i miękkiego usuwania, z myślą o przyszłej synchronizacji. Rekordy wbudowanej biblioteki muszą mieć stabilne identyfikatory między wersjami aplikacji.

## Decyzja

- `id TEXT PRIMARY KEY` z UUIDv7 w postaci tekstowej (36 znaków). Czytelne w backupie JSON i eksporcie, uporządkowane czasowo.
- Rekordy wbudowane mają stałe UUIDv7 wygenerowane raz i zapisane w pliku seed (`assets/seed/exercises.json`).
- Każda tabela poza `settings` ma `created_at`, `updated_at`, `deleted_at` (epoch ms UTC). Usuwanie jest wyłącznie miękkie.
- Klucze autoinkrementowane (rowid SQLite) nie są identyfikatorami biznesowymi i nie trafiają do backupu.

## Konsekwencje

- Synchronizacja „ostatni zapis wygrywa” per rekord według `updated_at` jest możliwa bez zmian schematu.
- Zapytania muszą filtrować `deleted_at IS NULL`; repozytoria robią to domyślnie.
- Indeks tekstowy jest większy niż na liczbach, przy skali aplikacji bez znaczenia.
