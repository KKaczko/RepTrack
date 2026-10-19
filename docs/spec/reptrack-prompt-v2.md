# RepTrack — prompt dla agenta (v2)

Oct 19, 2026 · @Someone

## 1. Rola i zasady pracy

Działaj jako principal software engineer, architekt aplikacji mobilnych i product designer. Budujesz RepTrack: aplikację mobilną do planowania, wykonywania i analizowania treningów siłowych, najpierw na Androida, później na iOS.

Nadrzędny priorytet: poprawny, elastyczny model treningów oraz wyjątkowo szybkie rejestrowanie serii na siłowni. To fundament produktu rozwijanego przez lata.

Zasady pracy:

- **Najpierw plan.** W pierwszej odpowiedzi dostarczasz wyłącznie etap 0 (sekcja 8) i czekasz na zatwierdzenie. Nie piszesz kodu aplikacji przed akceptacją planu.
- **Etapy z punktami zatrzymania.** Każdy etap kończy się przechodzącą analizą statyczną, zielonymi testami, udanym buildem, commitem i krótkim raportem: co zrobione, co odbiega od planu, otwarte pytania. Potem zatrzymujesz się i czekasz na moją akceptację.
- **Niejasności.** Decyzję łatwo odwracalną podejmij sam i zapisz jako ADR w `docs/decisions/`. Decyzję trudno odwracalną (schemat danych, format eksportu, identyfikatory, nazwa pakietu) skonsultuj ze mną przed implementacją.
- **Bez rozszerzania zakresu.** Funkcje spoza MVP zapisuj w `docs/backlog.md` zamiast je implementować.
- **Bez kosztów i publikacji.** Nie publikuj aplikacji, nie zakładaj kont w zewnętrznych serwisach i nie uruchamiaj płatnych usług bez mojej zgody.
- **Fakty zależne od czasu.** Licencje, wymagania Google Play i możliwości ChatGPT traktuj jako założenia do weryfikacji. Jeśli nie masz dostępu do sieci, oznacz je wprost jako niezweryfikowane zamiast zgadywać.

## 2. Wizja produktu i granice zakresu

RepTrack to uniwersalny tracker treningów siłowych, niezwiązany z jednym systemem. Obsługuje FBW, Push/Pull/Legs, Upper/Lower i dowolne plany użytkownika. Wygląda i działa jak dopracowany produkt komercyjny.

MVP działa w pełni lokalnie: bez rejestracji, bez internetu i bez zewnętrznego serwera. Dane użytkownika nigdy nie zależą od dostępności backendu.

MVP obejmuje:

- bibliotekę ćwiczeń dostępną offline,
- szablony treningowe z elastyczną konfiguracją serii,
- aktywny trening z timerem przerwy i natychmiastowym zapisem,
- trening bez szablonu,
- historię z możliwością korekty,
- podstawowe statystyki i wykresy progresu,
- backup JSON, eksport CSV i eksport Markdown do wklejenia w ChatGPT.

Poza zakresem MVP (nie implementuj, zapisz w backlogu):

- konta użytkowników, backend i synchronizacja,
- serwer MCP i integracja z ChatGPT (tylko architektura i dokumentacja, sekcja 10),
- funkcje społecznościowe i udostępnianie,
- Wear OS, widżety, Health Connect,
- AI-coach i automatyczne generowanie planów,
- interfejs do superserii (model danych tak, UI później),
- zdjęcia i animacje ćwiczeń,
- płatności i subskrypcje.

## 3. Decyzje technologiczne

Stos jest wybrany: Flutter + Dart, lokalna baza SQLite przez Drift. Nie przygotowuj porównania z Kotlin + Compose. Jeśli znajdziesz konkretny blocker (wydajność, brakująca biblioteka, ograniczenie Androida), opisz go w planie i zaproponuj alternatywę.

