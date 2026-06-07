enum MatchStatus { upcoming, live, finished }

extension MatchStatusLabel on MatchStatus {
  String get label {
    switch (this) {
      case MatchStatus.upcoming:
        return 'Upcoming';
      case MatchStatus.live:
        return 'Live';
      case MatchStatus.finished:
        return 'Finished';
    }
  }
}

class Player {
  const Player({
    required this.name,
    required this.position,
    this.club,
    this.number,
    this.age,
    this.caps,
    this.goals,
  });

  final String name;
  final String position;
  final String? club;
  final int? number;
  final int? age;
  final int? caps;
  final int? goals;
}

class Team {
  const Team({
    required this.id,
    required this.name,
    required this.group,
    required this.flag,
    required this.fifaRanking,
    required this.coach,
    this.squad = const [],
  });

  final String id;
  final String name;
  final String group;
  final String flag;
  final int fifaRanking;
  final String coach;
  final List<Player> squad;
}

class MatchEntry {
  const MatchEntry({
    required this.id,
    required this.group,
    required this.homeTeamId,
    required this.awayTeamId,
    required this.kickoffUtc,
    required this.venue,
    required this.city,
    required this.status,
    this.homeScore,
    this.awayScore,
  });

  final String id;
  final String group;
  final String homeTeamId;
  final String awayTeamId;
  final DateTime kickoffUtc;
  final String venue;
  final String city;
  final MatchStatus status;
  final int? homeScore;
  final int? awayScore;

  bool get hasResult => homeScore != null && awayScore != null;
  String get scoreLabel => hasResult ? '$homeScore:$awayScore' : '-:-';
}

class RecentMatch {
  const RecentMatch({
    required this.date,
    required this.opponent,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.competition,
    required this.neutralVenue,
  });

  final DateTime date;
  final String opponent;
  final int goalsFor;
  final int goalsAgainst;
  final String competition;
  final bool neutralVenue;

  int get points {
    if (goalsFor > goalsAgainst) return 3;
    if (goalsFor == goalsAgainst) return 1;
    return 0;
  }

  String get resultLabel {
    if (goalsFor > goalsAgainst) return 'W';
    if (goalsFor == goalsAgainst) return 'D';
    return 'L';
  }
}

class Prediction {
  const Prediction({
    required this.homeWin,
    required this.draw,
    required this.awayWin,
    required this.predictedHomeGoals,
    required this.predictedAwayGoals,
    required this.confidence,
    required this.explanation,
    this.expectedHomeGoals = 0,
    this.expectedAwayGoals = 0,
    this.dataQuality = 0,
    this.homeModelScore = 0,
    this.awayModelScore = 0,
    this.factors = const [],
    this.sourceLabel = 'Local model',
  });

  final int homeWin;
  final int draw;
  final int awayWin;
  final int predictedHomeGoals;
  final int predictedAwayGoals;
  final double confidence;
  final String explanation;
  final double expectedHomeGoals;
  final double expectedAwayGoals;
  final double dataQuality;
  final int homeModelScore;
  final int awayModelScore;
  final List<PredictionFactor> factors;
  final String sourceLabel;

  String get score => '$predictedHomeGoals:$predictedAwayGoals';
}

class PredictionFactor {
  const PredictionFactor({
    required this.label,
    required this.homeValue,
    required this.awayValue,
    required this.homeScore,
    required this.awayScore,
    required this.description,
  });

  final String label;
  final String homeValue;
  final String awayValue;
  final double homeScore;
  final double awayScore;
  final String description;
}

class TeamModelProfile {
  const TeamModelProfile({
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
  int get dataQualityPercent => (dataQuality * 100).round().clamp(1, 100);
}

class TeamTournamentOutlook {
  const TeamTournamentOutlook({
    required this.round32,
    required this.round16,
    required this.quarterFinal,
    required this.semiFinal,
    required this.finalChance,
    required this.trophy,
  });

  final int round32;
  final int round16;
  final int quarterFinal;
  final int semiFinal;
  final int finalChance;
  final int trophy;
}

class TeamWorldCupRecord {
  const TeamWorldCupRecord({
    required this.firstWorldCup,
    required this.participationsBefore2026,
    required this.played,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.goalsScored,
    required this.goalsConceded,
  });

  final int firstWorldCup;
  final int participationsBefore2026;
  final int played;
  final int wins;
  final int draws;
  final int losses;
  final int goalsScored;
  final int goalsConceded;

  int get participationIn2026 => participationsBefore2026 + 1;
  bool get isDebut => participationsBefore2026 == 0;
}

class StandingRow {
  const StandingRow({
    required this.team,
    required this.played,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.points,
  });

  final Team team;
  final int played;
  final int wins;
  final int draws;
  final int losses;
  final int goalsFor;
  final int goalsAgainst;
  final int points;

  int get goalDifference => goalsFor - goalsAgainst;
}
