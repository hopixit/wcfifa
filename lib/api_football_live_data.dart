import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import 'api_proxy_config.dart';
import 'models.dart';
import 'seed_data.dart';

class WorldCupDataScope extends InheritedNotifier<WorldCupDataController> {
  const WorldCupDataScope({
    required WorldCupDataController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static WorldCupDataController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<WorldCupDataScope>();
    assert(scope != null, 'WorldCupDataScope is missing from the widget tree');
    return scope!.notifier!;
  }
}

class WorldCupDataController extends ChangeNotifier {
  WorldCupDataController({required this.apiEnabled, ApiFootballClient? client})
    : _client = client ?? ApiFootballClient();

  static final DateTime _resultPollingStart = DateTime(2026, 6, 11);
  static const Duration _resultPollingInterval = Duration(minutes: 5);
  static const Duration _resultPollingWindow = Duration(minutes: 180);

  final bool apiEnabled;
  final ApiFootballClient _client;

  List<MatchEntry> _fixtures = SeedData.fixtures;
  Timer? _resultTimer;
  bool _isRefreshing = false;
  bool _usingApiFixtures = false;
  String? _lastError;
  DateTime? _lastSyncedAt;
  int? _requestsRemainingToday;
  int _rawFixtureCount = 0;
  bool _isRefreshingPredictions = false;
  int _rawPredictionCount = 0;
  int _predictionRequestCount = 0;
  DateTime? _lastPredictionsSyncedAt;
  String? _lastPredictionError;
  final Map<String, ApiFixturePrediction> _predictionsByMatchId = {};
  bool _isRefreshingResults = false;
  int _rawResultCount = 0;
  int _resultRequestCount = 0;
  DateTime? _lastResultsSyncedAt;
  String? _lastResultError;
  final Map<String, ApiTeamRoster> _teamRosters = {};
  final Map<String, Future<ApiTeamRoster?>> _teamRosterRequests = {};
  String? _lastRosterError;
  final Map<String, ApiMatchDetails> _matchDetails = {};
  final Map<String, Future<ApiMatchDetails?>> _matchDetailsRequests = {};
  final Map<String, String> _matchDetailsErrors = {};

  List<MatchEntry> get fixtures => _fixtures;
  bool get isRefreshing => _isRefreshing;
  bool get usingApiFixtures => _usingApiFixtures;
  String? get lastError => _lastError;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  int? get requestsRemainingToday => _requestsRemainingToday;
  int get rawFixtureCount => _rawFixtureCount;
  bool get isRefreshingPredictions => _isRefreshingPredictions;
  int get rawPredictionCount => _rawPredictionCount;
  int get predictionRequestCount => _predictionRequestCount;
  DateTime? get lastPredictionsSyncedAt => _lastPredictionsSyncedAt;
  String? get lastPredictionError => _lastPredictionError;
  bool get isRefreshingResults => _isRefreshingResults;
  int get rawResultCount => _rawResultCount;
  int get resultRequestCount => _resultRequestCount;
  DateTime? get lastResultsSyncedAt => _lastResultsSyncedAt;
  String? get lastResultError => _lastResultError;
  String? get lastRosterError => _lastRosterError;
  ApiTeamRoster? rosterFor(Team team) => _teamRosters[team.id];
  ApiMatchDetails? matchDetailsFor(MatchEntry match) => _matchDetails[match.id];
  String? matchDetailsErrorFor(MatchEntry match) =>
      _matchDetailsErrors[match.id];
  ApiFixturePrediction? predictionFor(MatchEntry match) {
    return _predictionsByMatchId[match.id];
  }

  Future<void> refreshApiData({bool forceResults = false}) async {
    await refreshFixtures();
    if (forceResults || _shouldRefreshResultsNow(DateTime.now())) {
      await refreshResults();
    }
  }

  void startResultPolling() {
    if (!apiEnabled || _resultTimer != null) return;
    if (_shouldRefreshResultsNow(DateTime.now())) {
      unawaited(refreshResults());
    }
    _resultTimer = Timer.periodic(_resultPollingInterval, (_) {
      if (_shouldRefreshResultsNow(DateTime.now())) {
        unawaited(refreshResults());
      }
    });
  }

  Future<ApiTeamRoster?> syncTeamRoster(Team team) {
    if (!apiEnabled) return Future<ApiTeamRoster?>.value(null);
    return _teamRosterRequests.putIfAbsent(team.id, () async {
      _lastRosterError = null;
      notifyListeners();
      try {
        final roster = await _client.fetchTeamRoster(team);
        _teamRosters[team.id] = roster;
        return roster;
      } catch (error) {
        _lastRosterError = '$error';
        return null;
      } finally {
        _teamRosterRequests.remove(team.id);
        notifyListeners();
      }
    });
  }

