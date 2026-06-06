import 'models.dart';
import 'squad_data.dart';

class SeedData {
  static final DateTime lastUpdatedUtc = DateTime.utc(2026, 6, 6, 5, 20);

  static const List<Team> _baseTeams = [
    Team(
      id: 'mex',
      name: 'Mexico',
      group: 'A',
      flag: '🇲🇽',
      fifaRanking: 15,
      coach: 'Javier Aguirre',
      squad: [
        Player(
          name: 'Guillermo Ochoa',
          position: 'Вратар',
          club: 'AVS',
          number: 13,
          age: 40,
        ),
        Player(
          name: 'Edson Alvarez',
          position: 'Полузащитник',
          club: 'West Ham',
          number: 4,
          age: 28,
        ),
        Player(
          name: 'Santiago Gimenez',
          position: 'Нападател',
          club: 'Milan',
          number: 11,
          age: 25,
        ),
      ],
    ),
    Team(
      id: 'rsa',
      name: 'South Africa',
      group: 'A',
      flag: '🇿🇦',
      fifaRanking: 60,
      coach: 'Hugo Broos',
    ),
    Team(
      id: 'kor',
      name: 'Korea Republic',
      group: 'A',
      flag: '🇰🇷',
      fifaRanking: 25,
      coach: 'Hong Myung-bo',
    ),
    Team(
      id: 'cze',
      name: 'Czechia',
      group: 'A',
      flag: '🇨🇿',
      fifaRanking: 41,
      coach: 'Miroslav Koubek',
    ),
    Team(
      id: 'can',
      name: 'Canada',
      group: 'B',
      flag: '🇨🇦',
      fifaRanking: 30,
      coach: 'Jesse Marsch',
    ),
    Team(
      id: 'sui',
      name: 'Switzerland',
      group: 'B',
      flag: '🇨🇭',
      fifaRanking: 19,
      coach: 'Murat Yakin',
    ),
    Team(
      id: 'qat',
      name: 'Qatar',
      group: 'B',
      flag: '🇶🇦',
      fifaRanking: 55,
      coach: 'Julen Lopetegui',
    ),
    Team(
      id: 'bih',
      name: 'Bosnia and Herzegovina',
      group: 'B',
      flag: '🇧🇦',
      fifaRanking: 65,
      coach: 'Sergej Barbarez',
    ),
    Team(
      id: 'bra',
      name: 'Brazil',
      group: 'C',
      flag: '🇧🇷',
      fifaRanking: 6,
      coach: 'Carlo Ancelotti',
      squad: [
        Player(
          name: 'Alisson',
          position: 'Вратар',
          club: 'Liverpool',
          number: 1,
          age: 33,
        ),
        Player(
          name: 'Bruno Guimaraes',
          position: 'Полузащитник',
          club: 'Newcastle',
          number: 5,
          age: 28,
        ),
        Player(
          name: 'Vinicius Junior',
          position: 'Нападател',
          club: 'Real Madrid',
          number: 7,
          age: 25,
        ),
      ],
    ),
    Team(
      id: 'mar',
      name: 'Morocco',
      group: 'C',
      flag: '🇲🇦',
      fifaRanking: 8,
      coach: 'Walid Regragui',
    ),
    Team(
      id: 'hai',
      name: 'Haiti',
      group: 'C',
      flag: '🇭🇹',
      fifaRanking: 83,
      coach: 'Sebastien Migne',
    ),
    Team(
      id: 'sco',
      name: 'Scotland',
      group: 'C',
      flag: 'SCO',
      fifaRanking: 43,
      coach: 'Steve Clarke',
    ),
    Team(
      id: 'usa',
      name: 'United States',
      group: 'D',
      flag: '🇺🇸',
      fifaRanking: 16,
      coach: 'Mauricio Pochettino',
    ),
    Team(
      id: 'par',
      name: 'Paraguay',
      group: 'D',
      flag: '🇵🇾',
      fifaRanking: 40,
      coach: 'Gustavo Alfaro',
    ),
    Team(
      id: 'aus',
      name: 'Australia',
      group: 'D',
      flag: '🇦🇺',
      fifaRanking: 27,
      coach: 'Tony Popovic',
    ),
    Team(
      id: 'tur',
      name: 'Türkiye',
      group: 'D',
      flag: '🇹🇷',
      fifaRanking: 22,
      coach: 'Vincenzo Montella',
    ),
    Team(
      id: 'ger',
      name: 'Germany',
      group: 'E',
      flag: '🇩🇪',
      fifaRanking: 10,
      coach: 'Julian Nagelsmann',
      squad: [
        Player(
          name: 'Manuel Neuer',
          position: 'Вратар',
          club: 'Bayern Munich',
          number: 1,
          age: 40,
        ),
        Player(
          name: 'Joshua Kimmich',
          position: 'Полузащитник',
          club: 'Bayern Munich',
          number: 6,
          age: 31,
        ),
        Player(
          name: 'Florian Wirtz',
          position: 'Полузащитник',
          club: 'Liverpool',
          number: 17,
          age: 23,
        ),
      ],
    ),
    Team(
      id: 'cur',
      name: 'Curacao',
      group: 'E',
      flag: '🇨🇼',
      fifaRanking: 82,
      coach: 'Dick Advocaat',
    ),
    Team(
      id: 'civ',
      name: 'Cote d’Ivoire',
      group: 'E',
      flag: '🇨🇮',
      fifaRanking: 34,
      coach: 'Emerse Fae',
    ),
    Team(
      id: 'ecu',
      name: 'Ecuador',
      group: 'E',
      flag: '🇪🇨',
      fifaRanking: 23,
      coach: 'Sebastian Beccacece',
    ),
    Team(
      id: 'ned',
      name: 'Netherlands',
      group: 'F',
      flag: '🇳🇱',
      fifaRanking: 7,
      coach: 'Ronald Koeman',
    ),
    Team(
      id: 'jpn',
      name: 'Japan',
      group: 'F',
      flag: '🇯🇵',
      fifaRanking: 18,
      coach: 'Hajime Moriyasu',
    ),
    Team(
      id: 'tun',
      name: 'Tunisia',
      group: 'F',
      flag: '🇹🇳',
      fifaRanking: 44,
      coach: 'Sami Trabelsi',
    ),
    Team(
      id: 'swe',
      name: 'Sweden',
      group: 'F',
      flag: '🇸🇪',
      fifaRanking: 38,
      coach: 'Jon Dahl Tomasson',
    ),
    Team(
      id: 'bel',
      name: 'Belgium',
      group: 'G',
      flag: '🇧🇪',
      fifaRanking: 9,
      coach: 'Rudi Garcia',
    ),
    Team(
      id: 'egy',
      name: 'Egypt',
      group: 'G',
      flag: '🇪🇬',
      fifaRanking: 29,
      coach: 'Hossam Hassan',
    ),
    Team(
      id: 'irn',
      name: 'IR Iran',
      group: 'G',
      flag: '🇮🇷',
      fifaRanking: 21,
      coach: 'Amir Ghalenoei',
    ),
    Team(
      id: 'nzl',
      name: 'New Zealand',
      group: 'G',
      flag: '🇳🇿',
      fifaRanking: 85,
      coach: 'Darren Bazeley',
    ),
    Team(
      id: 'esp',
      name: 'Spain',
      group: 'H',
      flag: '🇪🇸',
      fifaRanking: 2,
      coach: 'Luis de la Fuente',
      squad: [
        Player(
          name: 'Unai Simon',
          position: 'Вратар',
          club: 'Athletic Club',
          number: 23,
          age: 29,
        ),
        Player(
          name: 'Rodri',
          position: 'Полузащитник',
          club: 'Manchester City',
          number: 16,
          age: 29,
        ),
        Player(
          name: 'Lamine Yamal',
          position: 'Нападател',
          club: 'Barcelona',
          number: 19,
          age: 18,
        ),
      ],
    ),
    Team(
      id: 'cpv',
      name: 'Cabo Verde',
      group: 'H',
      flag: '🇨🇻',
      fifaRanking: 69,
      coach: 'Bubista',
    ),
    Team(
      id: 'ksa',
      name: 'Saudi Arabia',
      group: 'H',
      flag: '🇸🇦',
      fifaRanking: 61,
      coach: 'Herve Renard',
    ),
    Team(
      id: 'uru',
      name: 'Uruguay',
      group: 'H',
      flag: '🇺🇾',
      fifaRanking: 17,
      coach: 'Marcelo Bielsa',
    ),
    Team(
      id: 'fra',
      name: 'France',
      group: 'I',
      flag: '🇫🇷',
      fifaRanking: 1,
      coach: 'Didier Deschamps',
      squad: [
        Player(
          name: 'Mike Maignan',
          position: 'Вратар',
          club: 'Milan',
          number: 16,
          age: 30,
        ),
        Player(
          name: 'Aurelien Tchouameni',
          position: 'Полузащитник',
          club: 'Real Madrid',
          number: 8,
          age: 26,
        ),
        Player(
          name: 'Kylian Mbappe',
          position: 'Нападател',
          club: 'Real Madrid',
          number: 10,
          age: 27,
        ),
      ],
    ),
    Team(
      id: 'sen',
      name: 'Senegal',
      group: 'I',
      flag: '🇸🇳',
      fifaRanking: 14,
      coach: 'Pape Thiaw',
    ),
    Team(
      id: 'nor',
      name: 'Norway',
      group: 'I',
      flag: '🇳🇴',
      fifaRanking: 31,
      coach: 'Stale Solbakken',
    ),
    Team(
      id: 'irq',
      name: 'Iraq',
      group: 'I',
      flag: '🇮🇶',
      fifaRanking: 57,
      coach: 'Graham Arnold',
    ),
    Team(
      id: 'arg',
      name: 'Argentina',
      group: 'J',
      flag: '🇦🇷',
      fifaRanking: 3,
      coach: 'Lionel Scaloni',
      squad: [
        Player(
          name: 'Emiliano Martinez',
          position: 'Вратар',
          club: 'Aston Villa',
          number: 23,
          age: 33,
        ),
        Player(
          name: 'Enzo Fernandez',
          position: 'Полузащитник',
          club: 'Chelsea',
          number: 24,
          age: 25,
        ),
        Player(
          name: 'Lionel Messi',
          position: 'Нападател',
          club: 'Inter Miami',
          number: 10,
          age: 38,
        ),
      ],
    ),
    Team(
      id: 'alg',
      name: 'Algeria',
      group: 'J',
      flag: '🇩🇿',
      fifaRanking: 28,
      coach: 'Vladimir Petkovic',
    ),
    Team(
      id: 'aut',
      name: 'Austria',
      group: 'J',
      flag: '🇦🇹',
      fifaRanking: 24,
      coach: 'Ralf Rangnick',
    ),
    Team(
      id: 'jor',
      name: 'Jordan',
      group: 'J',
      flag: '🇯🇴',
      fifaRanking: 63,
      coach: 'Jamal Sellami',
    ),
    Team(
      id: 'por',
      name: 'Portugal',
      group: 'K',
      flag: '🇵🇹',
      fifaRanking: 5,
      coach: 'Roberto Martinez',
    ),
    Team(
      id: 'uzb',
      name: 'Uzbekistan',
      group: 'K',
      flag: '🇺🇿',
      fifaRanking: 50,
      coach: 'Timur Kapadze',
    ),
    Team(
      id: 'col',
      name: 'Colombia',
      group: 'K',
      flag: '🇨🇴',
      fifaRanking: 13,
      coach: 'Nestor Lorenzo',
    ),
    Team(
      id: 'cod',
      name: 'Congo DR',
      group: 'K',
      flag: '🇨🇩',
      fifaRanking: 46,
      coach: 'Sebastien Desabre',
    ),
    Team(
      id: 'eng',
      name: 'England',
      group: 'L',
      flag: 'ENG',
      fifaRanking: 4,
      coach: 'Thomas Tuchel',
      squad: [
        Player(
          name: 'Jordan Pickford',
          position: 'Вратар',
          club: 'Everton',
          number: 1,
          age: 32,
        ),
        Player(
          name: 'Jude Bellingham',
          position: 'Полузащитник',
          club: 'Real Madrid',
          number: 10,
          age: 22,
        ),
        Player(
          name: 'Harry Kane',
          position: 'Нападател',
          club: 'Bayern Munich',
          number: 9,
          age: 32,
        ),
      ],
    ),
    Team(
      id: 'cro',
      name: 'Croatia',
      group: 'L',
      flag: '🇭🇷',
      fifaRanking: 11,
      coach: 'Zlatko Dalic',
    ),
    Team(
      id: 'gha',
      name: 'Ghana',
      group: 'L',
      flag: '🇬🇭',
      fifaRanking: 74,
      coach: 'Otto Addo',
    ),
    Team(
      id: 'pan',
      name: 'Panama',
      group: 'L',
      flag: '🇵🇦',
      fifaRanking: 33,
      coach: 'Thomas Christiansen',
    ),
  ];

