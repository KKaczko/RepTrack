# Wydanie i publikacja

Status: przygotowanie w Etapie 7. Nic nie zostało opublikowane; każdy krok publikacji wykonuje właściciel.

Fakty o wymaganiach Google sprawdzone **2026-10-20** w dokumentacji Google (źródła na końcu). Zasady Google Play zmieniają się co roku, więc przed publikacją trzeba je sprawdzić ponownie.

## Podpisane APK i AAB

1. Wygeneruj klucz przesyłania (upload key) **poza repozytorium**, np.:

   ```bash
   D:/Dev/tools/jdk-17/bin/keytool -genkey -v -keystore D:/Klucze/reptrack-upload.jks -keyalg RSA -keysize 4096 -validity 10000 -alias upload
   ```

2. Skopiuj `android/key.properties.example` jako `android/key.properties` (plik jest w `.gitignore`) i uzupełnij hasła oraz ścieżkę.
3. Zrób kopię zapasową keystore i haseł w bezpiecznym miejscu, osobno od komputera.
4. Zbuduj:

   ```bash
   bash tool/check.sh
   ```

   Skrypt sprawdza format, analizę i testy, a potem buduje `build/app/outputs/flutter-apk/app-release.apk` i `build/app/outputs/bundle/release/app-release.aab`. Bez `key.properties` oba pliki są podpisane kluczem debug: nadają się do instalacji na własnym telefonie, ale nie do Google Play.

Wersja aplikacji: `version` w `pubspec.yaml` (`1.0.0+1` = versionName + versionCode). Przy każdym wydaniu podnieś numer po `+`; stałą `appVersionName` w `lib/app/app_info.dart` trzyma w zgodzie test.

## Instalacja poza sklepem (APK)

- Instalacja przez `adb` (także z Android Studio) nie wymaga weryfikacji dewelopera, również po wprowadzeniu weryfikacji.
- **Weryfikacja deweloperów Androida:** od 30 września 2026 obowiązuje na certyfikowanych urządzeniach w Brazylii, Indonezji, Singapurze i Tajlandii. Rozszerzenie na cały świat Google zapowiada na 2027 rok, bez konkretnej daty dla Polski i UE.
  - Po wprowadzeniu w Polsce przekazanie APK innym osobom (nie przez `adb`) wymaga zarejestrowania pakietu na zweryfikowanym koncie.
  - Druga możliwość to „zaawansowany” proces instalacji niezweryfikowanych aplikacji po stronie użytkownika.
  - Konta „limited distribution” (studenci, hobbyści) pozwalają udostępnić aplikację na najwyżej 20 urządzeń bez dokumentu tożsamości i opłaty.

## Google Play

1. **Konto deweloperskie** (opłata rejestracyjna, weryfikacja tożsamości). Nowe konta prywatne (utworzone po 13 listopada 2023) muszą przed produkcją przejść **test zamknięty: co najmniej 12 testerów przez 14 dni**. Źródła to głównie opisy zewnętrzne; sprawdź w pomocy Play Console przed rejestracją.
2. **Target API:** od 31 sierpnia 2026 nowe aplikacje i aktualizacje muszą celować w Android 16 (API 36) lub wyżej. RepTrack ma `targetSdk = 36`.
3. **Play App Signing:** włącz przy pierwszym wydaniu. Google przechowuje klucz podpisujący aplikację, a Twój keystore jest tylko kluczem przesyłania; jego utratę da się odwrócić resetem w Play Console.
4. **Wydanie:** prześlij `app-release.aab` na ścieżkę testu wewnętrznego, potem zamkniętego, potem produkcyjnego.
5. **Strona w sklepie:**
   - opis;
   - zrzuty ekranu (ciemny i jasny motyw, aktywny trening, historia);
   - ikona 512 × 512 (z `ic_launcher_foreground` na tle `#0E0F11`);
   - grafika 1024 × 500.
6. **Polityka prywatności (URL):** wymagana. Treść poniżej, do opublikowania np. na GitHub Pages.

### Data safety (formularz w Play Console)

- Aplikacja **nie zbiera i nie udostępnia** danych w rozumieniu Google Play. Wszystko zostaje na urządzeniu; nie ma kont, serwera dewelopera, analityki ani reklam.
- **Asystent AI** ([ADR 0014](decisions/0014-asystent-ai-ollama.md)), domyślnie wyłączony:
  - po akcji użytkownika wysyła dane treningowe (także notatki i samopoczucie) na serwer Ollama pod adresem, który użytkownik sam wpisał, zwykle jego własny komputer w sieci domowej;
  - deweloper ich nie dostaje;
  - przed wypełnieniem formularza sprawdź, jak Google traktuje przesyłanie danych na serwer wskazany przez użytkownika (np. czy to „udostępnianie”). Najbezpieczniej opisać je w formularzu i w polityce.
