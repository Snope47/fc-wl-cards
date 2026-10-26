import 'card.dart';

const _replacements = {
  'ß': 'ss', 'æ': 'ae', 'œ': 'oe', 'ø': 'o', 'ł': 'l', 'đ': 'd', 'ð': 'd', 'þ': 'th', 'ı': 'i', //
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a', 'ă': 'a', 'ą': 'a',
  'ç': 'c', 'ć': 'c', 'č': 'c', 'ĉ': 'c', 'ċ': 'c',
  'ď': 'd',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ė': 'e', 'ę': 'e', 'ě': 'e',
  'ğ': 'g', 'ģ': 'g',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i', 'į': 'i', 'İ': 'i',
  'ķ': 'k',
  'ĺ': 'l', 'ļ': 'l', 'ľ': 'l',
  'ñ': 'n', 'ń': 'n', 'ņ': 'n', 'ň': 'n',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ō': 'o', 'ő': 'o',
  'ŕ': 'r', 'ř': 'r',
  'ś': 's', 'ş': 's', 'ș': 's', 'š': 's',
  'ţ': 't', 'ț': 't', 'ť': 't',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u', 'ů': 'u', 'ű': 'u', 'ų': 'u',
  'ý': 'y', 'ÿ': 'y',
  'ź': 'z', 'ż': 'z', 'ž': 'z',
};

/// Vereinheitlicht Text für die Suche: Kleinbuchstaben, ohne Akzente,
/// Satzzeichen werden zu Leerzeichen. "Mbappé" → "mbappe", "Ødegaard" → "odegaard".
String normalizeForSearch(String input) {
  final buf = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    final ch = String.fromCharCode(rune);
    final mapped = _replacements[ch] ?? ch;
    buf.write(RegExp(r'[a-z0-9 ]').hasMatch(mapped) ? mapped : ' ');
  }
  return buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Zerlegt eine Sucheingabe in normalisierte Wörter.
List<String> searchTokens(String query) =>
    normalizeForSearch(query).split(' ').where((t) => t.isNotEmpty).toList();

/// Text, in dem die App sucht: alle Namensteile, Version und Positionen.
/// So findet "mbappe" alle Versionen und "mbappe dfg"/"mbappe destined" gezielt eine.
String cardSearchText(PlayerCard c) => normalizeForSearch([
      c.name,
      c.firstName,
      c.lastName,
      c.version,
      _initials(c.version),
      c.position,
      ...c.altPositions,
    ].join(' '));

/// "Destined for Glory" → "dfg", "Team of the Week" → "totw".
String _initials(String version) {
  final words = normalizeForSearch(version).split(' ').where((w) => w.isNotEmpty).toList();
  return words.length < 2 ? '' : words.map((w) => w[0]).join();
}
