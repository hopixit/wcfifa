import 'dart:math';

import 'models.dart';
import 'seed_data.dart';
import 'tournament_power_data.dart';

class PredictionModel {
  static const String version = 'Poisson seed v2';
  static const int _simulationRuns = 420;
  static const int _maxGoals = 7;

  static final Map<String, _TeamMetrics> _metricsCache = {};
  static Map<String, TeamTournamentOutlook>? _outlookCache;

  int cupWinProbability(Team team) => tournamentOutlook(team).trophy;

  TeamTournamentOutlook tournamentOutlook(Team team) {
    return (_outlookCache ??= _buildTournamentOutlooks())[team.id] ??
        const TeamTournamentOutlook(
          round32: 0,
          round16: 0,
          quarterFinal: 0,
          semiFinal: 0,
          finalChance: 0,
          trophy: 0,
        );
  }

  TeamModelProfile teamProfile(Team team) => _metricsFor(team).profile;

  List<Player> famousPlayers(Team team, {int limit = 5}) {
    final players = [...team.squad];
    players.sort(
      (a, b) => _playerProminence(b).compareTo(_playerProminence(a)),
    );
    return players.take(limit).toList();
  }

  Prediction predict(MatchEntry match) {
    final core = _predictCore(match);
    final home = core.home;
    final away = core.away;
    final percentages = _asPercentages([
      core.homeWinProbability,
      core.drawProbability,
      core.awayWinProbability,
    ]);
    final ordered = [...percentages]..sort((a, b) => b.compareTo(a));
    final spread = (ordered.first - ordered[1]) / 100;
    final confidence =
        (spread * 0.72 +
                (core.homeExpectedGoals - core.awayExpectedGoals).abs() * 0.05 +
                core.dataQuality * 0.18)
            .clamp(0.08, 0.88);

    return Prediction(
      homeWin: percentages[0],
      draw: percentages[1],
      awayWin: percentages[2],
      predictedHomeGoals: core.predictedHomeGoals,
      predictedAwayGoals: core.predictedAwayGoals,
      confidence: confidence,
      explanation: _explanation(core, percentages[0], percentages[2]),
      expectedHomeGoals: core.homeExpectedGoals,
      expectedAwayGoals: core.awayExpectedGoals,
      dataQuality: core.dataQuality,
      homeModelScore: home.modelScore,
      awayModelScore: away.modelScore,
      factors: _factorsFor(core),
      sourceLabel: version,
    );
  }

  _PredictionCore _predictCore(MatchEntry match) {
    final home = SeedData.teamById(match.homeTeamId);
    final away = SeedData.teamById(match.awayTeamId);
    final homeMetrics = _metricsFor(home);
    final awayMetrics = _metricsFor(away);
    final homeContext = _matchContextScore(home, match);
    final awayContext = _matchContextScore(away, match);
    final homeExpectedGoals = _expectedGoals(
      attacking: homeMetrics,
      defending: awayMetrics,
      ownContext: homeContext,
      opponentContext: awayContext,
    );
    final awayExpectedGoals = _expectedGoals(
      attacking: awayMetrics,
      defending: homeMetrics,
      ownContext: awayContext,
      opponentContext: homeContext,
    );
    final scoreGrid = _scoreGrid(homeExpectedGoals, awayExpectedGoals);
    final dataQuality =
        ((homeMetrics.dataQuality + awayMetrics.dataQuality) / 2)
            .clamp(0, 1)
            .toDouble();

    return _PredictionCore(
      match: match,
      home: homeMetrics,
      away: awayMetrics,
      homeContext: homeContext,
      awayContext: awayContext,
      homeExpectedGoals: homeExpectedGoals,
      awayExpectedGoals: awayExpectedGoals,
      homeWinProbability: scoreGrid.homeWin,
      drawProbability: scoreGrid.draw,
      awayWinProbability: scoreGrid.awayWin,
      predictedHomeGoals: scoreGrid.homeGoals,
      predictedAwayGoals: scoreGrid.awayGoals,
      dataQuality: dataQuality,
    );
  }

