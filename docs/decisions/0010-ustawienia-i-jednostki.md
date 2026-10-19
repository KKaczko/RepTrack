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

## Implementacja (Etap 4)

- Ekran ustawień: jednostka, krok ciężaru, skala wysiłku, domyślna przerwa, „Nie wygaszaj ekranu podczas treningu”, status dokładnego alarmu i motyw. Każda zmiana zapisuje się od razu.
- Krok ciężaru do wyboru: 0,5 / 1 / 1,25 / 2,5 / 5 kg albo 1 / 2,5 / 5 / 10 lb. Po zmianie jednostki krok spoza listy nowej jednostki wraca do domyślnego (2,5 kg, 5 lb).
- Stepper ciężaru idzie do następnego punktu siatki kroku: przy kroku 2,5 kg z 81 kg „+” daje 82,5, a „−” 80.
- Wysiłek w treningu: RIR 0–5 albo RPE 6–10 (co 0,5 od 7), wybór chipem; ponowne tapnięcie czyści pole.
- Pozostałe kroki stepperów: powtórzenia 1, czas 5 s, dystans 100 m.
