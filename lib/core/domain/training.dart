/// Typy wspólne dla szablonów i sesji. Nazwy wartości są stabilnymi kodami
/// zapisywanymi w bazie i backupie, więc nie wolno ich zmieniać.
library;

/// Typ serii. Serie rozgrzewkowe są wykluczone z objętości i rekordów.
enum SetType { warmup, working, drop, amrap }

/// Rodzaj celu serii: zakres powtórzeń albo czasu (w sekundach).
enum TargetKind { reps, duration }

/// Skala wysiłku zapisywana przy serii.
enum EffortScale { rir, rpe }
