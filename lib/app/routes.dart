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

  /// Wybór jednego ćwiczenia (zamiana w treningu); zwraca listę z jednym id.
  static const exercisePickerSingle = '/pick-exercises?single=true';
  static const settings = '/settings';
  static const licenses = '/settings/licenses';
  static const workout = '/workout';
  static const workoutFinish = '/workout/finish';

  static String templateEdit(String id) => '/templates/$id';

  static String exerciseDetail(String id) => '/exercises/$id';

  static String exerciseEdit(String id) => '/exercises/$id/edit';

  /// Zakończony trening (pełny ekran, z historii, Startu i ekranu ćwiczenia).
  static String sessionDetail(String id) => '/sessions/$id';

  static String sessionCompare(String id) => '/sessions/$id/compare';
}
