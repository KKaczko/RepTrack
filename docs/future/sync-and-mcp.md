# Przyszłość: synchronizacja i integracja MCP

Status: projekt, **nie do implementacji w MVP** (spec. 10). Ten dokument opisuje docelową ścieżkę i sprawdza, że model danych z MVP jej nie blokuje.

Docelowo: aplikacja → synchronizacja → backend z PostgreSQL → autoryzowany zdalny serwer MCP → ChatGPT albo inny klient MCP. Konta z tego projektu są też warunkiem hostowanego asystenta premium ([rozwój i premium](rozwoj-i-premium.md)). Do tego czasu są dwa pomosty:
- eksport Markdown ([backup-format.md](../backup-format.md#eksport-markdown));
- darmowy asystent AI z Ollamą na komputerze właściciela, działający bez backendu ([ADR 0014](../decisions/0014-asystent-ai-ollama.md)).

ChatGPT wymaga do własnych serwerów MCP planu Pro albo Business (pomoc OpenAI, sprawdzone 2026-10-20).

## Założenia do weryfikacji w chwili realizacji

**Niezweryfikowane.** Spec. 10 zaznacza, że doniesienia z 2026 roku są sprzeczne; przed implementacją trzeba je sprawdzić w dokumentacji OpenAI i innych klientów MCP:

- ChatGPT łączy się tylko ze zdalnymi serwerami MCP przez HTTPS; serwer lokalny na telefonie nie zadziała.
- Własne konektory wymagają trybu deweloperskiego, a lista obsługiwanych planów zmieniała się w 2026 roku.
- Uwierzytelnianie przez OAuth.

Wniosek z założeń: bez backendu nie da się podłączyć danych z telefonu do ChatGPT.

## Co już przygotowuje MVP

| Wymaganie synchronizacji | Stan w MVP |
| --- | --- |
| Globalnie unikalne id tworzone na urządzeniu | UUIDv7 jako TEXT we wszystkich tabelach ([ADR 0003](../decisions/0003-identyfikatory-i-usuwanie.md)) |
| Wykrywanie zmian | `updated_at` zmienia się tylko w zmienionych wierszach (`upsertIfChanged`) |
| Usunięcia | wyłącznie miękkie (`deleted_at`); usunięcie da się przesłać jak każdą inną zmianę |
| Rekord = jednostka synchronizacji | listy (aliasy, mięśnie) w wierszu ćwiczenia, bez tabel łączących ([D14](../roadmap.md)) |
| Stabilne kody | enumy jako kody snake_case ([ADR 0013](../decisions/0013-kody-enumow.md)) |
| Czas | epoch ms UTC + strefa IANA i data lokalna sesji |
| Repozytoria za interfejsami | dekorator z kolejką zmian może owinąć repozytoria bez zmian w logice treningu |
| Format wymiany | backup JSON ma płaskie tablice per tabela z `updatedAt` i `deletedAt` ([backup-format.md](../backup-format.md)) |

Przy dodaniu synchronizacji nie trzeba zmieniać schematu. Dojdą najwyżej kolumny techniczne: kolejka zmian lokalnych i znacznik ostatniej synchronizacji (osobna tabela).

## Synchronizacja

- **Konta i uwierzytelnianie:** konto użytkownika z logowaniem przez dostawcę tożsamości (np. „Zaloguj przez Google”) i OAuth 2.1 z PKCE w aplikacji mobilnej. Tokeny w bezpiecznym magazynie systemu (Android Keystore). Bez haseł przechowywanych przez nas.
- **Backend:** API HTTPS i PostgreSQL. Tabele jak w aplikacji, plus `user_id` w każdej tabeli i indeks `(user_id, updated_at)`. Row Level Security albo równoważna izolacja: każde zapytanie ograniczone do zalogowanego użytkownika.
- **Protokół:**
  1. Push: aplikacja wysyła wiersze z `updated_at` późniejszym niż ostatnia udana synchronizacja.
  2. Pull: aplikacja pobiera wiersze zmienione na serwerze od jej ostatniego znacznika, stronicowane.
  3. Znacznik synchronizacji to czas serwera, nie urządzenia; zegar telefonu może się mylić.
- **Konflikty:** „ostatni zapis wygrywa” per rekord według `updatedAt`, przy remisie decyduje porządek leksykograficzny id urządzenia. Miękkie usunięcie to zwykła zmiana z `deletedAt`, więc wygrywa albo przegrywa jak każda inna. Rozważyć wyjątek: zatwierdzona seria (`completed_at` ustawione) nie jest cofana przez starszą zmianę z innego urządzenia.
- **Aktywna sesja:** indeks „najwyżej jedna aktywna sesja” obowiązuje per użytkownik. Konflikt dwóch aktywnych sesji z różnych urządzeń rozstrzyga serwer: nowsza zostaje aktywna, starsza staje się zakończona z adnotacją.
- **Seed biblioteki:** ćwiczenia wbudowane mają stałe id, więc są wspólne dla urządzeń. Synchronizowane są tylko zmiany użytkownika (`user_modified`) i ćwiczenia własne.
- **RODO:**
  - eksport własnych danych (format backupu JSON);
  - usunięcie konta i wszystkich danych na serwerze (twarde usunięcie po okresie karencji);
  - rejestr przetwarzania;
  - umowy powierzenia z dostawcą hostingu.
- **Szyfrowanie:** TLS w tranzycie; szyfrowanie bazy i kopii zapasowych w spoczynku u dostawcy.
- **Dane o zdrowiu:** notatki i samopoczucie mogą być danymi o zdrowiu (szczególna kategoria). Polityka prywatności i formularz Data safety muszą to opisać; rozważyć opcję „nie synchronizuj notatek”.

## Serwer MCP (tylko odczyt)

Zdalny serwer MCP na backendzie, z autoryzacją OAuth i dostępem wyłącznie do danych zalogowanego użytkownika.

| Narzędzie | Zwraca |
| --- | --- |
| `search_exercises(query)` | pasujące ćwiczenia z `exercise_id`; bez tego model nie zna identyfikatorów |
| `list_workouts(date_from, date_to, limit, cursor)` | listę sesji z podsumowaniem |
| `get_workout(workout_id)` | pełną sesję z seriami |
| `get_exercise_history(exercise_id, date_from, date_to, limit, cursor)` | wykonania ćwiczenia w okresie |
| `get_personal_records(exercise_id)` | rekordy dla ćwiczenia |
| `get_progress_summary(period)` | metryki progresu z spec. 5.5 |
| `list_templates()` | szablony z planem serii |

Wymagania dla narzędzi:

- **Jednostki jawne** w każdej odpowiedzi, np. `"weight": {"value": 82.5, "unit": "kg"}`, w jednostce z ustawień użytkownika. Surowe wartości jak w backupie (gramy) tylko z opisem.
- **Czas:** ISO 8601 z przesunięciem strefy (`2026-10-19T18:05:00+02:00`) oraz data lokalna treningu.
- **Stabilne identyfikatory:** UUID z bazy.
- **Paginacja i limity:** `limit` (domyślnie 20, najwyżej 100), kursor oparty na `(started_at, id)`, limit rozmiaru odpowiedzi.
- **Logika metryk** taka sama jak w aplikacji ([ADR 0007](../decisions/0007-metryki.md)). Najlepiej wspólna specyfikacja z testami na tych samych danych: dziś domena Dart, na serwerze np. TypeScript albo Dart.
- **Bez narzędzi zapisu** w pierwszej wersji: model nie może zmieniać danych treningowych.

## Kolejność wdrożenia (propozycja)

1. Backend i konta, synchronizacja jednokierunkowa (kopia w chmurze) z widocznym statusem w aplikacji.
2. Synchronizacja dwukierunkowa z rozwiązywaniem konfliktów i testami na wielu urządzeniach.
3. Serwer MCP tylko do odczytu, z testami na danych przykładowych i limitami.
4. Zaktualizowana polityka prywatności, Data safety i procedury RODO przed udostępnieniem komukolwiek poza właścicielem.