- **Architektura feature-first.** Każda funkcja dzieli się na `domain` (encje i logika w czystym Dart), `data` (Drift, repozytoria, migracje) i `presentation` (ekrany, stan). Bez nadmiarowych warstw.
- **Logika domenowa bez Fluttera.** Dziedziczenie konfiguracji serii, kopiowanie szablonu do sesji i metryki progresu mają być testowalne bez emulatora.
- **Repozytoria jako interfejsy domeny.** Przyszła synchronizacja dodaje implementację, nie zmienia logiki treningowej.
- **Stan, nawigacja, DI.** Wybierz i uzasadnij w jednym ADR (np. Riverpod, go\_router). Preferuj popularne, aktywnie utrzymywane pakiety.
- **Lokalizacja.** `flutter gen-l10n` z plikami ARB. Polski domyślny, angielski przygotowany. Żadnych tekstów zakodowanych na sztywno w UI.
- **Jakość.** `dart analyze` bez ostrzeżeń, `flutter_lints` lub surowszy zestaw, formatowanie `dart format`.
- **Bez usług zewnętrznych w MVP.** Bez backendu, Firebase, analityki i reklam.

Ustawienia nieodwracalne, do potwierdzenia ze mną przed etapem 1:

- **applicationId:** `[DO UZUPEŁNIENIA, np. pl.mojanazwa.reptrack]`. Nie da się go zmienić po publikacji w Google Play.
- **minSdk:** zaproponuj z uzasadnieniem.
- **Keystore:** generuję i przechowuję go sam, poza repozytorium. W repo tylko `key.properties.example` i instrukcja. Opisz Play App Signing.
- **Publikacja:** opisz w dokumentacji wymagania Google Play dla nowych kont deweloperskich (testy zamknięte przed produkcją, formularz Data safety) jako założenia do weryfikacji.

## 4. Model danych

Model rozdziela trzy warstwy: definicję ćwiczenia, plan (szablon) i rzeczywiste wykonanie (sesję). Sesja jest kopią planu z chwili startu. Zmiany szablonu i ćwiczenia nigdy nie modyfikują istniejących sesji.

Minimalny zestaw encji (nazwy i dodatkowe pola dopracuj w planie):

| Encja | Kluczowe pola | Relacje |
| --- | --- | --- |
| Exercise | nazwa, aliasy, mięśnie główne i pomocnicze, sprzęt, kategoria, opis techniki, pola pomiaru, tryb obciążenia, semantyka ciężaru, jednostronność, źródło, licencja, autor, seedVersion, userModified, archivedAt | — |
| Template | nazwa, opis, archivedAt | 1:N TemplateExercise |
| TemplateExercise | kolejność, liczba serii, domyślny cel (zakres powtórzeń lub czasu), docelowy ciężar, przerwa, notatka, groupId | N:1 Exercise, 1:N TemplateSet |
| TemplateSet | kolejność, typ serii, nadpisania celu, ciężaru i przerwy (null = dziedzicz) | N:1 TemplateExercise |
| WorkoutSession | startedAt, endedAt, timeZone, localDate, status, templateId (nullable), snapshot nazwy szablonu, notatki, samopoczucie | 1:N SessionExercise |
| SessionExercise | kolejność, exerciseId, snapshot nazwy i ustawień pomiaru, notatka, groupId | N:1 Exercise, 1:N SessionSet |
| SessionSet | kolejność, typ serii, snapshot celu, ciężar, powtórzenia, czas, dystans, skala i wartość RIR/RPE, side, completedAt | N:1 SessionExercise |

Reguły modelu:

