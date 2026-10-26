import 'dart:convert';
import 'dart:io';

import 'package:card_sync/card_sync.dart';
import 'package:test/test.dart';

PlayerCard card(
  int id, {
  int rating = 80,
  String created = '2026-10-01T00:00:00Z',
  String img = 'x/1.aaaaaaaa11.webp',
}) => PlayerCard(
  id: id,
  basePlayerId: id,
  name: 'Spieler $id',
  firstName: 'Vor',
  lastName: 'Nach',
  rating: rating,
  position: 'ST',
  altPositions: const [],
  version: 'Rare',
  createdAt: DateTime.parse(created),
  sourceImagePath: img,
);

void main() {
  group('fut.gg-Seite parsen', () {
    final json = jsonDecode(File('test/fixtures/futgg_page.json').readAsStringSync()) as Map<String, dynamic>;

    test('liest alle Karten mit Pflichtfeldern', () {
      final page = FutggClient.parsePage(json);
      expect(page.cards, hasLength(4));
      expect(page.hasNext, isTrue);
      expect(page.skipped, 0);
    });

    test('Spezialkarte: Version, Positionen, Basis-ID', () {
      final dfg = FutggClient.parsePage(json).cards[3];
      expect(dfg.id, 50563395);
      expect(dfg.basePlayerId, 231747);
      expect(dfg.name, 'Kylian Mbappé');
      expect(dfg.rating, 91);
      expect(dfg.position, 'ST');
      expect(dfg.altPositions, ['LW']);
      expect(dfg.version, 'Destined for Glory');
      expect(dfg.imageFile, '50563395-e43a4741.webp');
    });

    test('überspringt Einträge ohne Pflichtfelder', () {
      final page = FutggClient.parsePage({
        'data': [
          {'eaId': 1, 'overall': 80},
          ...json['data'] as List,
        ],
        'next': null,
      });
      expect(page.cards, hasLength(4));
      expect(page.skipped, 1);
      expect(page.hasNext, isFalse);
    });
  });

  group('mergeCards', () {
    test('zählt neue und geänderte Karten, neue Daten gewinnen', () {
      final result = mergeCards([card(1, rating: 80), card(2)], [card(1, rating: 82), card(2), card(3)]);
      expect(result.added, 1);
      expect(result.changed, 1);
      expect(result.cards.firstWhere((c) => c.id == 1).rating, 82);
      expect(result.cards, hasLength(3));
    });

    test('behält Karten, die nicht erneut geholt wurden', () {
      final result = mergeCards([card(1), card(2)], [card(3)]);
      expect(result.cards.map((c) => c.id), containsAll([1, 2, 3]));
    });

    test('sortiert neueste zuerst, dann nach Wertung', () {
      final result = mergeCards([], [
        card(1, rating: 85, created: '2026-10-01T00:00:00Z'),
        card(2, rating: 90, created: '2026-10-01T00:00:00Z'),
        card(3, rating: 70, created: '2026-10-05T00:00:00Z'),
      ]);
      expect(result.cards.map((c) => c.id), [3, 2, 1]);
    });
  });

  group('isPageFullyKnown', () {
    final known = DateTime.parse('2026-10-10T00:00:00Z');

    test('ohne Bestand nie bekannt', () {
      expect(isPageFullyKnown([card(1)], null), isFalse);
    });

    test('nur alte Karten (vor Puffer) → bekannt', () {
      expect(isPageFullyKnown([card(1, created: '2026-10-07T00:00:00Z')], known), isTrue);
    });

    test('Karte innerhalb des Puffers → weiterblättern', () {
      expect(
        isPageFullyKnown([card(1, created: '2026-10-07T00:00:00Z'), card(2, created: '2026-10-09T00:00:00Z')], known),
        isFalse,
      );
    });
  });

  test('CardStore schreibt, liest und räumt verwaiste Bilder auf', () {
    final dir = Directory.systemTemp.createTempSync('card_store_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = CardStore(dir);
    final a = card(1, img: 'p/1.aaaaaaaa.webp');
    final b = card(2, img: 'p/2.bbbbbbbb.webp');

    store.writeCards([a, b], now: DateTime.utc(2026, 10, 22));
    store.writeImage(a, [1, 2, 3]);
    store.writeImage(b, [4, 5, 6]);
    expect(store.readCards().map((c) => c.id), [1, 2]);
    expect(store.hasImage(a), isTrue);

    final meta = jsonDecode(File('${dir.path}/meta.json').readAsStringSync()) as Map<String, dynamic>;
    expect(meta['count'], 2);
    expect(meta['version'], '2026-10-22T00:00:00.000Z');

    expect(store.removeOrphanImages([a]), 1);
    expect(store.hasImage(b), isFalse);
  });
}
