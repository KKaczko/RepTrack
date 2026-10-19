# ADR 0004: Dziedziczenie serii i liczba serii

- Status: zaakceptowana (2026-10-19)
- Odwracalność: trudna ⚠ (schemat danych)

## Kontekst

Specyfikacja (sekcja 4) przewiduje pole „liczba serii” w `TemplateExercise` oraz wiersze `TemplateSet` z nadpisaniami, gdzie `null` oznacza dziedziczenie. Zapis „3 × 8–12” to trzy serie bez nadpisań. Przechowywanie licznika obok wierszy tworzy dwa źródła prawdy, które mogą się rozjechać.

## Decyzja

- Liczba serii jest **wyliczana** z liczby wierszy `template_sets`. Kolumny licznika nie ma. To odstępstwo od tabeli w sekcji 4 specyfikacji.
- Każda seria szablonu ma wiersz `template_sets`, także bez nadpisań (wszystkie pola NULL).
- Nadpisywalne pola: `set_type`, `target_min` + `target_max` (zawsze razem), `target_weight_g`, `rest_seconds`.
- Efektywny plan liczy jedna czysta funkcja `resolveEffectiveSets`. Zmiana liczby serii dodaje wiersze z samymi NULL-ami albo usuwa ostatnie. „Przywróć dziedziczenie” ustawia pole na NULL.

## Konsekwencje

- Brak niespójności licznika i wierszy.
- Znane ograniczenie: nie da się nadpisać wartością „brak” (np. seria bez docelowego ciężaru, gdy ćwiczenie ma cel). Jeśli okaże się potrzebne, dojdą flagi nadpisań w osobnej migracji.

## Implementacja w UI (Etap 3)

- W edytorze serii puste pole celu oznacza wartość wspólną. Wpisanie tylko „Do 10” przy wspólnym 8–12 zapisuje nadpisanie 8–10. Oba pola puste usuwają nadpisanie celu.
- Typ serii i przerwa mają opcję „Wspólne”, która zapisuje NULL.
- „Przywróć dziedziczenie” czyści wszystkie nadpisania serii.

