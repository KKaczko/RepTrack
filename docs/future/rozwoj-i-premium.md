# Rozwój RepTrack i ścieżka do premium

Status: kierunek ustalony z właścicielem **2026-10-21**. Na początku wszystko jest za darmo. Premium (hostowany asystent AI) to przyszłość, w tym dokumencie tylko jako projekt.

## Mapa rozwoju

| Runda | Zakres | Stan |
| --- | --- | --- |
| 1. Trening na siłowni | kroki dla sprzętu, kalkulator talerzy, rozgrzewka, deload, własne przerwy, pytanie o niezatwierdzone serie ([ADR 0020](../decisions/0020-narzedzia-treningu.md)) | zrobione 2026-10-21 |
| 2. AI, które działa | odpowiedzi w JSON według schematu; propozycje z podglądem, zatwierdzane jednym tapnięciem (ciężary na następny trening, zmiany szablonu, nowy szablon z biblioteki, plan tygodnia); tygodniowe podsumowanie na żądanie | następna |
| 3. Ciało i zdrowie | masa ciała i obwody z wykresami, metryki ćwiczeń z masą ciała; Health Connect (waga, zapis treningów). ⚠ Baza v4 i backup v4, uprawnienia zdrowotne i deklaracja w Google Play | wymaga zgody przed startem |
| 4. Na co dzień | widżet na ekranie głównym (dzisiejszy trening, seria tygodni), tygodniowe podsumowanie w powiadomieniu | później |
| Wydanie | polityka prywatności, opis i zrzuty sklepu PL/EN, testy zamknięte | osobna runda, gdy funkcje będą gotowe |

Każda runda dostaje osobny plan do akceptacji.

## Ścieżka do premium

### Model

- **Rdzeń darmowy i lokalny:**
  - trening, plan, historia, progres, programy;
  - kopia, eksport;
  - asystent z własną Ollamą.
- **Premium** to hostowany asystent „RepTrack AI”: aplikacja łączy się z serwerem właściciela, a nie z komputerem użytkownika.
- **Do decyzji później:** czy darmowa opcja „własny serwer Ollama” zostaje. Zostawienie jej jest uczciwe wobec zaawansowanych użytkowników, ale słabiej zachęca do premium.

### Architektura

```
aplikacja ──HTTPS──▶ bramka RepTrack AI ──sieć prywatna──▶ Ollama (GPU)
                     · konto i token
                     · sprawdzenie subskrypcji
                     · limity na użytkownika
                     · kolejka i limity czasu
                     · logi bez treści rozmów
```

- **Ollama nigdy publicznie.** Nie ma uwierzytelniania ([ADR 0014](../decisions/0014-asystent-ai-ollama.md)). Między bramką a komputerem z GPU działa sieć prywatna, np. Tailscale.
- **Punkt wymiany w aplikacji:** `AssistantClient` (`lib/features/assistant/data/assistant_client.dart`). Drugi klient doda nagłówek z tokenem i adres bramki; kontekst, budżet i propozycje zostają te same.
- **Propozycje z rundy 2** to ten sam JSON lokalnie i w chmurze, więc premium nie wymaga drugiej wersji funkcji.
- **Konta:** projekt w [sync-and-mcp.md](sync-and-mcp.md) (logowanie przez dostawcę tożsamości, tokeny w Android Keystore).

### Warunki wstępne

1. Publikacja w Google Play ([publishing.md](../publishing.md)).
2. Konta użytkowników.
3. Subskrypcja przez Google Play Billing z weryfikacją zakupów na serwerze. Dobra cyfrowe w aplikacji z Google Play wymagają rozliczenia przez Google Play.
4. Polityka prywatności i Data safety. Do serwera trafiają podsumowania treningów, notatki i samopoczucie.
5. RODO: notatki i samopoczucie mogą być danymi o zdrowiu (szczególna kategoria), więc potrzebna jest wyraźna zgoda, możliwość usunięcia danych i umowy z dostawcą hostingu.
6. Niezawodny serwer: domowy PC nie wystarczy płacącym użytkownikom (dostępność, kolejki przy kilku osobach naraz).

### Do sprawdzenia w chwili decyzji

Tych faktów nie podajemy dziś jako liczb, bo się zmieniają. Przy decyzji trzeba je sprawdzić i zapisać z datą weryfikacji:
- opłata Google Play od subskrypcji;
- wymagania testów zamkniętych dla nowych kont deweloperskich (liczba testerów, czas);
- koszt serwera z GPU albo innego dostawcy modeli;
- przepustowość Ollamy przy wielu użytkownikach naraz (`OLLAMA_NUM_PARALLEL`, kolejka).
