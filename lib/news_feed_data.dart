import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

enum NewsSourceFilter {
  all('all', 'All'),
  espn('espn', 'ESPN'),
  sky('sky', 'Sky Sports');

  const NewsSourceFilter(this.queryValue, this.label);

  final String queryValue;
  final String label;
}

enum NewsScopeFilter {
  worldCup('worldcup', 'World Cup'),
  football('all', 'All Football');

  const NewsScopeFilter(this.queryValue, this.label);

  final String queryValue;
  final String label;
}

class NewsFeedClient {
  NewsFeedClient({http.Client? client, String? proxyBaseUrl})
    : _client = client ?? http.Client(),
      _proxyBaseUrl =
          proxyBaseUrl ??
          const String.fromEnvironment(
            'API_PROXY_BASE_URL',
            defaultValue: 'http://127.0.0.1:8787',
          );

  final http.Client _client;
  final String _proxyBaseUrl;

  Future<NewsFeedResult> fetchNews({
    required NewsSourceFilter source,
    required NewsScopeFilter scope,
    int limit = 36,
  }) async {
    final uri = Uri.parse(_proxyBaseUrl).replace(
      path: '/api/news',
      queryParameters: {
        'source': source.queryValue,
        'scope': scope.queryValue,
        'limit': '$limit',
      },
    );
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw NewsFeedException(
        'News proxy returned HTTP ${response.statusCode}.',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const NewsFeedException('Unexpected news payload.');
    }

    return NewsFeedResult.fromJson(decoded);
  }
}

class NewsFeedResult {
  const NewsFeedResult({
    required this.items,
    required this.generatedAt,
    required this.totalFetched,
    required this.totalMatched,
    required this.errors,
  });

  final List<NewsArticle> items;
  final DateTime? generatedAt;
  final int totalFetched;
  final int totalMatched;
  final List<NewsFeedError> errors;

  factory NewsFeedResult.fromJson(Map<String, dynamic> json) {
    final items = json['items'] is List
        ? json['items'] as List<dynamic>
        : const <dynamic>[];
    final errors = json['errors'] is List
        ? json['errors'] as List<dynamic>
        : const <dynamic>[];

    return NewsFeedResult(
      items: [
        for (final item in items)
          if (item is Map<String, dynamic>) NewsArticle.fromJson(item),
      ],
      generatedAt: DateTime.tryParse(json['generatedAt']?.toString() ?? ''),
      totalFetched: int.tryParse('${json['totalFetched'] ?? 0}') ?? 0,
      totalMatched: int.tryParse('${json['totalMatched'] ?? 0}') ?? 0,
      errors: [
        for (final error in errors)
          if (error is Map<String, dynamic>) NewsFeedError.fromJson(error),
      ],
    );
  }
}

class NewsArticle {
  const NewsArticle({
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

  DateTime? get publishedAt {
    final value = publishedAtMillis;
    if (value == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  }

  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    return NewsArticle(
      source: json['source']?.toString() ?? 'News',
      sourceTitle: json['sourceTitle']?.toString() ?? 'News',
      title: json['title']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      link: json['link']?.toString() ?? '',
      publishedLabel: json['publishedLabel']?.toString() ?? '',
      publishedAtMillis: int.tryParse('${json['publishedAtMillis'] ?? ''}'),
      imageUrl: json['imageUrl']?.toString(),
    );
  }
}

class NewsFeedError {
  const NewsFeedError({required this.source, required this.message});

  final String source;
  final String message;

  factory NewsFeedError.fromJson(Map<String, dynamic> json) {
    return NewsFeedError(
      source: json['source']?.toString() ?? 'RSS',
      message: json['message']?.toString() ?? 'Feed unavailable',
    );
  }
}

class NewsFeedException implements Exception {
  const NewsFeedException(this.message);

  final String message;

  @override
  String toString() => message;
}
