import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:xml/xml.dart';

const _defaultHost = 'v3.football.api-sports.io';
const _leagueId = '1';
const _season = '2026';
const _newsCacheTtl = Duration(minutes: 20);

const _newsFeeds = [
  _NewsFeed(
    source: 'ESPN',
    title: 'ESPN Soccer',
    url: 'https://www.espn.com/espn/rss/soccer/news',
    homeUrl: 'https://www.espn.com/soccer/',
  ),
  _NewsFeed(
    source: 'Sky Sports',
    title: 'Sky Sports Football',
    url: 'http://www.skysports.com/rss/0,20514,11661,00.xml',
    homeUrl: 'https://www.skysports.com/football',
  ),
];

const _worldCupNewsTerms = [
  'world cup',
  'worldcup',
  'fifa',
  'wcup',
  '2026 world',
  'usmnt',
  'мондиал',
  'световно',
];

Future<void> main() async {
  final localEnv = _readLocalEnv();
  final apiKey = _configValue('API_FOOTBALL_KEY', localEnv);
  if (apiKey == null || apiKey.isEmpty) {
    stdout.writeln(
      'API_FOOTBALL_KEY is not set. API-Football routes will return an error, RSS news still works.',
    );
  }

  final host =
      _configValue('API_FOOTBALL_HOST', localEnv) ??
      _configValue('API_FOOTBALL_BASE_URL', localEnv) ??
      _defaultHost;
  final upstreamHost = host
      .replaceFirst('https://', '')
      .replaceFirst('http://', '')
      .trim();
  final port =
      int.tryParse(_configValue('API_FOOTBALL_PROXY_PORT', localEnv) ?? '') ??
      8787;
  final proxy = _ApiFootballProxy(apiKey: apiKey, upstreamHost: upstreamHost);
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);

  stdout.writeln('API-Football proxy listening on http://127.0.0.1:$port');
  stdout.writeln('Upstream: https://$upstreamHost');

  await for (final request in server) {
    unawaited(proxy.handle(request));
  }
}

class _ApiFootballProxy {
  _ApiFootballProxy({required this.apiKey, required this.upstreamHost});

  final String? apiKey;
  final String upstreamHost;
  final _client = HttpClient();
  final _cacheDir = Directory('.api_cache/api_football');

  Future<void> handle(HttpRequest request) async {
    _setCors(request.response);

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }

    if (request.method != 'GET') {
      await _sendJson(request.response, HttpStatus.methodNotAllowed, {
        'error': 'GET only',
      });
      return;
    }