  bool isRosterSyncing(Team team) => _teamRosterRequests.containsKey(team.id);

  Future<ApiMatchDetails?> syncMatchDetails(MatchEntry match) {
    if (!apiEnabled) return Future<ApiMatchDetails?>.value(null);
    if (_matchDetails[match.id] case final cached?) {
      return Future<ApiMatchDetails?>.value(cached);
    }

    return _matchDetailsRequests.putIfAbsent(match.id, () async {
      _matchDetailsErrors.remove(match.id);
      notifyListeners();
      try {
        final details = await _client.fetchMatchDetails(match);
        _matchDetails[match.id] = details;
        _requestsRemainingToday =
            details.requestsRemainingToday ?? _requestsRemainingToday;
        return details;
      } catch (error) {
        _matchDetailsErrors[match.id] = '$error';
        return null;
      } finally {
        _matchDetailsRequests.remove(match.id);
        notifyListeners();
      }
    });
  }

  bool isMatchDetailsSyncing(MatchEntry match) {
    return _matchDetailsRequests.containsKey(match.id);
  }

  Future<void> refreshFixtures() async {
    if (!apiEnabled || _isRefreshing) return;

    _isRefreshing = true;
    _lastError = null;
    notifyListeners();

    try {
      final result = await _client.fetchFixtures();
      if (result.fixtures.isNotEmpty) {
        _fixtures = result.fixtures;
        _usingApiFixtures = true;
        _lastSyncedAt = result.fetchedAt;
        _requestsRemainingToday = result.requestsRemainingToday;
        _rawFixtureCount = result.rawFixtureCount;
        await refreshPredictions();
      } else {
        _lastError =
            'The match feed returned ${result.rawFixtureCount} fixtures, but none matched local teams.';
      }
    } catch (error) {
      _lastError = '$error';
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> refreshPredictions() async {
    if (!apiEnabled || _isRefreshingPredictions) return;

    _isRefreshingPredictions = true;
    _lastPredictionError = null;
    notifyListeners();

    try {
      final result = await _client.fetchPredictions();
      _predictionsByMatchId
        ..clear()
        ..addAll(result.predictionsByMatchId);
      _rawPredictionCount = result.predictionsByMatchId.length;
      _predictionRequestCount = result.requestCount;
      _lastPredictionsSyncedAt = result.fetchedAt;
      _requestsRemainingToday =
          result.requestsRemainingToday ?? _requestsRemainingToday;
    } catch (error) {
      _lastPredictionError = '$error';
    } finally {
      _isRefreshingPredictions = false;
      notifyListeners();
    }
  }

  Future<void> refreshResults() async {
    if (!apiEnabled || _isRefreshingResults) return;

    _isRefreshingResults = true;
    _lastResultError = null;
    notifyListeners();

    try {
      final result = await _client.fetchResults();
      _mergeResultFixtures(result.fixtures);
      _rawResultCount = result.rawResultCount;
      _resultRequestCount = result.requestCount;
      _lastResultsSyncedAt = result.fetchedAt;
      _requestsRemainingToday =
          result.requestsRemainingToday ?? _requestsRemainingToday;
    } catch (error) {
      _lastResultError = '$error';
    } finally {
      _isRefreshingResults = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _resultTimer?.cancel();
    super.dispose();
  }

  bool _shouldRefreshResultsNow(DateTime now) {
    final localNow = now.toLocal();
    if (localNow.isBefore(_resultPollingStart)) return false;

    return _fixtures.any((match) {
      final kickoff = match.kickoffUtc.toLocal();
      final finishedPolling = kickoff.add(_resultPollingWindow);
      return !localNow.isBefore(kickoff) && localNow.isBefore(finishedPolling);
    });
  }

  void _mergeResultFixtures(List<MatchEntry> updates) {
    if (updates.isEmpty) return;

    final byId = {for (final match in updates) match.id: match};
    final byMatchKey = {
      for (final match in updates) _resultMergeKey(match): match,
    };
    final matchedUpdateIds = <String>{};
    final merged = <MatchEntry>[];

    for (final fixture in _fixtures) {
      final update = byId[fixture.id] ?? byMatchKey[_resultMergeKey(fixture)];
      if (update == null) {
        merged.add(fixture);
        continue;
      }

      matchedUpdateIds.add(update.id);
      merged.add(_mergeResultIntoFixture(fixture, update));
    }

    if (_usingApiFixtures) {
      for (final update in updates) {
        if (!matchedUpdateIds.contains(update.id)) merged.add(update);
      }
    }

    merged.sort((a, b) => a.kickoffUtc.compareTo(b.kickoffUtc));
    _fixtures = merged;
  }

  String _resultMergeKey(MatchEntry match) {
    final local = match.kickoffUtc.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day:${match.group}:${match.homeTeamId}:${match.awayTeamId}';
  }

  MatchEntry _mergeResultIntoFixture(MatchEntry fixture, MatchEntry update) {
    return MatchEntry(
      id: fixture.id,
      group: update.group,
      homeTeamId: fixture.homeTeamId,
      awayTeamId: fixture.awayTeamId,
      kickoffUtc: update.kickoffUtc,
      venue: update.venue,
      city: update.city,
      status: update.status,
      homeScore: update.homeScore,
      awayScore: update.awayScore,
    );
  }
}

class ApiFootballClient {
  ApiFootballClient({http.Client? client, String? proxyBaseUrl})
    : _client = client ?? http.Client(),
      _proxyBaseUrl = proxyBaseUrl ?? defaultApiProxyBaseUrl();

  final http.Client _client;
  final String _proxyBaseUrl;
  Map<String, int>? _apiTeamIdsByName;

  Future<ApiFootballFixturesResult> fetchFixtures() async {
    final uri = _proxyUri('/api/worldcup/fixtures');
    final response = await _client.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiFootballException(
        'Proxy returned HTTP ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const ApiFootballException('Unexpected match feed response.');
    }

    final errors = decoded['errors'];
    if (errors is Map && errors.isNotEmpty) {
      throw ApiFootballException('Match feed error: ${jsonEncode(errors)}');
    }

    final rawFixtures = decoded['response'] is List
        ? decoded['response'] as List<dynamic>
        : const <dynamic>[];
    final mapped = <MatchEntry>[];

    for (final item in rawFixtures) {
      final match = _matchFromApiFixture(item);
      if (match != null) mapped.add(match);
    }

    mapped.sort((a, b) => a.kickoffUtc.compareTo(b.kickoffUtc));

    return ApiFootballFixturesResult(
      fixtures: mapped,
      rawFixtureCount: rawFixtures.length,
      requestsRemainingToday: int.tryParse(
        response.headers['x-ratelimit-requests-remaining'] ?? '',
      ),
      fetchedAt: DateTime.now(),
    );
  }

  Future<ApiFootballPredictionsResult> fetchPredictions() async {
    final payload = await _getJson(
      _proxyUri('/api/worldcup/predictions', {
        'scope': 'all',
        'strategy': 'full',
      }),
    );
    final rawItems = payload['response'] is List
        ? payload['response'] as List<dynamic>
        : const <dynamic>[];
    final predictions = <String, ApiFixturePrediction>{};

    for (final item in rawItems) {
      final prediction = ApiFixturePrediction.fromAggregateItem(item);
      if (prediction == null) continue;
      predictions['api_${prediction.fixtureId}'] = prediction;
    }

    return ApiFootballPredictionsResult(
      predictionsByMatchId: predictions,
      requestCount: _asInt(payload['requestCount']) ?? rawItems.length,
      requestsRemainingToday: _asInt(payload['requestsRemainingToday']),
      fetchedAt: DateTime.now(),
    );
  }

  Future<ApiFootballResultsResult> fetchResults() async {
    final payload = await _getJson(_proxyUri('/api/worldcup/results'));
    final rawItems = payload['response'] is List
        ? payload['response'] as List<dynamic>
        : const <dynamic>[];
    final mapped = <MatchEntry>[];

    for (final item in rawItems) {
      final match = _matchFromApiFixture(item);
      if (match != null) mapped.add(match);
    }

    mapped.sort((a, b) => a.kickoffUtc.compareTo(b.kickoffUtc));

    return ApiFootballResultsResult(
      fixtures: mapped,
      rawResultCount: rawItems.length,
      requestCount: _asInt(payload['requestCount']) ?? 0,
      requestsRemainingToday: _asInt(payload['requestsRemainingToday']),
      fetchedAt: DateTime.now(),
    );
  }

  Future<ApiMatchDetails> fetchMatchDetails(MatchEntry match) async {
    final fixtureId = _apiFixtureIdFromMatch(match);
    if (fixtureId == null) {
      throw ApiFootballException(
        'No provider fixture id is available for this match.',
      );
    }

    final payload = await _getJson(
      _proxyUri('/api/worldcup/match-details', {'fixture': fixtureId}),
    );

    return ApiMatchDetails.fromProxyPayload(
      fixtureId: fixtureId,
      match: match,
      payload: payload,
    );
  }

  Future<ApiTeamRoster> fetchTeamRoster(Team team) async {
    final apiTeamId = await _apiTeamIdFor(team);
    if (apiTeamId == null) {
      throw ApiFootballException('No provider team id found for ${team.name}.');
    }

    final squadResponse = await _getJson(
      _proxyUri('/api/worldcup/team-squad', {'team': '$apiTeamId'}),
    );
    final coachResponse = await _getJson(
      _proxyUri('/api/worldcup/team-coach', {'team': '$apiTeamId'}),
    );

    final squadItems = squadResponse['response'] is List
        ? squadResponse['response'] as List<dynamic>
        : const <dynamic>[];
    final firstSquad = squadItems.isEmpty ? null : _asMap(squadItems.first);
    final playersRaw = firstSquad?['players'] is List
        ? firstSquad!['players'] as List<dynamic>
        : const <dynamic>[];
    final players = <Player>[
      for (final item in playersRaw)
        if (_playerFromSquadItem(item) case final player?) player,
    ];

    final coachItems = coachResponse['response'] is List
        ? coachResponse['response'] as List<dynamic>
        : const <dynamic>[];
    final firstCoach = coachItems.isEmpty ? null : _asMap(coachItems.first);
    final coachName = firstCoach?['name']?.toString();

    return ApiTeamRoster(
      team: team,
      apiTeamId: apiTeamId,
      coachName: coachName,
      players: players,
      fetchedAt: DateTime.now(),
    );
  }

  Future<Map<String, int>> _fetchApiTeamIdsByName() async {
    if (_apiTeamIdsByName case final cached?) return cached;
    final payload = await _getJson(_proxyUri('/api/worldcup/teams'));
    final rawTeams = payload['response'] is List
        ? payload['response'] as List<dynamic>
        : const <dynamic>[];
    final result = <String, int>{};
    for (final item in rawTeams) {
      final team = _asMap(_asMap(item)['team']);
      final id = _asInt(team['id']);
      final name = team['name']?.toString();
      if (id != null && name != null) {
        result[_normalizeName(name)] = id;
      }
    }
    _apiTeamIdsByName = result;
    return result;
  }

  Future<int?> _apiTeamIdFor(Team team) async {
    final teams = await _fetchApiTeamIdsByName();
    final normalized = _normalizeName(team.name);
    if (teams[normalized] case final id?) return id;

    for (final entry in _apiTeamNameToLocalId.entries) {
      if (entry.value == team.id) {
        final id = teams[entry.key];
        if (id != null) return id;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final response = await _client.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiFootballException(
        'Proxy returned HTTP ${response.statusCode}: ${response.body}',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const ApiFootballException('Unexpected match feed response.');
    }
    final errors = decoded['errors'];
    if (errors is Map && errors.isNotEmpty) {
      throw ApiFootballException('Match feed error: ${jsonEncode(errors)}');
    }
    return decoded;
  }

  Uri _proxyUri(String path, [Map<String, String>? queryParameters]) {
    final base = Uri.parse(_proxyBaseUrl);
    return base.replace(path: path, queryParameters: queryParameters);
  }

  String? _apiFixtureIdFromMatch(MatchEntry match) {
    final matchId = RegExp(r'^api_(\d+)$').firstMatch(match.id);
    return matchId?.group(1);
  }

  MatchEntry? _matchFromApiFixture(Object? value) {
    final root = _asMap(value);
    final fixture = _asMap(root['fixture']);
    final league = _asMap(root['league']);
    final teams = _asMap(root['teams']);
    final homeApiTeam = _asMap(teams['home']);
    final awayApiTeam = _asMap(teams['away']);
    final venue = _asMap(fixture['venue']);
    final status = _asMap(fixture['status']);
    final goals = _asMap(root['goals']);

    final homeName = homeApiTeam['name']?.toString();
    final awayName = awayApiTeam['name']?.toString();
    if (homeName == null || awayName == null) return null;

    final home = _teamByApiName(homeName);
    final away = _teamByApiName(awayName);
    if (home == null || away == null) return null;

    final date = fixture['date']?.toString();
    final kickoff = date == null ? null : DateTime.tryParse(date);
    if (kickoff == null) return null;

    final apiId = fixture['id']?.toString();
    final group = home.group == away.group
        ? home.group
        : _groupFromRound(league['round']?.toString()) ?? home.group;

    return MatchEntry(
      id: apiId == null ? 'api_${home.id}_${away.id}' : 'api_$apiId',
      group: group,
      homeTeamId: home.id,
      awayTeamId: away.id,
      kickoffUtc: kickoff.toUtc(),
      venue: venue['name']?.toString() ?? 'TBD',
      city: venue['city']?.toString() ?? 'TBD',
      status: _statusFromApi(status['short']?.toString()),
      homeScore: _asInt(goals['home']),
      awayScore: _asInt(goals['away']),
    );
  }

  Player? _playerFromSquadItem(Object? value) {
    final item = _asMap(value);
    final name = item['name']?.toString();
    if (name == null || name.trim().isEmpty) return null;
    return Player(
      name: name,
      position: _positionFromApi(item['position']?.toString()),
      number: _asInt(item['number']),
      age: _asInt(item['age']),
    );
  }

  String _positionFromApi(String? value) {
    switch (_normalizeName(value ?? '')) {
      case 'goalkeeper':
      case 'goal':
        return 'Goalkeeper';
      case 'defender':
        return 'Defender';
      case 'midfielder':
        return 'Midfielder';
      case 'attacker':
      case 'forward':
        return 'Forward';
      default:
        return value == null || value.isEmpty ? 'Player' : value;
    }
  }

  MatchStatus _statusFromApi(String? status) {
    switch (status) {
      case '1H':
      case 'HT':
      case '2H':
      case 'ET':
      case 'P':
      case 'BT':
      case 'LIVE':
      case 'INT':
        return MatchStatus.live;
      case 'FT':
      case 'AET':
      case 'PEN':
        return MatchStatus.finished;
      default:
        return MatchStatus.upcoming;
    }
  }

  String? _groupFromRound(String? value) {
    if (value == null) return null;
    final match = RegExp(
      r'Group\s+([A-L])',
      caseSensitive: false,
    ).firstMatch(value);
    return match?.group(1)?.toUpperCase();
  }

  Team? _teamByApiName(String name) {
    final teamId = _apiTeamNameToLocalId[_normalizeName(name)];
    if (teamId == null) return null;
    return SeedData.teamById(teamId);
  }

  static final Map<String, String> _apiTeamNameToLocalId = {
    for (final team in SeedData.teams) _normalizeName(team.name): team.id,
    _normalizeName('Czech Republic'): 'cze',
    _normalizeName('South Korea'): 'kor',
    _normalizeName('USA'): 'usa',
    _normalizeName('United States of America'): 'usa',
    _normalizeName('Turkey'): 'tur',
    _normalizeName('Turkiye'): 'tur',
    _normalizeName('Türkiye'): 'tur',
    _normalizeName('Curacao'): 'cur',
    _normalizeName('Curaçao'): 'cur',
    _normalizeName('Ivory Coast'): 'civ',
    _normalizeName('Côte d’Ivoire'): 'civ',
    _normalizeName('Cote d Ivoire'): 'civ',
    _normalizeName('Iran'): 'irn',
    _normalizeName('IR Iran'): 'irn',
    _normalizeName('Cape Verde'): 'cpv',
    _normalizeName('Cabo Verde'): 'cpv',
    _normalizeName('DR Congo'): 'cod',
    _normalizeName('Congo DR'): 'cod',
    _normalizeName('Democratic Republic of Congo'): 'cod',
    _normalizeName('Bosnia-Herzegovina'): 'bih',
    _normalizeName('Bosnia and Herzegovina'): 'bih',
  };

  static String _normalizeName(String value) {
    return value
        .toLowerCase()
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ç', 'c')
        .replaceAll('ï', 'i')
        .replaceAll('ı', 'i')
        .replaceAll('ü', 'u')
        .replaceAll('’', ' ')
        .replaceAll("'", ' ')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map) return value.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value == null) return null;
    return int.tryParse(value.toString());
  }
}

class ApiFootballFixturesResult {
  const ApiFootballFixturesResult({
    required this.fixtures,
    required this.rawFixtureCount,
    required this.requestsRemainingToday,
    required this.fetchedAt,
  });

  final List<MatchEntry> fixtures;
  final int rawFixtureCount;
  final int? requestsRemainingToday;
  final DateTime fetchedAt;
}

class ApiFootballPredictionsResult {
  const ApiFootballPredictionsResult({
    required this.predictionsByMatchId,
    required this.requestCount,
    required this.requestsRemainingToday,
    required this.fetchedAt,
  });

  final Map<String, ApiFixturePrediction> predictionsByMatchId;
  final int requestCount;
  final int? requestsRemainingToday;
  final DateTime fetchedAt;
}

class ApiFootballResultsResult {
  const ApiFootballResultsResult({
    required this.fixtures,
    required this.rawResultCount,
    required this.requestCount,
    required this.requestsRemainingToday,
    required this.fetchedAt,
  });

  final List<MatchEntry> fixtures;
  final int rawResultCount;
  final int requestCount;
  final int? requestsRemainingToday;
  final DateTime fetchedAt;
}

class ApiFixturePrediction {
  const ApiFixturePrediction({
    required this.fixtureId,
    required this.homeWin,
    required this.draw,
    required this.awayWin,
    required this.winnerName,
    required this.advice,
  });

  final String fixtureId;
  final int homeWin;
  final int draw;
  final int awayWin;
  final String? winnerName;
  final String? advice;

  static ApiFixturePrediction? fromAggregateItem(Object? value) {
    final item = ApiFootballClient._asMap(value);
    final fixture = ApiFootballClient._asMap(item['fixture']);
    final payload = ApiFootballClient._asMap(item['payload']);
    final fixtureId = fixture['id']?.toString();
    if (fixtureId == null || fixtureId.isEmpty) return null;

    final responseItems = payload['response'] is List
        ? payload['response'] as List<dynamic>
        : const <dynamic>[];
    if (responseItems.isEmpty) return null;

    final response = ApiFootballClient._asMap(responseItems.first);
    final predictions = ApiFootballClient._asMap(response['predictions']);
    final percent = ApiFootballClient._asMap(predictions['percent']);
    final values = _cleanPercentages([
      _percentValue(percent['home']),
      _percentValue(percent['draw']),
      _percentValue(percent['away']),
    ]);
    if (values == null) return null;

    final winner = ApiFootballClient._asMap(predictions['winner']);
    final winnerName = winner['name']?.toString();

    return ApiFixturePrediction(
      fixtureId: fixtureId,
      homeWin: values[0],
      draw: values[1],
      awayWin: values[2],
      winnerName: winnerName == null || winnerName.trim().isEmpty
          ? null
          : winnerName,
      advice: predictions['advice']?.toString(),
    );
  }

  Prediction toPrediction(MatchEntry match, Prediction fallback) {
    final ordered = [homeWin, draw, awayWin]..sort((a, b) => b.compareTo(a));
    final spread = (ordered.first - ordered[1]) / 100;
    final confidence = (spread * 0.7 + fallback.confidence * 0.3)
        .clamp(0.08, 0.9)
        .toDouble();
    final notes = [
      'Daily forecast uses provider form, head-to-head and historical comparison.',
      if (winnerName != null) 'Provider edge: $winnerName.',
      if (advice != null && advice!.trim().isNotEmpty)
        'Signal: ${advice!.trim()}.',
      'Local score and xG stay as the fallback estimate.',
    ].join(' ');

    return Prediction(
      homeWin: homeWin,
      draw: draw,
      awayWin: awayWin,
      predictedHomeGoals: fallback.predictedHomeGoals,
      predictedAwayGoals: fallback.predictedAwayGoals,
      confidence: confidence,
      explanation: notes,
      expectedHomeGoals: fallback.expectedHomeGoals,
      expectedAwayGoals: fallback.expectedAwayGoals,
      dataQuality: fallback.dataQuality,
      homeModelScore: fallback.homeModelScore,
      awayModelScore: fallback.awayModelScore,
      sourceLabel: 'Daily forecast',
    );
  }

  static double? _percentValue(Object? value) {
    if (value == null) return null;
    final match = RegExp(r'-?\d+(?:[\.,]\d+)?').firstMatch(value.toString());
    if (match == null) return null;
    return double.tryParse(match.group(0)!.replaceAll(',', '.'));
  }

  static List<int>? _cleanPercentages(List<double?> values) {
    if (values.any((value) => value == null)) return null;
    final safe = values
        .map((value) => value!.clamp(0.01, 98.0).toDouble())
        .toList();
    final total = safe.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) return null;
    final raw = safe.map((value) => value / total * 100).toList();
    final floors = raw.map((value) => value.floor()).toList();
    var remainder = 100 - floors.fold<int>(0, (sum, value) => sum + value);
    final fractions = List.generate(
      raw.length,
      (index) => MapEntry(index, raw[index] - floors[index]),
    )..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in fractions) {
      if (remainder <= 0) break;
      floors[entry.key] += 1;
      remainder -= 1;
    }

    return floors;
  }
}

class ApiTeamRoster {
  const ApiTeamRoster({
    required this.team,
    required this.apiTeamId,
    required this.coachName,
    required this.players,
    required this.fetchedAt,
  });