  _TeamMetrics _metricsFor(Team team) {
    return _metricsCache.putIfAbsent(team.id, () {
      final recent = SeedData.recentMatchesFor(team, count: 20);
      final fifaElo = _estimatedElo(team);
      final rankingScore = (1 - ((team.fifaRanking - 1) / 92)).clamp(0.08, 1.0);
      final eloScore = ((fifaElo - 1400) / (2171 - 1400)).clamp(0.08, 1.0);
      final fifaScore = (eloScore * 0.78 + rankingScore * 0.22).clamp(
        0.08,
        1.0,
      );
      final formScore = _weightedFormScore(team, recent);
      final attackScore = _attackScore(recent);
      final defenseScore = _defenseScore(recent);
      final squad = _squadProfile(team.squad, fifaScore);
      final last10 = recent
          .take(10)
          .fold<int>(0, (sum, match) => sum + match.points);
      final goalsFor = _weightedGoalsFor(recent.take(20));
      final goalsAgainst = _weightedGoalsAgainst(recent.take(20));
      final dataQuality = _dataQuality(team, recent);

      final overall =
          (fifaScore * 0.28 +
                  formScore * 0.16 +
                  attackScore * 0.14 +
                  defenseScore * 0.14 +
                  squad.squadScore * 0.16 +
                  squad.experienceScore * 0.07 +
                  squad.depthScore * 0.05)
              .clamp(0.03, 0.98);

      return _TeamMetrics(
        team: team,
        overall: overall,
        fifaElo: fifaElo,
        fifaScore: fifaScore.toDouble(),
        formScore: formScore,
        attackScore: attackScore,
        defenseScore: defenseScore,
        squadScore: squad.squadScore,
        experienceScore: squad.experienceScore,
        depthScore: squad.depthScore,
        dataQuality: dataQuality,
        last10Points: last10,
        goalsForPerMatch: goalsFor,
        goalsAgainstPerMatch: goalsAgainst,
      );
    });
  }

  double _weightedFormScore(Team team, List<RecentMatch> recent) {
    if (recent.isEmpty) return 0.45;
    var weighted = 0.0;
    var weights = 0.0;
    final teamElo = _estimatedElo(team);

    for (var index = 0; index < recent.length; index += 1) {
      final match = recent[index];
      final opponent = SeedData.teamByNameOrNull(match.opponent);
      final opponentElo = opponent == null ? 1700 : _estimatedElo(opponent);
      final recency = exp(-index / 7.5);
      final competition = match.competition == 'Qualifier' ? 1.0 : 0.72;
      final neutral = match.neutralVenue ? 0.96 : 1.0;
      final weight = recency * competition * neutral;
      final expectedPoints = _expectedPoints(teamElo, opponentElo);
      final resultScore = match.points / 3;
      final overPerformance = ((match.points - expectedPoints) / 3 + 0.5).clamp(
        0.0,
        1.0,
      );

      weighted += (resultScore * 0.64 + overPerformance * 0.36) * weight;
      weights += weight;
    }

    if (weights == 0) return 0.45;
    return (weighted / weights).clamp(0.05, 0.95);
  }

  double _attackScore(List<RecentMatch> recent) {
    final adjustedGoals = recent.indexed.map((entry) {
      final index = entry.$1;
      final match = entry.$2;
      final opponent = SeedData.teamByNameOrNull(match.opponent);
      final opponentStrength = opponent == null
          ? 0.5
          : (1 - ((opponent.fifaRanking - 1) / 92)).clamp(0.08, 1.0);
      final recency = exp(-index / 8);
      final strengthAdjustment = 0.78 + opponentStrength * 0.38;
      return _WeightedValue(
        match.goalsFor * strengthAdjustment,
        recency * _competitionWeight(match),
      );
    }).toList();
    final average = _weightedAverage(adjustedGoals, fallback: 1.05);
    return (average / 2.65).clamp(0.06, 0.97);
  }

  double _defenseScore(List<RecentMatch> recent) {
    final adjustedAgainst = recent.indexed.map((entry) {
      final index = entry.$1;
      final match = entry.$2;
      final opponent = SeedData.teamByNameOrNull(match.opponent);
      final opponentStrength = opponent == null
          ? 0.5
          : (1 - ((opponent.fifaRanking - 1) / 92)).clamp(0.08, 1.0);
      final recency = exp(-index / 8);
      final strengthAdjustment = 1.12 - opponentStrength * 0.34;
      return _WeightedValue(
        match.goalsAgainst * strengthAdjustment,
        recency * _competitionWeight(match),
      );
    }).toList();
    final average = _weightedAverage(adjustedAgainst, fallback: 1.1);
    return (1 - average / 2.55).clamp(0.05, 0.96);
  }

