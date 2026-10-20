# UX: mapa ekranów i aktywny trening

Status: plan z Etapu 0 (zatwierdzony 2026-10-19), aktywny trening zaimplementowany w Etapie 4. Kierunek wizualny: [ADR 0012](decisions/0012-wyglad.md).

## Mapa ekranów

```
Shell z dolną nawigacją (StatefulShellRoute, 4 zakładki):
├─ Start /                    baner wznowienia · „Rozpocznij: <ostatni szablon>” · ostatnie szablony
│                             · pusty trening · ostatnia sesja · treningi w tym tygodniu · ⚙ → Ustawienia
├─ Szablony /templates        lista (przełącznik archiwum) → /templates/new, /templates/:id edytor
│                             → arkusz konfiguracji serii ćwiczenia (nadpisania, „przywróć dziedziczenie”)
├─ Historia /history          [Sesje | Progres]
│    Sesje → /sessions/:id szczegóły + tryb edycji → /sessions/:id/compare
│    Progres → okres (4 tyg. · 3 mies. · rok · całość) · podsumowanie z porównaniem
│              · treningi/tydzień · serie na partię mięśniową · wybór ćwiczenia → kafelki i wykresy
└─ Ćwiczenia /exercises       szukaj + filtry → /exercises/:id [Info | Historia | Rekordy | Wykresy]
                              → /exercises/:id/edit, /exercises/new

Poza shellem (pełny ekran):
  /workout                    aktywny trening (arkusze: wybór ćwiczenia, kolejność, zamiana)
  /workout/finish             podsumowanie, notatka, samopoczucie, diff „zaktualizuj szablon”
  /sessions/:id               zakończony trening: szczegóły, edycja, usunięcie (z Historii, Startu, ekranu ćwiczenia)
  /sessions/:id/compare       porównanie z poprzednim wykonaniem każdego ćwiczenia
  /settings → /settings/backup (backup, przywracanie, CSV, MD) · /settings/licenses
  /glossary                   słowniczek pojęć (z ustawień, z zakładki Progres i z arkusza ⓘ)
  /pick-exercises             wspólny wybór ćwiczeń (szablony, trening, filtr eksportu); zwraca listę id
                              ?single=true: jedno ćwiczenie jednym tapnięciem (zamiana w treningu)
```

Gdy trwa sesja, nad dolną nawigacją wisi pasek „Trening trwa 32:10 · Wróć” na każdym ekranie shella.

## Szkic aktywnego treningu (360–430 dp, jedna ręka)

```
┌────────────────────────────────────┐
│ ⌄ Push A            ⏱ 32:15     ⋮ │  ⌄ minimalizuj · ⋮ zakończ / porzuć / kolejność
├────────────────────────────────────┤
│ 2/6  Wyciskanie sztangi na ławce   │  przesuń ← → między ćwiczeniami (PageView)
│ 3 × 8–12 · przerwa 2:00        ⓘ  │
├────────────────────────────────────┤
│ #   Plan   Poprz.   kg    powt   ✓ │
│ R   10     40×10    40    10     ● │  wykonana: pełny kontrast
│ 1   8–12   80×10    80    10     ● │
│ 2▸  8–12   80×9    ·80·  ·9·     ○ │  bieżąca: podpowiedź wyszarzona
│ 3   8–12   80×8    ·80·  ·8·     ○ │
│ + Dodaj serię                      │
├──────────── strefa kciuka ─────────┤
│ ┌ Ciężar ───────────┐ ┌ Powt. ───┐ │
│ │ [ − ]  80 kg [ + ]│ │[−] 9 [+] │ │  steppery 56 dp, krok z ustawień
│ └───────────────────┘ └──────────┘ │
│ RIR  0 1 2 3 4 5                   │  wysiłek, gdy skala włączona w ustawieniach
│ ┌────────────────────────────────┐ │
│ │      ✓  ZATWIERDŹ SERIĘ 2      │ │  64 dp, kolor akcentu
│ └────────────────────────────────┘ │
└────────────────────────────────────┘
```

