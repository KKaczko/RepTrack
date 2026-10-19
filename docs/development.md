# Środowisko i komendy

Pełna instrukcja budowania i wydania powstanie w Etapie 7. Ten dokument opisuje środowisko używane od Etapu 1.

## Wersje

| Narzędzie | Wersja | Lokalizacja (maszyna właściciela) |
| --- | --- | --- |
| Flutter | 3.47.7 stable (Dart 3.13.5) | `D:\Dev\tools\flutter` |
| JDK | Microsoft OpenJDK 17.0.20.1 | `D:\Dev\tools\jdk-17` |
| Android SDK | platform-tools 37.0.1, platforms/android-36, build-tools/36.0.0, ndk/28.2.13676358 | `D:\Dev\tools\android-sdk` |
| Gradle / AGP / Kotlin | 9.3.1 / 9.1.0 / 2.4.0 (z szablonu Fluttera) | cache w `D:\Dev\tools\gradle-home` |

Zmienne użytkownika: `JAVA_HOME`, `ANDROID_HOME`, `GRADLE_USER_HOME`, `PUB_CACHE` oraz wpisy w `PATH` dla `flutter\bin`, `jdk-17\bin`, `android-sdk\platform-tools` i `android-sdk\cmdline-tools\latest\bin`.

## Android SDK: nowe `android` CLI

Od cmdline-tools 16111833 `sdkmanager` jest przestarzały. Pakiety instaluje się poleceniem `android sdk install`, z nazwami pakietów pisanymi przez ukośnik. Osobnego kroku `--licenses` już nie ma: instalacja oznacza akceptację [warunków Android SDK](https://developer.android.com/studio/terms). Narzędzie domyślnie wysyła do Google statystyki użycia, dlatego zawsze dodajemy `--no-metrics`:

```bash
D:/Dev/tools/android-sdk/cmdline-tools/latest/bin/android.exe --no-metrics --sdk=D:/Dev/tools/android-sdk sdk install platforms/android-36
```

## Emulator i telefon

| Urządzenie | Do czego |
| --- | --- |
| Emulator `RepTrack_360dp` | automatyczne testy na prawdziwym Androidzie, zrzuty ekranu, różne rozmiary i ustawienia; uruchamia go agent |
| Samsung Galaxy S20 FE (Android 13, One UI 5.1, 360 dp) | kontrole ręczne właściciela (sekcja 9 specyfikacji), zachowania One UI: usypianie w tle, powiadomienia, wibracje |

Emulator: Android 36 (Google APIs, x86_64), 1080×2400 przy 480 dpi, czyli 360×800 dp jak telefon testowy. Język pl-PL, strefa Europe/Warsaw. Wirtualne urządzenia są w `D:\Dev\tools\avd` (zmienna `ANDROID_AVD_HOME`). Wymaga włączonej funkcji Windows „Platforma funkcji hypervisor”.

```bash
bash tool/emulator.sh
```

Instalacja wersji release na emulatorze:

```bash
D:/Dev/tools/android-sdk/platform-tools/adb.exe -s emulator-5554 install -r build/app/outputs/flutter-apk/app-release.apk
```

Na Samsungu z włączonym Bezpiecznym folderem polecenia `adb` dotyczące pakietów wymagają `--user 0`, inaczej kończą się błędem „Shell does not have permission to access user 150”:

```bash
D:/Dev/tools/android-sdk/platform-tools/adb.exe -d install -r --user 0 build/app/outputs/flutter-apk/app-release.apk
```

## Komendy

```bash
bash tool/check.sh
```

Pełna weryfikacja etapu: zależności, generowanie kodu (Drift, freezed), lokalizacja, format, analiza, testy i build release APK. `--skip-build` pomija build, `--bundle` dodaje AAB.

Kod generowany (`*.g.dart`, `*.freezed.dart`, `lib/core/l10n/generated/`) nie jest w repozytorium. Po świeżym checkoucie uruchom `tool/check.sh` albo `dart run build_runner build` i `flutter gen-l10n`.

## Zmiana schematu bazy

1. Zmień tabele w `lib/core/database/tables.dart` i podbij `schemaVersion`.
2. `dart run drift_dev make-migrations`: zrzut nowej wersji w `drift_schemas/` i plik kroków migracji.
3. `dart run drift_dev schema generate drift_schemas/app_database/ test/drift/app_database/generated/`.
4. Dopisz migrację w `onUpgrade` (stepByStep) i test vN → vN+1 z danymi w `test/drift/app_database/migration_test.dart`.

## Biblioteka ćwiczeń (seed)

Źródłem prawdy jest `tool/seed/catalog_pl.yaml` ([ADR 0005](decisions/0005-katalog-cwiczen.md)). Wygenerowany `assets/seed/exercises.json` i mapa identyfikatorów `tool/seed/ids.json` są w repozytorium. Zmiana katalogu:

1. Edytuj `tool/seed/catalog_pl.yaml`. Przy zmianie treści istniejącej pozycji podbij `seed_version`. Klucza (`key`) nie zmieniaj, bo z niego wynika stałe id.
2. Pobierz dane źródła z przypiętego commita (`sourceCommit` w `tool/seed/build_seed.dart`) do katalogu poza repozytorium, np.:

```bash
curl -sSfL -o ../free-exercise-db.json https://raw.githubusercontent.com/yuhonas/free-exercise-db/f00c92c7dcf1216a928a52c3706c7ce8e2f71ed5/dist/exercises.json
```

3. Zbuduj seed:

```bash
dart run tool/seed/build_seed.dart --source ../free-exercise-db.json
```

4. Uruchom `tool/check.sh`; `test/features/exercises/data/seed_catalog_test.dart` sprawdza wynik.

Aplikacja przy starcie stosuje nowszy seed: dodaje nowe pozycje, aktualizuje zmienione i pomija ćwiczenia zmodyfikowane przez użytkownika.

## Testy z bazą

- Testy repozytoriów używają prawdziwej bazy SQLite w pamięci (`memoryDatabase()`) albo w pliku (`fileDatabase()`, symulacja ubicia procesu).
- Testy widżetów używają `widgetTestDatabase()`: połączenie z `closeStreamsSynchronously: true` i zamknięcie przez `tester.runAsync(db.close)`. Bez tego `db.close()` zawiesza test, bo Drift odracza zamykanie strumieni timerem, którego fałszywy zegar `testWidgets` nie uruchamia.
- Testy całej aplikacji uruchamia `pumpRepTrack()` z `test/support/app_harness.dart` (polski język, baza testowa, opcjonalnie seed).
- `test/flutter_test_config.dart` sprawia, że stuknięcie w zasłonięty element kończy test błędem, a nie tylko ostrzeżeniem.
- Zapis do bazy w teście widżetu wykonuj przez `tester.runAsync(...)`.