  final Team team;
  final int apiTeamId;
  final String? coachName;
  final List<Player> players;
  final DateTime fetchedAt;
}

class ApiMatchDetails {
  const ApiMatchDetails({
    required this.fixtureId,
    required this.match,
    required this.events,
    required this.teamStatistics,
    required this.lineups,
    required this.errors,
    required this.requestCount,
    required this.requestsRemainingToday,
    required this.fetchedAt,
  });

  final String fixtureId;
  final MatchEntry match;
  final List<ApiMatchEvent> events;
  final List<ApiTeamMatchStatistics> teamStatistics;
  final List<ApiMatchLineup> lineups;
  final List<String> errors;
  final int requestCount;
  final int? requestsRemainingToday;
  final DateTime fetchedAt;

  bool get hasPayload =>
      events.isNotEmpty || teamStatistics.isNotEmpty || lineups.isNotEmpty;

  List<ApiMatchEvent> get goals => events.where((event) {
    return event.type.toLowerCase() == 'goal';
  }).toList();

  List<ApiMatchEvent> get cards => events.where((event) {
    return event.type.toLowerCase() == 'card';
  }).toList();

  List<ApiMatchEvent> get substitutions => events.where((event) {
    return event.type.toLowerCase() == 'subst';
  }).toList();

  ApiTeamMatchStatistics? statisticsForTeamName(String name) {
    final normalized = ApiFootballClient._normalizeName(name);
    for (final item in teamStatistics) {
      if (ApiFootballClient._normalizeName(item.teamName) == normalized) {
        return item;
      }
    }
    return null;
  }