W implementacji pasek przerwy („Przerwa 1:45 [−15] [+15] [Pomiń]”) jest na górze strefy kciuka, nad stepperami. Strefa kciuka jest przyklejona do dołu ekranu, więc pojawienie się timera zmniejsza tabelę serii, a przycisk „Zatwierdź” zostaje w tym samym miejscu.

```
```

## Budżet tapnięć

Sprawdzany testami widżetów w Etapach 4 i 5.

| Akcja | Ścieżka | Tapnięcia (limit) |
| --- | --- | --- |
| Seria zgodna z podpowiedzią | ✓ | 1 (1) |
| Ciężar o jeden krok | + → ✓ | 2 (≤ 2) |
| Inne powtórzenia | pole powt. → wybór liczby z siatki → ✓ | 3 (≤ 3) |
| Start → pierwsza seria | „Rozpocznij: Push A” na Starcie → ✓ (od Etapu 5); wcześniej zakładka Szablony → ▶ → ✓ | 2 (≤ 3) |

Przy pierwszym w ogóle treningu dochodzą jednorazowe okna zgód: systemowa zgoda na powiadomienia i prośba o dokładne alarmy. Nie wliczają się do budżetu, bo pojawiają się tylko raz.

## Zachowanie

- Tap w wiersz wybiera serię, a steppery działają na wybraną serię.
- Pole powtórzeń otwiera siatkę liczb wokół podpowiedzi oraz klawiaturę jako awaryjną drogę.
- Po ostatniej serii ćwiczenia wyróżniam „Następne ćwiczenie ▶” zamiast samoczynnie przewijać.
- Podpowiedzi są wizualnie odróżnione od wpisanych wartości i mają etykietę dla czytnika ekranu („podpowiedź: 80 kg”).
- Seria nigdy nie jest oznaczana jako wykonana automatycznie.
- Główny przycisk zależy od wybranej serii: „Zatwierdź serię N”, „Cofnij serię N” (seria już zatwierdzona, przycisk obrysowany), „Następne ćwiczenie” albo „Zakończ trening”, gdy wszystkie serie są zatwierdzone.
- Kółko w wierszu też zatwierdza serię albo cofa zatwierdzenie. Przytrzymanie wiersza otwiera usunięcie serii.
- Po zatwierdzeniu kolejne tapnięcie w ciągu 350 ms jest ignorowane, żeby przypadkowe podwójne tapnięcie nie zatwierdziło dwóch serii.
- Gdy brakuje wartości i podpowiedzi (np. pierwsze wykonanie bez planu), „Zatwierdź” otwiera wpis brakującego pola („Uzupełnij: Ciężar”) zamiast komunikatu, który zasłaniałby strefę kciuka.
- Każda zmiana zapisuje się od razu. Minimalizacja (⌄ albo przycisk wstecz) zostawia trening aktywnym; wraca się do niego paskiem nad nawigacją albo banerem na Starcie, także po ponownym uruchomieniu aplikacji.
- Ekran nie gaśnie tylko na ekranie treningu i tylko przy włączonym ustawieniu.
- Porzucenie i usunięcie ćwiczenia wymagają potwierdzenia. Zamiana ćwiczenia z zatwierdzonymi seriami też, bo czyści ich wartości.

## Historia i progres (Etap 5)

- Szczegóły treningu są pełnoekranową trasą `/sessions/:id`, a nie trasą w zakładce Historia, bo otwiera się je także ze Startu i z ekranu ćwiczenia. Push do trasy innej zakładki przełączałby zakładkę.
- Edycja zakończonego treningu działa na kopii: „Zapisz” zapisuje, ✕ i przycisk wstecz pytają o odrzucenie zmian. Stuknięcie serii w trybie edycji otwiera arkusz: wartości, wysiłek, „Seria zatwierdzona” i „Usuń serię”. „Dodaj serię” dopisuje zatwierdzoną serię z wartościami ostatniej.
- Ekran ćwiczenia ma zakładki Info, Historia, Rekordy i Wykresy. Zakładki historii dostarcza funkcja „historia”, a łączy je router (`exerciseProgressTabs()`), bo ekran ćwiczeń nie może importować ekranów innej funkcji.
- Wykresy mają jedną serię i nie mają legendy; tytuł nad wykresem mówi, co pokazuje. Linia ma 2 dp, kropki 8 dp z obwódką w kolorze tła, a słupki najwyżej 24 dp z zaokrąglonym końcem. Kolor serii to akcent volt w ciemnym motywie i ciemniejszy akcent w jasnym (kontrast ≥ 3:1). Dotknięcie pokazuje wartość w dymku, a czytnik ekranu dostaje opis z liczbą punktów i ostatnią wartością. Tabelę wartości zastępuje zakładka Historia.
- Start: „Rozpocznij: <ostatni szablon>” (ostatnio użyty, a gdy żadnego nie użyto, pierwszy alfabetycznie), do trzech innych szablonów, pusty trening, liczba treningów w tym tygodniu i ostatni trening.

