# ADR 0013: Kody enumów w snake_case

- Status: zaakceptowana (2026-10-19, decyzja właściciela po Etapie 1)
- Odwracalność: trudna ⚠ (kody są w bazie i w formacie backupu)

## Kontekst

W pierwszej implementacji schematu v1 enumy były zapisywane przez `textEnum` z Drift, czyli jako nazwy wartości w Dart (camelCase, np. `weightedBodyweight`). To odbiegało od `data-model.md` z Etapu 0 (snake_case) i wiązało dane z identyfikatorami w kodzie: zmiana nazwy w Dart po cichu zmieniałaby zapisywane wartości.

## Decyzja

- Każdy enum zapisywany w bazie lub backupie implementuje `CodedEnum` i ma jawne pole `code` w snake_case, niezależne od nazwy w Dart (np. `LoadMode.weightedBodyweight` → `weighted_bodyweight`).
- Drift zapisuje kody przez `CodedEnumConverter` i `CodedEnumListConverter`. Ustawienia (`theme_mode`, `weight_unit`, `effort_scale`) też używają kodów.
- Test `test/core/domain/enum_codes_test.dart` przypina pełną listę kodów, sprawdza snake_case i unikalność.
- Zrzut schematu v1 został wygenerowany ponownie zamiast dodawania migracji v2, bo żadna instalacja nie miała jeszcze danych. Typy kolumn SQL się nie zmieniły.

## Konsekwencje

- Nazwy wartości w Dart można zmieniać bez wpływu na dane.
- Nowa wartość enumu wymaga dopisania jej kodu w teście, co wymusza świadomą decyzję.
- Zmiana albo usunięcie kodu wymaga migracji bazy i nowej wersji formatu backupu.
