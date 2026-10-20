# RepTrack

Aplikacja mobilna do planowania, wykonywania i analizowania treningów siłowych. Najpierw Android, później iOS. Działa w pełni lokalnie: bez rejestracji, bez internetu i bez serwera.

## Funkcje

- **Biblioteka ćwiczeń:** około 120 pozycji z polskimi nazwami (na bazie free-exercise-db), wyszukiwanie bez polskich znaków, filtry i własne ćwiczenia.
- **Szablony:** ćwiczenia i serie ze wspólnym celem albo osobnym dla każdej serii, kolejność, duplikowanie, archiwum.
- **Aktywny trening:**
  - podpowiedzi z poprzedniego wykonania;
  - zatwierdzenie serii jednym tapnięciem;
  - timer przerwy z powiadomieniem;
  - natychmiastowy zapis i wznowienie po ubiciu aplikacji;
  - aktualizacja szablonu po treningu.
- **Historia i progres:** edycja zakończonych treningów, porównanie z poprzednim, rekordy, szacowany 1RM, objętość i wykresy.
- **Kopia i eksport:** pełna kopia JSON z przywracaniem, CSV dla polskiego Excela, Markdown do czatu z AI oraz Android Auto Backup.
- **Wygląd:** ciemny i jasny motyw, kg albo lb, RIR albo RPE, polski i angielski.

Stos: Flutter + Dart, Drift (SQLite), Riverpod, go_router.

## Stan

MVP (Etapy 0–7) gotowe w repozytorium; Etapy 0–3 zaakceptowane, Etapy 4–7 czekają na Twój przegląd. Przed wydaniem zostaje lista kontroli ręcznych na telefonie ([publishing.md](docs/publishing.md#lista-kontroli-ręcznych-spec-9)).

## Budowanie

Wymagany Flutter 3.47 (stable), JDK 17 i Android SDK z platformą 36; szczegóły w [docs/development.md](docs/development.md).

```bash
bash tool/check.sh
```

Skrypt pobiera zależności, generuje kod, sprawdza format i analizę, uruchamia testy i buduje:

- `build/app/outputs/flutter-apk/app-release.apk`;
- `build/app/outputs/bundle/release/app-release.aab`.

Bez `android/key.properties` wydanie jest podpisane kluczem debug. Podpis własnym kluczem i publikacja: [docs/publishing.md](docs/publishing.md).

## Dokumentacja

- [Specyfikacja](docs/spec/reptrack-prompt-v2.md)
- [Środowisko, budowanie i testy](docs/development.md)
- [Wydanie i publikacja](docs/publishing.md)
- [Plan etapów, testy i ryzyka](docs/roadmap.md)
- [Architektura](docs/architecture.md)
- [Model danych](docs/data-model.md)
- [Format kopii zapasowej i eksportu](docs/backup-format.md)
- [UX: mapa ekranów i aktywny trening](docs/ux.md)
- [Decyzje (ADR)](docs/decisions/README.md)
- [Backlog poza MVP](docs/backlog.md)
- [Przyszłość: synchronizacja i MCP](docs/future/sync-and-mcp.md)

## Licencje

Dane biblioteki ćwiczeń: free-exercise-db (Unlicense). Font Inter (SIL OFL 1.1). Licencje bibliotek open source są w aplikacji: Ustawienia → Licencje i źródła.