    try {
      if (request.uri.path == '/api/news') {
        await _handleNews(request);
        return;
      }

      final route = _routeFor(request.uri);
      if (route == null) {
        await _sendJson(request.response, HttpStatus.notFound, {
          'error': 'Unknown endpoint',
        });
        return;
      }

      if (route.health) {
        await _sendJson(request.response, HttpStatus.ok, {
          'ok': true,
          'upstream': 'https://$upstreamHost',
        });
        return;
      }

      final cached = await _cachedResponse(route);
      if (cached != null) {
        request.response.headers.set('x-cache', 'HIT');
        await _sendRawJson(request.response, HttpStatus.ok, cached.body);
        return;
      }

      final upstream = await _fetch(route);
      request.response.headers.set('x-cache', 'MISS');
      for (final header in [
        'x-ratelimit-requests-limit',
        'x-ratelimit-requests-remaining',
        'x-ratelimit-limit',
        'x-ratelimit-remaining',
      ]) {
        final value = upstream.headers.value(header);
        if (value != null) request.response.headers.set(header, value);
      }

      if (upstream.statusCode == HttpStatus.ok) {
        await _writeCache(route, upstream.body);
      }
      await _sendRawJson(request.response, upstream.statusCode, upstream.body);
    } catch (error) {
      await _sendJson(request.response, HttpStatus.badGateway, {
        'error': 'Proxy request failed',
        'message': '$error',
      });
    }
  }

  _ProxyRoute? _routeFor(Uri uri) {
    final path = uri.path;
    if (path == '/api/health') return const _ProxyRoute.health();
    if (path == '/api/worldcup/fixtures') {
      return _ProxyRoute(
        endpoint: '/fixtures',
        cacheKey: 'fixtures',
        ttl: const Duration(minutes: 30),
        params: {
          'league': _leagueId,
          'season': _season,
          'timezone': uri.queryParameters['timezone'] ?? 'Europe/Sofia',
        },
      );
    }
    if (path == '/api/worldcup/standings') {
      return const _ProxyRoute(
        endpoint: '/standings',
        cacheKey: 'standings',
        ttl: Duration(hours: 1),
        params: {'league': _leagueId, 'season': _season},
      );
    }
    if (path == '/api/worldcup/teams') {
      return const _ProxyRoute(
        endpoint: '/teams',
        cacheKey: 'teams',
        ttl: Duration(hours: 12),
        params: {'league': _leagueId, 'season': _season},
      );
    }
    if (path == '/api/worldcup/team-squad') {
      final team = uri.queryParameters['team'];
      if (team == null || int.tryParse(team) == null) return null;
      return _ProxyRoute(
        endpoint: '/players/squads',
        cacheKey: 'squad_$team',
        ttl: const Duration(days: 7),
        params: {'team': team},
      );
    }
    if (path == '/api/worldcup/team-coach') {
      final team = uri.queryParameters['team'];
      if (team == null || int.tryParse(team) == null) return null;
      return _ProxyRoute(
        endpoint: '/coachs',
        cacheKey: 'coach_$team',
        ttl: const Duration(days: 1),
        params: {'team': team},
      );
    }
    if (path == '/api/worldcup/top-scorers') {
      return const _ProxyRoute(
        endpoint: '/players/topscorers',
        cacheKey: 'top_scorers',
        ttl: Duration(hours: 6),
        params: {'league': _leagueId, 'season': _season},
      );
    }
    if (path == '/api/worldcup/top-assists') {
      return const _ProxyRoute(
        endpoint: '/players/topassists',
        cacheKey: 'top_assists',
        ttl: Duration(hours: 6),
        params: {'league': _leagueId, 'season': _season},
      );
    }
    if (path == '/api/worldcup/status') {
      return const _ProxyRoute(
        endpoint: '/status',
        cacheKey: 'status',
        ttl: Duration(minutes: 5),
        params: {},
      );
    }
    return null;
  }

  Future<_CachedResponse?> _cachedResponse(_ProxyRoute route) async {
    final file = File('${_cacheDir.path}/${route.cacheKey}.json');
    if (!file.existsSync()) return null;
    final age = DateTime.now().difference(await file.lastModified());
    if (age > route.ttl) return null;
    return _CachedResponse(await file.readAsString());
  }

  Future<void> _writeCache(_ProxyRoute route, String body) async {
    if (!_cacheDir.existsSync()) {
      await _cacheDir.create(recursive: true);
    }
    final file = File('${_cacheDir.path}/${route.cacheKey}.json');
    await file.writeAsString(body);
  }

  Future<_UpstreamResponse> _fetch(_ProxyRoute route) async {
    final key = apiKey;
    if (key == null || key.isEmpty) {
      throw const _ProxyException(
        'Missing API_FOOTBALL_KEY. Export it or add it to .env.local.',
      );
    }
    final uri = Uri.https(upstreamHost, route.endpoint, route.params);
    final request = await _client
        .getUrl(uri)
        .timeout(const Duration(seconds: 10));
    request.headers.set('x-apisports-key', key);
    final response = await request.close().timeout(const Duration(seconds: 20));
    final body = await utf8.decoder.bind(response).join();
    final remaining = response.headers.value('x-ratelimit-requests-remaining');
    if (remaining != null) {
      stdout.writeln('${route.cacheKey}: $remaining requests remaining today');
    }
    return _UpstreamResponse(
      statusCode: response.statusCode,
      headers: response.headers,
      body: body,
    );
  }

  Future<void> _handleNews(HttpRequest request) async {
    final source = request.uri.queryParameters['source'] ?? 'all';
    final scope = request.uri.queryParameters['scope'] ?? 'worldcup';
    final limit =
        (int.tryParse(request.uri.queryParameters['limit'] ?? '') ?? 24).clamp(
          1,
          60,
        );
    final cacheKey = 'news_${source}_${scope}_$limit';
    final cacheRoute = _ProxyRoute(
      endpoint: '/api/news',
      cacheKey: cacheKey,
      ttl: _newsCacheTtl,
      params: {},
    );

    final cached = await _cachedResponse(cacheRoute);
    if (cached != null) {
      request.response.headers.set('x-cache', 'HIT');
      await _sendRawJson(request.response, HttpStatus.ok, cached.body);
      return;
    }

    final feeds = _newsFeeds
        .where((feed) {
          if (source == 'espn') return feed.source == 'ESPN';
          if (source == 'sky') return feed.source == 'Sky Sports';
          return true;
        })
        .toList(growable: false);

    final items = <_NewsItem>[];
    final errors = <Map<String, String>>[];
    for (final feed in feeds) {
      try {
        items.addAll(await _fetchNewsFeed(feed));
      } catch (error) {
        errors.add({'source': feed.source, 'message': '$error'});
      }
    }

    final scopedItems = scope == 'worldcup'
        ? items.where(_matchesWorldCupNewsTerms).toList()
        : [...items];
    scopedItems.sort((a, b) {
      final publishedCompare = (b.publishedAtMillis ?? 0).compareTo(
        a.publishedAtMillis ?? 0,
      );
      if (publishedCompare != 0) return publishedCompare;
      return a.title.compareTo(b.title);
    });

    final payload = jsonEncode({
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'scope': scope,
      'source': source,
      'feeds': [
        for (final feed in feeds)
          {
            'source': feed.source,
            'title': feed.title,
            'url': feed.url,
            'homeUrl': feed.homeUrl,
          },
      ],
      'errors': errors,
      'items': [for (final item in scopedItems.take(limit)) item.toJson()],
      'totalFetched': items.length,
      'totalMatched': scopedItems.length,
    });

    await _writeCache(cacheRoute, payload);
    request.response.headers.set('x-cache', 'MISS');
    await _sendRawJson(request.response, HttpStatus.ok, payload);
  }

  Future<List<_NewsItem>> _fetchNewsFeed(_NewsFeed feed) async {
    final request = await _client
        .getUrl(Uri.parse(feed.url))
        .timeout(const Duration(seconds: 10));
    request.headers.set(
      HttpHeaders.userAgentHeader,
      'SportAP World Cup News Reader/1.0',
    );
    final response = await request.close().timeout(const Duration(seconds: 20));
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _ProxyException('RSS feed returned HTTP ${response.statusCode}');
    }

    final document = XmlDocument.parse(body);
    return [
      for (final item in document.findAllElements('item'))
        if (_newsItemFromXml(feed, item) case final article?) article,
    ];
  }

  _NewsItem? _newsItemFromXml(_NewsFeed feed, XmlElement item) {
    final title = _xmlChildText(item, 'title');
    final link = _xmlChildText(item, 'link');
    if (title.isEmpty || link.isEmpty) return null;
    final description = _rssSummary(item);
    final pubDate = _xmlChildText(item, 'pubDate');
    final publishedAt = _parseRssDate(pubDate);
    final imageUrls = item
        .findElements('enclosure')
        .map((element) => element.getAttribute('url'))
        .whereType<String>()
        .toList(growable: false);
    final imageUrl = imageUrls.isEmpty ? null : imageUrls.first;

    return _NewsItem(
      source: feed.source,
      sourceTitle: feed.title,
      title: title,
      summary: description,
      link: link,
      publishedLabel: pubDate,
      publishedAtMillis: publishedAt?.millisecondsSinceEpoch,
      imageUrl: imageUrl,
    );
  }

  bool _matchesWorldCupNewsTerms(_NewsItem item) {
    final haystack = '${item.title} ${item.summary} ${item.link}'.toLowerCase();
    return _worldCupNewsTerms.any(haystack.contains);
  }
}

