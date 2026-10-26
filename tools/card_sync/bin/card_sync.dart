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
    ..addOption('parallel', defaultsTo: '6', help: 'Gleichzeitige Bild-Downloads')
    ..addOption('image-minutes', defaultsTo: '0', help: 'Zeitbudget für Bilder in Minuten (0 = unbegrenzt)')
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

    // Kartenliste zuerst sichern: bricht der Bild-Download ab, bleibt der
    // Stand erhalten (Cache) und der nächste Lauf lädt nur fehlende Bilder.
    final listChanged = merged.added > 0 || merged.changed > 0 || existing.isEmpty;
    if (listChanged) store.writeCards(merged.cards, now: DateTime.now());

    var images = 0;
    var imageErrors = 0;
    if (!(opts['no-images'] as bool)) {
      final imageMinRating = int.parse(opts['image-min-rating'] as String);
      final parallel = int.parse(opts['parallel'] as String);
      final budget = Duration(minutes: int.parse(opts['image-minutes'] as String));
      final todo = [
        for (final card in merged.cards)
          if (card.rating >= imageMinRating && !store.hasImage(card)) card,
      ];
      stdout.writeln('Bilder: ${todo.length} fehlen, lade mit $parallel parallel …');
      final started = DateTime.now();
      var next = 0;
      var done = 0;
      var consecutiveErrors = 0;
      var stop = false;
      Future<void> worker() async {
        while (!stop && next < todo.length) {
          final card = todo[next++];
          try {
            store.writeImage(card, await client.fetchImage(card.sourceImagePath));
            images++;
            consecutiveErrors = 0;
          } on Exception catch (e) {
            // Fehlende Bilder werden beim nächsten Lauf erneut versucht; die
            // App zeigt solange eine Ersatzkarte.
            imageErrors++;
            consecutiveErrors++;
            stderr.writeln('Bild fehlgeschlagen (${card.id}): $e');
            if (consecutiveErrors >= 50) {
              stderr.writeln('50 Fehler in Folge – Bild-Download abgebrochen.');
              stop = true;
            }
          }
          done++;
          if (done % 250 == 0 || done == todo.length) {
            final secs = DateTime.now().difference(started).inSeconds;
            stdout.writeln('  Bilder $done/${todo.length} · ${secs}s · Fehler $imageErrors');
          }
          if (budget > Duration.zero && DateTime.now().difference(started) > budget) {
            if (!stop) stdout.writeln('Zeitbudget erreicht – Rest beim nächsten Lauf.');
            stop = true;
          }
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      }

      await Future.wait([for (var i = 0; i < parallel; i++) worker()]);
      final removed = store.removeOrphanImages(merged.cards);
      stdout.writeln('Bilder: $images neu, $removed entfernt, $imageErrors Fehler');
    }

    if (listChanged || images > 0) {
      store.writeCards(merged.cards, now: DateTime.now());
      stdout.writeln('cards.json + meta.json geschrieben.');
    } else {
      stdout.writeln('Keine Änderungen.');
    }
  } finally {
    client.close();
  }
}
