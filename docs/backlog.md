# Backlog (poza MVP)

Funkcje spoza MVP. Nie implementujemy ich bez decyzji właściciela.

## Ze specyfikacji (sekcja 2)

- Konta użytkowników, backend i synchronizacja (projekt w `docs/future/sync-and-mcp.md`, Etap 7)
- Serwer MCP i integracja z ChatGPT (tylko architektura i dokumentacja)
- Funkcje społecznościowe i udostępnianie
- Wear OS, widżety, Health Connect
- AI-coach i automatyczne generowanie planów
- Zdjęcia i animacje ćwiczeń (`image_ref` jest w schemacie)
- Płatności i subskrypcje
- Wersja na iOS

## Wynikłe z Etapów 4–7

- Komunikaty walidacji pliku kopii (szczegóły błędów) są tylko po polsku; tytuł i opis błędu są przetłumaczone.
- Snackbar na ekranie „Kopia i eksport” przez kilka sekund zasłania przyciski eksportu na dole listy.
- Własne długości przerw (obecnie lista 0:30–5:00).
- Osobne kroki ciężaru dla sprzętu (hantle, maszyny) w progresji i stepperach — ADR 0017.
- Zmniejszanie ciężaru (deload) po kilku nieudanych treningach — ADR 0017.
- Wybór zakresu na wykresach (obecnie 12 ostatnich tygodni i treningów) oraz wykres masy ciała.
- Przypomnienie o niezatwierdzonych seriach przed zakończeniem treningu (obecnie tylko informacja na podsumowaniu).

## Wynikłe z planu Etapu 0

- Scalanie danych przy imporcie backupu (MVP: tylko „zastąp wszystko”) — ADR 0008
- Przełącznik formatu CSV „międzynarodowy” (przecinek, kropka dziesiętna) — ADR 0008
- Lokalizacja nazw ćwiczeń wbudowanych (EN jako osobna nazwa, nie tylko alias) — ADR 0005
- Ćwiczenia z wger (CC-BY-SA) z atrybucją — ADR 0005
- Śledzenie masy ciała użytkownika i metryki dla ćwiczeń z masą ciała — ADR 0007
- Osobne logowanie lewej i prawej strony w ćwiczeniach jednostronnych (pole `side`) — ADR 0005
- Nadpisanie pola serii wartością „brak” (flagi nadpisań) — ADR 0004
- Cel serii jako dystans (obecnie: powtórzenia albo czas)
- Wyszukiwanie odporne na odmianę polskich słów („ławka” → „na ławce”), np. przez proste ucinanie końcówek lub więcej aliasów — ADR 0005
