# Model danych (Drift, schemat v3)

Status: zaimplementowany w Etapie 1 jako schemat v1 (`lib/core/database/tables.dart`, zrzut `drift_schemas/app_database/drift_schema_v1.json`). Decyzje: [ADR 0003](decisions/0003-identyfikatory-i-usuwanie.md), [ADR 0004](decisions/0004-dziedziczenie-serii.md), [ADR 0005](decisions/0005-katalog-cwiczen.md).

Model rozdziela trzy warstwy: definicję ćwiczenia, plan (szablon) i wykonanie (sesję). Sesja jest kopią planu z chwili startu. Zmiany szablonu i ćwiczenia nigdy nie modyfikują istniejących sesji. Ręczna korekta zakończonej sesji jest dozwolona i aktualizuje `updated_at`.

## Wspólne zasady

- **Kolumny wspólne** (każda tabela poza `settings`): `id TEXT PK` (UUIDv7 z urządzenia), `created_at`, `updated_at`, `deleted_at INT NULL`.
- **Czas:** epoch ms UTC.
- **Usuwanie:** wyłącznie miękkie. Zapytania domyślnie filtrują `deleted_at IS NULL`.
- **Klucze obce:** `PRAGMA foreign_keys = ON`, tryb WAL.
- **Jednostki:** ciężar w gramach (`INT`), dystans w metrach, czas w sekundach, RIR/RPE w dziesiątych częściach (`INT`, np. RPE 8,5 → 85). Konwersja kg/lb wyłącznie w UI.
- **Enumy:** zapisywane jako stabilne kody tekstowe w snake_case, nie indeksy ani nazwy z Dart ([ADR 0013](decisions/0013-kody-enumow.md)). Te same kody trafiają do bazy i backupu. Wartości wolno dodawać, a zmiana lub usunięcie kodu wymaga migracji. Kody przypina test `test/core/domain/enum_codes_test.dart`.

### Kody enumów (v1)

| Enum | Kody |
| --- | --- |
| MuscleGroup | abdominals, abductors, adductors, biceps, calves, chest, forearms, glutes, hamstrings, lats, lower_back, middle_back, neck, quadriceps, shoulders, traps, triceps |
| Equipment | barbell, dumbbell, kettlebell, cable, machine, smith_machine, ez_bar, bodyweight, bands, medicine_ball, exercise_ball, foam_roll, other |
| ExerciseCategory | strength, cardio, mobility, plyometrics, olympic, strongman |
| Mechanic | compound, isolation |
| Force | push, pull, static |
| LoadMode | external, bodyweight, weighted_bodyweight, assisted |
| WeightSemantics | total, per_hand, per_side |
| ExerciseSource | builtin, user |
| SetType | warmup, working, drop, amrap |
| TargetKind | reps, duration |
| EffortScale | rir, rpe |
| SessionStatus | active, completed, discarded |
| Side | both, left, right |
| AppThemeMode (ustawienia) | dark, light, system |
| WeightUnit (ustawienia) | kg, lb |
| PlannedKind (v2) | workout, rest |

Klucze `settings`: `theme_mode`, `weight_unit`, `weight_step`, `effort_scale` (`off` / `rir` / `rpe`), `default_rest_seconds`, `keep_screen_on`, `exact_alarm_prompted` (czy pokazano prośbę o dokładne alarmy), `assistant_url` i `assistant_model` (serwer Ollama i model asystenta AI, [ADR 0014](decisions/0014-asystent-ai-ollama.md); `null` wyłącza asystenta), `plan_reminders` i `plan_reminder_minutes` (przypomnienia o treningach z planu i ich godzina w minutach od północy, [ADR 0015](decisions/0015-plan-treningow.md)), `duration_step_seconds` i `distance_step_meters` (kroki stepperów czasu i dystansu, [ADR 0016](decisions/0016-zamienniki-cwiczen.md)).

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

