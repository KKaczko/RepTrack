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

## Testy z bazą

- Testy repozytoriów używają prawdziwej bazy SQLite w pamięci (`memoryDatabase()`) albo w pliku (`fileDatabase()`, symulacja ubicia procesu).
- Testy widżetów używają `widgetTestDatabase()`: połączenie z `closeStreamsSynchronously: true` i zamknięcie przez `tester.runAsync(db.close)`. Bez tego `db.close()` zawiesza test, bo Drift odracza zamykanie strumieni timerem, którego fałszywy zegar `testWidgets` nie uruchamia.