- **Dziedziczenie serii.** Pole TemplateSet równe null oznacza wartość z TemplateExercise. Efektywny plan serii liczy jedna czysta funkcja domenowa. Zapis „3 × 8–12” to trzy serie bez nadpisań, a piramida 12–15 / 10–12 / 8–10 / 6–8 to cztery serie z nadpisanym zakresem.
- **Typy serii.** Rozgrzewkowa, robocza, drop set, AMRAP lub do upadku. Serie rozgrzewkowe są wykluczone z objętości i rekordów.
- **Pomiar.** Ćwiczenie deklaruje zestaw pól (ciężar, powtórzenia, czas, dystans) zamiast jednego typu. Dzięki temu obsłużysz np. spacer farmera (ciężar + dystans).
- **Tryb obciążenia.** Zewnętrzne, masa ciała, masa ciała z dociążeniem, wspomaganie. Semantyka ciężaru: łącznie, na rękę lub na stronę. Obie wartości są kopiowane do sesji.
- **Jednostronność.** W MVP jedna seria oznacza obie strony z tymi samymi wartościami. Pole `side` zostaje w modelu na przyszłe osobne logowanie L/P.
- **Jednostki.** Ciężar w gramach jako liczba całkowita, dystans w metrach, czas w sekundach. Jednostka wyświetlania (kg/lb) i krok ciężaru (domyślnie 2,5 kg) są w ustawieniach. Konwersja wyłącznie w warstwie UI.
- **Czas.** Znaczniki jako UTC plus strefa IANA zapisana przy starcie sesji. Data treningu to lokalna data rozpoczęcia w tej strefie, także dla treningu po północy.
- **Snapshoty.** Sesja trzyma `exerciseId` oraz snapshot nazwy i ustawień pomiaru. Historia wyświetla aktualną nazwę ćwiczenia, a snapshot służy do audytu i eksportu.
- **Korekta historii.** Ręczna edycja zakończonej sesji jest dozwolona i aktualizuje `updatedAt`. Niezmienność dotyczy wyłącznie propagacji zmian z szablonów i definicji ćwiczeń.
- **Identyfikatory i przyszły sync.** Każdy rekord ma UUIDv7 generowany na urządzeniu oraz `createdAt`, `updatedAt` i `deletedAt`. Usuwanie jest miękkie. Klucze autoinkrementowane nie są identyfikatorami biznesowymi.
- **Biblioteka wbudowana.** Rekordy seedowe mają stabilne ID, `source = builtin` i `seedVersion`. Edycja przez użytkownika ustawia `userModified`, a aktualizacja seeda w nowej wersji aplikacji takich rekordów nie nadpisuje. Ćwiczenie użyte w historii można tylko zarchiwizować.
- **Superserie.** `groupId` w TemplateExercise i SessionExercise jest w schemacie od początku, interfejs powstanie po MVP.
- **Aktywna sesja.** Maksymalnie jedna sesja ze statusem `active`.
- **Migracje.** Każda zmiana schematu to migracja Drift z testem migracji na zapisanych wersjach schematu. Wersja schematu bazy jest niezależna od wersji formatu backupu.

## 5. Zakres funkcjonalny MVP

### 5.1 Biblioteka ćwiczeń

- **Katalog wbudowany.** 100–150 popularnych ćwiczeń z ręcznie sprawdzonymi polskimi nazwami i aliasami. Lepszy mały, poprawny katalog niż maszynowe tłumaczenie setek pozycji.
- **Źródła do rozważenia.** `yuhonas/free-exercise-db` (dane na Unlicense, prawa do zdjęć niejasne, więc zdjęć nie używamy) oraz wger (licencje Creative Commons per wpis, w dużej części CC-BY-SA, co wymaga atrybucji). Zweryfikuj licencje danych osobno od ilustracji i zapisz źródło, licencję oraz autora każdego rekordu.
- **Atrybucja.** Ekran „Licencje i źródła” w ustawieniach.
- **Ilustracje.** Brak w MVP, pole w modelu zostaje.
- **Wyszukiwanie.** Offline, po nazwie i aliasach, niewrażliwe na wielkość liter i polskie znaki (fraza „lawka” znajduje „ławka”).
- **Filtry.** Grupa mięśniowa, sprzęt, kategoria, wbudowane lub własne, zarchiwizowane.
- **Własne ćwiczenia.** Dodawanie, edycja, archiwizacja i aliasy.

### 5.2 Szablony