class _NewsFeed {
  const _NewsFeed({
    required this.source,
    required this.title,
    required this.url,
    required this.homeUrl,
  });

  final String source;
  final String title;
  final String url;
  final String homeUrl;
}

class _NewsItem {
  const _NewsItem({
    required this.source,
    required this.sourceTitle,
    required this.title,
    required this.summary,
    required this.link,
    required this.publishedLabel,
    required this.publishedAtMillis,
    required this.imageUrl,
  });

  final String source;
  final String sourceTitle;
  final String title;
  final String summary;
  final String link;
  final String publishedLabel;
  final int? publishedAtMillis;
  final String? imageUrl;

  Map<String, Object?> toJson() {
    return {
      'source': source,
      'sourceTitle': sourceTitle,
      'title': title,
      'summary': summary,
      'link': link,
      'publishedLabel': publishedLabel,
      'publishedAtMillis': publishedAtMillis,
      'imageUrl': imageUrl,
    };
  }
}

class _ProxyException implements Exception {
  const _ProxyException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _ProxyRoute {
  const _ProxyRoute({
    required this.endpoint,
    required this.cacheKey,
    required this.ttl,
    required this.params,
  }) : health = false;

  const _ProxyRoute.health()
    : endpoint = '',
      cacheKey = 'health',
      ttl = Duration.zero,
      params = const {},
      health = true;

  final String endpoint;
  final String cacheKey;
  final Duration ttl;
  final Map<String, String> params;
  final bool health;
}

class _CachedResponse {
  const _CachedResponse(this.body);