  static final List<Team> teams = [
    for (final team in _baseTeams)
      Team(
        id: team.id,
        name: team.name,
        group: team.group,
        flag: team.flag,
        fifaRanking: team.fifaRanking,
        coach: team.coach,
        squad: squadData[team.id] ?? team.squad,
      ),
  ];

  static final List<MatchEntry> _fixtureSeed = [
    MatchEntry(
      id: 'm001',
      group: 'A',
      homeTeamId: 'mex',
      awayTeamId: 'rsa',
      kickoffUtc: DateTime.utc(2026, 6, 11, 20),
      venue: 'Mexico City Stadium',
      city: 'Mexico City',
      status: MatchStatus.upcoming,
    ),
    MatchEntry(
      id: 'm002',
      group: 'A',
      homeTeamId: 'kor',
      awayTeamId: 'cze',
      kickoffUtc: DateTime.utc(2026, 6, 12, 1),
      venue: 'Estadio Guadalajara',
      city: 'Guadalajara',
      status: MatchStatus.upcoming,
    ),
    MatchEntry(
      id: 'm003',
      group: 'B',
      homeTeamId: 'can',
      awayTeamId: 'bih',
      kickoffUtc: DateTime.utc(2026, 6, 12, 19),
      venue: 'Toronto Stadium',
      city: 'Toronto',
      status: MatchStatus.upcoming,
    ),
    MatchEntry(
      id: 'm004',
      group: 'D',
      homeTeamId: 'usa',
      awayTeamId: 'par',
      kickoffUtc: DateTime.utc(2026, 6, 13, 1),
      venue: 'Los Angeles Stadium',
      city: 'Los Angeles',
      status: MatchStatus.upcoming,
    ),
    MatchEntry(
      id: 'm005',
      group: 'C',
      homeTeamId: 'hai',
      awayTeamId: 'sco',
      kickoffUtc: DateTime.utc(2026, 6, 13, 16),
      venue: 'Boston Stadium',
      city: 'Boston',
      status: MatchStatus.upcoming,
    ),
    MatchEntry(
      id: 'm006',
      group: 'D',
      homeTeamId: 'aus',
      awayTeamId: 'tur',
      kickoffUtc: DateTime.utc(2026, 6, 13, 19),
      venue: 'BC Place Vancouver',
      city: 'Vancouver',
      status: MatchStatus.upcoming,
    ),
    MatchEntry(
      id: 'm007',
      group: 'C',
      homeTeamId: 'bra',
      awayTeamId: 'mar',
      kickoffUtc: DateTime.utc(2026, 6, 14, 0),
      venue: 'New York New Jersey Stadium',
      city: 'New York New Jersey',
      status: MatchStatus.upcoming,
    ),
    MatchEntry(
      id: 'm008',
      group: 'B',
      homeTeamId: 'qat',
      awayTeamId: 'sui',
      kickoffUtc: DateTime.utc(2026, 6, 14, 3),
      venue: 'San Francisco Bay Area Stadium',
      city: 'San Francisco Bay Area',
      status: MatchStatus.upcoming,
    ),
    MatchEntry(
      id: 'm009',
      group: 'E',
      homeTeamId: 'civ',
      awayTeamId: 'ecu',
      kickoffUtc: DateTime.utc(2026, 6, 14, 16),
      venue: 'Philadelphia Stadium',
      city: 'Philadelphia',
      status: MatchStatus.upcoming,
    ),
    MatchEntry(
      id: 'm010',
      group: 'E',
      homeTeamId: 'ger',
      awayTeamId: 'cur',
      kickoffUtc: DateTime.utc(2026, 6, 14, 19),
      venue: 'Houston Stadium',
      city: 'Houston',
      status: MatchStatus.upcoming,
    ),
    MatchEntry(
      id: 'm011',
      group: 'F',
      homeTeamId: 'ned',
      awayTeamId: 'jpn',
      kickoffUtc: DateTime.utc(2026, 6, 14, 22),
      venue: 'Dallas Stadium',
      city: 'Dallas',
      status: MatchStatus.upcoming,
    ),
    MatchEntry(
      id: 'm012',
      group: 'F',
      homeTeamId: 'swe',
      awayTeamId: 'tun',
      kickoffUtc: DateTime.utc(2026, 6, 15, 3),
      venue: 'Estadio Monterrey',
      city: 'Monterrey',
      status: MatchStatus.upcoming,
    ),
    MatchEntry(
      id: 'm013',
      group: 'G',
      homeTeamId: 'bel',
      awayTeamId: 'egy',
      kickoffUtc: DateTime.utc(2026, 6, 15, 19),
      venue: 'Seattle Stadium',
      city: 'Seattle',
      status: MatchStatus.upcoming,
    ),
    MatchEntry(
      id: 'm014',
      group: 'G',
      homeTeamId: 'irn',
      awayTeamId: 'nzl',
      kickoffUtc: DateTime.utc(2026, 6, 16, 1),
      venue: 'Kansas City Stadium',
      city: 'Kansas City',
      status: MatchStatus.upcoming,
    ),
    MatchEntry(
      id: 'm015',
      group: 'H',
      homeTeamId: 'esp',
      awayTeamId: 'cpv',
      kickoffUtc: DateTime.utc(2026, 6, 16, 19),
      venue: 'Miami Stadium',
      city: 'Miami',
      status: MatchStatus.upcoming,
    ),
    MatchEntry(
      id: 'm016',
      group: 'H',
      homeTeamId: 'ksa',
      awayTeamId: 'uru',
      kickoffUtc: DateTime.utc(2026, 6, 17, 1),
      venue: 'Atlanta Stadium',
      city: 'Atlanta',
      status: MatchStatus.upcoming,
    ),
    MatchEntry(
      id: 'm017',
      group: 'I',
      homeTeamId: 'fra',
      awayTeamId: 'sen',
      kickoffUtc: DateTime.utc(2026, 6, 17, 19),
      venue: 'Boston Stadium',
      city: 'Boston',
      status: MatchStatus.upcoming,
    ),
    MatchEntry(
      id: 'm018',
      group: 'I',
      homeTeamId: 'nor',
      awayTeamId: 'irq',
      kickoffUtc: DateTime.utc(2026, 6, 18, 1),
      venue: 'Toronto Stadium',
      city: 'Toronto',
      status: MatchStatus.upcoming,
    ),
    MatchEntry(
      id: 'm019',
      group: 'J',
      homeTeamId: 'arg',
      awayTeamId: 'alg',
      kickoffUtc: DateTime.utc(2026, 6, 18, 19),
      venue: 'Los Angeles Stadium',
      city: 'Los Angeles',
      status: MatchStatus.upcoming,
    ),
    MatchEntry(
      id: 'm020',
      group: 'J',
      homeTeamId: 'aut',
      awayTeamId: 'jor',
      kickoffUtc: DateTime.utc(2026, 6, 19, 1),
      venue: 'San Francisco Bay Area Stadium',
      city: 'San Francisco Bay Area',
      status: MatchStatus.upcoming,
    ),
    MatchEntry(
      id: 'm021',
      group: 'K',
      homeTeamId: 'por',
      awayTeamId: 'uzb',
      kickoffUtc: DateTime.utc(2026, 6, 19, 19),
      venue: 'Houston Stadium',
      city: 'Houston',
      status: MatchStatus.upcoming,
    ),
    MatchEntry(
      id: 'm022',
      group: 'K',
      homeTeamId: 'col',
      awayTeamId: 'cod',
      kickoffUtc: DateTime.utc(2026, 6, 20, 1),
      venue: 'Miami Stadium',
      city: 'Miami',
      status: MatchStatus.upcoming,
    ),
    MatchEntry(
      id: 'm023',
      group: 'L',
      homeTeamId: 'eng',
      awayTeamId: 'cro',
      kickoffUtc: DateTime.utc(2026, 6, 17, 20),
      venue: 'Dallas Stadium',
      city: 'Dallas',
      status: MatchStatus.upcoming,
    ),
    MatchEntry(
      id: 'm024',
      group: 'L',
      homeTeamId: 'gha',
      awayTeamId: 'pan',
      kickoffUtc: DateTime.utc(2026, 6, 20, 19),
      venue: 'New York New Jersey Stadium',
      city: 'New York New Jersey',
      status: MatchStatus.upcoming,
    ),
    MatchEntry(
      id: 'm025',
      group: 'A',
      homeTeamId: 'mex',
      awayTeamId: 'kor',
      kickoffUtc: DateTime.utc(2026, 6, 18, 22),
      venue: 'Estadio Guadalajara',
      city: 'Guadalajara',
      status: MatchStatus.upcoming,
    ),
    MatchEntry(
      id: 'm026',
      group: 'A',
      homeTeamId: 'cze',
      awayTeamId: 'rsa',
      kickoffUtc: DateTime.utc(2026, 6, 18, 19),
      venue: 'Atlanta Stadium',
      city: 'Atlanta',
      status: MatchStatus.upcoming,
    ),
    MatchEntry(
      id: 'm027',
      group: 'A',
      homeTeamId: 'mex',
      awayTeamId: 'cze',
      kickoffUtc: DateTime.utc(2026, 6, 24, 20),
      venue: 'Mexico City Stadium',
      city: 'Mexico City',
      status: MatchStatus.upcoming,
    ),
    MatchEntry(
      id: 'm028',
      group: 'A',
      homeTeamId: 'rsa',
      awayTeamId: 'kor',
      kickoffUtc: DateTime.utc(2026, 6, 24, 20),
      venue: 'Estadio Monterrey',
      city: 'Monterrey',
      status: MatchStatus.upcoming,
    ),
  ];