  static ApiMatchDetails fromProxyPayload({
    required String fixtureId,
    required MatchEntry match,
    required Map<String, dynamic> payload,
  }) {
    final response = ApiFootballClient._asMap(payload['response']);
    final eventsRaw = response['events'] is List
        ? response['events'] as List<dynamic>
        : const <dynamic>[];
    final statisticsRaw = response['statistics'] is List
        ? response['statistics'] as List<dynamic>
        : const <dynamic>[];
    final lineupsRaw = response['lineups'] is List
        ? response['lineups'] as List<dynamic>
        : const <dynamic>[];
    final errorsRaw = payload['errors'] is List
        ? payload['errors'] as List<dynamic>
        : const <dynamic>[];
    final generatedAt = payload['generatedAt']?.toString();

    return ApiMatchDetails(
      fixtureId: fixtureId,
      match: match,
      events: [
        for (final item in eventsRaw)
          if (ApiMatchEvent.fromJson(item) case final event?) event,
      ],
      teamStatistics: [
        for (final item in statisticsRaw)
          if (ApiTeamMatchStatistics.fromJson(item) case final stats?) stats,
      ],
      lineups: [
        for (final item in lineupsRaw)
          if (ApiMatchLineup.fromJson(item) case final lineup?) lineup,
      ],
      errors: [
        for (final item in errorsRaw)
          if (item != null) item.toString(),
      ],
      requestCount: ApiFootballClient._asInt(payload['requestCount']) ?? 0,
      requestsRemainingToday: ApiFootballClient._asInt(
        payload['requestsRemainingToday'],
      ),
      fetchedAt: generatedAt == null
          ? DateTime.now()
          : DateTime.tryParse(generatedAt)?.toLocal() ?? DateTime.now(),
    );
  }
}

class ApiMatchEvent {
  const ApiMatchEvent({
    required this.elapsed,
    required this.extra,
    required this.teamName,
    required this.playerName,
    required this.assistName,
    required this.type,
    required this.detail,
    required this.comments,
  });