  _SquadProfile _squadProfile(List<Player> squad, double fallbackScore) {
    if (squad.isEmpty) {
      return _SquadProfile(
        squadScore: (fallbackScore * 0.72).clamp(0.08, 0.72),
        experienceScore: (fallbackScore * 0.62).clamp(0.08, 0.65),
        depthScore: 0.2,
      );
    }

    final caps = squad
        .map((player) => player.caps ?? 0)
        .fold<int>(0, (sum, value) => sum + value);
    final goals = squad
        .map((player) => player.goals ?? 0)
        .fold<int>(0, (sum, value) => sum + value);
    final knownAges = squad
        .map((player) => player.age)
        .whereType<int>()
        .toList(growable: false);
    final averageAge = knownAges.isEmpty
        ? 27.5
        : knownAges.fold<int>(0, (sum, value) => sum + value) /
              knownAges.length;
    final ageBalance = (1 - (averageAge - 27.4).abs() / 10).clamp(0.15, 1.0);
    final clubScore = _weightedAverage([
      for (final player in squad) _WeightedValue(_clubTier(player.club), 1),
    ], fallback: fallbackScore);
    final prominence = [...squad]
      ..sort((a, b) => _playerProminence(b).compareTo(_playerProminence(a)));
    final starScore =
        (prominence
                    .take(6)
                    .fold<int>(
                      0,
                      (sum, player) => sum + _playerProminence(player),
                    ) /
                1100)
            .clamp(0.05, 1.0);
    final experienceScore = (caps / (squad.length * 55)).clamp(0.04, 1.0);
    final contributionScore = (goals / (squad.length * 8)).clamp(0.03, 1.0);
    final depthScore = _positionDepthScore(squad);
    final squadScore =
        (clubScore * 0.23 +
                experienceScore * 0.21 +
                contributionScore * 0.16 +
                starScore * 0.18 +
                depthScore * 0.13 +
                ageBalance * 0.09)
            .clamp(0.04, 0.98);

    return _SquadProfile(
      squadScore: squadScore,
      experienceScore: experienceScore,
      depthScore: depthScore,
    );
  }

  double _positionDepthScore(List<Player> squad) {
    final goalkeepers = squad
        .where((player) => player.position == 'Вратар')
        .length;
    final defenders = squad
        .where((player) => player.position == 'Защитник')
        .length;
    final midfielders = squad
        .where((player) => player.position == 'Полузащитник')
        .length;
    final forwards = squad
        .where((player) => player.position == 'Нападател')
        .length;
    final squadSize = (squad.length / 26).clamp(0.65, 1.0);

    return ((goalkeepers / 3).clamp(0.0, 1.0) * 0.2 +
            (defenders / 8).clamp(0.0, 1.0) * 0.24 +
            (midfielders / 8).clamp(0.0, 1.0) * 0.24 +
            (forwards / 5).clamp(0.0, 1.0) * 0.22 +
            squadSize * 0.1)
        .clamp(0.04, 1.0);
  }

  double _dataQuality(Team team, List<RecentMatch> recent) {
    final squadCompleteness = (team.squad.length / 26).clamp(0.0, 1.0);
    final detailFields = team.squad.isEmpty
        ? 0.0
        : team.squad.fold<double>(0, (sum, player) {
                final fields = [
                  player.club,
                  player.age,
                  player.caps,
                  player.goals,
                ].where((value) => value != null).length;
                return sum + fields / 4;
              }) /
              team.squad.length;
    final recentDepth = (recent.length / 20).clamp(0.0, 1.0);

    return (0.26 +
            squadCompleteness * 0.18 +
            detailFields * 0.16 +
            recentDepth * 0.12)
        .clamp(0.3, 0.74);
  }

  double _matchContextScore(Team team, MatchEntry match) {
    var score = 0.5;
    final city = match.city.toLowerCase();
    final mexicoVenue =
        city.contains('mexico') ||
        city.contains('guadalajara') ||
        city.contains('monterrey');
    final canadaVenue = city.contains('toronto') || city.contains('vancouver');
    final usaVenue = !mexicoVenue && !canadaVenue;

    if (team.id == 'mex' && mexicoVenue) score += 0.14;
    if (team.id == 'mex' && city.contains('mexico city')) score += 0.04;
    if (team.id == 'can' && canadaVenue) score += 0.1;
    if (team.id == 'usa' && usaVenue) score += 0.09;

    if (_americasTeams.contains(team.id)) score += 0.025;
    if (_heatCities.any(city.contains) && !_americasTeams.contains(team.id)) {
      score -= 0.018;
    }
    if (match.kickoffUtc.hour >= 23 || match.kickoffUtc.hour <= 3) {
      score -= 0.01;
    }

    return score.clamp(0.38, 0.7);
  }

