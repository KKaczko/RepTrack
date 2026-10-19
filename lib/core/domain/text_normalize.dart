const _diacritics = <String, String>{
  'ą': 'a', 'ć': 'c', 'ę': 'e', 'ł': 'l', 'ń': 'n', 'ó': 'o', 'ś': 's', //
  'ź': 'z', 'ż': 'z', 'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', //
  'å': 'a', 'č': 'c', 'ç': 'c', 'ď': 'd', 'é': 'e', 'è': 'e', 'ê': 'e', //
  'ë': 'e', 'ě': 'e', 'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', 'ň': 'n', //
  'ñ': 'n', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', 'ø': 'o', 'ř': 'r', //
  'š': 's', 'ß': 'ss', 'ť': 't', 'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', //
  'ů': 'u', 'ý': 'y', 'ÿ': 'y', 'ž': 'z',
};

final _nonWord = RegExp(r'[^a-z0-9]+');

/// Normalizuje tekst do wyszukiwania: małe litery, bez polskich i innych
/// znaków diakrytycznych, znaki niealfanumeryczne zamienione na spacje.
///
/// Dzięki temu fraza „lawka” znajduje „Ławka”, a „wyciskanie-sztangi”
/// znajduje „Wyciskanie sztangi”.
String normalizeForSearch(String text) {
  final lower = text.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_diacritics[char] ?? char);
  }
  return buffer.toString().replaceAll(_nonWord, ' ').trim();
}

/// Czy znormalizowany [haystack] zawiera wszystkie słowa zapytania [query],
/// w dowolnej kolejności.
bool matchesSearch(String haystack, String query) {
  final terms = normalizeForSearch(query).split(' ').where((t) => t.isNotEmpty);
  return terms.every(haystack.contains);
}