  final int? elapsed;
  final int? extra;
  final String? teamName;
  final String? playerName;
  final String? assistName;
  final String type;
  final String detail;
  final String? comments;

  String get minuteLabel {
    if (elapsed == null) return '--';
    if (extra != null && extra! > 0) return "$elapsed+$extra'";
    return "$elapsed'";
  }

  String get description {
    final parts = [
      if (playerName != null && playerName!.trim().isNotEmpty) playerName!,
      if (assistName != null && assistName!.trim().isNotEmpty)
        'Assist: $assistName',
      if (comments != null && comments!.trim().isNotEmpty) comments!,
    ];
    return parts.isEmpty ? detail : parts.join(' • ');
  }

  static ApiMatchEvent? fromJson(Object? value) {
    final item = ApiFootballClient._asMap(value);
    final time = ApiFootballClient._asMap(item['time']);
    final team = ApiFootballClient._asMap(item['team']);
    final player = ApiFootballClient._asMap(item['player']);
    final assist = ApiFootballClient._asMap(item['assist']);
    final type = item['type']?.toString();
    final detail = item['detail']?.toString();
    if (type == null || detail == null) return null;

    return ApiMatchEvent(
      elapsed: ApiFootballClient._asInt(time['elapsed']),
      extra: ApiFootballClient._asInt(time['extra']),
      teamName: _cleanString(team['name']),
      playerName: _cleanString(player['name']),
      assistName: _cleanString(assist['name']),
      type: type,
      detail: detail,
      comments: _cleanString(item['comments']),
    );
  }
}

class ApiTeamMatchStatistics {
  const ApiTeamMatchStatistics({
    required this.teamName,
    required this.statistics,
  });