  double _expectedGoals({
    required _TeamMetrics attacking,
    required _TeamMetrics defending,
    required double ownContext,
    required double opponentContext,
  }) {
    final base = 1.18;
    final attackTerm = (attacking.attackScore - 0.5) * 1.1;
    final defenseTerm = (0.5 - defending.defenseScore) * 0.92;
    final strengthTerm = (attacking.overall - defending.overall) * 0.86;
    final squadTerm = (attacking.squadScore - defending.squadScore) * 0.28;
    final contextTerm = (ownContext - opponentContext) * 0.48;
    final formTerm = (attacking.formScore - defending.formScore) * 0.24;

    return (base +
            attackTerm +
            defenseTerm +
            strengthTerm +
            squadTerm +
            contextTerm +
            formTerm)
        .clamp(0.24, 3.85);
  }

  _ScoreGrid _scoreGrid(double homeLambda, double awayLambda) {
    final homeDistribution = _poissonDistribution(homeLambda);
    final awayDistribution = _poissonDistribution(awayLambda);
    var homeWin = 0.0;
    var draw = 0.0;
    var awayWin = 0.0;
    var bestProbability = -1.0;
    var predictedHome = 0;
    var predictedAway = 0;

    for (var homeGoals = 0; homeGoals <= _maxGoals; homeGoals += 1) {
      for (var awayGoals = 0; awayGoals <= _maxGoals; awayGoals += 1) {
        final probability =
            homeDistribution[homeGoals] * awayDistribution[awayGoals];
        if (homeGoals > awayGoals) {
          homeWin += probability;
        } else if (homeGoals == awayGoals) {
          draw += probability;
        } else {
          awayWin += probability;
        }
        if (probability > bestProbability) {
          bestProbability = probability;
          predictedHome = homeGoals;
          predictedAway = awayGoals;
        }
      }
    }

    final total = homeWin + draw + awayWin;
    return _ScoreGrid(
      homeWin: homeWin / total,
      draw: draw / total,
      awayWin: awayWin / total,
      homeGoals: predictedHome,
      awayGoals: predictedAway,
    );
  }

  List<double> _poissonDistribution(double lambda) {
    final values = <double>[];
    var total = 0.0;
    for (var goals = 0; goals <= _maxGoals; goals += 1) {
      final probability = exp(-lambda) * pow(lambda, goals) / _factorial(goals);
      values.add(probability);
      total += probability;
    }
    return [for (final value in values) value / total];
  }

  int _factorial(int value) {
    var result = 1;
    for (var i = 2; i <= value; i += 1) {
      result *= i;
    }
    return result;
  }

