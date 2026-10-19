# ADR 0001: applicationId i minSdk

- Status: zaakceptowana (2026-10-19)
- Odwracalność: trudna ⚠ (applicationId nie da się zmienić po publikacji w Google Play)

## Kontekst

Specyfikacja wymaga potwierdzenia applicationId i minSdk przed Etapem 1. Google Play od 31.08.2026 wymaga targetSdk 36 dla nowych aplikacji i aktualizacji (developer.android.com, sprawdzone 2026-10-19). Flutter 3.47 domyślnie ustawia minSdk 24 i compile/target 36.

## Decyzja

- applicationId: `io.github.kkaczko.reptrack`. Oparty na koncie GitHub właściciela, więc nie wchodzi w cudzą przestrzeń nazw i nie wymaga domeny.
- minSdk: 26 (Android 8.0). compileSdk i targetSdk: 36.

## Konsekwencje

- Kanały powiadomień (API 26) są zawsze dostępne, więc timer przerwy ma jedną ścieżkę kodu.
- Mniej gałęzi dla starszych wersji Androida. Odcina pomijalny odsetek urządzeń w porównaniu z domyślnym 24.
- targetSdk trzeba podnosić co roku zgodnie z wymaganiami Google Play.