  static final List<MatchEntry> fixtures = _buildFixtures();

  static List<MatchEntry> _buildFixtures() {
    final matches = [..._fixtureSeed];
    final knownPairs = {
      for (final match in matches)
        _pairKey(match.group, match.homeTeamId, match.awayTeamId),
    };
    var nextId = matches.length + 1;

    const pairOrder = [
      [0, 1],
      [2, 3],
      [0, 2],
      [3, 1],
      [0, 3],
      [1, 2],
    ];
    const venues = [
      ('Toronto Stadium', 'Toronto'),
      ('Los Angeles Stadium', 'Los Angeles'),
      ('Boston Stadium', 'Boston'),
      ('BC Place Vancouver', 'Vancouver'),
      ('New York New Jersey Stadium', 'New York New Jersey'),
      ('San Francisco Bay Area Stadium', 'San Francisco Bay Area'),
      ('Philadelphia Stadium', 'Philadelphia'),
      ('Houston Stadium', 'Houston'),
      ('Dallas Stadium', 'Dallas'),
      ('Estadio Monterrey', 'Monterrey'),
      ('Seattle Stadium', 'Seattle'),
      ('Kansas City Stadium', 'Kansas City'),
      ('Miami Stadium', 'Miami'),
      ('Atlanta Stadium', 'Atlanta'),
      ('Mexico City Stadium', 'Mexico City'),
      ('Estadio Guadalajara', 'Guadalajara'),
    ];

    for (final group in groups) {
      final groupIndex = groups.indexOf(group);
      final groupTeams = teams.where((team) => team.group == group).toList();
      for (var roundIndex = 0; roundIndex < pairOrder.length; roundIndex += 1) {
        final pair = pairOrder[roundIndex];
        final home = groupTeams[pair[0]];
        final away = groupTeams[pair[1]];
        final key = _pairKey(group, home.id, away.id);
        if (knownPairs.contains(key)) continue;

        final venue = venues[(groupIndex * 3 + roundIndex) % venues.length];
        matches.add(
          MatchEntry(
            id: 'm${nextId.toString().padLeft(3, '0')}',
            group: group,
            homeTeamId: home.id,
            awayTeamId: away.id,
            kickoffUtc: DateTime.utc(
              2026,
              6,
              21 + roundIndex * 2 + groupIndex ~/ 4,
              16 + (roundIndex % 4) * 3,
            ),
            venue: venue.$1,
            city: venue.$2,
            status: MatchStatus.upcoming,
          ),
        );
        knownPairs.add(key);
        nextId += 1;
      }
    }

    matches.sort((a, b) => a.kickoffUtc.compareTo(b.kickoffUtc));
    return matches;
  }

