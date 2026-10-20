# ADR 0012: Wygląd

- Status: zaakceptowana (2026-10-19)
- Odwracalność: łatwa

## Kontekst

Minimalistyczny wygląd komercyjnej aplikacji fitness: ciemny motyw domyślny, jasny jako alternatywa, jeden wyrazisty akcent, design tokens, kontrast co najmniej WCAG AA, działanie offline.

## Decyzja

- Ciemny motyw domyślny: tło #0E0F11, powierzchnie #17181C.
- Jeden akcent „volt” #C8F25A jako token. W jasnym motywie akcent tylko jako wypełnienie z ciemnym tekstem, żeby utrzymać kontrast AA.
- Font Inter (licencja OFL) dołączony do aplikacji, bez pobierania z sieci. Cyfry tabelaryczne dla liczb i timera.
- Ikony: wbudowane Material Icons w wariancie Rounded, bez dodatkowych pakietów.
- Tokeny: promienie 12/16/24, odstępy 4/8/12/16/24/32, przyciski min. 48 dp, główne akcje treningu 56–64 dp.

## Konsekwencje

- Inter wymaga atrybucji na ekranie „Licencje i źródła”.
- Zmiana akcentu to zmiana jednego tokenu.

## Implementacja (Etap 7)

- Ikona adaptacyjna: sztanga w kolorze volt na tle #0E0F11 (`res/drawable/ic_launcher_foreground.xml`, `res/mipmap-anydpi-v26/ic_launcher.xml`), z warstwą monochromatyczną dla ikon tematycznych Androida 13+. Przy minSdk 26 mapy bitowe ikony nie są potrzebne.
- Ekran startowy i tło okna przed pierwszą klatką Fluttera mają kolor #0E0F11 zamiast domyślnej bieli.
- Przegląd dostępności w testach (`test/app/accessibility_test.dart`): czcionka 2× na 360 dp bez przepełnień na ekranach treningu, podsumowania, historii, porównania, ustawień i kopii; cele dotyku 48 dp, etykiety i kontrast tekstu (WCAG AA) w ciemnym i jasnym motywie.
