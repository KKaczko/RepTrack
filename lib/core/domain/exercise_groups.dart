/// Superserie (ADR 0018): co najmniej dwa ćwiczenia stojące obok siebie
/// z tym samym `groupId`. Funkcje działają na liście `groupId` w kolejności
/// ćwiczeń, więc obsługują szablony i treningi tak samo.
library;

/// Grupy w kolejności ćwiczeń: listy indeksów kolejnych ćwiczeń z tym
/// samym `groupId`, każda z co najmniej dwoma ćwiczeniami.
List<List<int>> exerciseGroups(List<String?> groupIds) {
  final groups = <List<int>>[];
  var start = 0;
  while (start < groupIds.length) {
    final id = groupIds[start];
    var end = start + 1;
    while (end < groupIds.length && id != null && groupIds[end] == id) {
      end++;
    }
    if (id != null && end - start >= 2) {
      groups.add([for (var i = start; i < end; i++) i]);
    }
    start = end;
  }
  return groups;
}

/// Porządkuje grupy po zmianie kolejności albo usunięciu: grupa to ciągły
/// odcinek. Ćwiczenie samo w grupie traci `groupId`. Gdy ten sam `groupId`
/// występuje w kilku odcinkach, zostaje przy pierwszym, a dalsze dostają
/// nowy z [newId] (bez [newId] tracą grupę).
List<String?> normalizeGroupIds(
  List<String?> groupIds, {
  String Function()? newId,
}) {
  final result = List<String?>.filled(groupIds.length, null);
  final seen = <String>{};
  var start = 0;
  while (start < groupIds.length) {
    final id = groupIds[start];
    var end = start + 1;
    while (end < groupIds.length && id != null && groupIds[end] == id) {
      end++;
    }
    if (id != null && end - start >= 2) {
      final kept = seen.add(id) ? id : newId?.call();
      for (var i = start; i < end; i++) {
        result[i] = kept;
      }
    }
    start = end;
  }
  return result;
}

/// Łączy ćwiczenie [index] z następnym w superserię. Następne dołącza do
/// grupy bieżącego; gdy samo jest w grupie, obie grupy się łączą.
List<String?> linkWithNext(
  List<String?> groupIds,
  int index,
  String Function() newId,
) {
  if (index < 0 || index >= groupIds.length - 1) return groupIds;
  final result = [...groupIds];
  final current = result[index];
  final next = result[index + 1];
  final target = current ?? next ?? newId();
  result[index] = target;
  if (next == null) {
    result[index + 1] = target;
  } else if (next != target) {
    for (var i = index + 1; i < result.length && result[i] == next; i++) {
      result[i] = target;
    }
  }
  return normalizeGroupIds(result, newId: newId);
}

/// Odłącza ćwiczenie [index] od superserii. Reszta grupy zostaje razem,
/// a gdy odłączenie dzieli ją na dwa odcinki, drugi dostaje nowy `groupId`.
List<String?> unlinkAt(
  List<String?> groupIds,
  int index,
  String Function() newId,
) {
  if (index < 0 || index >= groupIds.length) return groupIds;
  final result = [...groupIds]..[index] = null;
  return normalizeGroupIds(result, newId: newId);
}

/// Oznaczenie ćwiczenia w superserii: litera grupy (A, B…) i numer
/// w grupie (1, 2…).
typedef GroupLabel = ({String letter, int number, int size});

/// Oznaczenia ćwiczeń w kolejności; null dla ćwiczeń poza superserią.
List<GroupLabel?> groupLabels(List<String?> groupIds) {
  final labels = List<GroupLabel?>.filled(groupIds.length, null);
  for (final (g, group) in exerciseGroups(groupIds).indexed) {
    final letter = String.fromCharCode(0x41 + g % 26);
    for (final (n, index) in group.indexed) {
      labels[index] = (letter: letter, number: n + 1, size: group.length);
    }
  }
  return labels;
}
