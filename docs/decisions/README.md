# Decyzje architektoniczne (ADR)

Decyzje łatwo odwracalne agent podejmuje sam i zapisuje tutaj. Decyzje trudno odwracalne (oznaczone ⚠: schemat danych, format eksportu, identyfikatory, nazwa pakietu) wymagają zgody właściciela przed implementacją. Wszystkie poniższe zostały zatwierdzone razem z planem Etapu 0 (2026-10-19). Numery D1–D22 odpowiadają tabeli decyzji z planu.

| ADR | Temat | Decyzje z planu |
| --- | --- | --- |
| [0001](0001-application-id-i-min-sdk.md) | applicationId i minSdk ⚠ | D1, D2 |
| [0002](0002-stan-nawigacja-di.md) | Stan, nawigacja, DI | D11 |
| [0003](0003-identyfikatory-i-usuwanie.md) | Identyfikatory i miękkie usuwanie ⚠ | D12 |
| [0004](0004-dziedziczenie-serii.md) | Dziedziczenie serii i liczba serii ⚠ | D13 |
| [0005](0005-katalog-cwiczen.md) | Katalog ćwiczeń ⚠ | D9, D10, D14, D18, D19 |
| [0006](0006-poprzednie-wykonanie-i-podpowiedzi.md) | Poprzednie wykonanie, podpowiedzi, nazwy w historii | D3, D4 |
| [0007](0007-metryki.md) | Metryki: 1RM, objętość, rekordy | D8, D15, D20 |
| [0008](0008-backup-i-eksport.md) | Backup, import i eksport ⚠ | D5, D6, D16 |
| [0009](0009-timer-przerwy.md) | Timer przerwy | D17 |
| [0010](0010-ustawienia-i-jednostki.md) | Ustawienia, jednostki, skala wysiłku | D7 |
| [0011](0011-jakosc-kodu.md) | Jakość kodu i kod generowany | D21 |
| [0012](0012-wyglad.md) | Wygląd | D22 |
| [0013](0013-kody-enumow.md) | Kody enumów w snake_case ⚠ | po Etapie 1 |
| [0014](0014-asystent-ai-ollama.md) | Asystent AI przez lokalną Ollamę | po wydaniu 1.0.0 |
| [0015](0015-plan-treningow.md) | Plan treningów i kalendarz ⚠ | po wydaniu 1.0.0 |
| [0016](0016-zamienniki-cwiczen.md) | Ćwiczenia zastępcze i kroki stepperów ⚠ | po wydaniu 1.0.0 |
| [0017](0017-progresja-podwojna.md) | Automatyczna progresja podwójna | po wydaniu 1.0.0 |
| [0018](0018-superserie.md) | Superserie | po wydaniu 1.0.0 |

## Szablon

```
# ADR NNNN: Tytuł

- Status: proponowana | zaakceptowana (RRRR-MM-DD) | zastąpiona przez NNNN
- Odwracalność: łatwa | trudna ⚠

## Kontekst
## Decyzja
## Konsekwencje
```
