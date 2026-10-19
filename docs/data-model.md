# Model danych (Drift, schemat v1)

Status: Etap 0 (plan), zatwierdzony 2026-10-19. Implementacja w Etapie 1. Decyzje: [ADR 0003](decisions/0003-identyfikatory-i-usuwanie.md), [ADR 0004](decisions/0004-dziedziczenie-serii.md), [ADR 0005](decisions/0005-katalog-cwiczen.md).

Model rozdziela trzy warstwy: definicję ćwiczenia, plan (szablon) i wykonanie (sesję). Sesja jest kopią planu z chwili startu. Zmiany szablonu i ćwiczenia nigdy nie modyfikują istniejących sesji. Ręczna korekta zakończonej sesji jest dozwolona i aktualizuje `updated_at`.

## Wspólne zasady

- **Kolumny wspólne** (każda tabela poza `settings`): `id TEXT PK` (UUIDv7 z urządzenia), `created_at`, `updated_at`, `deleted_at INT NULL`.
- **Czas:** epoch ms UTC.
- **Usuwanie:** wyłącznie miękkie. Zapytania domyślnie filtrują `deleted_at IS NULL`.
- **Klucze obce:** `PRAGMA foreign_keys = ON`, tryb WAL.
- **Jednostki:** ciężar w gramach (`INT`), dystans w metrach, czas w sekundach, RIR/RPE w dziesiątych częściach (`INT`, np. RPE 8,5 → 85). Konwersja kg/lb wyłącznie w UI.
- **Enumy:** zapisywane jako stabilne kody tekstowe, nie indeksy.

## `exercises`

| Kolumna | Typ | Uwagi |
| --- | --- | --- |
| name | TEXT | nazwa wyświetlana (PL) |
| aliases | TEXT (JSON array) | aliasy PL i EN, np. „bench press” |
| search_text | TEXT | znormalizowane `name` i aliasy: małe litery, bez diakrytyków (ł→l itd.); liczone przy zapisie |
| primary_muscles, secondary_muscles | TEXT (JSON array kodów) | np. `chest`, `triceps` |
| equipment | TEXT NULL | jeden główny sprzęt |
| category | TEXT | strength / cardio / mobility / plyometrics / olympic / strongman |
| mechanic | TEXT NULL | compound / isolation |
| force | TEXT NULL | push / pull / static (przydatne dla PPL) |
| instructions | TEXT NULL | opis techniki |
| measure_weight, measure_reps, measure_duration, measure_distance | BOOL | CHECK: co najmniej jedno true |
| load_mode | TEXT | external / bodyweight / weighted_bodyweight / assisted |
| weight_semantics | TEXT | total / per_hand / per_side |
| is_unilateral | BOOL | w MVP jedna seria = obie strony |
| image_ref | TEXT NULL | na przyszłe ilustracje |
| source | TEXT | builtin / user |
| origin_ref, license, license_author | TEXT NULL | origin_ref np. `free-exercise-db:Barbell_Squat` |
| seed_version | INT NULL | |
| user_modified | BOOL | edycja rekordu wbudowanego; seed go nie nadpisze |
| archived_at | INT NULL | ćwiczenie użyte w historii można tylko zarchiwizować |

## `templates`

`name`, `description NULL`, `archived_at NULL`. „Ostatnio używane” liczymy z sesji, bez osobnej kolumny.

## `template_exercises`

- `template_id` FK, `exercise_id` FK, `position`
- `target_kind` (reps / duration), `target_min NULL`, `target_max NULL`
- `target_weight_g NULL`, `rest_seconds NULL`, `default_set_type` (domyślnie working), `note NULL`, `group_id NULL` (superserie)
- **Liczby serii nie przechowujemy.** To liczba wierszy `template_sets`, więc licznik nie rozjedzie się z wierszami ([ADR 0004](decisions/0004-dziedziczenie-serii.md)).

## `template_sets`

- `template_exercise_id` FK, `position`
- Nadpisania, gdzie `NULL` znaczy „dziedzicz”: `set_type`, `target_min` + `target_max` (nadpisywane razem), `target_weight_g`, `rest_seconds`.

## `workout_sessions`

- `status`: active / completed / discarded
- `started_at`, `ended_at NULL`, `time_zone` (IANA), `local_date` (`YYYY-MM-DD` w strefie startu, także dla treningu po północy)
- `template_id NULL` FK, `template_name_snapshot NULL`, `title NULL`
- `notes NULL`, `wellbeing NULL` (1–5)
- `rest_ends_at NULL`: koniec bieżącej przerwy, żeby timer przetrwał ubicie procesu

