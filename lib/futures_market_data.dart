class FuturesMarketEntry {
  const FuturesMarketEntry({
    required this.name,
    required this.teamId,
    required this.value,
    required this.meta,
    required this.note,
  });

  final String name;
  final String teamId;
  final int value;
  final String meta;
  final String note;
}

class FuturesMarketData {
  static const List<FuturesMarketEntry> goldenBoot = [
    FuturesMarketEntry(
      name: 'Kylian Mbappe',
      teamId: 'fra',
      value: 16,
      meta: 'Golden Boot chance',
      note: 'France focal point and penalty threat',
    ),
    FuturesMarketEntry(
      name: 'Harry Kane',
      teamId: 'eng',
      value: 12,
      meta: 'Golden Boot chance',
      note: 'Elite finisher in a favorable group',
    ),
    FuturesMarketEntry(
      name: 'Erling Haaland',
      teamId: 'nor',
      value: 6,
      meta: 'Golden Boot chance',
      note: 'Huge scoring ceiling if Norway advance',
    ),
    FuturesMarketEntry(
      name: 'Mikel Oyarzabal',
      teamId: 'esp',
      value: 6,
      meta: 'Golden Boot chance',
      note: 'Spain No. 9 profile on the title favorite',
    ),
    FuturesMarketEntry(
      name: 'Lionel Messi',
      teamId: 'arg',
      value: 6,
      meta: 'Golden Boot chance',
      note: 'Set pieces, penalties and tournament path',
    ),
    FuturesMarketEntry(
      name: 'Lamine Yamal',
      teamId: 'esp',
      value: 5,
      meta: 'Golden Boot chance',
      note: 'High-volume Spain attacker',
    ),
    FuturesMarketEntry(
      name: 'Cristiano Ronaldo',
      teamId: 'por',
      value: 5,
      meta: 'Golden Boot chance',
      note: 'Portugal volume and penalty role',
    ),
    FuturesMarketEntry(
      name: 'Vinicius Junior',
      teamId: 'bra',
      value: 4,
      meta: 'Golden Boot chance',
      note: 'Brazil transition threat',
    ),
  ];

  static const List<FuturesMarketEntry> assistKings = [
    FuturesMarketEntry(
      name: 'Bruno Fernandes',
      teamId: 'por',
      value: 10,
      meta: 'Most assists implied chance',
      note: 'Portugal creator and set-piece hub',
    ),
    FuturesMarketEntry(
      name: 'Michael Olise',
      teamId: 'fra',
      value: 9,
      meta: 'Most assists implied chance',
      note: 'France service into elite finishers',
    ),
    FuturesMarketEntry(
      name: 'Lionel Messi',
      teamId: 'arg',
      value: 8,
      meta: 'Most assists implied chance',
      note: 'Argentina creator with set pieces',
    ),
    FuturesMarketEntry(
      name: 'Lamine Yamal',
      teamId: 'esp',
      value: 8,
      meta: 'Most assists implied chance',
      note: 'Spain winger and chance creator',
    ),
    FuturesMarketEntry(
      name: 'Vinicius Junior',
      teamId: 'bra',
      value: 7,
      meta: 'Most assists implied chance',
      note: 'Brazil carry-and-create outlet',
    ),
    FuturesMarketEntry(
      name: 'Kevin De Bruyne',
      teamId: 'bel',
      value: 5,
      meta: 'Most assists implied chance',
      note: 'Belgium set-piece and through-ball specialist',
    ),
    FuturesMarketEntry(
      name: 'Florian Wirtz',
      teamId: 'ger',
      value: 5,
      meta: 'Most assists implied chance',
      note: 'Germany between-the-lines creator',
    ),
    FuturesMarketEntry(
      name: 'Raphinha',
      teamId: 'bra',
      value: 4,
      meta: 'Most assists implied chance',
      note: 'Brazil wide delivery and shots',
    ),
  ];

  static const List<FuturesMarketEntry> bestPassingTeams = [
    FuturesMarketEntry(
      name: 'Spain',
      teamId: 'esp',
      value: 94,
      meta: 'Control index',
      note: 'Possession, rotations and chance volume',
    ),
    FuturesMarketEntry(
      name: 'Germany',
      teamId: 'ger',
      value: 88,
      meta: 'Control index',
      note: 'Aggressive midfield and territorial pressure',
    ),
    FuturesMarketEntry(
      name: 'Netherlands',
      teamId: 'ned',
      value: 86,
      meta: 'Control index',
      note: 'Structured build-up and technical depth',
    ),
    FuturesMarketEntry(
      name: 'Portugal',
      teamId: 'por',
      value: 85,
      meta: 'Control index',
      note: 'Creative midfield plus elite wide talent',
    ),
    FuturesMarketEntry(
      name: 'Argentina',
      teamId: 'arg',
      value: 84,
      meta: 'Control index',
      note: 'Tempo control through Messi and midfield depth',
    ),
    FuturesMarketEntry(
      name: 'France',
      teamId: 'fra',
      value: 83,
      meta: 'Control index',
      note: 'Direct power with enough midfield security',
    ),
    FuturesMarketEntry(
      name: 'England',
      teamId: 'eng',
      value: 82,
      meta: 'Control index',
      note: 'Bellingham, Foden and Kane link play',
    ),
    FuturesMarketEntry(
      name: 'Brazil',
      teamId: 'bra',
      value: 81,
      meta: 'Control index',
      note: 'Fast circulation into elite forwards',
    ),
  ];

  static const List<FuturesMarketEntry> highestScoringTeams = [
    FuturesMarketEntry(
      name: 'Spain',
      teamId: 'esp',
      value: 22,
      meta: 'Highest-scoring team implied chance',
      note: 'Market leader at 7/2',
    ),
    FuturesMarketEntry(
      name: 'Brazil',
      teamId: 'bra',
      value: 17,
      meta: 'Highest-scoring team implied chance',
      note: 'Forward depth and open-game ceiling',
    ),
    FuturesMarketEntry(
      name: 'Germany',
      teamId: 'ger',
      value: 15,
      meta: 'Highest-scoring team implied chance',
      note: 'Aggressive chance creation profile',
    ),
    FuturesMarketEntry(
      name: 'England',
      teamId: 'eng',
      value: 14,
      meta: 'Highest-scoring team implied chance',
      note: 'Kane plus favorable group scoring spots',
    ),
    FuturesMarketEntry(
      name: 'France',
      teamId: 'fra',
      value: 14,
      meta: 'Highest-scoring team implied chance',
      note: 'Mbappe-led attack and deep run potential',
    ),
    FuturesMarketEntry(
      name: 'Argentina',
      teamId: 'arg',
      value: 11,
      meta: 'Highest-scoring team implied chance',
      note: 'Final-third quality across the squad',
    ),
  ];
}
