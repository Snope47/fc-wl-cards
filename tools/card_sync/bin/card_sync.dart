import 'dart:io';
import 'dart:math' as math;

import 'package:args/args.dart';
import 'package:card_sync/card_sync.dart';

/// Täglicher Kartenabruf.
///
///   dart run bin/card_sync.dart --out out          # nur neue Karten
///   dart run bin/card_sync.dart --out out --full   # kompletter Abgleich ab Mindestwertung
Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('out', defaultsTo: 'out', help: 'Ausgabeverzeichnis')
    ..addFlag('full', help: 'Alle Karten ab --min-rating neu abgleichen (z. B. wöchentlich)')
    ..addOption('min-rating', defaultsTo: '0', help: 'Mindestwertung beim kompletten Abgleich')
    ..addOption(
      'image-min-rating',
      defaultsTo: '65',
      help: 'Bilder nur für Karten ab dieser Wertung speichern (darunter zeigt die App eine Ersatzkarte)',
    )
    ..addOption('max-pages', defaultsTo: '400', help: 'Sicherheitsgrenze für Seiten pro Lauf')
    ..addOption('delay-ms', defaultsTo: '1500', help: 'Pause zwischen API-Anfragen')
    ..addFlag('no-images', help: 'Keine Bilder laden (zum Testen)')
    ..addFlag('help', abbr: 'h', negatable: false);
  final opts = parser.parse(args);
  if (opts['help'] as bool) {
    stdout.writeln(parser.usage);
    return;
  }

  final store = CardStore(Directory(opts['out'] as String));
  final client = FutggClient(requestDelay: Duration(milliseconds: int.parse(opts['delay-ms'] as String)));
  final maxPages = int.parse(opts['max-pages'] as String);

  try {
    final existing = store.readCards();
    final full = (opts['full'] as bool) || existing.isEmpty;
    final newestKnown = existing.isEmpty
        ? null
        : existing.map((c) => c.createdAt).reduce((a, b) => a.isAfter(b) ? a : b);

    // Täglich: alle neuen Karten unabhängig von der Wertung (Spezialkarten
    // können auch niedrig sein). Komplett: alles ab Mindestwertung, in
    // Wertungsbändern, weil die Quelle höchstens 10.000 Treffer je Abfrage liefert.
    final minRating = int.parse(opts['min-rating'] as String);
    stdout.writeln(
      full ? 'Kompletter Abgleich ab Wertung $minRating …' : 'Neue Karten seit ${newestKnown!.toIso8601String()} …',
    );

    final fetched = <PlayerCard>[];
    var skipped = 0;
    final List<(int?, int?)> bands = full
        ? [
            for (final (lo, hi) in const [(75, null), (65, 74), (0, 64)])
              if ((hi ?? 99) >= minRating) (math.max(lo, minRating), hi),
          ]
        : const [(null, null)];
    for (final (lo, hi) in bands) {
      for (var page = 1; page <= maxPages; page++) {
        final result = await client.fetchPage(page, minRating: lo, maxRating: hi);
        fetched.addAll(result.cards);
        skipped += result.skipped;
        if (!result.hasNext) break;
        if (!full && isPageFullyKnown(result.cards, newestKnown)) break;
        if (page == maxPages) stderr.writeln('Warnung: Seitengrenze $maxPages erreicht.');
      }
    }

    final merged = mergeCards(existing, fetched);
    stdout.writeln(
      'Geholt: ${fetched.length} (übersprungen: $skipped) · neu: ${merged.added} · '
      'geändert: ${merged.changed} · gesamt: ${merged.cards.length}',
    );

    var images = 0;
    var imageErrors = 0;
    if (!(opts['no-images'] as bool)) {
      final imageMinRating = int.parse(opts['image-min-rating'] as String);
      for (final card in merged.cards) {
        if (card.rating < imageMinRating || store.hasImage(card)) continue;
        try {
          store.writeImage(card, await client.fetchImage(card.sourceImagePath));
          images++;
          await Future<void>.delayed(const Duration(milliseconds: 150));
        } on Exception catch (e) {
          // Fehlende Bilder werden beim nächsten Lauf erneut versucht; die
          // App zeigt solange eine Ersatzkarte.
          imageErrors++;
          stderr.writeln('Bild fehlgeschlagen (${card.id}): $e');
        }
      }
      final removed = store.removeOrphanImages(merged.cards);
      stdout.writeln('Bilder: $images neu, $removed entfernt, $imageErrors Fehler');
    }

    if (merged.added > 0 || merged.changed > 0 || images > 0 || existing.isEmpty) {
      store.writeCards(merged.cards, now: DateTime.now());
      stdout.writeln('cards.json + meta.json geschrieben.');
    } else {
      stdout.writeln('Keine Änderungen.');
    }
  } finally {
    client.close();
  }
}