## `session_exercises`

- `session_id` FK, `exercise_id` FK, `position`, `template_exercise_id NULL` (do diffu „zaktualizuj szablon”)
- Snapshot: `exercise_name_snapshot`, `measure_*_snapshot`, `load_mode_snapshot`, `weight_semantics_snapshot`, `is_unilateral_snapshot`
- `note NULL`, `group_id NULL`

## `session_sets`

- `session_exercise_id` FK, `position`, `set_type` (warmup / working / drop / amrap)
- Snapshot planu: `target_kind NULL`, `target_min NULL`, `target_max NULL`, `target_weight_g NULL`, `rest_seconds NULL`
- Wykonanie: `weight_g NULL`, `reps NULL`, `duration_s NULL`, `distance_m NULL`, `effort_scale NULL` (rir / rpe), `effort_tenths NULL`, `side NULL`, `completed_at NULL`
- Seria jest wykonana wtedy i tylko wtedy, gdy `completed_at` nie jest NULL.

## `settings`

Pary `key TEXT PK`, `value TEXT (JSON)`, `updated_at`. Klucze: motyw, jednostka (kg/lb), krok ciężaru, skala wysiłku (off / rir / rpe), domyślna przerwa, „nie wygaszaj ekranu”, wersja seeda. Ustawienia są w bazie, więc backup obejmuje je automatycznie.

## Relacje i indeksy

```
exercises 1─N template_exercises N─1 templates
template_exercises 1─N template_sets
workout_sessions N─1 templates (nullable)
workout_sessions 1─N session_exercises N─1 exercises
session_exercises 1─N session_sets
```

| Indeks | Cel |
| --- | --- |
| `UNIQUE workout_sessions(status) WHERE status='active' AND deleted_at IS NULL` | najwyżej jedna aktywna sesja, wymuszone w bazie |
| `workout_sessions(local_date)`, `(started_at)`, `(template_id, started_at)` | historia, tydzień, ostatnio używane szablony |
| `template_exercises(template_id, position)`, `(exercise_id)` | edytor, blokada usuwania ćwiczenia |
| `template_sets(template_exercise_id, position)` | |
| `session_exercises(session_id, position)`, `(exercise_id)` | poprzednie wykonanie, historia ćwiczenia |
| `session_sets(session_exercise_id, position)` | |

`exercises` to mała tabela (poniżej ~1000 wierszy). Wyszukiwanie i filtry działają w pamięci na wczytanym katalogu, więc wystarczą proste indeksy.

## Kluczowe funkcje domenowe (czysty Dart)

- **`resolveEffectiveSets(templateExercise, templateSets)`**
  - `setType = ts.setType ?? te.defaultSetType`
  - cel z `ts` albo z `te`; ciężar i przerwa analogicznie
  - Zmiana liczby serii dodaje wiersze z samymi NULL-ami albo usuwa ostatnie.
  - „Przywróć dziedziczenie” ustawia NULL.
  - Znane ograniczenie: nie da się nadpisać wartością „brak” (np. seria bez docelowego ciężaru, gdy ćwiczenie ma cel).
- **`buildSessionFromTemplate(...)`** kopiuje efektywny plan i snapshoty ćwiczeń. **`buildEmptySession(...)`** tworzy pusty trening.
- **`previousPerformance(exerciseId)`**: ostatnia zakończona sesja z tym ćwiczeniem, niezależnie od szablonu ([ADR 0006](decisions/0006-poprzednie-wykonanie-i-podpowiedzi.md)).
- **`hintFor(set)`**: podpowiedź liczona dynamicznie, nigdy nie oznacza serii jako wykonanej.
- **`localDateFor(utc, ianaZone)`** na pakiecie `timezone`.
- **`normalizeForSearch`**: małe litery i usunięte polskie znaki, więc „lawka” znajduje „ławka”.
- **Metryki:** e1RM, objętość, rekordy, treningi w tygodniu (tydzień od poniedziałku) ([ADR 0007](decisions/0007-metryki.md)).
- **`templateDiff(session, template)`** dla opcji „zaktualizuj szablon na podstawie treningu”.

## Migracje

Każda zmiana schematu to migracja Drift (`stepByStep`) z testem na zapisanych wersjach schematu (`drift_schemas/`, `drift_dev make-migrations`). Wersja schematu bazy jest niezależna od wersji formatu backupu ([ADR 0008](decisions/0008-backup-i-eksport.md)).
