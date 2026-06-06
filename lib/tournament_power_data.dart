class TournamentPowerSeed {
  const TournamentPowerSeed({
    required this.teamId,
    required this.elo,
    required this.round32,
    required this.titleChance,
  });

  final String teamId;
  final int elo;
  final int round32;
  final double titleChance;
}

class TournamentPowerData {
  static const String sourceLabel =
      'Elo + market/model consensus, updated June 2026';

  static const Map<String, TournamentPowerSeed> byTeamId = {
    'esp': TournamentPowerSeed(
      teamId: 'esp',
      elo: 2171,
      round32: 96,
      titleChance: 19,
    ),
    'fra': TournamentPowerSeed(
      teamId: 'fra',
      elo: 2063,
      round32: 86,
      titleChance: 16,
    ),
    'arg': TournamentPowerSeed(
      teamId: 'arg',
      elo: 2113,
      round32: 95,
      titleChance: 14,
    ),
    'eng': TournamentPowerSeed(
      teamId: 'eng',
      elo: 2042,
      round32: 95,
      titleChance: 9,
    ),
    'bra': TournamentPowerSeed(
      teamId: 'bra',
      elo: 1978,
      round32: 89,
      titleChance: 7,
    ),
    'por': TournamentPowerSeed(
      teamId: 'por',
      elo: 1976,
      round32: 92,
      titleChance: 5.5,
    ),
    'ger': TournamentPowerSeed(
      teamId: 'ger',
      elo: 1910,
      round32: 88,
      titleChance: 5,
    ),
    'ned': TournamentPowerSeed(
      teamId: 'ned',
      elo: 1959,
      round32: 91,
      titleChance: 4,
    ),
    'col': TournamentPowerSeed(
      teamId: 'col',
      elo: 1998,
      round32: 89,
      titleChance: 3,
    ),
    'nor': TournamentPowerSeed(
      teamId: 'nor',
      elo: 1922,
      round32: 70,
      titleChance: 3,
    ),
    'cro': TournamentPowerSeed(
      teamId: 'cro',
      elo: 1932,
      round32: 86,
      titleChance: 2,
    ),
    'ecu': TournamentPowerSeed(
      teamId: 'ecu',
      elo: 1933,
      round32: 82,
      titleChance: 2,
    ),
    'uru': TournamentPowerSeed(
      teamId: 'uru',
      elo: 1890,
      round32: 82,
      titleChance: 2,
    ),
    'bel': TournamentPowerSeed(
      teamId: 'bel',
      elo: 1849,
      round32: 82,
      titleChance: 2,
    ),
    'mar': TournamentPowerSeed(
      teamId: 'mar',
      elo: 1840,
      round32: 72,
      titleChance: 1.5,
    ),
    'jpn': TournamentPowerSeed(
      teamId: 'jpn',
      elo: 1878,
      round32: 79,
      titleChance: 1.2,
    ),
    'sui': TournamentPowerSeed(
      teamId: 'sui',
      elo: 1897,
      round32: 83,
      titleChance: 1.2,
    ),
    'tur': TournamentPowerSeed(
      teamId: 'tur',
      elo: 1880,
      round32: 75,
      titleChance: 1,
    ),
    'mex': TournamentPowerSeed(
      teamId: 'mex',
      elo: 1835,
      round32: 77,
      titleChance: 1,
    ),
    'sen': TournamentPowerSeed(
      teamId: 'sen',
      elo: 1806,
      round32: 68,
      titleChance: 0.8,
    ),
    'aut': TournamentPowerSeed(
      teamId: 'aut',
      elo: 1818,
      round32: 70,
      titleChance: 0.8,
    ),
    'can': TournamentPowerSeed(
      teamId: 'can',
      elo: 1803,
      round32: 68,
      titleChance: 0.6,
    ),
    'par': TournamentPowerSeed(
      teamId: 'par',
      elo: 1833,
      round32: 68,
      titleChance: 0.6,
    ),
    'usa': TournamentPowerSeed(
      teamId: 'usa',
      elo: 1747,
      round32: 63,
      titleChance: 0.6,
    ),
    'alg': TournamentPowerSeed(
      teamId: 'alg',
      elo: 1757,
      round32: 60,
      titleChance: 0.4,
    ),
    'irn': TournamentPowerSeed(
      teamId: 'irn',
      elo: 1754,
      round32: 61,
      titleChance: 0.4,
    ),
    'kor': TournamentPowerSeed(
      teamId: 'kor',
      elo: 1784,
      round32: 63,
      titleChance: 0.4,
    ),
    'aus': TournamentPowerSeed(
      teamId: 'aus',
      elo: 1774,
      round32: 59,
      titleChance: 0.3,
    ),
    'sco': TournamentPowerSeed(
      teamId: 'sco',
      elo: 1790,
      round32: 57,
      titleChance: 0.3,
    ),
    'pan': TournamentPowerSeed(
      teamId: 'pan',
      elo: 1742,
      round32: 45,
      titleChance: 0.2,
    ),
    'uzb': TournamentPowerSeed(
      teamId: 'uzb',
      elo: 1735,
      round32: 48,
      titleChance: 0.2,
    ),
    'cze': TournamentPowerSeed(
      teamId: 'cze',
      elo: 1731,
      round32: 50,
      titleChance: 0.2,
    ),
    'swe': TournamentPowerSeed(
      teamId: 'swe',
      elo: 1660,
      round32: 43,
      titleChance: 0.2,
    ),
    'cod': TournamentPowerSeed(
      teamId: 'cod',
      elo: 1657,
      round32: 36,
      titleChance: 0.1,
    ),
    'civ': TournamentPowerSeed(
      teamId: 'civ',
      elo: 1627,
      round32: 45,
      titleChance: 0.1,
    ),
    'egy': TournamentPowerSeed(
      teamId: 'egy',
      elo: 1623,
      round32: 47,
      titleChance: 0.1,
    ),
    'tun': TournamentPowerSeed(
      teamId: 'tun',
      elo: 1615,
      round32: 41,
      titleChance: 0.1,
    ),
    'ksa': TournamentPowerSeed(
      teamId: 'ksa',
      elo: 1593,
      round32: 36,
      titleChance: 0.1,
    ),
    'irq': TournamentPowerSeed(
      teamId: 'irq',
      elo: 1583,
      round32: 30,
      titleChance: 0.1,
    ),
    'bih': TournamentPowerSeed(
      teamId: 'bih',
      elo: 1571,
      round32: 29,
      titleChance: 0.1,
    ),
    'cpv': TournamentPowerSeed(
      teamId: 'cpv',
      elo: 1561,
      round32: 31,
      titleChance: 0.1,
    ),
    'rsa': TournamentPowerSeed(
      teamId: 'rsa',
      elo: 1551,
      round32: 26,
      titleChance: 0.1,
    ),
    'hai': TournamentPowerSeed(
      teamId: 'hai',
      elo: 1542,
      round32: 22,
      titleChance: 0.1,
    ),
    'gha': TournamentPowerSeed(
      teamId: 'gha',
      elo: 1509,
      round32: 24,
      titleChance: 0.1,
    ),
    'nzl': TournamentPowerSeed(
      teamId: 'nzl',
      elo: 1586,
      round32: 22,
      titleChance: 0.1,
    ),
    'cur': TournamentPowerSeed(
      teamId: 'cur',
      elo: 1467,
      round32: 18,
      titleChance: 0.1,
    ),
    'qat': TournamentPowerSeed(
      teamId: 'qat',
      elo: 1427,
      round32: 17,
      titleChance: 0.1,
    ),
    'jor': TournamentPowerSeed(
      teamId: 'jor',
      elo: 1691,
      round32: 20,
      titleChance: 0.1,
    ),
  };

  static TournamentPowerSeed? forTeam(String teamId) => byTeamId[teamId];

  static int eloFor(String teamId, int fallback) {
    return byTeamId[teamId]?.elo ?? fallback;
  }
}