- Dane trafiają poza aplikację tylko na polecenie użytkownika (zapis pliku, udostępnienie, schowek) albo przez systemową kopię Androida (Auto Backup do konta Google użytkownika). Według zasad Google Play to nie jest „zbieranie” przez dewelopera; przed wypełnieniem sprawdź aktualne objaśnienia formularza.
- Notatki i samopoczucie mogą być danymi o zdrowiu. Przy przyszłej synchronizacji z serwerem formularz i polityka prywatności muszą to uwzględnić ([future/sync-and-mcp.md](future/sync-and-mcp.md)).
- Uprawnienia:
  - powiadomienia: timer przerwy i przypomnienia o treningach z planu (domyślnie wyłączone);
  - dokładne alarmy (za zgodą): koniec przerwy na czas;
  - wibracja;
  - uruchomienie po restarcie: przywrócenie zaplanowanych powiadomień (przerwa, przypomnienia);
  - internet: tylko asystent AI i tylko z adresem z ustawień.

  Aplikacja nie prosi o dostęp do pamięci, lokalizacji ani kontaktów.

### Polityka prywatności (szkic)

> RepTrack przechowuje wszystkie dane (ćwiczenia, szablony, treningi, ustawienia) wyłącznie na Twoim urządzeniu. Aplikacja nie ma kont i nie wysyła danych do autora ani nikomu innemu. Dane opuszczają urządzenie tylko wtedy, gdy:
> - sam je wyeksportujesz albo udostępnisz;
> - korzystasz z opcjonalnego asystenta AI;
> - działa systemowa kopia zapasowa Androida na Twoim koncie Google (możesz ją wyłączyć w ustawieniach telefonu).
>
> Asystent AI jest domyślnie wyłączony. Gdy wpiszesz adres swojego serwera Ollama, aplikacja przy każdym pytaniu wysyła na ten adres, i tylko na niego, potrzebne dane treningowe, w tym notatki i samopoczucie z treningów. Rozmowy z asystentem nie są zapisywane w aplikacji. Odinstalowanie aplikacji usuwa dane z urządzenia.

## Lista kontroli ręcznych (spec. 9)

Do przejścia na telefonie przed wydaniem:

- [ ] APK instaluje się i uruchamia na telefonie z Androidem.
- [ ] Biblioteka ćwiczeń działa w trybie samolotowym.
- [ ] Dodaję i edytuję własne ćwiczenie.
- [ ] Tworzę szablon z dowolną liczbą ćwiczeń i serii, z zakresem wspólnym i osobnym dla serii.
- [ ] Rozpoczynam trening i zapisuję serie w limitach tapnięć ([ux.md](ux.md#budżet-tapnięć)).
- [ ] Po wymuszonym zamknięciu aplikacji w trakcie treningu sesja wznawia się bez strat.
- [ ] Timer przerwy powiadamia przy zablokowanym ekranie (z dokładnymi alarmami i bez).
- [ ] Edycja szablonu nie zmienia zakończonych treningów.
- [ ] Porównuję bieżący trening z poprzednim.
- [ ] Eksportuję backup, czyszczę dane aplikacji i przywracam wszystko z pliku.
- [ ] Android Auto Backup: odinstalowanie i ponowna instalacja odtwarzają dane ([development.md](development.md#android-auto-backup)).
- [ ] Plan treningów: plan tygodnia, przesunięcie dnia, „Rozpocznij” z karty dnia i ze Startu, przypomnienie o ustawionej godzinie ([ADR 0015](decisions/0015-plan-treningow.md)).
- [ ] Asystent AI z Ollamą na komputerze w tej samej sieci Wi‑Fi: test połączenia, pytanie, „Podsumuj z AI”, „Propozycja AI” ([ADR 0014](decisions/0014-asystent-ai-ollama.md)).

## Źródła (sprawdzone 2026-10-20)

- [Target API level requirements](https://developer.android.com/google/play/requirements/target-sdk)
- [Android developer verification](https://developer.android.com/developer-verification)
- [Android developer verification FAQ](https://developer.android.com/developer-verification/guides/faq)
- [Android Developers Blog: Android developer verification, 2026-06](https://android-developers.googleblog.com/2026/06/android-developer-verification.html)
- [Testy zamknięte dla nowych kont: opis zewnętrzny](https://www.testerscommunity.com/blog/google-play-closed-testing-requirements-2026) (do potwierdzenia w pomocy Play Console)
