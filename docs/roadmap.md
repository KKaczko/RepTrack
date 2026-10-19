# Plan etapów, testy i ryzyka

Status: Etapy 0–2 zaakceptowane (2026-10-19). W trakcie: Etap 3. Szczegóły w sekcji „Odstępstwa od planu”.

## Ustalenia

- applicationId: `io.github.kkaczko.reptrack`
- Środowisko instaluje agent na `D:\Dev\tools`, za zgodą właściciela przy każdym kroku. Na `C:` jest mało miejsca (18 GB), więc SDK, cache Gradle (`GRADLE_USER_HOME`) i pub (`PUB_CACHE`) idą na `D:`.
- Katalog ćwiczeń: free-exercise-db (Unlicense) + własne polskie nazwy.
- Telefon testowy: Samsung (One UI).

## Wersje sprawdzone 2026-10-19 (pub.dev, docs.flutter.dev)

| Element | Wersja |
| --- | --- |
| Flutter (stable) | 3.47.7 |
| Dart | 3.13.5 |
| drift | 2.35.2 (sqlite3 ^3.4) |
| flutter_riverpod | 3.4.3 |
| go_router | 18.1.0 (feature-complete, flutter.dev) |
| flutter_local_notifications | 22.3.2 (wymaga desugaringu, compileSdk 36) |
| fl_chart | 1.2.0 |

Domyślne wartości Fluttera: minSdk 24, compile/target 36. Dokładne wersje pakietów ustala `flutter pub add` w Etapie 1.

## Etapy

Każdy etap kończy się tak samo: zielony `tool/check.sh`, commit, raport (co zrobione, odstępstwa, pytania) i stop do akceptacji.

0. **Plan.** Ten dokument, [architektura](architecture.md), [model danych](data-model.md), [UX](ux.md), [ADR-y](decisions/README.md), [backlog](backlog.md).

1. **Fundament.**
   - Środowisko na `D:\Dev\tools`: Flutter 3.47.x (`git clone -b stable`), JDK 17 (winget), Android cmdline-tools z platformą 36 i build-tools, zmienne `ANDROID_HOME`, `GRADLE_USER_HOME`, `PUB_CACHE`, `PATH`. Licencje SDK (`sdkmanager --licenses`) akceptuje właściciel.
   - `flutter create --org io.github.kkaczko --project-name reptrack --platforms android`; iOS po MVP. minSdk 26, target/compile 36.
   - Lint: `flutter_lints` + `strict-casts`, `strict-inference`, `strict-raw-types` i dodatkowe reguły.
   - Tokeny, motyw ciemny i jasny, ARB PL/EN, go_router z shellem i ekranami-zaślepkami.
   - Schemat Drift v1 wszystkich tabel ze zrzutem `drift_schemas/` i infrastrukturą testów migracji, interfejsy i implementacje repozytoriów.
   - Testy: domena dziedziczenia serii, `localDateFor`, generator UUIDv7, test czystości domeny.
   - `key.properties.example` z fallbackiem na podpis debug, `tool/check.sh`.

2. **Biblioteka ćwiczeń.**
   - `tool/seed/` buduje `assets/seed/exercises.json` z ~120 pozycji free-exercise-db oraz pliku nadpisań PL (nazwy, aliasy, krótkie wskazówki techniki), ze stałymi UUIDv7.
   - Seeder z logiką wersji: nie nadpisuje `user_modified` i niczego nie usuwa.
   - Wyszukiwarka bez diakrytyków i filtry.
   - Własne ćwiczenia: dodawanie, edycja, aliasy, archiwizacja. Twarde usunięcie tylko nieużytych.
   - Ekran „Licencje i źródła”: dane katalogu, Inter (OFL), pakiety przez `LicenseRegistry`.

3. **Szablony.** CRUD, duplikowanie, archiwizacja, przeciąganie kolejności, wspólny cel z nadpisaniami per seria, „przywróć dziedziczenie”, zmiana liczby serii.

4. **Aktywny trening.**
   - Start z szablonu i pusty, podpowiedzi i poprzednie wyniki.
   - Zmiany w trakcie: dodaj, usuń, zamień, zmień kolejność ćwiczeń i serii.
   - Zapis w transakcji przy każdej zmianie, wznawianie po restarcie.
   - Timer przerwy ([ADR 0009](decisions/0009-timer-przerwy.md)), `wakelock_plus`.
   - Zakończenie: podsumowanie, rekordy, notatka, samopoczucie, diff szablonu z potwierdzeniem. Porzucenie z potwierdzeniem.