  Map<String, TeamTournamentOutlook> _buildTournamentOutlooks() {
    final counters = {
      for (final team in SeedData.teams) team.id: _TournamentCounter(),
    };
    final random = Random(20260606);

    for (var run = 0; run < _simulationRuns; run += 1) {
      final standings = {
        for (final team in SeedData.teams) team.id: _SimulationStanding(team),
      };

      for (final match in SeedData.fixtures) {
        final core = _predictCore(match);
        final score = _sampleScore(
          random,
          core.homeExpectedGoals,
          core.awayExpectedGoals,
        );
        standings[match.homeTeamId]!.apply(score.$1, score.$2);
        standings[match.awayTeamId]!.apply(score.$2, score.$1);
      }

      final qualifiers = <_Qualifier>[];
      final thirdPlaced = <_Qualifier>[];

      for (final group in SeedData.groups) {
        final rows =
            SeedData.teamsByGroup(
                group,
              ).map((team) => standings[team.id]!).toList()
              ..sort(_compareSimulationRows);

        for (var index = 0; index < rows.length; index += 1) {
          final qualifier = _Qualifier(rows[index], group, index + 1);
          if (index < 2) {
            qualifiers.add(qualifier);
            counters[rows[index].team.id]!.round32 += 1;
          } else if (index == 2) {
            thirdPlaced.add(qualifier);
          }
        }
      }

      thirdPlaced.sort(_compareQualifiers);
      for (final qualifier in thirdPlaced.take(8)) {
        qualifiers.add(qualifier);
        counters[qualifier.team.id]!.round32 += 1;
      }

      qualifiers.sort(_compareQualifiers);
      final seeded = qualifiers.map((qualifier) => qualifier.team).toList();
      var alive = seeded;

      alive = _playKnockoutRound(alive, random);
      for (final team in alive) {
        counters[team.id]!.round16 += 1;
      }

      alive = _playKnockoutRound(alive, random);
      for (final team in alive) {
        counters[team.id]!.quarterFinal += 1;
      }

      alive = _playKnockoutRound(alive, random);
      for (final team in alive) {
        counters[team.id]!.semiFinal += 1;
      }

      alive = _playKnockoutRound(alive, random);
      for (final team in alive) {
        counters[team.id]!.finalChance += 1;
      }

      alive = _playKnockoutRound(alive, random);
      for (final team in alive) {
        counters[team.id]!.trophy += 1;
      }
    }

    return {
      for (final entry in counters.entries)
        entry.key: _externalCalibratedOutlook(
          SeedData.teamById(entry.key),
          TeamTournamentOutlook(
            round32: _counterPercent(entry.value.round32),
            round16: _counterPercent(entry.value.round16),
            quarterFinal: _counterPercent(entry.value.quarterFinal),
            semiFinal: _counterPercent(entry.value.semiFinal),
            finalChance: _counterPercent(entry.value.finalChance),
            trophy: _counterPercent(entry.value.trophy),
          ),
        ),
    };
  }

  TeamTournamentOutlook _externalCalibratedOutlook(
    Team team,
    TeamTournamentOutlook simulated,
  ) {
    final seed = TournamentPowerData.forTeam(team.id);
    if (seed == null) return simulated;

    final trophy = seed.titleChance.round().clamp(0, 100).toInt();
    final round32 = seed.round32.clamp(0, 100).toInt();
    final finalChance = max(
      simulated.finalChance,
      (seed.titleChance * 2.35 + 1.5).round(),
    ).clamp(trophy, round32).toInt();
    final semiFinal = max(
      simulated.semiFinal,
      (finalChance * 1.75 + 2).round(),
    ).clamp(finalChance, round32).toInt();
    final quarterFinal = max(
      simulated.quarterFinal,
      (semiFinal * 1.55 + 3).round(),
    ).clamp(semiFinal, round32).toInt();
    final round16 = max(
      simulated.round16,
      (quarterFinal * 1.42 + 4).round(),
    ).clamp(quarterFinal, round32).toInt();

    return TeamTournamentOutlook(
      round32: round32,
      round16: round16,
      quarterFinal: quarterFinal,
      semiFinal: semiFinal,
      finalChance: finalChance,
      trophy: trophy,
    );
  }

  List<Team> _playKnockoutRound(List<Team> entrants, Random random) {
    final winners = <Team>[];
    final half = entrants.length ~/ 2;
    for (var index = 0; index < half; index += 1) {
      final first = entrants[index];
      final second = entrants[entrants.length - 1 - index];
      final firstWin = _knockoutWinProbability(first, second);
      winners.add(random.nextDouble() < firstWin ? first : second);
    }
    return winners;
  }

  double _knockoutWinProbability(Team first, Team second) {
    final firstMetrics = _metricsFor(first);
    final secondMetrics = _metricsFor(second);
    final eloDiff = (firstMetrics.fifaElo - secondMetrics.fifaElo) / 420;
    final modelDiff = (firstMetrics.overall - secondMetrics.overall) * 4.2;
    final squadDiff =
        (firstMetrics.squadScore - secondMetrics.squadScore) * 0.85;
    final formDiff = (firstMetrics.formScore - secondMetrics.formScore) * 0.65;
    final value = modelDiff + eloDiff + squadDiff + formDiff;
    return (1 / (1 + exp(-value))).clamp(0.12, 0.88);
  }

  (int, int) _sampleScore(Random random, double homeLambda, double awayLambda) {
    return (
      _samplePoisson(random, homeLambda).clamp(0, _maxGoals),
      _samplePoisson(random, awayLambda).clamp(0, _maxGoals),
    );
  }

  int _samplePoisson(Random random, double lambda) {
    final limit = exp(-lambda);
    var product = 1.0;
    var goals = 0;
    do {
      goals += 1;
      product *= random.nextDouble();
    } while (product > limit && goals <= _maxGoals + 2);
    return goals - 1;
  }