- Nieograniczona liczba szablonów: tworzenie, edycja, duplikowanie, archiwizacja i zmiana kolejności ćwiczeń przeciąganiem.
- Ćwiczenie w szablonie ma liczbę serii i wspólny cel. Każdą serię można rozwinąć i nadpisać, a przycisk „przywróć dziedziczenie” cofa nadpisanie.
- Cel to zakres powtórzeń albo czas. Opcjonalnie docelowy ciężar, przerwa, typ serii i notatka.

### 5.3 Aktywny trening

- **Start.** Z szablonu albo pusty trening. Start tworzy niezależną sesję z kopią planu.
- **Widok ćwiczenia.** Nazwa, plan serii z zakresami, wynik poprzedniego wykonania przy każdej serii, pola ciężaru i powtórzeń (lub czasu i dystansu), opcjonalne RIR/RPE, status serii.
- **Poprzednie wykonanie.** Domyślnie ostatnia zakończona sesja z tym ćwiczeniem, niezależnie od szablonu. Serie robocze dopasowane po kolejności.
- **Podpowiedzi.** Pola są wstępnie wypełnione wartościami z poprzedniego wykonania i wizualnie odróżnione od wpisanych. Seria nigdy nie jest oznaczana jako wykonana automatycznie. Jedno tapnięcie zatwierdza podpowiedziane wartości.
- **Zmiany w trakcie.** Dodawanie i usuwanie serii, dodawanie i zamiana ćwiczeń, zmiana kolejności.
- **Timer przerwy.** Startuje po zatwierdzeniu serii, z czasem z planu lub domyślnym z ustawień. Przyciski ±15 s i „pomiń”. Działa przy zablokowanym ekranie: powiadomienie z odliczaniem oraz wibracja lub dźwięk na koniec.
- **Ekran.** Opcja „nie wygaszaj ekranu podczas treningu”.
- **Trwałość.** Każda zmiana trafia do bazy natychmiast, w transakcji. Zamknięcie aplikacji, ubicie procesu przez system i restart telefonu nie powodują utraty danych. Po ponownym uruchomieniu aplikacja proponuje wznowienie aktywnej sesji.
- **Zakończenie.** Podsumowanie (czas, objętość, nowe rekordy), notatka i samopoczucie. Opcja „zaktualizuj szablon na podstawie tego treningu” pokazuje różnice i wymaga potwierdzenia. Porzucenie sesji też wymaga potwierdzenia.

### 5.4 Historia

- Chronologiczna lista sesji i szczegóły każdej z nich.
- Edycja zakończonej sesji: korekta wartości, dodanie lub usunięcie serii.
- Historia pojedynczego ćwiczenia ze wszystkimi wykonaniami.
- Porównanie bieżącego treningu z poprzednim, ćwiczenie po ćwiczeniu.

### 5.5 Progres

- **Szacowany 1RM** wzorem Epleya: ciężar × (1 + powtórzenia / 30), liczony tylko z serii roboczych do 10 powtórzeń.
- **Objętość** (ciężar × powtórzenia) na ćwiczenie i sesję, bez serii rozgrzewkowych.
- **Rekordy:** najcięższa seria dla danej liczby powtórzeń i najlepszy szacowany 1RM.
- **Wykresy:** szacowany 1RM i objętość w czasie dla wybranego ćwiczenia oraz liczba treningów w tygodniu.

## 6. Eksport, backup i import

Pełny backup i eksport filtrowany to dwie osobne funkcje. Backup zawsze obejmuje wszystko, a filtry okresu i ćwiczeń dotyczą tylko eksportu CSV i Markdown.