  final String teamName;
  final List<ApiMatchStatistic> statistics;

  String? valueFor(String type) {
    final normalized = ApiFootballClient._normalizeName(type);
    for (final stat in statistics) {
      if (ApiFootballClient._normalizeName(stat.type) == normalized) {
        return stat.displayValue;
      }
    }
    return null;
  }

  static ApiTeamMatchStatistics? fromJson(Object? value) {
    final item = ApiFootballClient._asMap(value);
    final team = ApiFootballClient._asMap(item['team']);
    final teamName = _cleanString(team['name']);
    if (teamName == null) return null;
    final rawStats = item['statistics'] is List
        ? item['statistics'] as List<dynamic>
        : const <dynamic>[];

    return ApiTeamMatchStatistics(
      teamName: teamName,
      statistics: [
        for (final item in rawStats)
          if (ApiMatchStatistic.fromJson(item) case final stat?) stat,
      ],
    );
  }
}

class ApiMatchStatistic {
  const ApiMatchStatistic({required this.type, required this.displayValue});

  final String type;
  final String displayValue;

  static ApiMatchStatistic? fromJson(Object? value) {
    final item = ApiFootballClient._asMap(value);
    final type = _cleanString(item['type']);
    if (type == null) return null;
    final rawValue = item['value'];
    final displayValue = rawValue == null || rawValue.toString().trim().isEmpty
        ? '-'
        : rawValue.toString();
    return ApiMatchStatistic(type: type, displayValue: displayValue);
  }
}

class ApiMatchLineup {
  const ApiMatchLineup({
    required this.teamName,
    required this.formation,
    required this.coachName,
    required this.startXI,
    required this.substitutes,
  });