  int _compareSimulationRows(
    _SimulationStanding first,
    _SimulationStanding second,
  ) {
    final points = second.points.compareTo(first.points);
    if (points != 0) return points;
    final goalDifference = second.goalDifference.compareTo(
      first.goalDifference,
    );
    if (goalDifference != 0) return goalDifference;
    final goalsFor = second.goalsFor.compareTo(first.goalsFor);
    if (goalsFor != 0) return goalsFor;
    return _metricsFor(
      second.team,
    ).overall.compareTo(_metricsFor(first.team).overall);
  }

  int _compareQualifiers(_Qualifier first, _Qualifier second) {
    final position = first.groupPosition.compareTo(second.groupPosition);
    if (position != 0) return position;
    final points = second.row.points.compareTo(first.row.points);
    if (points != 0) return points;
    final goalDifference = second.row.goalDifference.compareTo(
      first.row.goalDifference,
    );
    if (goalDifference != 0) return goalDifference;
    final strength = _metricsFor(
      second.team,
    ).overall.compareTo(_metricsFor(first.team).overall);
    if (strength != 0) return strength;
    return first.group.compareTo(second.group);
  }

  int _counterPercent(int count) {
    return (count / _simulationRuns * 100).round().clamp(0, 100);
  }

  int _estimatedElo(Team team) {
    final fallback = (2242 - (team.fifaRanking - 1) * 8.15).round().clamp(
      1360,
      2245,
    );
    return TournamentPowerData.eloFor(team.id, fallback);
  }

  double _expectedPoints(int teamElo, int opponentElo) {
    final winProbability = 1 / (1 + pow(10, (opponentElo - teamElo) / 430));
    final drawProbability =
        (0.18 + (1 - (winProbability - 0.5).abs() * 2) * 0.16).clamp(
          0.12,
          0.34,
        );
    return winProbability * (3 - drawProbability) + drawProbability;
  }

  double _weightedGoalsFor(Iterable<RecentMatch> matches) {
    final values = matches.indexed
        .map(
          (entry) => _WeightedValue(
            entry.$2.goalsFor.toDouble(),
            exp(-entry.$1 / 8) * _competitionWeight(entry.$2),
          ),
        )
        .toList();
    return _weightedAverage(values, fallback: 1.1);
  }

  double _weightedGoalsAgainst(Iterable<RecentMatch> matches) {
    final values = matches.indexed
        .map(
          (entry) => _WeightedValue(
            entry.$2.goalsAgainst.toDouble(),
            exp(-entry.$1 / 8) * _competitionWeight(entry.$2),
          ),
        )
        .toList();
    return _weightedAverage(values, fallback: 1.1);
  }

  double _weightedAverage(
    List<_WeightedValue> values, {
    required double fallback,
  }) {
    if (values.isEmpty) return fallback;
    final weight = values.fold<double>(0, (sum, value) => sum + value.weight);
    if (weight == 0) return fallback;
    return values.fold<double>(
          0,
          (sum, value) => sum + value.value * value.weight,
        ) /
        weight;
  }

  double _competitionWeight(RecentMatch match) {
    return match.competition == 'Qualifier' ? 1.0 : 0.72;
  }

  int _playerProminence(Player player) {
    final caps = player.caps ?? 0;
    final goals = player.goals ?? 0;
    final clubBonus = (_clubTier(player.club) * 20).round();
    final positionBonus = switch (player.position) {
      'Нападател' => 18,
      'Полузащитник' => 12,
      'Вратар' => 10,
      _ => 6,
    };
    return caps * 2 + goals * 5 + clubBonus + positionBonus;
  }

  double _clubTier(String? club) {
    if (club == null || club.isEmpty) return 0.42;
    final value = club.toLowerCase();
    if (_eliteClubKeywords.any(value.contains)) return 1;
    if (_strongClubKeywords.any(value.contains)) return 0.78;
    if (_europeanClubKeywords.any(value.contains)) return 0.62;
    if (_competitiveClubKeywords.any(value.contains)) return 0.52;
    return 0.38;
  }