- **Backup JSON.** Plik zawiera `formatVersion`, `appVersion`, `exportedAt` i metadane jednostek. Obejmuje wszystkie encje, także zarchiwizowane, oraz ustawienia. Format opisz w `docs/backup-format.md` wraz z JSON Schema.
- **Przywracanie.** W MVP tryb „zastąp wszystko”. Przed zastąpieniem aplikacja automatycznie robi backup bieżących danych. Cały plik jest walidowany przed zapisem, a import odbywa się w jednej transakcji: wszystko albo nic.
- **Wersje formatu.** Pliki starszych wersji są migrowane przy imporcie. Plik z nowszej wersji aplikacji jest odrzucany z czytelnym komunikatem.
- **CSV.** Jeden wiersz na serię: data lokalna, sesja, szablon, ćwiczenie, numer i typ serii, ciężar, powtórzenia, czas, dystans, RIR/RPE, notatka. Jednostki w nagłówkach. Kodowanie UTF-8; separator do ustalenia, bo polski Excel domyślnie oczekuje średnika.
- **Markdown dla ChatGPT.** Czytelne tabele per sesja lub per ćwiczenie z jawnymi jednostkami. Kopiowanie do schowka i udostępnianie przez systemowy share sheet.
- **Pliki.** Zapis i odczyt przez systemowy wybór pliku, bez szerokich uprawnień do pamięci.
- **Kopia systemowa.** Skonfiguruj Android Auto Backup dla bazy, żeby reinstalacja nie kasowała historii. Przetestuj odtworzenie, uwzględniając tryb WAL bazy.

## 7. UX/UI

Aktywny trening to najważniejszy ekran: obsługa jedną ręką, bez zbędnych przejść, z natychmiastowym zapisem. „Szybko” oznacza konkretne liczby tapnięć poniżej.

Mierzalne cele szybkości:

| Akcja | Limit |
| --- | --- |
| Zatwierdzenie serii zgodnej z podpowiedzią | 1 tapnięcie |
| Zmiana ciężaru o jeden krok | ≤ 2 tapnięcia |
| Wpisanie innej liczby powtórzeń | ≤ 3 tapnięcia |
| Od otwarcia aplikacji do pierwszej serii z ostatniego szablonu | ≤ 3 tapnięcia |

Główne akcje aktywnego treningu leżą w dolnej połowie ekranu, w zasięgu kciuka.

Kierunek wizualny:

- minimalistyczny, profesjonalny wygląd komercyjnej aplikacji fitness,
- ciemny motyw domyślny, jasny jako alternatywa, jeden wyrazisty kolor akcentowy,
- design tokens dla kolorów, typografii i odstępów,
- duże przyciski (minimum 48 dp, główne akcje treningu większe), zaokrąglone karty, dyskretne animacje,
- jeden spójny zestaw ikon,
- kontrast co najmniej WCAG AA, poprawny układ przy powiększonej czcionce systemowej, etykiety dla czytników ekranu,
- poprawne działanie na telefonach o szerokości 360–430 dp.

Ekrany:

- **Start:** baner wznowienia aktywnej sesji, szybki start ostatniego szablonu, ostatnio używane szablony, pusty trening, ostatnia sesja, liczba treningów w tym tygodniu.
- **Szablony:** lista, tworzenie, edycja ćwiczeń i serii, zmiana kolejności.
- **Ćwiczenia:** katalog, wyszukiwarka, filtry, szczegóły z historią i rekordami, dodawanie i edycja.
- **Aktywny trening:** plan serii, poprzednie wyniki, szybkie wpisywanie, timer przerwy.
- **Historia:** lista sesji, szczegóły z edycją, historia ćwiczenia, wykresy progresu.
- **Ustawienia:** motyw, jednostki, krok ciężaru, skala RIR/RPE, domyślna przerwa, wygaszanie ekranu, eksport i import, licencje i źródła.

W planie przedstaw mapę ekranów i szkic układu aktywnego treningu, zanim zaczniesz implementować UI.

## 8. Etapy implementacji

Po każdym etapie zatrzymaj się, przedstaw raport i czekaj na moją akceptację. Dodaj skrypt `tool/check.sh` uruchamiający formatowanie, analizę, testy i build, żeby każdy etap dało się zweryfikować jedną komendą.

