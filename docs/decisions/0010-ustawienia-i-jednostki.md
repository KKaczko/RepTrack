# ADR 0010: Ustawienia, jednostki i skala wysiłku

- Status: zaakceptowana (2026-10-19)
- Odwracalność: łatwa

## Kontekst

Ustawienia muszą trafiać do backupu. Specyfikacja wymaga wyboru RIR albo RPE w ustawieniach oraz opcjonalnego pola wysiłku w aktywnym treningu.

## Decyzja

- Ustawienia w tabeli `settings` (klucz, wartość JSON), więc backup obejmuje je bez osobnego mechanizmu.
- Jednostka wyświetlania kg/lb i krok ciężaru (domyślnie 2,5 kg) zapisane w jednostce wyświetlania. Baza zawsze w gramach, konwersja wyłącznie w UI.
- Skala wysiłku: RIR, RPE albo **wyłączona**. Domyślnie RIR. Pole jest opcjonalne i nie blokuje zatwierdzenia serii.
- Wartość wysiłku w dziesiątych częściach (`effort_tenths`), np. RPE 8,5 → 85, RIR 2 → 20.

## Konsekwencje

- Zmiana skali w ustawieniach nie zmienia zapisanych serii, bo każda seria zapisuje własne `effort_scale`.
