import 'dart:convert';

import 'package:cards_core/cards_core.dart';
import 'package:test/test.dart';

PlayerCard mbappeDfg() => PlayerCard(
      id: 50563395,
      basePlayerId: 231747,
      name: 'Kylian Mbappé',
      firstName: 'Kylian',
      lastName: 'Mbappé',
      rating: 91,
      position: 'ST',
      altPositions: const ['LW'],
      version: 'Destined for Glory',
      createdAt: DateTime.utc(2026, 9, 25),
      sourceImagePath: '2027/player-item-simple-card/27-50563395.e43a47410a46def0.webp',
    );

void main() {
  test('JSON-Rundreise erhält alle Felder', () {
    final c = mbappeDfg();
    final back = PlayerCard.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
    expect(back.toJson(), c.toJson());
  });

  test('imageFile enthält ID und Hash-Anfang', () {
    expect(mbappeDfg().imageFile, '50563395-e43a4741.webp');
  });

  group('normalizeForSearch', () {
    test('entfernt Akzente und Großschreibung', () {
      expect(normalizeForSearch('Kylian Mbappé'), 'kylian mbappe');
      expect(normalizeForSearch('Martin Ødegaard'), 'martin odegaard');
      expect(normalizeForSearch('Hakan Çalhanoğlu'), 'hakan calhanoglu');
      expect(normalizeForSearch('Bartłomiej Gradecki'), 'bartlomiej gradecki');
      expect(normalizeForSearch('Narcis Ilaș'), 'narcis ilas');
      expect(normalizeForSearch('Müller'), 'muller');
    });

    test('Satzzeichen werden zu Leerzeichen', () {
      expect(normalizeForSearch("N'Golo  Kanté"), 'n golo kante');
      expect(normalizeForSearch('Alexander-Arnold'), 'alexander arnold');
    });
  });

  test('searchTokens zerlegt die Eingabe', () {
    expect(searchTokens('  Mbappé   DFG '), ['mbappe', 'dfg']);
    expect(searchTokens(''), isEmpty);
  });

  test('cardSearchText enthält Namen, Version, Kürzel und Positionen', () {
    final text = cardSearchText(mbappeDfg());
    for (final t in ['kylian', 'mbappe', 'destined for glory', 'dfg', 'st', 'lw']) {
      expect(text, contains(t));
    }
  });
}