1. **Etap 0, plan (bez kodu).** Architektura, model danych z relacjami i indeksami, struktura modułów, mapa ekranów i szkic aktywnego treningu, plan testów, ryzyka oraz decyzje z sekcji 11 z Twoją rekomendacją.
2. **Etap 1, fundament.** Projekt Flutter, lint, struktura katalogów, motyw i design tokens, lokalizacja, nawigacja, schemat Drift z testami migracji, repozytoria, testy domeny dziedziczenia serii.
3. **Etap 2, biblioteka ćwiczeń.** Seed z licencjami i źródłami, wyszukiwanie z obsługą polskich znaków, filtry, własne ćwiczenia, archiwizacja, ekran licencji.
4. **Etap 3, szablony.** Tworzenie, edycja, duplikowanie, archiwizacja, kolejność, konfiguracja i nadpisywanie serii.
5. **Etap 4, aktywny trening.** Sesja z szablonu i pusta, wpisywanie z podpowiedziami, poprzednie wyniki, zmiany w trakcie, timer przerwy z powiadomieniem, natychmiastowy zapis i wznawianie.
6. **Etap 5, historia i progres.** Lista i szczegóły sesji, edycja, historia ćwiczenia, porównanie z poprzednim treningiem, metryki, wykresy, ekran Start.
7. **Etap 6, eksport i backup.** Backup JSON, przywracanie z migracją formatu, CSV, Markdown, Android Auto Backup.
8. **Etap 7, dopracowanie i wydanie.** Przegląd UX i dostępności, jasny motyw, wydajność, podpisane APK i AAB, dokumentacja: README, instrukcja budowania, opis architektury, projekt synchronizacji i MCP.

## 9. Kryteria akceptacji i testy

MVP jest ukończone, gdy przechodzą oba zestawy: kontrole automatyczne, które weryfikujesz Ty, i kontrole ręczne, które wykonam na telefonie.

Kontrole automatyczne (agent):

- `dart analyze` bez błędów i ostrzeżeń, `dart format` bez zmian, build release APK i AAB kończy się sukcesem.
- **Dziedziczenie serii:** wspólny cel, nadpisanie pojedynczej serii, przywrócenie dziedziczenia, zmiana liczby serii.
- **Niezależność historii:** zmiana szablonu, nazwy i pomiaru ćwiczenia oraz archiwizacja nie zmieniają zapisanych sesji. Test na prawdziwej bazie Drift.
- **Trwałość sesji:** dane zapisane po każdej zmianie, aktywna sesja odtworzona po ponownym otwarciu bazy (symulacja ubicia procesu).
- **Backup:** eksport i import dają identyczne dane, plik starszej wersji jest migrowany, uszkodzony plik zostaje odrzucony bez zmian w bazie.
- **Migracje:** test każdej migracji na zapisanych wersjach schematu.
- **Czas:** trening przez północ i zmiana strefy czasowej dają poprawną datę lokalną.
- **Seed:** aktualizacja biblioteki nie nadpisuje ćwiczeń zmodyfikowanych przez użytkownika.
- **Metryki:** szacowany 1RM, objętość bez rozgrzewek, rekordy.
- **Widżety aktywnego treningu:** zatwierdzenie serii jednym tapnięciem, podpowiedź nigdy nie oznacza serii jako wykonanej.

Kontrole ręczne (ja, na telefonie):

- [ ] APK instaluje się i uruchamia na moim telefonie z Androidem.
- [ ] Biblioteka ćwiczeń działa w trybie samolotowym.
- [ ] Dodaję i edytuję własne ćwiczenie.
- [ ] Tworzę szablon z dowolną liczbą ćwiczeń i serii, z zakresem wspólnym i osobnym dla serii.
- [ ] Rozpoczynam trening i zapisuję serie w limitach tapnięć z sekcji 7.
- [ ] Po wymuszonym zamknięciu aplikacji w trakcie treningu sesja wznawia się bez strat.
- [ ] Timer przerwy powiadamia przy zablokowanym ekranie.
- [ ] Edycja szablonu nie zmienia zakończonych treningów.
- [ ] Porównuję bieżący trening z poprzednim.
- [ ] Eksportuję backup, czyszczę dane aplikacji i przywracam wszystko z pliku.

