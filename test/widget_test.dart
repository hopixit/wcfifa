import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sport_ap/api_proxy_config.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sport_ap/api_football_live_data.dart';
import 'package:sport_ap/main.dart';
import 'package:sport_ap/models.dart';
import 'package:sport_ap/news_feed_data.dart';
import 'package:sport_ap/prediction_model.dart';
import 'package:sport_ap/seed_data.dart';
import 'package:sport_ap/team_world_cup_record_data.dart';

void main() {
  test('seed data covers the local group-stage prototype', () {
    expect(SeedData.teams, hasLength(48));
    expect(SeedData.groups, hasLength(12));
    expect(SeedData.fixtures, hasLength(72));

    for (final group in SeedData.groups) {
      expect(
        SeedData.teams.where((team) => team.group == group),
        hasLength(4),
        reason: 'Group $group should have four teams',
      );
      expect(
        SeedData.fixtures.where((match) => match.group == group),
        hasLength(6),
        reason: 'Group $group should have six round-robin matches',
      );
    }
  });

  test('every team has an official squad loaded', () {
    final totalPlayers = SeedData.teams.fold<int>(
      0,
      (sum, team) => sum + team.squad.length,
    );

    expect(totalPlayers, 1247);
    for (final team in SeedData.teams) {
      expect(
        team.squad.length,
        inInclusiveRange(23, 26),
        reason: '${team.name} should have a complete official squad list',
      );
      expect(
        team.squad.where((player) => player.position == 'Вратар'),
        hasLength(greaterThanOrEqualTo(3)),
        reason: '${team.name} should include at least three goalkeepers',
      );
    }
  });

  test('every team has a World Cup history card', () {
    expect(teamWorldCupRecords, hasLength(48));
    for (final team in SeedData.teams) {
      final record = teamWorldCupRecords[team.id];
      expect(record, isNotNull, reason: '${team.name} needs record data');
      expect(record!.played, record.wins + record.draws + record.losses);
    }
  });

  test('prediction model v2 returns bounded deterministic outputs', () {
    final model = PredictionModel();

    for (final match in SeedData.fixtures) {
      final prediction = model.predict(match);
      expect(
        prediction.homeWin + prediction.draw + prediction.awayWin,
        100,
        reason: 'Prediction ${match.id} should display clean percentages',
      );
      expect(prediction.homeWin, inInclusiveRange(1, 98));
      expect(prediction.draw, inInclusiveRange(1, 98));
      expect(prediction.awayWin, inInclusiveRange(1, 98));
      expect(prediction.expectedHomeGoals, inInclusiveRange(0.2, 4.0));
      expect(prediction.expectedAwayGoals, inInclusiveRange(0.2, 4.0));
      expect(prediction.confidence, inInclusiveRange(0.0, 1.0));
      expect(prediction.dataQuality, inInclusiveRange(0.0, 1.0));
      expect(prediction.factors.length, greaterThanOrEqualTo(3));
      expect(prediction.explanation.toLowerCase(), isNot(contains('bet')));
      expect(prediction.explanation.toLowerCase(), isNot(contains('odds')));
    }

    final firstMatch = SeedData.fixtures.first;
    final firstPrediction = model.predict(firstMatch);
    final repeatedPrediction = model.predict(firstMatch);
    expect(repeatedPrediction.homeWin, firstPrediction.homeWin);
    expect(repeatedPrediction.draw, firstPrediction.draw);
    expect(repeatedPrediction.awayWin, firstPrediction.awayWin);
    expect(repeatedPrediction.score, firstPrediction.score);
  });

  test('api football prediction payload maps to display prediction', () {
    final apiPrediction = ApiFixturePrediction.fromAggregateItem({
      'fixture': {'id': '12345'},
      'payload': {
        'response': [
          {
            'predictions': {
              'winner': {'name': 'Mexico'},
              'advice': 'Mexico or draw',
              'percent': {'home': '47%', 'draw': '29%', 'away': '24%'},
            },
          },
        ],
      },
    });
    final match = MatchEntry(
      id: 'api_12345',
      group: 'A',
      homeTeamId: 'mex',
      awayTeamId: 'rsa',
      kickoffUtc: DateTime.utc(2026, 6, 11, 20),
      venue: 'Mexico City Stadium',
      city: 'Mexico City',
      status: MatchStatus.upcoming,
    );
    final fallback = PredictionModel().predict(match);
    final prediction = apiPrediction!.toPrediction(match, fallback);

    expect(prediction.homeWin + prediction.draw + prediction.awayWin, 100);
    expect(prediction.homeWin, 47);
    expect(prediction.draw, 29);
    expect(prediction.awayWin, 24);
    expect(prediction.score, fallback.score);
    expect(prediction.sourceLabel, 'Daily forecast');
  });

  test('api football results payload maps fixture scores', () async {
    final client = ApiFootballClient(
      proxyBaseUrl: 'http://proxy.test',
      client: MockClient((request) async {
        expect(request.url.path, '/api/worldcup/results');
        return http.Response(
          jsonEncode({
            'response': [
              {
                'fixture': {
                  'id': 12345,
                  'date': '2026-06-11T20:00:00+00:00',
                  'venue': {
                    'name': 'Mexico City Stadium',
                    'city': 'Mexico City',
                  },
                  'status': {'short': 'FT'},
                },
                'league': {'round': 'Group A'},
                'teams': {
                  'home': {'id': 16, 'name': 'Mexico'},
                  'away': {'id': 29, 'name': 'South Africa'},
                },
                'goals': {'home': 2, 'away': 1},
              },
            ],
            'requestCount': 1,
            'requestsRemainingToday': 99,
            'errors': {},
          }),
          200,
        );
      }),
    );

    final result = await client.fetchResults();
    final match = result.fixtures.single;

    expect(result.requestCount, 1);
    expect(result.requestsRemainingToday, 99);
    expect(match.id, 'api_12345');
    expect(match.status, MatchStatus.finished);
    expect(match.scoreLabel, '2:1');
  });

  test(
    'api football match details payload maps events stats and lineups',
    () async {
      final match = MatchEntry(
        id: 'api_12345',
        group: 'B',
        homeTeamId: 'can',
        awayTeamId: 'bih',
        kickoffUtc: DateTime.utc(2026, 6, 12, 19),
        venue: 'Toronto Stadium',
        city: 'Toronto',
        status: MatchStatus.finished,
        homeScore: 1,
        awayScore: 0,
      );
      final client = ApiFootballClient(
        proxyBaseUrl: 'http://proxy.test',
        client: MockClient((request) async {
          expect(request.url.path, '/api/worldcup/match-details');
          expect(request.url.queryParameters['fixture'], '12345');
          return http.Response(
            jsonEncode({
              'generatedAt': '2026-06-12T21:10:00.000Z',
              'fixture': '12345',
              'requestCount': 3,
              'requestsRemainingToday': 88,
              'errors': const [],
              'response': {
                'events': [
                  {
                    'time': {'elapsed': 22, 'extra': null},
                    'team': {'name': 'Canada'},
                    'player': {'name': 'Jonathan David'},
                    'assist': {'name': 'Alphonso Davies'},
                    'type': 'Goal',
                    'detail': 'Normal Goal',
                    'comments': null,
                  },
                  {
                    'time': {'elapsed': 71, 'extra': 2},
                    'team': {'name': 'Bosnia and Herzegovina'},
                    'player': {'name': 'Example Defender'},
                    'assist': {'name': null},
                    'type': 'Card',
                    'detail': 'Yellow Card',
                    'comments': 'Foul',
                  },
                ],
                'statistics': [
                  {
                    'team': {'name': 'Canada'},
                    'statistics': [
                      {'type': 'Ball Possession', 'value': '58%'},
                      {'type': 'Shots on Goal', 'value': 6},
                    ],
                  },
                  {
                    'team': {'name': 'Bosnia and Herzegovina'},
                    'statistics': [
                      {'type': 'Ball Possession', 'value': '42%'},
                      {'type': 'Shots on Goal', 'value': 2},
                    ],
                  },
                ],
                'lineups': [
                  {
                    'team': {'name': 'Canada'},
                    'formation': '4-2-3-1',
                    'coach': {'name': 'Jesse Marsch'},
                    'startXI': [
                      {
                        'player': {
                          'name': 'Jonathan David',
                          'number': 20,
                          'pos': 'F',
                          'grid': '4:2',
                        },
                      },
                    ],
                    'substitutes': const [],
                  },
                ],
              },
            }),
            200,
          );
        }),
      );

      final details = await client.fetchMatchDetails(match);

      expect(details.requestCount, 3);
      expect(details.requestsRemainingToday, 88);
      expect(details.goals.single.playerName, 'Jonathan David');
      expect(details.goals.single.assistName, 'Alphonso Davies');
      expect(details.cards.single.minuteLabel, "71+2'");
      expect(
        details.statisticsForTeamName('Canada')!.valueFor('Ball Possession'),
        '58%',
      );
      expect(details.lineups.single.formation, '4-2-3-1');
      expect(details.lineups.single.startXI.single.label, contains('20.'));
    },
  );

  test('tournament outlook is deterministic and monotonic', () {
    final model = PredictionModel();

    for (final team in SeedData.teams) {
      final outlook = model.tournamentOutlook(team);
      expect(outlook.round32, greaterThanOrEqualTo(outlook.round16));
      expect(outlook.round16, greaterThanOrEqualTo(outlook.quarterFinal));
      expect(outlook.quarterFinal, greaterThanOrEqualTo(outlook.semiFinal));
      expect(outlook.semiFinal, greaterThanOrEqualTo(outlook.finalChance));
      expect(outlook.finalChance, greaterThanOrEqualTo(outlook.trophy));
      expect(outlook.round32, inInclusiveRange(0, 100));
      expect(outlook.trophy, inInclusiveRange(0, 100));
      expect(model.cupWinProbability(team), outlook.trophy);
    }

    final brazil = SeedData.teamById('bra');
    final first = model.tournamentOutlook(brazil);
    final second = PredictionModel().tournamentOutlook(brazil);
    expect(second.round32, first.round32);
    expect(second.round16, first.round16);
    expect(second.quarterFinal, first.quarterFinal);
    expect(second.semiFinal, first.semiFinal);
    expect(second.finalChance, first.finalChance);
    expect(second.trophy, first.trophy);
  });

  test('match score label reflects fixture result data', () {
    expect(SeedData.fixtures.first.scoreLabel, '-:-');

    final finished = MatchEntry(
      id: 'sample',
      group: 'A',
      homeTeamId: 'mex',
      awayTeamId: 'rsa',
      kickoffUtc: DateTime.utc(2026, 6, 11, 20),
      venue: 'Mexico City Stadium',
      city: 'Mexico City',
      status: MatchStatus.finished,
      homeScore: 2,
      awayScore: 1,
    );

    expect(finished.hasResult, isTrue);
    expect(finished.scoreLabel, '2:1');
  });

  test('news feed result parses proxy payload', () {
    final result = NewsFeedResult.fromJson({
      'generatedAt': '2026-06-06T12:00:00.000Z',
      'totalFetched': 2,
      'totalMatched': 1,
      'errors': const [],
      'items': [
        {
          'source': 'ESPN',
          'sourceTitle': 'ESPN Soccer',
          'title': 'World Cup headline',
          'summary': 'A short RSS summary.',
          'link': 'https://www.espn.com/soccer/story/example',
          'publishedLabel': 'Sat, 6 Jun 2026 11:06:01 EST',
          'publishedAtMillis': 1780758361000,
          'imageUrl': null,
        },
      ],
    });

    expect(result.items, hasLength(1));
    expect(result.items.first.source, 'ESPN');
    expect(result.items.first.title, 'World Cup headline');
    expect(result.totalMatched, 1);
  });

  test('news client calls the configured API proxy route', () async {
    final client = NewsFeedClient(
      proxyBaseUrl: 'https://sport-ap.test',
      client: MockClient((request) async {
        expect(request.url.scheme, 'https');
        expect(request.url.host, 'sport-ap.test');
        expect(request.url.path, '/api/news');
        expect(request.url.queryParameters, {
          'source': 'espn',
          'scope': 'worldcup',
          'limit': '36',
        });

        return http.Response(
          jsonEncode({
            'generatedAt': '2026-06-09T13:20:00.000Z',
            'totalFetched': 0,
            'totalMatched': 0,
            'errors': const [],
            'items': const [],
          }),
          200,
        );
      }),
    );

    final result = await client.fetchNews(
      source: NewsSourceFilter.espn,
      scope: NewsScopeFilter.worldCup,
    );

    expect(result.items, isEmpty);
    expect(defaultApiProxyBaseUrl(), 'http://127.0.0.1:8787');
  });

  test('news helpers build seven-sentence news briefs', () {
    const article = NewsArticle(
      source: 'ESPN',
      sourceTitle: 'ESPN Soccer',
      title: 'Simulating the World Cup: Who did EA Sports predic...',
      summary:
          'EA Sports has correctly predicted the winners for the past four World Cups. But who does it pick for 2026?',
      link:
          'https://www.espn.com/soccer/story/_/id/48965907/simulating-world-cup-did-ea-predict-winners-how-did-usmnt-get-on',
      publishedLabel: 'Sat, 6 Jun 2026 11:06:01 EST',
      publishedAtMillis: 1780758361000,
      imageUrl: null,
    );

    expect(newsDisplayTitle(article), isNot(contains('...')));
    expect(newsDisplayTitle(article), contains('USMNT'));
    final briefSentences = newsBriefSentences(article);
    final brief = briefSentences.join(' ');
    expect(briefSentences, hasLength(7));
    expect(brief, startsWith('ESPN published'));
    expect(brief, contains('EA Sports has correctly predicted'));
    expect(
      brief,
      contains(
        'The main angle is predictions, expert picks, and tournament outlooks.',
      ),
    );
    expect(brief, isNot(contains('available wording')));
    expect(brief, isNot(contains('According to')));
    expect(brief, isNot(contains('linked below')));
  });

  testWidgets('news article button opens article content in a modal', (
    tester,
  ) async {
    const article = NewsArticle(
      source: 'ESPN',
      sourceTitle: 'ESPN Soccer',
      title: 'World Cup headline',
      summary: 'A short RSS summary.',
      link: 'https://www.espn.com/soccer/story/example',
      publishedLabel: 'Sat, 6 Jun 2026 11:06:01 EST',
      publishedAtMillis: 1780758361000,
      imageUrl: null,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: NewsArticleCard(item: article),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Full article at ESPN'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Close article'), findsOneWidget);
    expect(find.text('World Cup headline'), findsWidgets);
    expect(find.text('News brief'), findsWidgets);
    expect(find.textContaining('A short RSS summary.'), findsWidgets);
    expect(find.textContaining('The main angle is'), findsWidgets);
    expect(
      find.text('https://www.espn.com/soccer/story/example'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Close article'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Close article'), findsNothing);
  });

  testWidgets('renders MVP shell and main navigation', (tester) async {
    await tester.pumpWidget(const SportApApp());

    expect(find.text('World Cup 2026'), findsOneWidget);
    expect(find.text('World Cup Futures Dashboard'), findsOneWidget);
    expect(find.text('Golden Boot Favorites'), findsOneWidget);
    expect(find.text('Assist Kings'), findsOneWidget);
    expect(find.text('Highest-Scoring Teams'), findsOneWidget);
    expect(find.text('Developed by Hopix'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('Results'), findsOneWidget);
    expect(find.text('News'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.table_chart_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Groups'), findsWidgets);
    expect(find.text('Group A'), findsOneWidget);
  });

  testWidgets('mobile layout exposes every primary tab', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const SportApApp());

    expect(find.byTooltip('Home'), findsOneWidget);
    expect(find.byTooltip('Schedule & Predictions'), findsOneWidget);
    expect(find.byTooltip('Results'), findsOneWidget);
    expect(find.byTooltip('Groups'), findsOneWidget);
    expect(find.byTooltip('Teams'), findsOneWidget);
    expect(find.byTooltip('News'), findsOneWidget);
  });

  testWidgets('desktop layout uses a header menu', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const SportApApp());

    expect(find.text('Predictions and teams'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.text('Schedule & Predictions').first);
    await tester.pumpAndSettle();

    expect(find.text('Schedule & Predictions'), findsWidgets);
  });

  testWidgets('results page lists fixtures with score placeholders', (
    tester,
  ) async {
    await tester.pumpWidget(const SportApApp());

    await tester.tap(find.text('Results'));
    await tester.pumpAndSettle();

    final match = SeedData.fixtures.first;
    final home = SeedData.teamById(match.homeTeamId);
    final away = SeedData.teamById(match.awayTeamId);

    expect(find.text('Results'), findsWidgets);
    expect(find.text(formatDateTime(match.kickoffUtc.toLocal())), findsWidgets);
    expect(find.text(match.scoreLabel), findsWidgets);
    expect(find.text(home.name), findsWidgets);
    expect(find.text(away.name), findsWidgets);
  });

  testWidgets('schedule rows expand and collapse predictions inline', (
    tester,
  ) async {
    await tester.pumpWidget(const SportApApp());

    await tester.tap(find.text('Schedule').first);
    await tester.pumpAndSettle();

    expect(find.text('Why this %?'), findsNothing);

    await tester.tap(find.byTooltip('Expand details').first);
    await tester.pumpAndSettle();

    expect(find.text('Why this %?'), findsOneWidget);
    expect(find.text('Last 5 matches'), findsOneWidget);
    expect(find.byTooltip('Collapse details'), findsWidgets);

    await tester.tap(find.byTooltip('Collapse details').first);
    await tester.pumpAndSettle();

    expect(find.text('Why this %?'), findsNothing);
  });

  testWidgets('match preview shows percentages and links team names', (
    tester,
  ) async {
    await tester.pumpWidget(const SportApApp());

    await tester.tap(find.text('Schedule').first);
    await tester.pumpAndSettle();

    final match = SeedData.upcomingMatches(limit: 1).first;
    final prediction = PredictionModel().predict(match);
    final home = SeedData.teamById(match.homeTeamId);
    final away = SeedData.teamById(match.awayTeamId);

    expect(find.text('${prediction.homeWin}%'), findsWidgets);
    expect(find.text('${prediction.awayWin}%'), findsWidgets);
    expect(find.textContaining('xG'), findsWidgets);

    final homeLink = find.byTooltip('Open ${home.name}').first;
    await tester.ensureVisible(homeLink);
    await tester.tap(homeLink);
    await tester.pumpAndSettle();

    expect(find.text('${home.name} • profile'), findsOneWidget);
    expect(find.text('Next match'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    final awayLink = find.byTooltip('Open ${away.name}').first;
    await tester.ensureVisible(awayLink);
    await tester.tap(awayLink);
    await tester.pumpAndSettle();

    expect(find.text('${away.name} • profile'), findsOneWidget);
  });

  testWidgets('top search opens a full team page', (tester) async {
    await tester.pumpWidget(const SportApApp());

    await tester.tap(find.byTooltip('Search team'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'Brazil');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Brazil').last);
    await tester.pumpAndSettle();

    expect(find.text('Brazil • profile'), findsOneWidget);
    expect(find.text('Title chance'), findsWidgets);
    expect(find.text('Tournament path'), findsOneWidget);
    expect(find.text('Model profile'), findsOneWidget);

    await tester.tap(find.text('Matches'));
    await tester.pumpAndSettle();

    expect(
      find.text('Tournament fixtures and results for Brazil'),
      findsOneWidget,
    );
    expect(find.text('-:-'), findsWidgets);

    await tester.tap(find.text('Players'));
    await tester.pumpAndSettle();

    expect(find.text('Squad by position (26)'), findsOneWidget);
    expect(find.text('Coach: Carlo Ancelotti'), findsWidgets);
    expect(find.text('Goalkeeper'), findsWidgets);
    expect(find.text('Defender'), findsWidgets);
    expect(find.text('Midfielder'), findsWidgets);
    expect(find.text('Forward'), findsWidgets);
    expect(find.text('Most notable players'), findsWidgets);
  });
}
