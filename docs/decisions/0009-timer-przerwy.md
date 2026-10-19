# ADR 0009: Timer przerwy

- Status: zaakceptowana (2026-10-19), zaimplementowana w Etapie 4; test na Samsungu u właściciela
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

## Implementacja (Etap 4)

- `lib/core/platform/rest_notifications.dart`: interfejs `RestNotifications` z implementacją na `flutter_local_notifications` i wersją bez efektów do testów.
- Dwa kanały: „Odliczanie przerwy” (niski priorytet, bez dźwięku) i „Koniec przerwy” (wysoki priorytet, dźwięk i wibracja).
- Odliczanie: trwałe powiadomienie z chronometrem odliczającym do `rest_ends_at`, które samo znika po końcu przerwy (`timeoutAfter`).
- Koniec: `zonedSchedule` jako exact, gdy `canScheduleExactNotifications()` zwraca true; inaczej inexact. Receivery `ScheduledNotificationReceiver` i `ScheduledNotificationBootReceiver` w manifeście przywracają alarm po restarcie telefonu.
- Zgoda na powiadomienia (Android 13+) jest proszona przy starcie treningu (system pyta tylko raz).
- O dokładne alarmy aplikacja pyta jeden raz, po wejściu w pierwszy trening, okienkiem z wyjaśnieniem („Nie teraz” / „Zezwól”). Potem status i przejście do zgody systemowej są w Ustawieniach. Na emulatorze bez tej zgody powiadomienie końca przerwy przyszło około 80 s po czasie.
- Przy starcie aplikacji trwająca przerwa wraca do powiadomień (`restoreRestNotification` w `bootstrap.dart`), bo wymuszone zamknięcie usuwa powiadomienia i alarmy aplikacji.
- W aplikacji pasek przerwy liczy czas z `rest_ends_at`; na końcu przerwy telefon wibruje (`HapticFeedback.vibrate`). Dźwięk daje powiadomienie końca przerwy, także przy aplikacji na ekranie.
- ±15 s i „Pomiń” zmieniają `rest_ends_at` i przeplanowują albo anulują oba powiadomienia. Przerwa nie startuje po ostatniej serii treningu ani przy przerwie 0.