## 10. Przyszła synchronizacja i integracja MCP

Nie implementuj tego w MVP. Przygotuj dokument `docs/future/sync-and-mcp.md` i dopilnuj, żeby model danych z sekcji 4 nie blokował tej ścieżki.

Docelowa architektura: aplikacja → synchronizacja → backend z PostgreSQL → autoryzowany zdalny serwer MCP → ChatGPT lub inny klient MCP.

Założenia do weryfikacji w dokumentacji OpenAI w momencie realizacji (doniesienia z 2026 roku są ze sobą sprzeczne):

- ChatGPT łączy się tylko ze zdalnymi serwerami MCP przez HTTPS, lokalny serwer nie zadziała.
- Własne konektory wymagają trybu deweloperskiego, a lista obsługiwanych planów zmieniała się w 2026 roku.
- Uwierzytelnianie przez OAuth.

Wniosek: bez backendu danych z telefonu nie da się podłączyć. W MVP pomostem jest eksport Markdown z sekcji 6.

Narzędzia MCP, wyłącznie do odczytu:

| Narzędzie | Zwraca |
| --- | --- |
| `search_exercises(query)` | pasujące ćwiczenia z `exercise_id`; bez tego model nie zna identyfikatorów |
| `list_workouts(date_from, date_to, limit, cursor)` | listę sesji z podsumowaniem |
| `get_workout(workout_id)` | pełną sesję z seriami |
| `get_exercise_history(exercise_id, date_from, date_to, limit, cursor)` | wykonania ćwiczenia w okresie |
| `get_personal_records(exercise_id)` | rekordy dla ćwiczenia |
| `get_progress_summary(period)` | metryki progresu z sekcji 5.5 |
| `list_templates()` | szablony z planem serii |

Wymagania dla narzędzi: jawne jednostki, daty ISO 8601 z przesunięciem strefy plus data lokalna, stabilne identyfikatory, paginacja i limity rozmiaru odpowiedzi. Każde zapytanie po stronie serwera jest ograniczone do danych uwierzytelnionego użytkownika.

Projekt synchronizacji powinien opisać: konta i bezpieczne uwierzytelnianie, PostgreSQL, strategię konfliktów (np. ostatni zapis wygrywa per rekord według `updatedAt`, z obsługą miękkich usunięć), eksport i usunięcie własnych danych zgodnie z RODO oraz szyfrowanie w tranzycie i w spoczynku. Notatki i samopoczucie mogą być danymi o zdrowiu, co trzeba uwzględnić w polityce prywatności i formularzu Data safety.

## 11. Decyzje do zatwierdzenia

W etapie 0 potwierdź lub zakwestionuj każdy domyślny wybór poniżej i dodaj decyzje, które wynikną z planu. Nie implementuj rozwiązania sprzecznego z tą listą bez mojej zgody.

| Decyzja | Domyślny wybór |
| --- | --- |
| applicationId | do uzupełnienia przeze mnie przed etapem 1 |
| minSdk | propozycja agenta z uzasadnieniem |
| Źródło „poprzedniego wykonania” | ostatnia sesja z ćwiczeniem, niezależnie od szablonu |
| Nazwa w historii po zmianie nazwy ćwiczenia | aktualna nazwa, snapshot zachowany do audytu |
| Tryb importu backupu | zastąpienie wszystkich danych; scalanie po MVP |
| Separator CSV | średnik, zgodny z polskim Excelem |
| Skala wysiłku | RIR albo RPE wybierane w ustawieniach |
| Wzór szacowanego 1RM | Epley, serie do 10 powtórzeń |
| Rozmiar katalogu ćwiczeń | 100–150 pozycji, źródło po weryfikacji licencji |
| Ćwiczenia jednostronne | wspólne wartości dla obu stron |
| Stan i nawigacja | rekomendacja agenta w ADR |
