# UX: mapa ekranów i aktywny trening

Status: Etap 0 (plan), zatwierdzony 2026-10-19. Kierunek wizualny: [ADR 0012](decisions/0012-wyglad.md).

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
│ ┌────────────────────────────────┐ │
│ │      ✓  ZATWIERDŹ SERIĘ 2      │ │  64 dp, kolor akcentu
│ └────────────────────────────────┘ │
│ Przerwa 1:45   [−15] [+15] [Pomiń] │  pasek timera po zatwierdzeniu
└────────────────────────────────────┘
```

## Budżet tapnięć

Sprawdzany testami widżetów w Etapach 4 i 5.

| Akcja | Ścieżka | Tapnięcia (limit) |
| --- | --- | --- |
| Seria zgodna z podpowiedzią | ✓ | 1 (1) |
| Ciężar o jeden krok | + → ✓ | 2 (≤ 2) |
| Inne powtórzenia | pole powt. → wybór liczby z siatki → ✓ | 3 (≤ 3) |
| Start → pierwsza seria | „Rozpocznij: Push A” → ✓ | 2 (≤ 3) |

## Zachowanie

- Tap w wiersz wybiera serię, a steppery działają na wybraną serię.
- Pole powtórzeń otwiera siatkę liczb wokół podpowiedzi oraz klawiaturę jako awaryjną drogę.
- Po ostatniej serii ćwiczenia wyróżniam „Następne ćwiczenie ▶” zamiast samoczynnie przewijać.
- Podpowiedzi są wizualnie odróżnione od wpisanych wartości i mają etykietę dla czytnika ekranu („podpowiedź: 80 kg”).
- Seria nigdy nie jest oznaczana jako wykonana automatycznie.
