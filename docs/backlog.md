# Backlog (poza MVP)

Funkcje spoza MVP. Nie implementujemy ich bez decyzji właściciela.

## Ze specyfikacji (sekcja 2)

- Konta użytkowników, backend i synchronizacja (projekt w `docs/future/sync-and-mcp.md`, Etap 7)
- Serwer MCP i integracja z ChatGPT (tylko architektura i dokumentacja)
- Funkcje społecznościowe i udostępnianie
- Wear OS, widżety, Health Connect
- AI-coach i automatyczne generowanie planów
- Interfejs do superserii (`group_id` jest w schemacie od początku)
- Zdjęcia i animacje ćwiczeń (`image_ref` jest w schemacie)
- Płatności i subskrypcje
- Wersja na iOS

## Wynikłe z planu Etapu 0

- Scalanie danych przy imporcie backupu (MVP: tylko „zastąp wszystko”) — ADR 0008
- Przełącznik formatu CSV „międzynarodowy” (przecinek, kropka dziesiętna) — ADR 0008
- Lokalizacja nazw ćwiczeń wbudowanych (EN jako osobna nazwa, nie tylko alias) — ADR 0005
- Ćwiczenia z wger (CC-BY-SA) z atrybucją — ADR 0005
- Śledzenie masy ciała użytkownika i metryki dla ćwiczeń z masą ciała — ADR 0007
- Osobne logowanie lewej i prawej strony w ćwiczeniach jednostronnych (pole `side`) — ADR 0005
- Nadpisanie pola serii wartością „brak” (flagi nadpisań) — ADR 0004
- Cel serii jako dystans (obecnie: powtórzenia albo czas)
