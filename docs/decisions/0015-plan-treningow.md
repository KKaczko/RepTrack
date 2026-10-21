# ADR 0015: Plan treningów i kalendarz ⚠

- Status: zaakceptowana (2026-10-20, plan zatwierdzony przez właściciela)
- Odwracalność: trudna ⚠
  - schemat bazy v2 z trzema nowymi tabelami (istniejące bez zmian);
  - format backupu v2 (nowe tablice, migracja plików v1).

## Kontekst

Właściciel chce planować treningi w dwóch trybach:
- plan tygodniowy (np. pon Push A, śr Pull A, pt Nogi);
- pojedyncze daty w kalendarzu.

Wszystko ma być widać na jednej stronie z kalendarzem. Po dotknięciu dnia widać krótki opis, a ze szczegółów można przejść dalej.

Dodatki wybrane przez właściciela:
- dzisiejszy trening na Starcie;
- realizacja planu;
- przypomnienia;
- asystent AI zna plan.

Cykl co N dni nie wszedł.

## Decyzja

- **Plan tygodniowy w wersjach** (`weekly_plans`, `weekly_plan_days`). Edycja działającego planu zamyka bieżącą wersję na wczoraj i otwiera nową od dziś. Wersję, która jeszcze nie działała, poprawiamy w miejscu. Dzięki temu przeszłe dni pokazują to, co było wtedy zaplanowane, a realizacja i seria tygodni się nie przepisują.
- **Wpisy na daty** (`planned_days`, rodzaj `workout` z szablonem albo `rest`) zastępują plan tygodniowy danego dnia w całości. Tym jednym mechanizmem działają:
  - „zaplanuj trening” (wpisy = plan tygodniowy dnia + nowy trening);
  - „pomiń” (bez treningów = dzień wolny);
  - „przesuń na jutro / na dzień” (dzień źródłowy bez treningu, docelowy z nim);
  - „zamień szablon”;
  - „przywróć plan tygodnia” (usunięcie wpisów daty).

  „Pomiń” i „przesuń” mają „Cofnij” (poprzednie wpisy wracają). Przeniesienie i jego cofnięcie zapisują obie daty w jednej transakcji (`setDays`, od 2026-10-21), więc błąd zapisu nie gubi treningu.
- **Stan treningu z planu** wynika z zakończonych treningów tego dnia (`local_date`, `template_id`), bez kluczy obcych do sesji:
  - zrobiony (ten sam szablon);
  - zastąpiony (inny trening tego dnia);
  - pominięty (dzień minął);
  - na dziś;
  - zaplanowany.

  Treningi spoza planu są „dodatkowe”.
- **Realizacja i seria:**
  - realizacja tygodnia (od poniedziałku): zrobione i zastąpione wobec wszystkich zaplanowanych;
  - seria: kolejne tygodnie z planem wykonanym w całości; niepełny bieżący tydzień serii nie przerywa, a tydzień bez planu przerywa.
- **Opis dnia bez wchodzenia w szczegóły:** liczba ćwiczeń i serii z planu szablonu, szacowany czas i pierwsze ćwiczenia. Czas liczymy jako ok. 40 s na serię plus przerwa z planu albo domyślna, zaokrąglony do 5 min. Dla zrobionego treningu: godzina, czas, serie i objętość.
- **Kalendarz:** własna siatka bez zależności. Znaczniki różnią się kształtem, nie tylko kolorem: ● zrobiony, ○ zaplanowany, ✕ pominięty.
- **Przypomnienia:**
  - dokładne alarmy, gdy użytkownik już na nie zezwolił (zgoda z timera przerwy, ADR 0009); inaczej przybliżone (`inexactAllowWhileIdle`), które Android może opóźnić do ok. godziny (okno sprawdzone na emulatorze 2026-10-20). O dokładne alarmy dla przypomnień nie prosimy;
  - najbliższe 14 dni o jednej godzinie (domyślnie 17:00);
  - przeliczane po każdej zmianie planu, ustawień, szablonów i zakończonych treningów;
  - pomijają dni zrobione i minione godziny.

  Ustawienia `plan_reminders` i `plan_reminder_minutes`.
- **Asystent AI:** przegląd w kontekście dostaje sekcję planu (tydzień ze stanami, najbliższe 7 dni, plan tygodniowy, realizacja i seria). Asystent dalej niczego nie zapisuje.

## Konsekwencje

- Baza v2: migracja v1 → v2 tworzy tabele i indeksy, z testem na danych (`test/drift/app_database/migration_test.dart`).
- Backup v2: pliki v1 dostają puste tablice planu (`migrateBackupV1ToV2`); plik z wersji wyższej niż obsługiwana jest odrzucany.
- Planowanie przypomnień idzie przez kolejkę (`PlanReminderScheduler`): naraz najwyżej jedno przeliczenie, a prośby z jego czasu zastępuje najnowsza, więc starsze przeliczenie nie przywróci nieaktualnych alarmów.
- Przypomnienia działają tylko za zgodą na powiadomienia, tak jak timer przerwy. Bez otwierania aplikacji przez dwa tygodnie zaplanowane przypomnienia się kończą, bo przeliczanie dzieje się w aplikacji.
- Usunięty albo zarchiwizowany szablon w planie pokazuje się jako „(usunięty szablon)” i nie przypomina.
