# Format kopii zapasowej i eksportu

Status: wersja formatu 3 (zamienniki ćwiczeń, [ADR 0016](decisions/0016-zamienniki-cwiczen.md)); wersje 1 (Etap 6) i 2 (plan treningów, [ADR 0015](decisions/0015-plan-treningow.md)) są migrowane przy wczytaniu. Decyzja: [ADR 0008](decisions/0008-backup-i-eksport.md). Pełny opis pól: [backup-format.schema.json](backup-format.schema.json) (JSON Schema 2020-12, generowana z `lib/features/backup/domain/backup_format.dart`).

## Kopia zapasowa (JSON)

Jeden plik UTF-8 z obiektem JSON. Kopia obejmuje wszystko: także zarchiwizowane i miękko usunięte wiersze oraz ustawienia.

```json
{
  "format": "reptrack-backup",
  "formatVersion": 3,
  "appVersion": "1.0.0+1",
  "exportedAt": "2026-10-19T18:05:00.000Z",
  "units": { "weight": "g", "distance": "m", "duration": "s", "effort": "tenths", "time": "ISO 8601 UTC" },
  "exercises": [ … ],
  "templates": [ … ],
  "templateExercises": [ … ],
  "templateSets": [ … ],
  "workoutSessions": [ … ],
  "sessionExercises": [ … ],
  "sessionSets": [ … ],
  "weeklyPlans": [ … ],
  "weeklyPlanDays": [ … ],
  "plannedDays": [ … ],
  "exerciseSubstitutes": [ … ],
  "settings": [ { "key": "weight_unit", "value": "kg", "updatedAt": "…" } ]
}
```

### Zasady

- **Tabele:** płaska tablica obiektów na tabelę bazy. Klucze w camelCase, np. `template_exercise_id` → `templateExerciseId`.
- **Identyfikatory:** teksty (UUIDv7, a dla ćwiczeń wbudowanych stałe identyfikatory z seeda). Odwołania między tabelami to identyfikatory, np. `sessionSets[].sessionExerciseId`.
- **Czas:** ISO 8601 w UTC z `Z`, np. `2026-10-19T16:05:00.000Z`. Data treningu (`localDate`) to `YYYY-MM-DD` w strefie zapisanej w `timeZone`.
- **Jednostki:** ciężar w gramach, dystans w metrach, czas w sekundach, wysiłek RIR/RPE w dziesiątych częściach (`effortTenths: 85` to RPE 8,5). Jednostka wyświetlania (kg/lb) jest w ustawieniach i nie zmienia wartości w pliku.
- **Kody:** stałe kody snake_case z [data-model.md](data-model.md#kody-enumów-v1), np. `weighted_bodyweight`.
- **Wspólne pola** każdej tabeli poza `settings`: `id`, `createdAt`, `updatedAt`, `deletedAt` (null albo czas miękkiego usunięcia).
- **Ustawienia:** tablica `{key, value, updatedAt}`, gdzie `value` to dowolna wartość JSON. Klucze opisuje [data-model.md](data-model.md).

### Przywracanie

1. Plik jest odczytywany i sprawdzany w całości, zanim cokolwiek trafi do bazy:
   - format;
   - wersja;
   - typy pól, kody i zakresy;
   - unikalne identyfikatory i klucze obce;
   - co najmniej jedno pole pomiaru w każdym ćwiczeniu;
   - najwyżej jeden aktywny trening.
2. Plik z wyższą `formatVersion` niż obsługiwana jest odrzucany z komunikatem o aktualizacji aplikacji.
3. Starsze wersje przechodzą przez migracje formatu (`backupMigrations`, każda z wersji `n` do `n + 1`). Migracja 1 → 2 dodaje puste tablice `weeklyPlans`, `weeklyPlanDays` i `plannedDays` (kopia sprzed planu treningów), a 2 → 3 pustą tablicę `exerciseSubstitutes` (kopia sprzed zamienników).
4. Przed zastąpieniem aplikacja zapisuje kopię bieżących danych w pamięci telefonu (`files/kopie`, 5 najnowszych, poza Android Auto Backup).
5. Zastąpienie odbywa się w jednej transakcji: usunięcie wszystkich wierszy i wstawienie danych z pliku. Przy jakimkolwiek błędzie baza zostaje bez zmian.

Tryb importu w MVP to „zastąp wszystko”. Scalanie jest w [backlogu](backlog.md).

### Zmiana formatu

Zmiana kształtu pliku (nowe pole wymagane, zmiana nazwy, inna jednostka) wymaga:

1. podniesienia `backupFormatVersion`;
2. migracji z poprzedniej wersji w `backupMigrations`;
3. testu migracji na pliku starszej wersji;
4. ponownego wygenerowania schematu: `REPTRACK_WRITE_SCHEMA=1 flutter test test/features/backup/domain/backup_schema_test.dart`.

Nowe pole opcjonalne (nullable) nie wymaga nowej wersji, jeśli import starszych plików przyjmuje dla niego null.

## Eksport CSV

Do arkusza kalkulacyjnego. Jeden wiersz na zatwierdzoną serię zakończonego treningu, z filtrami okresu i ćwiczeń.

- Kodowanie UTF-8 z BOM, separator średnik, przecinek dziesiętny, końce linii CRLF. Bez BOM polski Excel psuje polskie znaki.
- Kolumny: Data, Godzina, Trening, Szablon, Ćwiczenie, Seria, Typ serii, Ciężar (kg albo lb), Powtórzenia, Czas (s), Dystans (m), RIR, RPE, Notatka (notatka treningu).
- Ciężar w jednostce z ustawień, do dwóch miejsc po przecinku, bez separatora tysięcy. Pola ze średnikiem, cudzysłowem albo nową linią są ujęte w cudzysłowy.
- Nazwa ćwiczenia: aktualna z biblioteki ([ADR 0006](decisions/0006-poprzednie-wykonanie-i-podpowiedzi.md)).

## Eksport Markdown

Do wklejenia w czat z modelem językowym. Na początku jest zdanie o jednostkach; separator dziesiętny i teksty są w języku aplikacji.

- **Per trening:** nagłówek z datą i nazwą treningu, linia ze startem, czasem trwania, szablonem i samopoczuciem, notatka, a dalej tabela na ćwiczenie. Kolumny tabeli to tylko mierzone pola oraz RIR/RPE, gdy wpisano wysiłek.
- **Per ćwiczenie:** nagłówek ćwiczenia i tabela „Data | Trening | Serie”, np. `85×8 @RIR 2, 85×7`.

Markdown można udostępnić jako tekst, zapisać do pliku `.md` albo skopiować do schowka.

## Android Auto Backup

- Reguły `res/xml/backup_rules.xml` (Android do 11) i `res/xml/data_extraction_rules.xml` (od 12) obejmują tylko `files/reptrack.sqlite` i `files/reptrack.sqlite-wal`.
- Przy przejściu aplikacji w tło wykonuje się `PRAGMA wal_checkpoint(TRUNCATE)`, więc kopia systemowa zawiera spójną bazę z pustym WAL.
- Ustawienia są w bazie, więc trafiają do kopii systemowej razem z danymi.
- Jak sprawdzić odtworzenie po reinstalacji: [development.md](development.md#android-auto-backup).
