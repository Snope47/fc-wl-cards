import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cards_core/cards_core.dart';
import 'package:http/http.dart' as http;

class CardPage {
  CardPage(this.cards, {required this.hasNext, required this.skipped});
  final List<PlayerCard> cards;
  final bool hasNext;

  /// Einträge, die wegen fehlender Pflichtfelder übersprungen wurden.
  final int skipped;
}

/// Minimaler Client für die Kartendaten von fut.gg. Höflich: feste Pause
/// zwischen Anfragen und Rückzug bei 429/5xx.
class FutggClient {
  FutggClient({
    http.Client? client,
    this.gameYear = 27,
    this.requestDelay = const Duration(milliseconds: 1500),
    this.imageWidth = 150,
  }) : _http = client ?? http.Client();

  static const userAgent = 'WLTrackerCardSync/0.1 (daily, 1 run per day)';
  static const _apiBase = 'https://www.fut.gg/api/fut/players/v2';
  static const _assetBase = 'https://game-assets.fut.gg/cdn-cgi/image';

  final http.Client _http;
  final int gameYear;
  final Duration requestDelay;
  final int imageWidth;
  DateTime? _lastRequest;

  /// Holt eine Seite (30 Karten), neueste zuerst.
  Future<CardPage> fetchPage(int page, {int? minRating, int? maxRating}) async {
    final uri = Uri.parse('$_apiBase/$gameYear/').replace(
      queryParameters: {
        'page': '$page',
        'sorts': '-created_at',
        if (minRating != null) 'overall__gte': '$minRating',
        if (maxRating != null) 'overall__lte': '$maxRating',
      },
    );
    final res = await _get(uri, accept: 'application/json');
    return parsePage(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  /// Lädt das kompakte Kartenbild als WebP in der konfigurierten Breite.
  Future<Uint8List> fetchImage(String sourceImagePath) async {
    final uri = Uri.parse('$_assetBase/quality=85,format=auto,width=$imageWidth/$sourceImagePath');
    final res = await _get(uri, accept: 'image/webp', throttle: false);
    return res.bodyBytes;
  }

  void close() => _http.close();

  static CardPage parsePage(Map<String, dynamic> json) {
    final raw = (json['data'] as List?) ?? const [];
    final cards = <PlayerCard>[];
    for (final item in raw) {
      final card = item is Map<String, dynamic> ? cardFromFutgg(item) : null;
      if (card != null) cards.add(card);
    }
    return CardPage(cards, hasNext: json['next'] != null, skipped: raw.length - cards.length);
  }

  Future<http.Response> _get(Uri uri, {required String accept, bool throttle = true}) async {
    for (var attempt = 1; ; attempt++) {
      if (throttle) await _waitForSlot();
      final res = await _http.get(uri, headers: {'User-Agent': userAgent, 'Accept': accept});
      if (res.statusCode == 200) return res;
      final retryable = res.statusCode == 429 || res.statusCode >= 500;
      if (!retryable || attempt >= 4) {
        throw HttpException('HTTP ${res.statusCode} für $uri', uri: uri);
      }
      await Future<void>.delayed(Duration(seconds: 10 * attempt));
    }
  }

  Future<void> _waitForSlot() async {
    final last = _lastRequest;
    if (last != null) {
      final wait = requestDelay - DateTime.now().difference(last);
      if (wait > Duration.zero) await Future<void>.delayed(wait);
    }
    _lastRequest = DateTime.now();
  }
}

/// Liest eine Karte aus der fut.gg-API. Gibt `null` zurück, wenn
/// Pflichtfelder fehlen.
PlayerCard? cardFromFutgg(Map<String, dynamic> j) {
  final id = j['eaId'];
  final rating = j['overall'];
  final position = j['position'];
  final imagePath = j['simpleCardImagePath'];
  final createdAt = DateTime.tryParse(j['createdAt'] as String? ?? '');
  if (id is! int || rating is! int || position is! String || imagePath is! String || createdAt == null) {
    return null;
  }
  final first = (j['firstName'] as String?) ?? '';
  final last = (j['lastName'] as String?) ?? '';
  final name = (j['commonName'] as String?) ?? (j['cardName'] as String?) ?? '$first $last'.trim();
  return PlayerCard(
    id: id,
    basePlayerId: (j['basePlayerEaId'] as int?) ?? id,
    name: name,
    firstName: first,
    lastName: last,
    rating: rating,
    position: position,
    altPositions: [for (final p in (j['alternativePositions'] as List? ?? const [])) p as String],
    version: (j['rarityName'] as String?) ?? '',
    createdAt: createdAt.toUtc(),
    sourceImagePath: imagePath,
  );
}