  static String _pairKey(
    String group,
    String firstTeamId,
    String secondTeamId,
  ) {
    final pair = [firstTeamId, secondTeamId]..sort();
    return '$group:${pair[0]}:${pair[1]}';
  }

  static Team teamById(String id) => teams.firstWhere((team) => team.id == id);

  static Team? teamByNameOrNull(String name) {
    for (final team in teams) {
      if (team.name == name) return team;
    }
    return null;
  }

  static List<Team> teamsByGroup(String group) {
    return teams.where((team) => team.group == group).toList()
      ..sort((a, b) => a.fifaRanking.compareTo(b.fifaRanking));
  }

  static List<String> get groups {
    return teams.map((team) => team.group).toSet().toList()..sort();
  }

  static List<MatchEntry> upcomingMatches({int? limit}) {
    final matches =
        fixtures.where((match) => match.status != MatchStatus.finished).toList()
          ..sort((a, b) => a.kickoffUtc.compareTo(b.kickoffUtc));
    if (limit == null || matches.length <= limit) return matches;
    return matches.take(limit).toList();
  }

  static List<RecentMatch> recentMatchesFor(Team team, {int count = 20}) {
    final selfIndex = teams.indexWhere((candidate) => candidate.id == team.id);
    final rankingFactor = 92 - team.fifaRanking;

    return List.generate(count, (index) {
      final opponent = teams[(selfIndex + index * 7 + 5) % teams.length];
      var goalsFor = (rankingFactor + index * 2) % 4;
      var goalsAgainst = (team.fifaRanking + index * 3) % 3;

      if (team.fifaRanking <= 10 && index % 3 != 0) goalsFor += 1;
      if (team.fifaRanking >= 60 && index % 4 == 0) goalsAgainst += 1;
      if (opponent.fifaRanking <= 12 && goalsAgainst == 0) goalsAgainst = 1;
      if (opponent.fifaRanking >= 65 && goalsFor == 0) goalsFor = 1;

      return RecentMatch(
        date: DateTime.utc(2026, 6, 1).subtract(Duration(days: 8 + index * 9)),
        opponent: opponent.name,
        goalsFor: goalsFor,
        goalsAgainst: goalsAgainst,
        competition: index.isEven ? 'Friendly' : 'Qualifier',
        neutralVenue: index % 5 == 0,
      );
    });
  }
}