5. **Historia i progres.** Lista i szczegóły z edycją (`updated_at`), historia ćwiczenia, porównanie z poprzednim, e1RM, objętość, rekordy, wykresy (fl_chart), ekran Start.

6. **Eksport i backup.**
   - Backup JSON: format v1 opisany w `docs/backup-format.md` z JSON Schema.
   - Import: walidacja całego pliku, migracje formatu, automatyczny backup przed zastąpieniem, jedna transakcja. Plik nowszej wersji odrzucany.
   - CSV i Markdown z filtrami okresu i ćwiczeń.
   - Pliki przez systemowy wybór (SAF), schowek, share sheet.
   - Android Auto Backup: reguły `dataExtractionRules`, checkpoint WAL przy przejściu w tło, test `adb shell bmgr`.

7. **Dopracowanie i wydanie.**
   - Przegląd UX i dostępności: duża czcionka, 360 dp, TalkBack.
   - Wydajność, jasny motyw.
   - Podpisane APK i AAB (keystore generuje właściciel).
   - Dokumentacja: README, budowanie, `docs/publishing.md` (Play App Signing, testy zamknięte, Data safety), `docs/future/sync-and-mcp.md`.

## Plan testów

| Obszar | Rodzaj | Co sprawdza |
| --- | --- | --- |
| Dziedziczenie serii | unit (domena) | wspólny cel; nadpisanie pojedynczej serii; przywrócenie dziedziczenia; zmiana liczby serii; piramida 12–15/10–12/8–10/6–8 |
| Kopia szablonu do sesji | unit + Drift | sesja to niezależna kopia efektywnego planu i snapshotów |
| Niezależność historii | Drift (prawdziwa baza) | zmiana szablonu, nazwy i pomiaru ćwiczenia oraz archiwizacja nie zmieniają zapisanych sesji |
| Trwałość | Drift na pliku | zapis po każdej akcji; zamknięcie i ponowne otwarcie bazy (symulacja ubicia) odtwarza aktywną sesję i `rest_ends_at` |
| Jedna aktywna sesja | Drift | druga aktywna sesja jest odrzucona przez indeks |
| Czas | unit | trening przez północ; zmiana strefy w trakcie; DST w Europe/Warsaw |
| Poprzednie wykonanie i podpowiedzi | unit | dopasowanie po kolejności serii roboczych; podpowiedź nigdy nie ustawia `completed_at` |
| Seed | Drift | aktualizacja nie nadpisuje `user_modified`, dodaje nowe pozycje |
| Wyszukiwanie | unit | „lawka” → „ławka”, aliasy EN |
| Metryki | unit | e1RM (Epley, ≤ 10 powt., 1 powt. = ciężar), objętość bez rozgrzewek, rekordy, tryby obciążenia |
| Migracje | drift_dev SchemaVerifier | każda wersja schematu z `drift_schemas/` |
| Backup | unit + Drift | eksport → import daje identyczne dane; migracja starszego formatu; uszkodzony plik odrzucony bez zmian w bazie |
| CSV / MD | unit (golden tekstowe) | separator, BOM, przecinek dziesiętny, jednostki w nagłówkach |
| Aktywny trening | widget | 1 tapnięcie zatwierdza; budżet tapnięć z [ux.md](ux.md); brak overflow przy 360 dp i skali czcionki 2,0 |
| Architektura | unit | `domain/` nie importuje Fluttera ani Drift |

Testy integracyjne na urządzeniu (`integration_test`) dochodzą w Etapie 7. `check.sh` ich nie uruchamia, bo nie zakłada podłączonego telefonu. Kontrole ręczne z sekcji 9 specyfikacji właściciel wykonuje na telefonie po etapie, którego dotyczą.

### `tool/check.sh` (bash, działa w Git Bash)

1. `flutter pub get`
2. `dart run build_runner build --delete-conflicting-outputs`
3. `flutter gen-l10n`
4. `dart format --output=none --set-exit-if-changed` (pliki niegenerowane)
5. `flutter analyze --fatal-infos`
6. `flutter test`
7. `flutter build apk --release`; od Etapu 7 także `appbundle`. Bez `key.properties` podpis debug.

## Ryzyka