Pary `key TEXT PK`, `value TEXT (JSON)`, `updated_at`. Klucze: motyw, jednostka (kg/lb), kroki ciężaru, czasu i dystansu, skala wysiłku (off / rir / rpe), domyślna przerwa, „nie wygaszaj ekranu”, wersja seeda. Ustawienia są w bazie, więc backup obejmuje je automatycznie.

## `weekly_plans` (v2)

Wersje planu tygodniowego: `starts_on` i `ends_on` (daty lokalne `YYYY-MM-DD`, `ends_on` NULL = obowiązuje). Edycja działającego planu zamyka wersję na wczoraj i zaczyna nową od dziś ([ADR 0015](decisions/0015-plan-treningow.md)).

## `weekly_plan_days` (v2)

`plan_id → weekly_plans`, `weekday` (1 = poniedziałek … 7, CHECK), `template_id → templates`, `position` (kilka treningów w dniu).

## `planned_days` (v2)

Wpisy na pojedyncze daty: `date`, `kind` (`workout` | `rest`), `template_id` (NULL dla `rest`; CHECK: `workout` wymaga szablonu), `position`, `note`. Wpisy daty zastępują plan tygodniowy tego dnia.

## `exercise_substitutes` (v3)

Przypięte zamienniki: `exercise_id → exercises`, `substitute_id → exercises`, `position` (kolejność przypięcia). Para działa w obie strony; odpięcie to miękkie usunięcie ([ADR 0016](decisions/0016-zamienniki-cwiczen.md)). Propozycje automatyczne nie są zapisywane.

## Relacje i indeksy

```
exercises 1─N template_exercises N─1 templates
template_exercises 1─N template_sets
workout_sessions N─1 templates (nullable)
workout_sessions 1─N session_exercises N─1 exercises
session_exercises 1─N session_sets
weekly_plans 1─N weekly_plan_days N─1 templates
planned_days N─1 templates (nullable)
exercises 1─N exercise_substitutes N─1 exercises
```

| Indeks | Cel |
| --- | --- |
| `UNIQUE workout_sessions(status) WHERE status='active' AND deleted_at IS NULL` | najwyżej jedna aktywna sesja, wymuszone w bazie |
| `workout_sessions(local_date)`, `(started_at)`, `(template_id, started_at)` | historia, tydzień, ostatnio używane szablony |
| `template_exercises(template_id, position)`, `(exercise_id)` | edytor, blokada usuwania ćwiczenia |
| `template_sets(template_exercise_id, position)` | |
| `session_exercises(session_id, position)`, `(exercise_id)` | poprzednie wykonanie, historia ćwiczenia |
| `session_sets(session_exercise_id, position)` | |
| `weekly_plan_days(plan_id, weekday, position)` | dni wersji planu |
| `planned_days(date, position)` | wpisy dnia w kalendarzu |
| `exercise_substitutes(exercise_id)`, `(substitute_id)` | przypięte zamienniki w obie strony |

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
- **Plan** (`lib/features/plan/domain/plan_schedule.dart`): `dayPlan`, `dayOverview` (stany), `weekAdherence`, `planStreak`, operacje na dniach i `editWeeklyPlan` (wersjonowanie).
- **`suggestSubstitutes(target, catalog, {pinned, used})`** (`lib/features/exercises/domain/substitutes.dart`): przypięte na górze, potem propozycje według mięśni, ruchu, sprzętu i historii ([ADR 0016](decisions/0016-zamienniki-cwiczen.md)).

## Migracje

- **v1 → v2** (plan treningów): nowe tabele `weekly_plans`, `weekly_plan_days`, `planned_days` z indeksami; istniejące tabele bez zmian.
- **v2 → v3** (zamienniki ćwiczeń): nowa tabela `exercise_substitutes` z dwoma indeksami; istniejące tabele bez zmian.

Każda zmiana schematu to migracja Drift (`stepByStep`) z testem na zapisanych wersjach schematu (`drift_schemas/`, `drift_dev make-migrations`). Wersja schematu bazy jest niezależna od wersji formatu backupu ([ADR 0008](decisions/0008-backup-i-eksport.md)).
