# ADR 0002: Stan, nawigacja i DI

- Status: zaakceptowana (2026-10-19)
- Odwracalność: łatwa

## Kontekst

Aplikacja potrzebuje reaktywnego stanu opartego na strumieniach Drift, wstrzykiwania zależności podmienialnego w testach oraz nawigacji z dolnymi zakładkami, które zachowują swój stos. Specyfikacja preferuje popularne, aktywnie utrzymywane pakiety.

## Decyzja

- **Riverpod 3** (`flutter_riverpod` 3.4.x) jako stan i DI. Providery pisane ręcznie (`Notifier`, `AsyncNotifier`, `StreamProvider`), bez `riverpod_generator`.
- **go_router 18** (flutter.dev, feature-complete) ze `StatefulShellRoute` dla 4 zakładek. Aktywny trening i ustawienia jako trasy pełnoekranowe poza shellem.

## Konsekwencje

- Testy podmieniają `appDatabaseProvider`, `clockProvider` i `idGeneratorProvider` przez `ProviderScope(overrides: …)`.
- Bez generatora Riverpod mniej kodu generowanego i szybszy `build_runner` (i tak potrzebny dla Drift i freezed). Generator można dodać później bez zmian w domenie.
- go_router jest w trybie utrzymania (tylko poprawki), co przy stabilnym API jest zaletą.