  final String teamName;
  final String? formation;
  final String? coachName;
  final List<ApiLineupPlayer> startXI;
  final List<ApiLineupPlayer> substitutes;

  static ApiMatchLineup? fromJson(Object? value) {
    final item = ApiFootballClient._asMap(value);
    final team = ApiFootballClient._asMap(item['team']);
    final coach = ApiFootballClient._asMap(item['coach']);
    final teamName = _cleanString(team['name']);
    if (teamName == null) return null;
    final startRaw = item['startXI'] is List
        ? item['startXI'] as List<dynamic>
        : const <dynamic>[];
    final substituteRaw = item['substitutes'] is List
        ? item['substitutes'] as List<dynamic>
        : const <dynamic>[];

    return ApiMatchLineup(
      teamName: teamName,
      formation: _cleanString(item['formation']),
      coachName: _cleanString(coach['name']),
      startXI: [
        for (final item in startRaw)
          if (ApiLineupPlayer.fromJson(item) case final player?) player,
      ],
      substitutes: [
        for (final item in substituteRaw)
          if (ApiLineupPlayer.fromJson(item) case final player?) player,
      ],
    );
  }
}

class ApiLineupPlayer {
  const ApiLineupPlayer({
    required this.name,
    required this.number,
    required this.position,
    required this.grid,
  });

  final String name;
  final int? number;
  final String? position;
  final String? grid;

  String get label {
    final numberLabel = number == null ? '' : '$number. ';
    final meta = [
      if (position != null) position,
      if (grid != null) grid,
    ].join(' • ');
    return meta.isEmpty ? '$numberLabel$name' : '$numberLabel$name ($meta)';
  }

  static ApiLineupPlayer? fromJson(Object? value) {
    final item = ApiFootballClient._asMap(value);
    final player = ApiFootballClient._asMap(item['player']);
    final name = _cleanString(player['name']);
    if (name == null) return null;

    return ApiLineupPlayer(
      name: name,
      number: ApiFootballClient._asInt(player['number']),
      position: _cleanString(player['pos']),
      grid: _cleanString(player['grid']),
    );
  }
}

String? _cleanString(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
    return null;
  }
  return text;
}

class ApiFootballException implements Exception {
  const ApiFootballException(this.message);

  final String message;

  @override
  String toString() => message;
}
