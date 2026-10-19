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