  List<PredictionFactor> _factorsFor(_PredictionCore core) {
    return [
      PredictionFactor(
        label: 'FIFA/Elo',
        homeValue: '#${core.home.team.fifaRanking} / ${core.home.fifaElo}',
        awayValue: '#${core.away.team.fifaRanking} / ${core.away.fifaElo}',
        homeScore: core.home.fifaScore,
        awayScore: core.away.fifaScore,
        description:
            'FIFA ranking is blended with an external World Football Elo seed.',
      ),
      PredictionFactor(
        label: 'Form 20',
        homeValue: '${core.home.last10Points}/30',
        awayValue: '${core.away.last10Points}/30',
        homeScore: core.home.formScore,
        awayScore: core.away.formScore,
        description: 'Recent matches are weighted by recency and competition.',
      ),
      PredictionFactor(
        label: 'Attack/defense',
        homeValue:
            '${core.home.goalsForPerMatch.toStringAsFixed(1)} / ${core.home.goalsAgainstPerMatch.toStringAsFixed(1)}',
        awayValue:
            '${core.away.goalsForPerMatch.toStringAsFixed(1)} / ${core.away.goalsAgainstPerMatch.toStringAsFixed(1)}',
        homeScore: (core.home.attackScore + core.home.defenseScore) / 2,
        awayScore: (core.away.attackScore + core.away.defenseScore) / 2,
        description: 'Goals are adjusted for opponent strength.',
      ),
      PredictionFactor(
        label: 'Squad',
        homeValue: '${(core.home.squadScore * 100).round()}/100',
        awayValue: '${(core.away.squadScore * 100).round()}/100',
        homeScore: core.home.squadScore,
        awayScore: core.away.squadScore,
        description: 'Caps, goals, age balance, club tier and depth.',
      ),
      PredictionFactor(
        label: 'Context',
        homeValue: '${(core.homeContext * 100).round()}/100',
        awayValue: '${(core.awayContext * 100).round()}/100',
        homeScore: core.homeContext,
        awayScore: core.awayContext,
        description: 'Host country, region and venue effects.',
      ),
    ];
  }

  String _explanation(_PredictionCore core, int homeWin, int awayWin) {
    final leader = homeWin >= awayWin ? core.home : core.away;
    final factors = _factorsFor(core).toList()
      ..sort(
        (a, b) => (b.homeScore - b.awayScore).abs().compareTo(
          (a.homeScore - a.awayScore).abs(),
        ),
      );
    final topFactors = factors
        .take(3)
        .map((factor) => factor.label.toLowerCase())
        .join(', ');
    final quality = (core.dataQuality * 100).round();

    return 'The V2 model uses Poisson expected goals (${core.homeExpectedGoals.toStringAsFixed(2)}:${core.awayExpectedGoals.toStringAsFixed(2)}) and weighs $topFactors. Slight edge: ${leader.team.name}. Local data quality: $quality%.';
  }

  List<int> _asPercentages(List<double> values) {
    final safe = values.map((value) => value.clamp(0.01, 0.98)).toList();
    final total = safe.fold<double>(0, (sum, value) => sum + value);
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

  static const Set<String> _americasTeams = {
    'arg',
    'bra',
    'can',
    'col',
    'crc',
    'cur',
    'ecu',
    'hai',
    'mex',
    'pan',
    'par',
    'uru',
    'usa',
  };

  static const List<String> _heatCities = [
    'atlanta',
    'dallas',
    'guadalajara',
    'houston',
    'miami',
    'monterrey',
  ];

  static const List<String> _eliteClubKeywords = [
    'arsenal',
    'atlético madrid',
    'barcelona',
    'bayern',
    'chelsea',
    'inter',
    'juventus',
    'liverpool',
    'manchester city',
    'manchester united',
    'milan',
    'napoli',
    'paris saint-germain',
    'psg',
    'real madrid',
  ];

  static const List<String> _strongClubKeywords = [
    'ajax',
    'aston villa',
    'atalanta',
    'benfica',
    'bologna',
    'borussia dortmund',
    'brighton',
    'bayer leverkusen',
    'feyenoord',
    'leipzig',
    'marseille',
    'monaco',
    'newcastle',
    'porto',
    'psv',
    'roma',
    'sevilla',
    'sporting',
    'tottenham',
    'valencia',
    'west ham',
  ];

  static const List<String> _europeanClubKeywords = [
    'anderlecht',
    'az',
    'basel',
    'betis',
    'braga',
    'brugge',
    'celtic',
    'dinamo',
    'eintracht',
    'fenerbahçe',
    'fulham',
    'galatasaray',
    'gent',
    'genk',
    'girona',
    'lazio',
    'leeds',
    'lille',
    'lyon',
    'nice',
    'nottingham',
    'rangers',
    'real sociedad',
    'rennes',
    'salzburg',
    'stuttgart',
    'torino',
    'twente',
    'villarreal',
    'wolfsburg',
    'young boys',
  ];

  static const List<String> _competitiveClubKeywords = [
    'al-ahli',
    'al-hilal',
    'al-ittihad',
    'al-nassr',
    'america',
    'boca',
    'club américa',
    'cruz azul',
    'flamengo',
    'fluminense',
    'inter miami',
    'la galaxy',
    'monterrey',
    'palmeiras',
    'river plate',
    'santos',
    'tigres',
  ];
}

class _PredictionCore {
  const _PredictionCore({
    required this.match,
    required this.home,
    required this.away,
    required this.homeContext,
    required this.awayContext,
    required this.homeExpectedGoals,
    required this.awayExpectedGoals,
    required this.homeWinProbability,
    required this.drawProbability,
    required this.awayWinProbability,
    required this.predictedHomeGoals,
    required this.predictedAwayGoals,
    required this.dataQuality,
  });

