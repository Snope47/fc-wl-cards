/// Eine Spielerkarte, so wie sie in `cards.json` gespeichert und von der App
/// gelesen wird. Bewusst schlank: nur was für Suche und Anzeige nötig ist.
class PlayerCard {
  const PlayerCard({
    required this.id,
    required this.basePlayerId,
    required this.name,
    required this.firstName,
    required this.lastName,
    required this.rating,
    required this.position,
    required this.altPositions,
    required this.version,
    required this.createdAt,
    required this.sourceImagePath,
  });

  /// EA-Item-ID der Karte (jede Version hat eine eigene).
  final int id;

  /// EA-ID des Spielers; gleich für alle Versionen desselben Spielers.
  final int basePlayerId;

  /// Anzeigename, z. B. "Kylian Mbappé".
  final String name;
  final String firstName;
  final String lastName;
  final int rating;
  final String position;
  final List<String> altPositions;

  /// Kartenversion, z. B. "Rare", "Destined for Glory", "Base Icon".
  final String version;
  final DateTime createdAt;

  /// Pfad des kompakten Kartenbilds bei der Quelle (enthält einen Hash, der
  /// sich ändert, wenn sich das Bild ändert).
  final String sourceImagePath;

  /// Dateiname des Bilds in unserem Speicher. Der Hash-Anteil sorgt dafür,
  /// dass die App ein geändertes Bild neu lädt.
  String get imageFile {
    final hash = RegExp(r'\.([0-9a-f]{8})').firstMatch(sourceImagePath)?.group(1);
    return hash == null ? '$id.webp' : '$id-$hash.webp';
  }

  factory PlayerCard.fromJson(Map<String, dynamic> j) => PlayerCard(
        id: j['id'] as int,
        basePlayerId: j['base'] as int,
        name: j['name'] as String,
        firstName: j['first'] as String,
        lastName: j['last'] as String,
        rating: j['rating'] as int,
        position: j['pos'] as String,
        altPositions: [for (final p in j['altPos'] as List) p as String],
        version: j['version'] as String,
        createdAt: DateTime.parse(j['created'] as String),
        sourceImagePath: j['src'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'base': basePlayerId,
        'name': name,
        'first': firstName,
        'last': lastName,
        'rating': rating,
        'pos': position,
        'altPos': altPositions,
        'version': version,
        'created': createdAt.toIso8601String(),
        'img': imageFile,
        'src': sourceImagePath,
      };
}
