import 'dart:convert';
import 'dart:io';

import 'package:cards_core/cards_core.dart';

/// Ausgabeverzeichnis, das 1:1 veröffentlicht wird:
///
///   meta.json   – klein; die App prüft nur diese Datei täglich
///   cards.json  – alle Karten
///   `img/<id>-<hash>.webp`
class CardStore {
  CardStore(this.dir);

  final Directory dir;

  File get _cardsFile => File('${dir.path}/cards.json');
  File get _metaFile => File('${dir.path}/meta.json');
  Directory get imageDir => Directory('${dir.path}/img');

  List<PlayerCard> readCards() {
    if (!_cardsFile.existsSync()) return [];
    final json = jsonDecode(_cardsFile.readAsStringSync()) as Map<String, dynamic>;
    return [for (final c in json['cards'] as List) PlayerCard.fromJson(c as Map<String, dynamic>)];
  }

  void writeCards(List<PlayerCard> cards, {required DateTime now}) {
    dir.createSync(recursive: true);
    final version = now.toUtc().toIso8601String();
    _cardsFile.writeAsStringSync(
      jsonEncode({
        'schema': 1,
        'version': version,
        'cards': [for (final c in cards) c.toJson()],
      }),
    );
    _metaFile.writeAsStringSync(jsonEncode({'schema': 1, 'version': version, 'count': cards.length}));
  }

  bool hasImage(PlayerCard card) => File('${imageDir.path}/${card.imageFile}').existsSync();

  void writeImage(PlayerCard card, List<int> bytes) {
    imageDir.createSync(recursive: true);
    File('${imageDir.path}/${card.imageFile}').writeAsBytesSync(bytes);
  }

  /// Löscht Bilder, die zu keiner Karte mehr gehören (z. B. alte Hash-Stände).
  int removeOrphanImages(Iterable<PlayerCard> cards) {
    if (!imageDir.existsSync()) return 0;
    final wanted = {for (final c in cards) c.imageFile};
    var removed = 0;
    for (final f in imageDir.listSync().whereType<File>()) {
      if (!wanted.contains(f.uri.pathSegments.last)) {
        f.deleteSync();
        removed++;
      }
    }
    return removed;
  }
}