## Analiza progresu (po wydaniu 1.0.0)

- Zakładka Progres zaczyna się od przełącznika okresu: 4 tygodnie, 3 miesiące, rok, całość. Okres obejmuje dziś i liczy się wstecz; wybór dotyczy całej zakładki.
- „Podsumowanie”: cztery kafelki (treningi, serie, objętość, czas). Pod wartością jest zmiana względem poprzedniego okresu tej samej długości, ze strzałką i znakiem, więc nie zależy tylko od koloru. Liczby (treningi, serie) mają różnicę, a objętość i czas procent; bez danych w poprzednim okresie procentu nie ma. Dla całej historii zmian nie ma, bo nie ma z czym porównać.
- „Serie na partię mięśniową”: średnia tygodniowa zatwierdzonych serii roboczych w okresie, jako poziome paski od największej. Opis nad listą mówi, jak liczymy (1 dla mięśni głównych, 0,5 dla pomocniczych). Czytnik ekranu dostaje jeden opis na wiersz.
- „Ćwiczenie”: wybór z ćwiczeń z historii (od ostatnio wykonanego), potem kafelki (najlepszy wynik, zmiana w okresie, najlepsza seria, liczba treningów) i wykres miary. Miara zależy od ćwiczenia: szacowany 1RM dla ciężaru, najwięcej powtórzeń dla masy ciała i wspomagania, najdłuższy czas dla ćwiczeń na czas. Wykres objętości jest tylko przy 1RM.
- Zakładka „Wykresy” ekranu ćwiczenia pokazuje tę samą sekcję dla całej historii.
- Kafelki w rzędzie mają równą wysokość, także gdy etykieta zawija się na dwie linie albo jeden kafelek ma zmianę, a drugi nie.

## Słowniczek i ikonki ⓘ

- Słowniczek (`/glossary`) zbiera podstawowe pojęcia w czterech grupach: podstawy (powtórzenie, seria, rozgrzewka, seria robocza, mięśnie główne i pomocnicze, tryb obciążenia), wysiłek (RIR, RPE), wyniki i rekordy (1RM, szacowany 1RM, objętość, rekord, najlepsza seria), progres (serie na partię, zmiana w okresie, progresja). Wszystkie opisy są widoczne od razu, bez rozwijania, żeby dało się je przeczytać jak krótki poradnik.
- Wejścia: Ustawienia → Pomoc → „Słowniczek pojęć”, link „Co znaczą te liczby?” na końcu zakładki Progres i przycisk „Wszystkie pojęcia” w arkuszu ⓘ.
- Ikonka ⓘ stoi tuż za nazwą pojęcia i otwiera arkusz z opisem (nad dolną nawigacją). Jest przy:
  - skali wysiłku w ustawieniach (RIR i RPE);
  - „Serie na partię mięśniową”, wykresach szacowanego 1RM (z 1RM) i objętości w Progresie i na ekranie ćwiczenia;
  - „Najcięższa seria dla N powt.” w rekordach;
  - „Mięśnie główne” i na końcu wiersza „Obciążenie” na ekranie ćwiczenia.
- Ikonka ma pełny cel dotyku 48 dp i podpowiedź „Co to jest: <pojęcie>?”, którą czyta czytnik ekranu.
- Ikonki nie ma na ekranie aktywnego treningu: tam liczy się miejsce, a RIR/RPE opisuje ustawienie skali wysiłku.

