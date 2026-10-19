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
│    Sesje → /history/:id szczegóły + tryb edycji → /history/:id/compare
│    Progres → treningi/tydzień, wybór ćwiczenia → wykresy e1RM i objętości
└─ Ćwiczenia /exercises       szukaj + filtry → /exercises/:id [Info | Historia | Rekordy | Wykresy]
                              → /exercises/:id/edit, /exercises/new

Poza shellem (pełny ekran):
  /workout                    aktywny trening (arkusze: wybór ćwiczenia, kolejność, zamiana)
  /workout/finish             podsumowanie, notatka, samopoczucie, diff „zaktualizuj szablon”
  /settings → /settings/backup (backup, przywracanie, CSV, MD) · /settings/licenses
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
| Start → pierwsza seria | zakładka Szablony → ▶ na kafelku → ✓ (Etap 4); „Rozpocznij: Push A” na Starcie → ✓ (Etap 5) | 3 (≤ 3), potem 2 |

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
