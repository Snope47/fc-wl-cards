import 'package:cards_core/cards_core.dart';

/// Ergebnis eines Abgleichs zwischen vorhandenen und neu geholten Karten.
class MergeResult {
  MergeResult(this.cards, this.added, this.changed);

  /// Alle Karten, sortiert: neueste zuerst, dann nach Wertung.
  final List<PlayerCard> cards;
  final int added;
  final int changed;
}

/// Führt neu geholte Karten mit dem vorhandenen Bestand zusammen.
/// Neue Daten gewinnen; Karten, die nicht neu geholt wurden, bleiben erhalten.
MergeResult mergeCards(Iterable<PlayerCard> existing, Iterable<PlayerCard> fetched) {
  final byId = {for (final c in existing) c.id: c};
  var added = 0;
  var changed = 0;
  for (final c in fetched) {
    final old = byId[c.id];
    if (old == null) {
      added++;
    } else if (old.rating != c.rating ||
        old.sourceImagePath != c.sourceImagePath ||
        old.position != c.position ||
        old.version != c.version) {
      changed++;
    }
    byId[c.id] = c;
  }
  final cards = byId.values.toList()
    ..sort((a, b) {
      final byDate = b.createdAt.compareTo(a.createdAt);
      return byDate != 0 ? byDate : b.rating.compareTo(a.rating);
    });
  return MergeResult(cards, added, changed);
}

/// Beim täglichen Abruf (neueste zuerst) kann man aufhören, sobald eine
/// ganze Seite nur noch Karten enthält, die älter als der Stand sind.
/// Ein Puffer fängt Karten ab, die mit leicht verspätetem Datum eingetragen
/// werden.
bool isPageFullyKnown(Iterable<PlayerCard> page, DateTime? newestKnown, {Duration buffer = const Duration(days: 2)}) {
  if (newestKnown == null) return false;
  final cutoff = newestKnown.subtract(buffer);
  return page.every((c) => c.createdAt.isBefore(cutoff));
}
