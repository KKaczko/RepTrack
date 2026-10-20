# Plan etapów, testy i ryzyka

Status: Etapy 0–3 zaakceptowane (2026-10-19). Etapy 4–7 zakończone (2026-10-20) i czekają na przegląd właściciela; od Etapu 4 kolejne etapy szły bez czekania na akceptację (decyzja właściciela). Do wydania zostają kontrole ręczne na telefonie ([publishing.md](publishing.md#lista-kontroli-ręcznych-spec-9)). Szczegóły w sekcji „Odstępstwa od planu”.

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

### Etap 3

- **Granice między funkcjami** doprecyzowane w [architecture.md](architecture.md). Wolno importować cudze `domain/` i publiczne providery (`data/*_providers.dart`), a ekrany innych funkcji otwiera się przez trasy routera. Pilnuje tego nowy test `feature_boundaries_test.dart`.
- **Edytor szablonu** zapisuje zmiany przyciskiem „Zapisz” (z potwierdzeniem porzucenia zmian), a nie automatycznie. Natychmiastowy zapis każdej zmiany dotyczy aktywnego treningu (Etap 4).
- **Domyślne ustawienia nowego ćwiczenia w szablonie:**
  - powtórzenia: 3 × 8–12;
  - tylko czas: 3 × 30–60 s;
  - kardio: 1 seria bez celu;
  - pozostałe: 3 serie bez celu.
- **Przerwa** wybierana z listy: domyślna z ustawień albo 0:30–5:00. Własne wartości po MVP.
- **Wyjście z edytorów** (szablon, ćwiczenie): decyzja o potwierdzeniu zapada w chwili próby wyjścia. `canPop` liczone przy budowie bywało nieaktualne tuż po wpisaniu tekstu; wychwycił to test.
- **Usterki znalezione na emulatorze i poprawione:**
  - ucięta etykieta nazwy w edytorze;
  - przycisk „Dodaj (N)” chowający się pod klawiaturą;
  - klawiatura wracająca po wyborze ćwiczeń;
  - karty serii zlewające się z tłem arkusza;
  - snackbar zasłaniający przycisk „Nowy szablon”.
- **Snackbary w zakładkach:** każda zakładka ma własny `ScaffoldMessenger` (`branchContainer` w `app_shell.dart`), a edytory zwracają wynik i komunikat pokazuje ekran, do którego wracasz.

### Etap 4

- **Dwa błędy z wcześniejszych etapów wychwycone testami treningu i naprawione** (opis w [development.md](development.md#pułapki-drift)):
  - zapis nie czyścił pól ustawionych na null, więc „przywróć dziedziczenie” w szablonie nie trafiało do bazy;
  - lista szablonów nie odświeżała się, gdy jednocześnie obserwowano trening (Drift współdzielił strumienie o tym samym SQL).

  Oba mają testy regresji.
- **Start treningu** w tym etapie: przycisk ▶ na kafelku szablonu (3 tapnięcia od uruchomienia do pierwszej serii) i „Pusty trening” na Starcie. „Rozpocznij: <ostatni szablon>” na Starcie dochodzi w Etapie 5 razem z resztą ekranu Start.
- **Brakująca wartość przy zatwierdzeniu** otwiera wpis pola zamiast snackbara, bo snackbar zasłaniał przycisk „Zatwierdź” (wychwycone testem).
- **Blokada podwójnego tapnięcia:** 350 ms po zatwierdzeniu serii.
- **Niezatwierdzone serie** zostają w zakończonym treningu (nie liczą się do statystyk); ekran podsumowania mówi, ile ich jest. „Zaktualizuj szablon” przenosi strukturę treningu (ćwiczenia, kolejność, liczba serii), a cele i ciężary szablonu zostają.
- **Po zakończeniu albo porzuceniu** aplikacja wraca na Start i pokazuje komunikat.
- **Sprawdzone na emulatorze (Android 16, 360 dp):** start z szablonu, zgoda na powiadomienia, przerwa z odliczaniem w powiadomieniu i alarmem końca, pasek treningu i baner na Starcie, ustawienia, zakończenie z podsumowaniem, wznowienie po wymuszonym zamknięciu, porzucenie. Poprawione po tym sprawdzeniu:
  - podpowiedź z wcześniejszej serii tego treningu przy pierwszym wykonaniu ćwiczenia ([ADR 0006](decisions/0006-poprzednie-wykonanie-i-podpowiedzi.md));
  - jednorazowa prośba o dokładne alarmy, bo bez niej koniec przerwy przyszedł około 80 s później, i przywracanie powiadomienia przerwy po restarcie ([ADR 0009](decisions/0009-timer-przerwy.md));
  - szara ikona ▶ na kafelku szablonu, chipy RIR nie mieszczące się w wierszu, drobne wartości w ustawieniach, czerwony przycisk przy porzuceniu i usunięciu.
- **Ikona aplikacji** jest wciąż domyślna (Flutter); własna ikona w Etapie 7.
- **Do sprawdzenia przez właściciela na Samsungu:** powiadomienie przerwy przy zablokowanym ekranie (z dokładnymi alarmami i bez) oraz zachowanie One UI przy usypianiu aplikacji.

### Etap 5

- **Szczegóły treningu** są trasą `/sessions/:id` poza zakładkami, a nie `/history/:id` z planu ([ux.md](ux.md#historia-i-progres-etap-5)).
- **Historia liczona w pamięci** z listy zakończonych treningów; strumień odświeża się tylko po zmianie zakończonych sesji ([ADR 0007](decisions/0007-metryki.md)).
- **Wykresy:** `fl_chart` 1.2.0 (MIT), zgodnie z planem. Kolory, znaczniki i dostępność według [ux.md](ux.md#historia-i-progres-etap-5).
- **Błąd wychwycony testem i naprawiony:** „Rozpocznij” na Starcie nie startowało treningu, gdy żaden ekran nie obserwował katalogu ćwiczeń (Riverpod 3 wstrzymuje takie providery). Opis w [development.md](development.md#pułapki-drift-i-riverpod).
- **Usuwanie treningu z historii** (z potwierdzeniem) dodane, choć spec. 5.4 go nie wymienia. Bez niego błędnie zapisany trening zostałby na zawsze w statystykach.
- **Edycja zakończonego treningu** obejmuje też notatkę i samopoczucie.
- **Błąd z Etapu 4 wychwycony na emulatorze i naprawiony:** po „Rozpocznij” ekran treningu czasem od razu się zamykał. Strumień aktywnej sesji (baza w osobnym wątku) nie zdążył jeszcze pokazać nowej sesji, a ekran uznawał to za koniec treningu. Teraz przed wyjściem sprawdza stan w bazie. Test widżetu odtwarza ten wyścig na kontrolowanym strumieniu.
- **Rekordy „najcięższa seria”** pokazują tylko N, dla których ciężar różni się od rekordu dla N + 1 (np. „≥ 8 powt.: 85 kg” zamiast ośmiu wierszy z tym samym ciężarem).
- **Wykresy ćwiczenia** mają jeden punkt na dzień (najlepszy e1RM, suma objętości), żeby dwa treningi jednego dnia nie dawały pionowej kreski.
- **Sprawdzone na emulatorze:** szybki start ze Startu, lista historii, szczegóły, porównanie, progres (wykres tygodni, e1RM, objętość) i zakładki ćwiczenia.

### Etap 6

- **Format backupu** zgodny z ADR 0008 i planem. Pole `format: "reptrack-backup"` rozpoznaje plik, a `units` opisuje jednostki ([backup-format.md](backup-format.md)).
- **Migracje formatu:** wersja 1 jest pierwsza, więc nie ma jeszcze starszego pliku do migracji. Kryterium „plik starszej wersji jest migrowany” sprawdza mechanizm migracji z przykładową migracją w teście; pierwsza prawdziwa migracja dojdzie z wersją 2.
- **Nowe zależności:** `file_picker` 13.1.0 (MIT) i `share_plus` 13.3.1 (BSD-3), wersje sprawdzone 2026-10-20 przez `flutter pub add`.
- **Eksport Markdown** udostępnia się jako tekst (gotowy do wklejenia), a CSV jako plik.
- **Test Android Auto Backup** (`bmgr`) wymaga włączenia usługi kopii na urządzeniu, czyli zmiany ustawień systemowych. Kroki dla właściciela są w [development.md](development.md#android-auto-backup).
- **Sprawdzone na emulatorze:**
  - zapis kopii przez systemowy wybór pliku (174 kB z całą biblioteką) i przywrócenie z tego pliku z potwierdzeniem;
  - zapis CSV (BOM, średniki, przecinek dziesiętny);
  - udostępnienie Markdown jako tekstu przez arkusz systemowy.

### Etap 7

- **Przegląd dostępności** jako testy: czcionka 2× na 360 dp na wszystkich głównych ekranach, cele dotyku, etykiety i kontrast w obu motywach. Poprawione przepełnienie wiersza serii w szczegółach treningu.
- **Jasny motyw** sprawdzony na emulatorze (Start, ustawienia, kopia, aktywny trening).
- **Ikona i ekran startowy:** własna ikona adaptacyjna i ciemne tło startu ([ADR 0012](decisions/0012-wyglad.md)).
- **Test na urządzeniu** (`integration_test`) przechodzi na emulatorze; `flutter test integration_test` po teście odinstalowuje aplikację z danymi (ostrzeżenie w [development.md](development.md#komendy)).
- **check.sh** buduje zawsze APK i AAB. Bez `key.properties` podpis debug; klucz wydania tworzy właściciel ([publishing.md](publishing.md)).
- **Publikacja:** wymagania Google sprawdzone 2026-10-20:
  - target API 36 od 31.08.2026;
  - weryfikacja deweloperów: od 30.09.2026 w czterech krajach, globalnie w 2027, instalacja przez adb bez zmian;
  - test zamknięty 12 osób przez 14 dni dla nowych kont prywatnych (z opisów zewnętrznych, do potwierdzenia).
- **Dokumenty:** README z instrukcją budowania, [publishing.md](publishing.md) z polityką prywatności i Data safety, [future/sync-and-mcp.md](future/sync-and-mcp.md).
- **Wydajność:** historia przeładowuje się tylko po zmianach zakończonych treningów; dalsze pomiary (np. setki treningów na telefonie) zostają na kontrolę na telefonie.

### Po wydaniu: analiza progresu (2026-10-20)

- **Zakres** wybrany przez właściciela: podsumowanie okresu z porównaniem, serie na partię mięśniową i lepsza karta ćwiczenia. „Rekordy w okresie” nie weszły.
- **Zasady liczenia** w [ADR 0007](decisions/0007-metryki.md#analiza-okresu-2026-10-20-po-wydaniu-100), układ w [ux.md](ux.md#analiza-progresu-po-wydaniu-100).
- **Granice funkcji:** prezentacja może importować etykiety innej funkcji (`presentation/*_labels.dart`), np. nazwy partii mięśniowych ([architecture.md](architecture.md)).
- **Wychwycone na emulatorze i poprawione:**
  - „Wszystko” łamało się w przełączniku okresu przy 360 dp, teraz jest „Całość”;
  - kafelki w rzędzie miały różne wysokości;
  - dwa treningi jednego dnia liczyły się jako jeden trening z ćwiczeniem.
  - dolna nawigacja zasłaniała dół arkusza wyboru ćwiczenia (arkusz otwiera się teraz nad shellem).

### Po wydaniu: słowniczek pojęć (2026-10-20)

- **Prośba właściciela:** sekcja z podstawowymi informacjami (co to jest 1RM itp.) i okienka z ikonką ⓘ przy pojęciach.
- **Zakres:** 16 pojęć w czterech grupach, ekran słowniczka i ikonki ⓘ w ustawieniach, Progresie, rekordach i na ekranie ćwiczenia ([ux.md](ux.md#słowniczek-i-ikonki-ⓘ)).
- **Treść:** opisy wyjaśniają, jak liczy RepTrack (np. wzór Epleya, wagi 1 i 0,5 serii na mięsień). Jedyna wskazówka treningowa, zakres 10–20 serii tygodniowo na partię, jest podana jako orientacja, nie reguła.

### Po wydaniu: asystent AI z Ollamą (2026-10-20)

- **Decyzja właściciela:** zamiast płatnego ChatGPT (własne MCP wymaga planu Pro/Business) darmowa Ollama na komputerze, czat w aplikacji na telefonie ([ADR 0014](decisions/0014-asystent-ai-ollama.md)). Zakres v1: czat o danych, komentarz do treningu, propozycja następnego treningu; AI tylko czyta.
- **Kontekst, nie narzędzia:** aplikacja liczy liczby własną domeną i wysyła Markdown; małe modele (4B) radzą sobie z tym pewniej niż z wywoływaniem narzędzi.
- **Bez nowych zależności:** HTTP przez `dart:io`, prosty Markdown odpowiedzi.
- **Przy okazji:**
  - „Treningi z ćwiczeniem” liczą tylko wykonania z serią roboczą;
  - podpowiedzi pól w jasnym motywie mają kontrast 4,75:1 zamiast 4,28:1 (test dostępności z polem czatu).
- **Kroki po stronie PC** (zmiany ustawień systemu) robi właściciel: `OLLAMA_HOST=0.0.0.0`, reguła zapory dla TCP 11434 w sieci prywatnej, adres IPv4 w aplikacji. Instrukcja jest też w aplikacji (Ustawienia → Asystent AI → „Jak podłączyć komputer?”).
- **Sprawdzone na emulatorze z prawdziwą Ollamą** (`http://10.0.2.2:11434`, `qwen3.5:4b`, 2026-10-20):
  - test połączenia;
  - wybór modelu;
  - czat z danymi aplikacji: odpowiedź po polsku z listą i pogrubieniem;
  - zimny start modelu ok. 50 s, kolejne pytania kilka sekund.

  Pomiar przy grze obciążającej GPU (model szedł głównie na CPU), więc bez gry będzie szybciej.
- **Poprawione po teście:**
  - domyślny model to najmniejszy na serwerze (wcześniej pierwszy z listy Ollamy, czyli 27b);
  - krótsza podpowiedź „Jak rośnie moja siła?” (ucinała się przy 360 dp);
  - `tool/check.sh` formatuje pliki paczkami, bo lista plików przekroczyła limit wiersza poleceń `cmd`.
- **Nie odtworzone:** pierwsze pytanie przy ładowaniu modelu, gdy GPU było zajęte przez grę (Ollama zgłosiła timeout wykrywania GPU), skończyło się „Brak połączenia” mimo odpowiedzi 200 w logu Ollamy. „Spróbuj ponownie” i kolejne zimne starty działały. Do obserwacji na telefonie.

