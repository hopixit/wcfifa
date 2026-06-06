import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

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

  final bool apiEnabled;
  final ApiFootballClient _client;

  List<MatchEntry> _fixtures = SeedData.fixtures;
  bool _isRefreshing = false;
  bool _usingApiFixtures = false;
  String? _lastError;
  DateTime? _lastSyncedAt;
  int? _requestsRemainingToday;
  int _rawFixtureCount = 0;
  final Map<String, ApiTeamRoster> _teamRosters = {};
  final Map<String, Future<ApiTeamRoster?>> _teamRosterRequests = {};
  String? _lastRosterError;

  List<MatchEntry> get fixtures => _fixtures;
  bool get isRefreshing => _isRefreshing;
  bool get usingApiFixtures => _usingApiFixtures;
  String? get lastError => _lastError;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  int? get requestsRemainingToday => _requestsRemainingToday;
  int get rawFixtureCount => _rawFixtureCount;
  String? get lastRosterError => _lastRosterError;
  ApiTeamRoster? rosterFor(Team team) => _teamRosters[team.id];

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
      } else {
        _lastError =
            'API-Football returned ${result.rawFixtureCount} fixtures, but none matched local teams.';
      }
    } catch (error) {
      _lastError = '$error';
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }
}

class ApiFootballClient {
  ApiFootballClient({http.Client? client, String? proxyBaseUrl})
    : _client = client ?? http.Client(),
      _proxyBaseUrl =
          proxyBaseUrl ??
          const String.fromEnvironment(
            'API_PROXY_BASE_URL',
            defaultValue: 'http://127.0.0.1:8787',
          );

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
      throw const ApiFootballException('Unexpected API-Football JSON payload.');
    }

    final errors = decoded['errors'];
    if (errors is Map && errors.isNotEmpty) {
      throw ApiFootballException('API-Football error: ${jsonEncode(errors)}');
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

  Future<ApiTeamRoster> fetchTeamRoster(Team team) async {
    final apiTeamId = await _apiTeamIdFor(team);
    if (apiTeamId == null) {
      throw ApiFootballException(
        'No API-Football team id found for ${team.name}.',
      );
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
      throw const ApiFootballException('Unexpected API-Football JSON payload.');
    }
    final errors = decoded['errors'];
    if (errors is Map && errors.isNotEmpty) {
      throw ApiFootballException('API-Football error: ${jsonEncode(errors)}');
    }
    return decoded;
  }

  Uri _proxyUri(String path, [Map<String, String>? queryParameters]) {
    final base = Uri.parse(_proxyBaseUrl);
    return base.replace(path: path, queryParameters: queryParameters);
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

class ApiFootballException implements Exception {
  const ApiFootballException(this.message);

  final String message;

  @override
  String toString() => message;
}