  final MatchEntry match;
  final _TeamMetrics home;
  final _TeamMetrics away;
  final double homeContext;
  final double awayContext;
  final double homeExpectedGoals;
  final double awayExpectedGoals;
  final double homeWinProbability;
  final double drawProbability;
  final double awayWinProbability;
  final int predictedHomeGoals;
  final int predictedAwayGoals;
  final double dataQuality;
}

class _TeamMetrics {
  const _TeamMetrics({
    required this.team,
    required this.overall,
    required this.fifaElo,
    required this.fifaScore,
    required this.formScore,
    required this.attackScore,
    required this.defenseScore,
    required this.squadScore,
    required this.experienceScore,
    required this.depthScore,
    required this.dataQuality,
    required this.last10Points,
    required this.goalsForPerMatch,
    required this.goalsAgainstPerMatch,
  });

  final Team team;
  final double overall;
  final int fifaElo;
  final double fifaScore;
  final double formScore;
  final double attackScore;
  final double defenseScore;
  final double squadScore;
  final double experienceScore;
  final double depthScore;
  final double dataQuality;
  final int last10Points;
  final double goalsForPerMatch;
  final double goalsAgainstPerMatch;

  int get modelScore => (overall * 100).round().clamp(1, 99);

  TeamModelProfile get profile => TeamModelProfile(
    overall: overall,
    fifaElo: fifaElo,
    fifaScore: fifaScore,
    formScore: formScore,
    attackScore: attackScore,
    defenseScore: defenseScore,
    squadScore: squadScore,
    experienceScore: experienceScore,
    depthScore: depthScore,
    dataQuality: dataQuality,
    last10Points: last10Points,
    goalsForPerMatch: goalsForPerMatch,
    goalsAgainstPerMatch: goalsAgainstPerMatch,
  );
}

class _SquadProfile {
  const _SquadProfile({
    required this.squadScore,
    required this.experienceScore,
    required this.depthScore,
  });

  final double squadScore;
  final double experienceScore;
  final double depthScore;
}

class _WeightedValue {
  const _WeightedValue(this.value, this.weight);

  final double value;
  final double weight;
}

class _ScoreGrid {
  const _ScoreGrid({
    required this.homeWin,
    required this.draw,
    required this.awayWin,
    required this.homeGoals,
    required this.awayGoals,
  });

  final double homeWin;
  final double draw;
  final double awayWin;
  final int homeGoals;
  final int awayGoals;
}

class _SimulationStanding {
  _SimulationStanding(this.team);

  final Team team;
  int points = 0;
  int goalsFor = 0;
  int goalsAgainst = 0;

  int get goalDifference => goalsFor - goalsAgainst;

  void apply(int scored, int conceded) {
    goalsFor += scored;
    goalsAgainst += conceded;
    if (scored > conceded) {
      points += 3;
    } else if (scored == conceded) {
      points += 1;
    }
  }
}

class _Qualifier {
  const _Qualifier(this.row, this.group, this.groupPosition);

  final _SimulationStanding row;
  final String group;
  final int groupPosition;

  Team get team => row.team;
}

class _TournamentCounter {
  int round32 = 0;
  int round16 = 0;
  int quarterFinal = 0;
  int semiFinal = 0;
  int finalChance = 0;
  int trophy = 0;
}
