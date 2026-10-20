# ADR 0014: Asystent AI przez lokalną Ollamę

- Status: zaakceptowana (2026-10-20, plan zatwierdzony przez właściciela)
- Odwracalność: łatwa (funkcja opcjonalna, bez zmian schematu; domyślnie wyłączona)

## Kontekst

Właściciel chce rozmawiać z AI o swoich treningach bez płatnych usług. ChatGPT łączy się tylko z publicznymi serwerami MCP przez HTTPS i wymaga planu Pro albo Business (pomoc OpenAI, sprawdzone 2026-10-20), więc odpada. Na komputerze właściciela działa darmowa Ollama (0.40.6) z modelami `qwen3.5:4b` i `qwen3.8:27b`.

## Decyzja

- **Gdzie:** ekran „Asystent” w aplikacji na telefonie łączy się z API Ollamy na komputerze właściciela w sieci domowej. Adres i model są w ustawieniach (`assistant_url`, `assistant_model`). Bez adresu asystent jest wyłączony, a reszta aplikacji działa offline jak dotąd.
- **Kontekst zamiast narzędzi:** aplikacja liczy metryki własną domeną (ADR 0007, analiza okresu) i wysyła modelowi zwięzły Markdown z danymi oraz pytanie. Małe modele (4B) radzą sobie z tym pewniej niż z wywoływaniem narzędzi, a liczby w odpowiedzi pochodzą z aplikacji. Wywoływanie narzędzi (tool calling) można dodać później.
- **Tylko odczyt:** model nie zapisuje niczego w aplikacji. Propozycje treningu to tekst do przeczytania.
- **API:** `GET /api/version`, `GET /api/tags`, `POST /api/chat` ze strumieniem NDJSON, `think: false` (szybciej na słabszym sprzęcie) i `num_ctx` 8192. Klient na `dart:io`, bez nowych zależności. Limit ciszy między fragmentami: 3 minuty, bo na CPU model długo czyta kontekst.
- **Sieć:**
  - uprawnienie `INTERNET`;
  - ruch bez TLS dopuszczony w `network_security_config`, bo Ollama w sieci domowej mówi po HTTP, a adres (np. `192.168.1.10`) wpisuje użytkownik;
  - aplikacja nie łączy się z niczym innym.
- **Przygotowanie komputera** robi właściciel (to ustawienia systemu):
  - `OLLAMA_HOST=0.0.0.0` i restart Ollamy;
  - reguła zapory dla TCP 11434 w sieci prywatnej;
  - adres IPv4 komputera wpisany w aplikacji.

  Do testów bez zmian w systemie:
  - emulator: `http://10.0.2.2:11434`;
  - telefon przez USB: `adb reverse tcp:11434 tcp:11434` i `http://127.0.0.1:11434`.

## Dane, które wychodzą z telefonu

Tylko na adres z ustawień i tylko po akcji użytkownika (pytanie, „Podsumuj z AI”, „Propozycja AI”):
- podsumowania okresu i progresu;
- ostatnie treningi z seriami;
- nazwy ćwiczeń i szablonów;
- notatki i samopoczucie z treningów, które trafiają do kontekstu.

Notatki mogą być danymi o zdrowiu; zostają w sieci właściciela. Rozmowa nie jest zapisywana w aplikacji.

## Konsekwencje

- Polityka prywatności i Data safety muszą opisać uprawnienie internetu i wysyłanie danych na serwer wskazany przez użytkownika ([publishing.md](../publishing.md)).
- Asystent działa tylko w zasięgu komputera z Ollamą (np. w domu). Dostęp spoza domu (np. Tailscale) albo zdalny serwer MCP ([future/sync-and-mcp.md](../future/sync-and-mcp.md)) to osobne decyzje.
- Jakość i szybkość zależą od modelu i sprzętu. Na karcie z 4 GB VRAM `qwen3.5:4b` mieści się prawie w całości, a 27b działa głównie na CPU i jest wolny.