class StandingsCalculator {
  static List<StandingRow> rowsForGroup(
    String group, {
    List<MatchEntry>? fixtures,
  }) {
    final rows = <String, _MutableStanding>{
      for (final team in SeedData.teamsByGroup(group))
        team.id: _MutableStanding(team),
    };

    for (final match in (fixtures ?? SeedData.fixtures).where(
      (match) => match.group == group && match.hasResult,
    )) {
      final home = rows[match.homeTeamId];
      final away = rows[match.awayTeamId];
      if (home == null || away == null) continue;
      home.apply(match.homeScore!, match.awayScore!);
      away.apply(match.awayScore!, match.homeScore!);
    }

    final standings = rows.values.map((row) => row.toRow()).toList()
      ..sort((a, b) {
        final points = b.points.compareTo(a.points);
        if (points != 0) return points;
        final goalDifference = b.goalDifference.compareTo(a.goalDifference);
        if (goalDifference != 0) return goalDifference;
        final goalsFor = b.goalsFor.compareTo(a.goalsFor);
        if (goalsFor != 0) return goalsFor;
        return a.team.fifaRanking.compareTo(b.team.fifaRanking);
      });
    return standings;
  }
}

class _MutableStanding {
  _MutableStanding(this.team);

  final Team team;
  int played = 0;
  int wins = 0;
  int draws = 0;
  int losses = 0;
  int goalsFor = 0;
  int goalsAgainst = 0;
  int points = 0;

  void apply(int scored, int conceded) {
    played += 1;
    goalsFor += scored;
    goalsAgainst += conceded;
    if (scored > conceded) {
      wins += 1;
      points += 3;
    } else if (scored == conceded) {
      draws += 1;
      points += 1;
    } else {
      losses += 1;
    }
  }

  StandingRow toRow() {
    return StandingRow(
      team: team,
      played: played,
      wins: wins,
      draws: draws,
      losses: losses,
      goalsFor: goalsFor,
      goalsAgainst: goalsAgainst,
      points: points,
    );
  }
}
