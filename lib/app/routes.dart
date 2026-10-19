/// Ścieżki nawigacji (docs/ux.md, mapa ekranów).
abstract final class AppRoutes {
  static const home = '/';
  static const templates = '/templates';
  static const templateNew = '/templates/new';
  static const history = '/history';
  static const exercises = '/exercises';
  static const exerciseNew = '/exercises/new';

  /// Wybór ćwiczeń; zwraca listę identyfikatorów (`List<String>`).
  static const exercisePicker = '/pick-exercises';
  static const settings = '/settings';
  static const licenses = '/settings/licenses';
  static const workout = '/workout';

  static String templateEdit(String id) => '/templates/$id';

  static String exerciseDetail(String id) => '/exercises/$id';

  static String exerciseEdit(String id) => '/exercises/$id/edit';
}
