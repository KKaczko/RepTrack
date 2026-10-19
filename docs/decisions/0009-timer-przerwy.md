# ADR 0009: Timer przerwy

- Status: zaakceptowana (2026-10-19), do potwierdzenia testem na telefonie w Etapie 4
- Odwracalność: łatwa

## Kontekst

Timer przerwy musi działać przy zablokowanym ekranie: powiadomienie z odliczaniem oraz wibracja lub dźwięk na koniec. Ograniczenia (stan na 2026-10-19, częściowo niezweryfikowane w polityce Google Play):

- Od Androida 14 `SCHEDULE_EXACT_ALARM` jest domyślnie odebrane i wymaga zgody użytkownika.
- `USE_EXACT_ALARM` jest według dokumentacji Androida zastrzeżony dla aplikacji typu budzik, zegar lub kalendarz; timer przerwy prawdopodobnie się nie kwalifikuje.
- One UI na Samsungu usypia aplikacje w tle.

## Decyzja

- Odliczanie w trwałym powiadomieniu z systemowym chronometrem (`usesChronometer`, `chronometerCountDown` w `flutter_local_notifications`), więc wyświetlanie nie wymaga działającego procesu.
- Alarm końca przerwy: exact, gdy użytkownik nadał `SCHEDULE_EXACT_ALARM` (prośba z wyjaśnieniem przy pierwszym użyciu); w przeciwnym razie inexact.
- Gdy aplikacja jest na ekranie, wibracja i dźwięk z timera w aplikacji.
- Koniec przerwy zapisany w `workout_sessions.rest_ends_at`, więc timer przetrwa ubicie procesu.
- Plan B, jeśli test na telefonie wypadnie źle: foreground service na czas aktywnego treningu.

## Konsekwencje

- Bez zgody na exact alarm koniec przerwy może się spóźnić w trybie Doze.
- Wymaga desugaringu i compileSdk 36 (wymagania `flutter_local_notifications` 22.x).