  final String body;
}

class _UpstreamResponse {
  const _UpstreamResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
  });

  final int statusCode;
  final HttpHeaders headers;
  final String body;
}

Map<String, String> _readLocalEnv() {
  final file = File('.env.local');
  if (!file.existsSync()) return {};
  final values = <String, String>{};
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final separator = trimmed.indexOf('=');
    if (separator <= 0) continue;
    final key = trimmed.substring(0, separator).trim();
    var value = trimmed.substring(separator + 1).trim();
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      value = value.substring(1, value.length - 1);
    }
    values[key] = value;
  }
  return values;
}

String? _configValue(String key, Map<String, String> localEnv) {
  final envValue = Platform.environment[key];
  if (envValue != null && envValue.isNotEmpty) return envValue;
  final fileValue = localEnv[key];
  if (fileValue != null && fileValue.isNotEmpty) return fileValue;
  return null;
}

void _setCors(HttpResponse response) {
  response.headers.set('Access-Control-Allow-Origin', '*');
  response.headers.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  response.headers.set(
    'Access-Control-Allow-Headers',
    'Content-Type, x-requested-with',
  );
}

Future<void> _sendJson(
  HttpResponse response,
  int statusCode,
  Map<String, Object?> body,
) {
  return _sendRawJson(response, statusCode, jsonEncode(body));
}

Future<void> _sendRawJson(
  HttpResponse response,
  int statusCode,
  String body,
) async {
  response.statusCode = statusCode;
  response.headers.contentType = ContentType.json;
  response.write(body);
  await response.close();
}

String _xmlChildText(XmlElement item, String name) {
  return _xmlChildTextAny(item, [name]);
}

String _xmlChildTextAny(XmlElement item, List<String> names) {
  final wanted = names.map((name) => name.toLowerCase()).toSet();
  for (final child in item.children.whereType<XmlElement>()) {
    final qualified = child.name.qualified.toLowerCase();
    final local = child.name.local.toLowerCase();
    if (wanted.contains(qualified) || wanted.contains(local)) {
      return child.innerText.trim();
    }
  }
  return '';
}

String _rssSummary(XmlElement item) {
  final raw = _xmlChildTextAny(item, [
    'content:encoded',
    'encoded',
    'description',
  ]);
  return _truncatePlainText(_stripHtml(raw), 1200);
}

String _stripHtml(String value) {
  return value
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&nbsp;', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _truncatePlainText(String value, int maxLength) {
  if (value.length <= maxLength) return value;
  final trimmed = value.substring(0, maxLength).trimRight();
  final lastSpace = trimmed.lastIndexOf(' ');
  final clean = lastSpace > 80 ? trimmed.substring(0, lastSpace) : trimmed;
  return '$clean...';
}

DateTime? _parseRssDate(String value) {
  if (value.isEmpty) return null;
  final match = RegExp(
    r'^[A-Za-z]{3},\s+(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+'
    r'(\d{2}):(\d{2}):(\d{2})\s+([A-Za-z]{2,4}|[+-]\d{4})$',
  ).firstMatch(value.trim());
  if (match == null) return null;

  final month = const {
    'Jan': 1,
    'Feb': 2,
    'Mar': 3,
    'Apr': 4,
    'May': 5,
    'Jun': 6,
    'Jul': 7,
    'Aug': 8,
    'Sep': 9,
    'Oct': 10,
    'Nov': 11,
    'Dec': 12,
  }[match.group(2)];
  if (month == null) return null;

  final offset = _timezoneOffset(match.group(7)!);
  final local = DateTime.utc(
    int.parse(match.group(3)!),
    month,
    int.parse(match.group(1)!),
    int.parse(match.group(4)!),
    int.parse(match.group(5)!),
    int.parse(match.group(6)!),
  );
  return local.subtract(offset);
}

Duration _timezoneOffset(String value) {
  final named = {
    'GMT': Duration.zero,
    'UTC': Duration.zero,
    'EST': const Duration(hours: -5),
    'EDT': const Duration(hours: -4),
    'BST': const Duration(hours: 1),
  }[value.toUpperCase()];
  if (named != null) return named;

  final match = RegExp(r'^([+-])(\d{2})(\d{2})$').firstMatch(value);
  if (match == null) return Duration.zero;
  final sign = match.group(1) == '-' ? -1 : 1;
  return Duration(
    hours: sign * int.parse(match.group(2)!),
    minutes: sign * int.parse(match.group(3)!),
  );
}
