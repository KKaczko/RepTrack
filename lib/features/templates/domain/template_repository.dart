import 'template.dart';

abstract interface class TemplateRepository {
  /// Szablony z ćwiczeniami i seriami, posortowane po nazwie, bez usuniętych.
  Stream<List<Template>> watchAll({bool includeArchived = false});

  Future<Template?> findById(String id);

  /// Zapisuje cały szablon w jednej transakcji. Ćwiczenia i serie, których
  /// nie ma już w [template], są miękko usuwane.
  Future<void> save(Template template);

  Future<void> setArchived(String id, {required bool archived});

  Future<void> delete(String id);
}
