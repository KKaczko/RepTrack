import 'app_settings.dart';

abstract interface class SettingsRepository {
  /// Ustawienia; brakujące klucze przyjmują wartości domyślne.
  Stream<AppSettings> watch();

  Future<AppSettings> load();

  Future<void> save(AppSettings settings);
}