| Ryzyko | Mitygacja |
| --- | --- |
| Timer przerwy w tle. Exact alarms są domyślnie zablokowane od Androida 14, `USE_EXACT_ALARM` jest zastrzeżony dla aplikacji typu budzik/zegar, a One UI na Samsungu usypia aplikacje w tle. | [ADR 0009](decisions/0009-timer-przerwy.md). Test na telefonie w Etapie 4. Plan B: foreground service. |
| sqlite3 3.x (build hooks) w testach na Windows | **Rozwiązane w Etapie 1:** testy na prawdziwej bazie SQLite działają na Windows bez dodatkowej konfiguracji. |
| Brak toolchainu, mało miejsca na C: | Wszystko na `D:`, ścieżki cache przez zmienne środowiskowe. Po Etapie 2 dodany emulator `RepTrack_360dp` (Android 36, 360 dp) do testów automatycznych; telefon zostaje do kontroli ręcznych. |
| Auto Backup i WAL | Checkpoint `TRUNCATE` przy pauzie aplikacji. Reguły obejmują `.db` i `-wal`. Test backup → reinstalacja → restore. |
| Jakość polskich nazw w katalogu | Nazwy i aliasy pisane ręcznie, w Etapie 2 lista do przeglądu przez właściciela. |
| Wymagania Google Play zmieniają się co roku | `docs/publishing.md` z datą weryfikacji. Target API 36 od 31.08.2026 potwierdzony na developer.android.com (2026-10-19). |
| Testy zamknięte dla nowych kont osobistych (12 testerów przez 14 dni) | **Niezweryfikowane w dokumentacji Google** (źródła zewnętrzne, 2026-10-19). Do potwierdzenia w Etapie 7. |
| Weryfikacja deweloperów Androida (sideloading od 2026, najpierw wybrane kraje) | **Niezweryfikowane.** Do sprawdzenia przed Etapem 7, czy dotyczy instalacji APK w Polsce. |

## Weryfikacja

- **Każdy etap:** `bash tool/check.sh` przechodzi (format, analiza bez ostrzeżeń, testy, build release APK), commit na `main` (bez push bez zgody właściciela) i raport.
- **Etap 1:** `flutter doctor` bez błędów dla Androida, aplikacja-szkielet startuje na telefonie (`flutter run`), test migracji v1 przechodzi.
- **Koniec MVP:** wszystkie kontrole automatyczne z sekcji 9 specyfikacji są pokryte testami z tabeli powyżej, a właściciel przechodzi listę kontroli ręcznych na telefonie.

## Odstępstwa od planu

### Etap 1

- **JDK** pobrany jako oficjalny zip Microsoft OpenJDK 17 zamiast przez winget, żeby trafił na `D:` bez instalatora i akceptowania umowy.
- **Android SDK:** `sdkmanager` został zastąpiony nowym `android` CLI i nie ma już kroku `--licenses`. Warunki SDK zaakceptował właściciel przed instalacją pakietów. Szczegóły w [development.md](development.md).
- **Kody enumów:** pierwsza implementacja zapisywała nazwy z Dart (camelCase). Na decyzję właściciela zmienione na jawne kody snake_case ([ADR 0013](decisions/0013-kody-enumow.md)); zrzut schematu v1 wygenerowany ponownie, bo nie było jeszcze żadnych danych.
- **`build_runner`** w wersji 2.16 ignoruje flagę `--delete-conflicting-outputs`, więc `check.sh` jej nie używa.
- **Testy widżetów z bazą** wymagają połączenia z `closeStreamsSynchronously: true` (opis w [development.md](development.md)).

### Etap 2

- **Katalog:** 118 ćwiczeń (115 z free-exercise-db, 3 opracowania własne: przysiad bułgarski, swing oburącz, podciąganie z asystą), w zakresie 100–150 z planu.
- **Klucze ustawień** przeniesione do `lib/core/database/setting_keys.dart`, żeby seeder nie importował warstwy danych funkcji „ustawienia”.
- **Formularz ćwiczenia** używa `SingleChildScrollView` zamiast `ListView`. `ListView` niszczył pola poza ekranem, więc walidacja pomijała pustą nazwę po przewinięciu do „Zapisz”. Błąd wychwycił test widżetu.
- **Arkusz filtrów** otwiera się na głównym nawigatorze, bo snackbar zasłaniał przycisk „Pokaż wyniki”. Również wychwycone testem.
- **Ekran ustawień** zawiera na razie tylko „Licencje i źródła”. Motyw, jednostki, krok ciężaru, skala wysiłku i przerwa dojdą w Etapie 4 razem z funkcjami, które z nich korzystają.
