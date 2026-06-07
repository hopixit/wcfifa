import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api_football_live_data.dart';
import 'futures_market_data.dart';
import 'models.dart';
import 'news_feed_data.dart';
import 'prediction_model.dart';
import 'seed_data.dart';
import 'squad_data.dart';
import 'team_world_cup_record_data.dart';
import 'tournament_power_data.dart';

void main() {
  runApp(const SportApApp());
}

class SportApApp extends StatefulWidget {
  const SportApApp({super.key});

  @override
  State<SportApApp> createState() => _SportApAppState();
}

class _SportApAppState extends State<SportApApp> {
  static const _apiEnabled = bool.fromEnvironment(
    'USE_API_FOOTBALL',
    defaultValue: false,
  );

  late final WorldCupDataController _worldCupData = WorldCupDataController(
    apiEnabled: _apiEnabled,
  );

  @override
  void initState() {
    super.initState();
    if (_apiEnabled) {
      _worldCupData.startResultPolling();
      unawaited(_worldCupData.refreshApiData());
    }
  }

  @override
  void dispose() {
    _worldCupData.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WorldCupDataScope(
      controller: _worldCupData,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'World Cup 2026 Predictions',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: const ColorScheme.light(
            primary: FifaColors.blueDark,
            onPrimary: FifaColors.navy,
            secondary: FifaColors.orange,
            onSecondary: FifaColors.white,
            tertiary: FifaColors.focusYellow,
            surface: FifaColors.white,
            onSurface: FifaColors.navyAlt,
            error: FifaColors.red,
          ),
          scaffoldBackgroundColor: FifaColors.surface,
          appBarTheme: const AppBarTheme(
            centerTitle: false,
            backgroundColor: FifaColors.navy,
            foregroundColor: FifaColors.white,
            surfaceTintColor: FifaColors.navy,
            elevation: 0,
          ),
          tabBarTheme: const TabBarThemeData(
            labelColor: FifaColors.blue,
            unselectedLabelColor: FifaColors.border,
            indicatorColor: FifaColors.blue,
            dividerColor: FifaColors.deepBlue,
          ),
          cardTheme: CardThemeData(
            color: FifaColors.white,
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: FifaColors.border),
            ),
          ),
          chipTheme: ChipThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            selectedColor: FifaColors.blue.withValues(alpha: 0.14),
            labelStyle: const TextStyle(color: FifaColors.navyAlt),
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: FifaColors.white,
            indicatorColor: FifaColors.blue.withValues(alpha: 0.16),
            labelTextStyle: WidgetStateProperty.resolveWith(
              (states) => TextStyle(
                color: states.contains(WidgetState.selected)
                    ? FifaColors.blueDark
                    : FifaColors.muted,
                fontWeight: states.contains(WidgetState.selected)
                    ? FontWeight.w800
                    : FontWeight.w600,
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: FifaColors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: FifaColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: FifaColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: FifaColors.blue, width: 2),
            ),
          ),
        ),
        home: const AppShell(),
      ),
    );
  }
}

class FifaColors {
  static const navy = Color(0xFF020F2A);
  static const navyAlt = Color(0xFF03122B);
  static const deepBlue = Color(0xFF0D437A);
  static const blue = Color(0xFF00B8FF);
  static const blueDark = Color(0xFF1574C4);
  static const red = Color(0xFFB6002C);
  static const orange = Color(0xFFFA4119);
  static const focusYellow = Color(0xFFFFDC4E);
  static const surface = Color(0xFFF7F9FC);
  static const border = Color(0xFFE4E8F0);
  static const muted = Color(0xFF505B73);
  static const white = Color(0xFFFFFFFF);
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  bool _handledInitialTeamLink = false;

  static const _destinations = [
    _Destination('Home', Icons.dashboard_outlined, Icons.dashboard),
    _Destination(
      'Schedule & Predictions',
      Icons.sports_soccer_outlined,
      Icons.sports_soccer,
    ),
    _Destination('Results', Icons.list_alt_outlined, Icons.list_alt),
    _Destination('Groups', Icons.table_chart_outlined, Icons.table_chart),
    _Destination('Teams', Icons.flag_outlined, Icons.flag),
    _Destination('News', Icons.article_outlined, Icons.article),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _handledInitialTeamLink) return;
      _handledInitialTeamLink = true;
      final teamKey = Uri.base.queryParameters['team']?.trim().toLowerCase();
      if (teamKey == null || teamKey.isEmpty) return;
      final team = SeedData.teams.where((item) {
        return item.id.toLowerCase() == teamKey ||
            item.name.toLowerCase() == teamKey;
      }).firstOrNull;
      if (team != null) openTeamPage(context, team);
    });
  }

  @override
  Widget build(BuildContext context) {
    final worldCupData = WorldCupDataScope.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 920;
        final selected = _destinations[_selectedIndex];
        final homeFavorites = _selectedIndex == 0
            ? tournamentFavorites(limit: 10)
            : const <TournamentFavorite>[];
        final screens = [
          const HomeScreen(),
          const MatchesScreen(),
          const ResultsScreen(),
          const GroupsScreen(),
          const TeamsScreen(),
          NewsScreen(active: _selectedIndex == 5),
        ];

        return Scaffold(
          appBar: AppBar(
            toolbarHeight: wide ? 72 : null,
            titleSpacing: wide ? 20 : null,
            title: wide
                ? Row(
                    children: [
                      const HeaderBrand(),
                      const SizedBox(width: 22),
                      Expanded(
                        child: _HeaderMenu(
                          destinations: _destinations,
                          selectedIndex: _selectedIndex,
                          onSelected: (index) =>
                              setState(() => _selectedIndex = index),
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('World Cup 2026'),
                      Text(
                        selected.label,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: FifaColors.blue,
                        ),
                      ),
                    ],
                  ),
            actions: [
              if (wide)
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: SizedBox(width: 300, child: TeamTopSearch()),
                )
              else
                IconButton(
                  tooltip: 'Search team',
                  icon: const Icon(Icons.search),
                  onPressed: () => showTeamSearchSheet(context),
                ),
              if (wide && constraints.maxWidth >= 1180)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    child: StatusPill(
                      icon: Icons.sync,
                      label: worldCupData.usingApiFixtures
                          ? 'API: ${worldCupData.requestsRemainingToday ?? '?'} left'
                          : 'Seed: ${formatDate(SeedData.lastUpdatedUtc.toLocal())}',
                    ),
                  ),
                ),
            ],
          ),
          body: Column(
            children: [
              if (_selectedIndex == 0)
                HomeFavoritesDock(favorites: homeFavorites),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: IndexedStack(
                        index: _selectedIndex,
                        children: screens,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: wide
              ? null
              : _MobileBottomNav(
                  destinations: _destinations,
                  selectedIndex: _selectedIndex,
                  onSelected: (index) => setState(() => _selectedIndex = index),
                ),
        );
      },
    );
  }
}

class _MobileBottomNav extends StatelessWidget {
  const _MobileBottomNav({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_Destination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: FifaColors.white,
          border: Border(top: BorderSide(color: FifaColors.border)),
        ),
        child: SizedBox(
          height: 74,
          child: Row(
            children: [
              for (var index = 0; index < destinations.length; index += 1)
                Expanded(
                  child: _MobileNavButton(
                    destination: destinations[index],
                    selected: selectedIndex == index,
                    onPressed: () => onSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileNavButton extends StatelessWidget {
  const _MobileNavButton({
    required this.destination,
    required this.selected,
    required this.onPressed,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = selected ? FifaColors.blueDark : FifaColors.navy;
    final label = destination.label == 'Schedule & Predictions'
        ? 'Schedule'
        : destination.label;

    return Tooltip(
      message: destination.label,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected
                  ? FifaColors.blue.withValues(alpha: 0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    selected ? destination.selectedIcon : destination.icon,
                    color: color,
                    size: 20,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: color,
                      fontSize: 10.5,
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HeaderBrand extends StatelessWidget {
  const HeaderBrand({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: FifaColors.blue,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.public, color: FifaColors.navy, size: 22),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'World Cup 2026',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: FifaColors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'Predictions and teams',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: FifaColors.border,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeaderMenu extends StatelessWidget {
  const _HeaderMenu({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_Destination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < destinations.length; index += 1)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _HeaderMenuButton(
                destination: destinations[index],
                selected: selectedIndex == index,
                onPressed: () => onSelected(index),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeaderMenuButton extends StatelessWidget {
  const _HeaderMenuButton({
    required this.destination,
    required this.selected,
    required this.onPressed,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? FifaColors.navy : FifaColors.white;
    final background = selected ? FifaColors.blue : Colors.transparent;

    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(
        selected ? destination.selectedIcon : destination.icon,
        size: 18,
      ),
      label: Text(destination.label),
      style:
          TextButton.styleFrom(
            foregroundColor: foreground,
            backgroundColor: background,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ).copyWith(
            overlayColor: WidgetStateProperty.all(
              selected
                  ? FifaColors.white.withValues(alpha: 0.16)
                  : FifaColors.blue.withValues(alpha: 0.18),
            ),
          ),
    );
  }
}

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class TeamTopSearch extends StatelessWidget {
  const TeamTopSearch({super.key});

  @override
  Widget build(BuildContext context) {
    return Autocomplete<Team>(
      displayStringForOption: (team) => team.name,
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) return const Iterable<Team>.empty();
        return SeedData.teams
            .where((team) {
              return team.name.toLowerCase().contains(query) ||
                  team.group.toLowerCase().contains(query);
            })
            .take(8);
      },
      onSelected: (team) {
        FocusScope.of(context).unfocus();
        openTeamPage(context, team);
      },
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
            return SizedBox(
              height: 44,
              child: TextField(
                controller: textEditingController,
                focusNode: focusNode,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Search team',
                  prefixIcon: Icon(Icons.search),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            );
          },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340, maxHeight: 360),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: options.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final team = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    leading: FlagMark(value: team.flag),
                    title: Text(team.name),
                    subtitle: Text(
                      'Group ${team.group} • ${team.squad.length} players',
                    ),
                    onTap: () => onSelected(team),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<void> showTeamSearchSheet(BuildContext context) async {
  final selectedTeam = await showModalBottomSheet<Team>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const TeamSearchSheet(),
  );
  if (!context.mounted || selectedTeam == null) return;
  openTeamPage(context, selectedTeam);
}

class TeamSearchSheet extends StatefulWidget {
  const TeamSearchSheet({super.key});

  @override
  State<TeamSearchSheet> createState() => _TeamSearchSheetState();
}

class _TeamSearchSheetState extends State<TeamSearchSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = _query.trim().toLowerCase();
    final teams =
        SeedData.teams.where((team) {
          if (normalizedQuery.isEmpty) return true;
          return team.name.toLowerCase().contains(normalizedQuery) ||
              team.group.toLowerCase().contains(normalizedQuery);
        }).toList()..sort((a, b) {
          final groupCompare = a.group.compareTo(b.group);
          if (groupCompare != 0) return groupCompare;
          return a.fifaRanking.compareTo(b.fifaRanking);
        });

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.78,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Search team',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Name or group',
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: teams.isEmpty
                    ? const EmptyState(
                        icon: Icons.search_off,
                        title: 'No results',
                        body: 'Try another team name.',
                      )
                    : ListView.separated(
                        itemCount: teams.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final team = teams[index];
                          return ListTile(
                            leading: FlagMark(value: team.flag),
                            title: Text(team.name),
                            subtitle: Text(
                              'Group ${team.group} • ${team.squad.length} players',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.of(context).pop(team);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final model = PredictionModel();
    final advanceEntries = [...SeedData.teams]
      ..sort(
        (a, b) => model
            .tournamentOutlook(b)
            .round32
            .compareTo(model.tournamentOutlook(a).round32),
      );

    return PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HomeFuturesIntro(),
          const SizedBox(height: 16),
          const HomeFuturesLane(
            title: 'Golden Boot Favorites',
            subtitle: 'Top goalscorer contenders from current futures markets',
            icon: Icons.sports_soccer,
            accent: FifaColors.orange,
            entries: FuturesMarketData.goldenBoot,
          ),
          const SizedBox(height: 16),
          const HomeFuturesLane(
            title: 'Assist Kings',
            subtitle: 'Playmakers favored to finish with the most assists',
            icon: Icons.route,
            accent: FifaColors.blueDark,
            entries: FuturesMarketData.assistKings,
          ),
          const SizedBox(height: 16),
          const HomeFuturesLane(
            title: 'Best Passing Teams',
            subtitle: 'Model-only control index for possession and circulation',
            icon: Icons.hub,
            accent: FifaColors.deepBlue,
            entries: FuturesMarketData.bestPassingTeams,
          ),
          const SizedBox(height: 16),
          const HomeFuturesLane(
            title: 'Highest-Scoring Teams',
            subtitle: 'Nations favored to score the most goals overall',
            icon: Icons.trending_up,
            accent: FifaColors.red,
            entries: FuturesMarketData.highestScoringTeams,
          ),
          const SizedBox(height: 16),
          HomeFuturesLane(
            title: 'Most Likely to Advance',
            subtitle: 'Round of 32 chances from the Elo-calibrated path model',
            icon: Icons.account_tree_outlined,
            accent: FifaColors.blue,
            entries: [
              for (final team in advanceEntries.take(10))
                FuturesMarketEntry(
                  name: team.name,
                  teamId: team.id,
                  value: model.tournamentOutlook(team).round32,
                  meta: 'Round of 32 chance',
                  note:
                      'Group ${team.group} • title ${model.tournamentOutlook(team).trophy}%',
                ),
            ],
          ),
          const SizedBox(height: 24),
          const HomeFooter(),
        ],
      ),
    );
  }
}

class HomeFuturesIntro extends StatelessWidget {
  const HomeFuturesIntro({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FifaColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FifaColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final heading = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'World Cup Futures Dashboard',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                'Outright markets, player props and model-only team indicators in one scan-friendly home view.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: FifaColors.muted),
              ),
            ],
          );
          final chips = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              StatusPill(icon: Icons.public, label: 'Tournament futures'),
              StatusPill(icon: Icons.sports_soccer, label: 'Player props'),
              StatusPill(icon: Icons.hub, label: 'Team style indices'),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [heading, const SizedBox(height: 12), chips],
            );
          }

          return Row(
            children: [
              Expanded(child: heading),
              const SizedBox(width: 16),
              chips,
            ],
          );
        },
      ),
    );
  }
}

class HomeFuturesLane extends StatelessWidget {
  const HomeFuturesLane({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.entries,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final List<FuturesMarketEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: FifaColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FifaColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: accent, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: FifaColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusPill(
                  icon: Icons.query_stats,
                  label: 'Top ${entries.length}',
                ),
              ],
            ),
          ),
          SizedBox(
            height: 208,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              scrollDirection: Axis.horizontal,
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                return SizedBox(
                  width: 190,
                  child: HomeFuturesTile(
                    entry: entries[index],
                    rank: index + 1,
                    accent: accent,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class HomeFuturesTile extends StatelessWidget {
  const HomeFuturesTile({
    required this.entry,
    required this.rank,
    required this.accent,
    super.key,
  });

  final FuturesMarketEntry entry;
  final int rank;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final team = SeedData.teamById(entry.teamId);
    final suffix = entry.meta.toLowerCase().contains('index') ? '/100' : '%';
    final value = entry.value.clamp(0, 100).toInt();

    return Tooltip(
      message: 'Open ${team.name}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => openTeamPage(context, team),
          child: Ink(
            decoration: BoxDecoration(
              color: rank <= 3
                  ? accent.withValues(alpha: 0.1)
                  : FifaColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: accent.withValues(alpha: rank <= 3 ? 0.34 : 0.16),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          '$rank',
                          style: const TextStyle(
                            color: FifaColors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 34,
                        height: 34,
                        child: FittedBox(child: FlagMark(value: team.flag)),
                      ),
                      const Spacer(),
                      Text(
                        '$value$suffix',
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: FifaColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 9),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: value / 100,
                      minHeight: 7,
                      color: accent,
                      backgroundColor: accent.withValues(alpha: 0.14),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    entry.note,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: FifaColors.muted,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TournamentFavorite {
  const TournamentFavorite({
    required this.team,
    required this.outlook,
    required this.profile,
  });

  final Team team;
  final TeamTournamentOutlook outlook;
  final TeamModelProfile profile;
}

List<TournamentFavorite> tournamentFavorites({int? limit}) {
  final model = PredictionModel();
  final favorites =
      SeedData.teams
          .map(
            (team) => TournamentFavorite(
              team: team,
              outlook: model.tournamentOutlook(team),
              profile: model.teamProfile(team),
            ),
          )
          .toList()
        ..sort((a, b) {
          final trophyCompare = b.outlook.trophy.compareTo(a.outlook.trophy);
          if (trophyCompare != 0) return trophyCompare;
          final scoreCompare = b.profile.modelScore.compareTo(
            a.profile.modelScore,
          );
          if (scoreCompare != 0) return scoreCompare;
          return a.team.fifaRanking.compareTo(b.team.fifaRanking);
        });

  if (limit == null || favorites.length <= limit) return favorites;
  return favorites.take(limit).toList();
}

class HomeFavoritesDock extends StatelessWidget {
  const HomeFavoritesDock({required this.favorites, super.key});

  final List<TournamentFavorite> favorites;

  @override
  Widget build(BuildContext context) {
    if (favorites.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [FifaColors.navyAlt, FifaColors.deepBlue],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border(bottom: BorderSide(color: FifaColors.orange, width: 2)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 700;
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 12 : 16,
                  10,
                  compact ? 12 : 16,
                  12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: FifaColors.focusYellow,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.emoji_events,
                            color: FifaColors.navy,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            compact
                                ? 'Tournament favorites'
                                : 'TOP FAVORITES TO WIN THE TOURNAMENT',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: FifaColors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                        if (!compact)
                          Text(
                            'Elo + consensus odds',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: FifaColors.border,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: compact ? 84 : 92,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: favorites.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          return FavoriteDockItem(
                            favorite: favorites[index],
                            rank: index + 1,
                            compact: compact,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class FavoriteDockItem extends StatelessWidget {
  const FavoriteDockItem({
    required this.favorite,
    required this.rank,
    required this.compact,
    super.key,
  });

  final TournamentFavorite favorite;
  final int rank;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final team = favorite.team;
    final accent = rank <= 3 ? FifaColors.focusYellow : FifaColors.blue;
    final width = compact ? 142.0 : 172.0;

    return Tooltip(
      message: 'Open ${team.name}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => openTeamPage(context, team),
          child: Ink(
            width: width,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: FifaColors.white.withValues(alpha: rank <= 3 ? 0.16 : 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: accent.withValues(alpha: 0.46)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        '$rank',
                        style: const TextStyle(
                          color: FifaColors.navy,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: FittedBox(child: FlagMark(value: team.flag)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        team.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FifaColors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: favorite.outlook.trophy / 100,
                          minHeight: 6,
                          color: accent,
                          backgroundColor: FifaColors.white.withValues(
                            alpha: 0.16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${favorite.outlook.trophy}%',
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Group ${team.group} • Elo ${favorite.profile.fifaElo}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: FifaColors.border,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeFavoritesStrip extends StatelessWidget {
  const HomeFavoritesStrip({required this.favorites, super.key});

  final List<TournamentFavorite> favorites;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: FifaColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FifaColors.border),
        boxShadow: [
          BoxShadow(
            color: FifaColors.navy.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: FifaColors.focusYellow.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.emoji_events,
                    color: FifaColors.orange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tournament favorites',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        'Top teams by title chance and model strength',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: FifaColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusPill(
                  icon: Icons.functions,
                  label: PredictionModel.version,
                ),
              ],
            ),
          ),
          SizedBox(
            height: 186,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              scrollDirection: Axis.horizontal,
              itemCount: favorites.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                return SizedBox(
                  width: 156,
                  child: FavoriteTeamTile(
                    favorite: favorites[index],
                    rank: index + 1,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class FavoriteTeamTile extends StatelessWidget {
  const FavoriteTeamTile({
    required this.favorite,
    required this.rank,
    super.key,
  });

  final TournamentFavorite favorite;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final team = favorite.team;
    final chance = favorite.outlook.trophy;
    final profile = favorite.profile;
    final accent = rank <= 3 ? FifaColors.orange : FifaColors.blueDark;

    return Tooltip(
      message: 'Open ${team.name}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => openTeamPage(context, team),
          child: Ink(
            decoration: BoxDecoration(
              color: rank <= 3
                  ? FifaColors.focusYellow.withValues(alpha: 0.12)
                  : FifaColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: accent.withValues(alpha: rank <= 3 ? 0.32 : 0.18),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '#$rank',
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${chance.clamp(0, 100)}%',
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: FittedBox(child: FlagMark(value: team.flag)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    team.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: chance.clamp(0, 100) / 100,
                      minHeight: 7,
                      color: accent,
                      backgroundColor: accent.withValues(alpha: 0.14),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Group ${team.group} • M ${profile.modelScore}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: FifaColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeHeroPanel extends StatelessWidget {
  const HomeHeroPanel({
    required this.leadFavorite,
    required this.featuredMatch,
    required this.featuredPrediction,
    super.key,
  });

  final TournamentFavorite leadFavorite;
  final MatchEntry? featuredMatch;
  final Prediction? featuredPrediction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [FifaColors.navy, FifaColors.deepBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(height: 4, color: FifaColors.orange),
          Padding(
            padding: const EdgeInsets.all(18),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 780;
                final summary = _HomeHeroSummary(
                  leadFavorite: leadFavorite,
                  featuredMatch: featuredMatch,
                  featuredPrediction: featuredPrediction,
                );
                final leader = _HomeLeaderPanel(favorite: leadFavorite);

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [summary, const SizedBox(height: 16), leader],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 3, child: summary),
                    const SizedBox(width: 20),
                    Expanded(flex: 2, child: leader),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeHeroSummary extends StatelessWidget {
  const _HomeHeroSummary({
    required this.leadFavorite,
    required this.featuredMatch,
    required this.featuredPrediction,
  });

  final TournamentFavorite leadFavorite;
  final MatchEntry? featuredMatch;
  final Prediction? featuredPrediction;

  @override
  Widget build(BuildContext context) {
    final match = featuredMatch;
    final prediction = featuredPrediction;
    final matchup = match == null
        ? null
        : '${SeedData.teamById(match.homeTeamId).name} - ${SeedData.teamById(match.awayTeamId).name}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            const _HomeHeroPill(icon: Icons.public, label: '48 teams'),
            const _HomeHeroPill(icon: Icons.table_rows, label: '12 groups'),
            _HomeHeroPill(
              icon: Icons.emoji_events,
              label: 'Leader ${leadFavorite.team.name}',
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'Tournament dashboard with favorites, matches and predictions',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: FifaColors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'The home page brings the strongest teams, upcoming fixtures and the focus prediction into one clear view.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: FifaColors.border,
            height: 1.35,
          ),
        ),
        if (match != null && prediction != null && matchup != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FifaColors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: FifaColors.white.withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.sports_soccer,
                  color: FifaColors.focusYellow,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        matchup,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FifaColors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${formatDateTime(match.kickoffUtc.toLocal())} • Prediction ${prediction.score}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: FifaColors.border,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(prediction.confidence * 100).round()}%',
                  style: const TextStyle(
                    color: FifaColors.blue,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _HomeLeaderPanel extends StatelessWidget {
  const _HomeLeaderPanel({required this.favorite});

  final TournamentFavorite favorite;

  @override
  Widget build(BuildContext context) {
    final team = favorite.team;
    final outlook = favorite.outlook;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => openTeamPage(context, team),
        child: Ink(
          decoration: BoxDecoration(
            color: FifaColors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: FifaColors.white.withValues(alpha: 0.18)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 56,
                      height: 56,
                      child: FittedBox(child: FlagMark(value: team.flag)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '#1 favorite',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: FifaColors.focusYellow,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          Text(
                            team.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: FifaColors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _HomeLeaderMetric(
                        label: 'Title',
                        value: '${outlook.trophy}%',
                      ),
                    ),
                    Expanded(
                      child: _HomeLeaderMetric(
                        label: 'Final',
                        value: '${outlook.finalChance}%',
                      ),
                    ),
                    Expanded(
                      child: _HomeLeaderMetric(
                        label: 'Model',
                        value: '${favorite.profile.modelScore}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: outlook.trophy / 100,
                    minHeight: 9,
                    color: FifaColors.focusYellow,
                    backgroundColor: FifaColors.white.withValues(alpha: 0.16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeLeaderMetric extends StatelessWidget {
  const _HomeLeaderMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: FifaColors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: FifaColors.border),
        ),
      ],
    );
  }
}

class _HomeHeroPill extends StatelessWidget {
  const _HomeHeroPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: FifaColors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FifaColors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: FifaColors.blue),
          const SizedBox(width: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: FifaColors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class HomeStatsGrid extends StatelessWidget {
  const HomeStatsGrid({required this.totalMatches, super.key});

  final int totalMatches;

  @override
  Widget build(BuildContext context) {
    final stats = [
      _HomeStat(
        label: 'Teams',
        value: '48',
        icon: Icons.flag,
        color: FifaColors.blueDark,
      ),
      _HomeStat(
        label: 'Groups',
        value: '12',
        icon: Icons.table_rows,
        color: FifaColors.orange,
      ),
      _HomeStat(
        label: 'Seed matches',
        value: '$totalMatches',
        icon: Icons.event,
        color: FifaColors.red,
      ),
      const _HomeStat(
        label: 'Model',
        value: PredictionModel.version,
        icon: Icons.functions,
        color: FifaColors.deepBlue,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 940
            ? 4
            : constraints.maxWidth >= 620
            ? 2
            : 1;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final stat in stats)
              SizedBox(
                width: (constraints.maxWidth - (columns - 1) * 12) / columns,
                child: _HomeStatTile(stat: stat),
              ),
          ],
        );
      },
    );
  }
}

class _HomeStat {
  const _HomeStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _HomeStatTile extends StatelessWidget {
  const _HomeStatTile({required this.stat});

  final _HomeStat stat;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FifaColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FifaColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: stat.color,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: stat.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(stat.icon, color: stat.color, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stat.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        stat.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: FifaColors.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HomeScheduleList extends StatelessWidget {
  const HomeScheduleList({
    required this.matches,
    required this.totalMatches,
    required this.onLoadMore,
    super.key,
  });

  final List<MatchEntry> matches;
  final int totalMatches;
  final VoidCallback? onLoadMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Schedule',
          subtitle:
              'The next ${matches.length} of $totalMatches group-stage matches, sorted by kickoff time',
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              for (var index = 0; index < matches.length; index += 1) ...[
                HomeMatchListItem(match: matches[index]),
                if (index != matches.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.center,
          child: FilledButton.icon(
            onPressed: onLoadMore,
            icon: const Icon(Icons.expand_more),
            label: Text(
              onLoadMore == null ? 'All matches loaded' : 'Load more matches',
            ),
          ),
        ),
      ],
    );
  }
}

class HomeMatchListItem extends StatelessWidget {
  const HomeMatchListItem({required this.match, super.key});

  final MatchEntry match;

  @override
  Widget build(BuildContext context) {
    final home = SeedData.teamById(match.homeTeamId);
    final away = SeedData.teamById(match.awayTeamId);
    final prediction = predictionForMatch(context, match);

    return InkWell(
      onTap: () => showMatchDetails(context, match),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 680;
            final teams = Row(
              children: [
                Expanded(child: TeamBadge(team: home)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    prediction.score,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Expanded(child: TeamBadge(team: away, alignEnd: true)),
              ],
            );
            final meta = Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusPill(
                  icon: Icons.schedule,
                  label: formatDateTime(match.kickoffUtc.toLocal()),
                ),
                StatusPill(label: 'Group ${match.group}'),
                StatusPill(
                  icon: Icons.percent,
                  label:
                      '${prediction.homeWin}-${prediction.draw}-${prediction.awayWin}%',
                ),
                StatusPill(
                  icon: Icons.analytics_outlined,
                  label:
                      'xG ${prediction.expectedHomeGoals.toStringAsFixed(1)}:${prediction.expectedAwayGoals.toStringAsFixed(1)}',
                ),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [teams, const SizedBox(height: 10), meta],
              );
            }

            return Row(
              children: [
                Expanded(flex: 5, child: teams),
                const SizedBox(width: 16),
                Expanded(flex: 4, child: meta),
                const SizedBox(width: 10),
                const Icon(Icons.chevron_right, color: FifaColors.muted),
              ],
            );
          },
        ),
      ),
    );
  }
}

class HomeSummarySections extends StatelessWidget {
  const HomeSummarySections({
    required this.favorites,
    required this.featured,
    required this.featuredPrediction,
    super.key,
  });

  final List<TournamentFavorite> favorites;
  final MatchEntry? featured;
  final Prediction? featuredPrediction;

  @override
  Widget build(BuildContext context) {
    final model = PredictionModel();
    final advanceLeaders = [...SeedData.teams]
      ..sort(
        (a, b) => model
            .tournamentOutlook(b)
            .round32
            .compareTo(model.tournamentOutlook(a).round32),
      );

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 920 ? 3 : 1;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        final cards = [
          SizedBox(width: width, child: const HomeProgramPanel()),
          SizedBox(
            width: width,
            child: HomeTeamsPanel(favorites: favorites),
          ),
          SizedBox(
            width: width,
            child: HomeAdvancePanel(teams: advanceLeaders.take(6).toList()),
          ),
        ];

        return Wrap(spacing: 12, runSpacing: 12, children: cards);
      },
    );
  }
}

class HomeProgramPanel extends StatelessWidget {
  const HomeProgramPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final nextMatches = SeedData.upcomingMatches(limit: 1);
    final next = nextMatches.isEmpty ? null : nextMatches.first;

    return _HomeInfoPanel(
      icon: Icons.event,
      title: 'Program',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${SeedData.fixtures.length} seeded group-stage fixtures'),
          const SizedBox(height: 10),
          if (next != null)
            Text(
              'Next: ${SeedData.teamById(next.homeTeamId).name} vs ${SeedData.teamById(next.awayTeamId).name}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          const SizedBox(height: 10),
          StatusPill(icon: Icons.table_rows, label: '12 groups'),
        ],
      ),
    );
  }
}

class HomeTeamsPanel extends StatelessWidget {
  const HomeTeamsPanel({required this.favorites, super.key});

  final List<TournamentFavorite> favorites;

  @override
  Widget build(BuildContext context) {
    return _HomeInfoPanel(
      icon: Icons.flag,
      title: 'Teams',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${SeedData.teams.length} qualified teams in this prototype'),
          const SizedBox(height: 10),
          for (final favorite in favorites.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  FlagMark(value: favorite.team.flag),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      favorite.team.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${favorite.outlook.trophy}%',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class HomeAdvancePanel extends StatelessWidget {
  const HomeAdvancePanel({required this.teams, super.key});

  final List<Team> teams;

  @override
  Widget build(BuildContext context) {
    final model = PredictionModel();

    return _HomeInfoPanel(
      icon: Icons.trending_up,
      title: 'Best chance to advance',
      child: Column(
        children: [
          for (final team in teams)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ProbabilityBar(
                label: team.name,
                team: team,
                value: model.tournamentOutlook(team).round32,
                color: FifaColors.blueDark,
              ),
            ),
        ],
      ),
    );
  }
}

class _HomeInfoPanel extends StatelessWidget {
  const _HomeInfoPanel({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class HomeFooter extends StatelessWidget {
  const HomeFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: FifaColors.navy,
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final content = [
            const _FooterColumn(
              title: 'Program',
              lines: ['Full group schedule', 'Kickoff time and venues'],
            ),
            const _FooterColumn(
              title: 'Teams',
              lines: ['48 team profiles', 'Squads, form and Elo'],
            ),
            const _FooterColumn(
              title: 'Best chance to advance',
              lines: ['Round of 32 leaders', 'Elo-calibrated outlooks'],
            ),
          ];

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in content) ...[
                  item,
                  if (item != content.last) const SizedBox(height: 16),
                ],
                const SizedBox(height: 18),
                const Divider(color: FifaColors.deepBlue, height: 1),
                const SizedBox(height: 12),
                const HopixFooterLink(),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final item in content)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: item,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(color: FifaColors.deepBlue, height: 1),
              const SizedBox(height: 10),
              const Align(
                alignment: Alignment.centerRight,
                child: HopixFooterLink(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class HopixFooterLink extends StatelessWidget {
  const HopixFooterLink({super.key});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => openExternalUrl('https://www.hopixit.com/en'),
      icon: const Icon(Icons.open_in_new, size: 16),
      label: const Text('Developed by Hopix'),
      style: TextButton.styleFrom(
        foregroundColor: FifaColors.blue,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _FooterColumn extends StatelessWidget {
  const _FooterColumn({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: FifaColors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        for (final line in lines)
          Text(
            line,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: FifaColors.border),
          ),
      ],
    );
  }
}

class HomeContentGrid extends StatelessWidget {
  const HomeContentGrid({
    required this.upcoming,
    required this.featured,
    required this.featuredPrediction,
    super.key,
  });

  final List<MatchEntry> upcoming;
  final MatchEntry? featured;
  final Prediction? featuredPrediction;

  @override
  Widget build(BuildContext context) {
    final matches = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Upcoming matches',
          subtitle: 'Schedule cards with V2 probabilities in the preview',
        ),
        const SizedBox(height: 12),
        MatchList(matches: upcoming),
      ],
    );
    final focus = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Focus prediction',
          subtitle: 'Poisson xG, factors and local data quality',
        ),
        const SizedBox(height: 12),
        if (featured == null || featuredPrediction == null)
          const EmptyState(
            icon: Icons.query_stats,
            title: 'No focus match',
            body: 'When an upcoming match exists, the prediction appears here.',
          )
        else
          PredictionCard(match: featured!, prediction: featuredPrediction!),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [matches, const SizedBox(height: 24), focus],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: matches),
            const SizedBox(width: 18),
            Expanded(flex: 4, child: focus),
          ],
        );
      },
    );
  }
}

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  String? _group;
  MatchStatus? _status;

  @override
  Widget build(BuildContext context) {
    final worldCupData = WorldCupDataScope.of(context);
    final matches = worldCupData.fixtures.where((match) {
      final groupMatch = _group == null || match.group == _group;
      final statusMatch = _status == null || match.status == _status;
      return groupMatch && statusMatch;
    }).toList()..sort((a, b) => a.kickoffUtc.compareTo(b.kickoffUtc));

    return PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Schedule & Predictions',
            subtitle:
                'Filter by group or status, then expand a fixture for model details',
          ),
          const SizedBox(height: 12),
          ApiFootballStatusStrip(data: worldCupData),
          const SizedBox(height: 12),
          FilterStrip(
            group: _group,
            status: _status,
            onGroupChanged: (value) => setState(() => _group = value),
            onStatusChanged: (value) => setState(() => _status = value),
          ),
          const SizedBox(height: 16),
          MatchList(matches: matches, showDetails: true),
        ],
      ),
    );
  }
}

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final worldCupData = WorldCupDataScope.of(context);
    final matches = [...worldCupData.fixtures]
      ..sort((a, b) => a.kickoffUtc.compareTo(b.kickoffUtc));

    return PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Results',
            subtitle: 'Chronological match list with scores as they arrive',
          ),
          const SizedBox(height: 12),
          ApiFootballStatusStrip(data: worldCupData),
          const SizedBox(height: 12),
          ResultsMatchList(matches: matches),
        ],
      ),
    );
  }
}

class NewsScreen extends StatefulWidget {
  const NewsScreen({required this.active, super.key});

  final bool active;

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final _client = NewsFeedClient();
  NewsSourceFilter _source = NewsSourceFilter.all;
  NewsScopeFilter _scope = NewsScopeFilter.worldCup;
  NewsFeedResult? _result;
  Object? _error;
  bool _loading = false;
  bool _loadedOnce = false;

  @override
  void initState() {
    super.initState();
    if (widget.active) unawaited(_refresh());
  }

  @override
  void didUpdateWidget(covariant NewsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_loadedOnce && !_loading) {
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _client.fetchNews(source: _source, scope: _scope);
      if (!mounted) return;
      setState(() {
        _result = result;
        _loadedOnce = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setSource(NewsSourceFilter value) {
    if (_source == value) return;
    setState(() => _source = value);
    unawaited(_refresh());
  }

  void _setScope(Set<NewsScopeFilter> value) {
    if (value.isEmpty || _scope == value.first) return;
    setState(() => _scope = value.first);
    unawaited(_refresh());
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final items = result?.items ?? const <NewsArticle>[];

    return PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'News',
            subtitle: 'World Cup headlines from ESPN and Sky Sports RSS',
          ),
          const SizedBox(height: 12),
          NewsControls(
            source: _source,
            scope: _scope,
            loading: _loading,
            result: result,
            onSourceChanged: _setSource,
            onScopeChanged: _setScope,
            onRefresh: () => unawaited(_refresh()),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            NewsErrorBanner(message: 'News feed unavailable: $_error'),
          ],
          if (result != null && result.errors.isNotEmpty) ...[
            const SizedBox(height: 12),
            NewsErrorBanner(
              message: result.errors
                  .map((error) => '${error.source}: ${error.message}')
                  .join(' • '),
            ),
          ],
          const SizedBox(height: 16),
          if (_loading && !_loadedOnce)
            const NewsLoadingList()
          else if (items.isEmpty)
            const EmptyState(
              icon: Icons.article_outlined,
              title: 'No headlines',
              body: 'Try All Football or refresh the RSS feeds.',
            )
          else
            NewsArticleList(items: items),
        ],
      ),
    );
  }
}

class NewsControls extends StatelessWidget {
  const NewsControls({
    required this.source,
    required this.scope,
    required this.loading,
    required this.result,
    required this.onSourceChanged,
    required this.onScopeChanged,
    required this.onRefresh,
    super.key,
  });

  final NewsSourceFilter source;
  final NewsScopeFilter scope;
  final bool loading;
  final NewsFeedResult? result;
  final ValueChanged<NewsSourceFilter> onSourceChanged;
  final ValueChanged<Set<NewsScopeFilter>> onScopeChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final generatedAt = result?.generatedAt;
    final details = [
      if (result != null) '${result!.items.length} shown',
      if (result != null) '${result!.totalMatched} matched',
      if (result != null) '${result!.totalFetched} fetched',
      if (generatedAt != null)
        'Updated ${formatDateTime(generatedAt.toLocal())}',
    ].join(' • ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FifaColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FifaColors.border),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SegmentedButton<NewsScopeFilter>(
            segments: [
              for (final item in NewsScopeFilter.values)
                ButtonSegment(value: item, label: Text(item.label)),
            ],
            selected: {scope},
            onSelectionChanged: onScopeChanged,
          ),
          SegmentedButton<NewsSourceFilter>(
            segments: [
              for (final item in NewsSourceFilter.values)
                ButtonSegment(value: item, label: Text(item.label)),
            ],
            selected: {source},
            onSelectionChanged: (value) => onSourceChanged(value.first),
          ),
          StatusPill(icon: Icons.rss_feed, label: 'RSS'),
          if (details.isNotEmpty) StatusPill(label: details),
          Tooltip(
            message: 'Refresh RSS feeds',
            child: IconButton.filledTonal(
              onPressed: loading ? null : onRefresh,
              icon: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
            ),
          ),
        ],
      ),
    );
  }
}

class NewsArticleList extends StatelessWidget {
  const NewsArticleList({required this.items, super.key});

  final List<NewsArticle> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final item in items) ...[
          NewsArticleCard(item: item),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class NewsArticleCard extends StatefulWidget {
  const NewsArticleCard({required this.item, super.key});

  final NewsArticle item;

  @override
  State<NewsArticleCard> createState() => _NewsArticleCardState();
}

class _NewsArticleCardState extends State<NewsArticleCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final publishedAt = item.publishedAt;
    final dateLabel = publishedAt == null
        ? item.publishedLabel
        : formatDateTime(publishedAt.toLocal());
    final displayTitle = newsDisplayTitle(item);
    final quickTake = newsQuickTake(item);
    final hasLongSummary = quickTake.length > 360;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FifaColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FifaColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showImage =
              constraints.maxWidth >= 720 && item.imageUrl?.isNotEmpty == true;
          final textMaxWidth = constraints.maxWidth >= 900
              ? 640.0
              : double.infinity;
          final content = ConstrainedBox(
            constraints: BoxConstraints(maxWidth: textMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusPill(icon: Icons.public, label: item.source),
                    if (dateLabel.isNotEmpty)
                      StatusPill(icon: Icons.schedule, label: dateLabel),
                    StatusPill(label: 'Provided by ${item.source}'),
                    if (quickTake.isNotEmpty)
                      const StatusPill(
                        icon: Icons.short_text,
                        label: 'Quick take',
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (quickTake.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: FifaColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: FifaColors.blue.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick take',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: FifaColors.blueDark,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          quickTake,
                          maxLines: _expanded ? 14 : 7,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: FifaColors.muted, height: 1.35),
                        ),
                        if (hasLongSummary) ...[
                          const SizedBox(height: 4),
                          TextButton.icon(
                            onPressed: () =>
                                setState(() => _expanded = !_expanded),
                            icon: Icon(
                              _expanded ? Icons.expand_less : Icons.expand_more,
                              size: 18,
                            ),
                            label: Text(_expanded ? 'Less' : 'More'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => openExternalUrl(item.link),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: Text('Full article at ${item.source}'),
                  ),
                ),
              ],
            ),
          );

          if (!showImage) return content;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: content),
              const SizedBox(width: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  item.imageUrl!,
                  width: 176,
                  height: 104,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class NewsLoadingList extends StatelessWidget {
  const NewsLoadingList({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class NewsErrorBanner extends StatelessWidget {
  const NewsErrorBanner({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FifaColors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FifaColors.red.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: FifaColors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: FifaColors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final worldCupData = WorldCupDataScope.of(context);
    return PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Groups',
            subtitle:
                'Standings from seed results, with FIFA ranking as tie-breaker',
          ),
          const SizedBox(height: 12),
          for (final group in SeedData.groups) ...[
            GroupCard(group: group, fixtures: worldCupData.fixtures),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  String _query = '';
  String? _group;

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = _query.trim().toLowerCase();
    final teams =
        SeedData.teams.where((team) {
          final groupMatch = _group == null || team.group == _group;
          final queryMatch =
              normalizedQuery.isEmpty ||
              team.name.toLowerCase().contains(normalizedQuery);
          return groupMatch && queryMatch;
        }).toList()..sort((a, b) {
          final groupCompare = a.group.compareTo(b.group);
          if (groupCompare != 0) return groupCompare;
          return a.fifaRanking.compareTo(b.fifaRanking);
        });

    return PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Teams',
            subtitle: '48 teams with flags, groups and profiles',
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Search team',
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('All'),
                    selected: _group == null,
                    onSelected: (_) => setState(() => _group = null),
                  ),
                ),
                for (final group in SeedData.groups)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('Group $group'),
                      selected: _group == group,
                      onSelected: (_) => setState(() => _group = group),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900
                  ? 3
                  : constraints.maxWidth >= 620
                  ? 2
                  : 1;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final team in teams)
                    SizedBox(
                      width:
                          (constraints.maxWidth - (columns - 1) * 12) / columns,
                      child: TeamCard(team: team),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class PageFrame extends StatelessWidget {
  const PageFrame({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}

class DataNotice extends StatelessWidget {
  const DataNotice({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.offline_bolt,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Local Algorithm v2 mode',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    compact
                        ? 'Predictions come from a Poisson seed model. A live API/backend can replace synthetic form, xG and availability data.'
                        : 'The app uses a Poisson seed model, squad data and local tournament simulation. A backend/API layer can replace synthetic form, xG and availability data without changing navigation.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ApiFootballStatusStrip extends StatelessWidget {
  const ApiFootballStatusStrip({required this.data, super.key});

  final WorldCupDataController data;

  @override
  Widget build(BuildContext context) {
    final color = data.usingApiFixtures
        ? Theme.of(context).colorScheme.primary
        : FifaColors.muted;
    final source = data.usingApiFixtures
        ? data.rawResultCount > 0
              ? 'API-Football fixtures + results'
              : data.rawPredictionCount > 0
              ? 'API-Football fixtures + predictions'
              : 'API-Football fixtures'
        : data.apiEnabled
        ? 'Seed fallback'
        : 'Seed data';
    final details = [
      '${data.fixtures.length} matches',
      if (data.rawFixtureCount > 0) '${data.rawFixtureCount} raw API fixtures',
      if (data.rawPredictionCount > 0)
        '${data.rawPredictionCount} API predictions',
      if (data.predictionRequestCount > 0)
        '${data.predictionRequestCount} prediction calls',
      if (data.rawResultCount > 0) '${data.rawResultCount} result fixtures',
      if (data.resultRequestCount > 0)
        '${data.resultRequestCount} result calls',
      if (data.requestsRemainingToday != null)
        '${data.requestsRemainingToday} requests left',
      if (data.lastSyncedAt != null)
        'Synced ${formatDateTime(data.lastSyncedAt!.toLocal())}',
      if (data.lastPredictionsSyncedAt != null)
        'Predictions ${formatDateTime(data.lastPredictionsSyncedAt!.toLocal())}',
      if (data.lastResultsSyncedAt != null)
        'Results ${formatDateTime(data.lastResultsSyncedAt!.toLocal())}',
      if (data.lastError != null) 'API unavailable',
      if (data.lastPredictionError != null) 'Predictions unavailable',
      if (data.lastResultError != null) 'Results unavailable',
    ].join(' • ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: FifaColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FifaColors.border),
      ),
      child: Row(
        children: [
          Icon(
            data.usingApiFixtures ? Icons.cloud_done : Icons.storage_outlined,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  details,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: FifaColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: data.apiEnabled
                ? 'Refresh API-Football fixtures and predictions'
                : 'API-Football is disabled in this build',
            child: IconButton.filledTonal(
              onPressed:
                  data.apiEnabled &&
                      !data.isRefreshing &&
                      !data.isRefreshingPredictions &&
                      !data.isRefreshingResults
                  ? () => unawaited(data.refreshApiData(forceResults: true))
                  : null,
              icon:
                  data.isRefreshing ||
                      data.isRefreshingPredictions ||
                      data.isRefreshingResults
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
            ),
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, required this.subtitle, super.key});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: FifaColors.muted),
        ),
      ],
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    required this.label,
    required this.value,
    required this.icon,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: 184,
      height: 132,
      child: Container(
        decoration: BoxDecoration(
          color: FifaColors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: FifaColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

class FilterStrip extends StatelessWidget {
  const FilterStrip({
    required this.group,
    required this.status,
    required this.onGroupChanged,
    required this.onStatusChanged,
    super.key,
  });

  final String? group;
  final MatchStatus? status;
  final ValueChanged<String?> onGroupChanged;
  final ValueChanged<MatchStatus?> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: 'All groups',
                selected: group == null,
                onSelected: () => onGroupChanged(null),
              ),
              for (final item in SeedData.groups)
                _FilterChip(
                  label: 'Group $item',
                  selected: group == item,
                  onSelected: () => onGroupChanged(item),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('All statuses'),
              selected: status == null,
              onSelected: (_) => onStatusChanged(null),
            ),
            for (final item in MatchStatus.values)
              ChoiceChip(
                label: Text(item.label),
                selected: status == item,
                onSelected: (_) => onStatusChanged(item),
              ),
          ],
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class MatchList extends StatelessWidget {
  const MatchList({required this.matches, this.showDetails = false, super.key});

  final List<MatchEntry> matches;
  final bool showDetails;

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return const EmptyState(
        icon: Icons.event_busy,
        title: 'No matches',
        body: 'Change filters or refresh the data.',
      );
    }

    return Column(
      children: [
        for (final match in matches) ...[
          MatchCard(match: match, showDetails: showDetails),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class ResultsMatchList extends StatelessWidget {
  const ResultsMatchList({required this.matches, super.key});

  final List<MatchEntry> matches;

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) {
      return const EmptyState(
        icon: Icons.fact_check_outlined,
        title: 'No results',
        body: 'Match results will appear here when fixture data is updated.',
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < matches.length; index += 1) ...[
            ResultsMatchRow(match: matches[index]),
            if (index != matches.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class ResultsMatchRow extends StatelessWidget {
  const ResultsMatchRow({required this.match, super.key});

  final MatchEntry match;

  @override
  Widget build(BuildContext context) {
    final home = SeedData.teamById(match.homeTeamId);
    final away = SeedData.teamById(match.awayTeamId);
    final kickoff = formatDateTime(match.kickoffUtc.toLocal());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 680;
          final matchRow = Row(
            children: [
              Expanded(child: TeamBadge(team: home)),
              const SizedBox(width: 10),
              ResultScoreBox(match: match),
              const SizedBox(width: 10),
              Expanded(child: TeamBadge(team: away, alignEnd: true)),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kickoff,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: FifaColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                matchRow,
              ],
            );
          }

          return Row(
            children: [
              SizedBox(
                width: 104,
                child: Text(
                  kickoff,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: FifaColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: matchRow),
            ],
          );
        },
      ),
    );
  }
}

class ResultScoreBox extends StatelessWidget {
  const ResultScoreBox({required this.match, super.key});

  final MatchEntry match;

  @override
  Widget build(BuildContext context) {
    final hasResult = match.hasResult;
    final color = hasResult
        ? Theme.of(context).colorScheme.primary
        : FifaColors.muted;

    return Container(
      width: 58,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: hasResult ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        match.scoreLabel,
        maxLines: 1,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 16,
        ),
      ),
    );
  }
}

class MatchCard extends StatefulWidget {
  const MatchCard({required this.match, required this.showDetails, super.key});

  final MatchEntry match;
  final bool showDetails;

  @override
  State<MatchCard> createState() => _MatchCardState();
}

class _MatchCardState extends State<MatchCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
    final home = SeedData.teamById(match.homeTeamId);
    final away = SeedData.teamById(match.awayTeamId);
    final prediction = predictionForMatch(context, match);

    return Container(
      decoration: BoxDecoration(
        color: FifaColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FifaColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TeamMatchPreviewSide(
                    team: home,
                    winProbability: prediction.homeWin,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    children: [
                      Text(
                        match.hasResult
                            ? '${match.homeScore}:${match.awayScore}'
                            : 'vs',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      StatusPill(label: match.status.label),
                      const SizedBox(height: 4),
                      StatusPill(label: 'X ${prediction.draw}%'),
                    ],
                  ),
                ),
                Expanded(
                  child: TeamMatchPreviewSide(
                    team: away,
                    winProbability: prediction.awayWin,
                    alignEnd: true,
                  ),
                ),
                if (widget.showDetails) ...[
                  const SizedBox(width: 8),
                  Tooltip(
                    message: _expanded ? 'Collapse details' : 'Expand details',
                    child: IconButton.filledTonal(
                      icon: Icon(
                        _expanded ? Icons.expand_less : Icons.chevron_right,
                      ),
                      onPressed: () => setState(() => _expanded = !_expanded),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.schedule, size: 16, color: FifaColors.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${formatDateTime(match.kickoffUtc.toLocal())} • Group ${match.group}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${match.venue}, ${match.city}',
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusPill(
                  icon: Icons.sports_score,
                  label: 'Prediction ${prediction.score}',
                ),
                StatusPill(
                  icon: Icons.analytics_outlined,
                  label:
                      'xG ${prediction.expectedHomeGoals.toStringAsFixed(1)}:${prediction.expectedAwayGoals.toStringAsFixed(1)}',
                ),
                StatusPill(
                  icon: Icons.speed,
                  label: '${confidenceLabel(prediction.confidence)} confidence',
                ),
                StatusPill(
                  icon: Icons.dataset_outlined,
                  label: 'Data ${(prediction.dataQuality * 100).round()}%',
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),
              MatchInlineDetails(
                match: match,
                prediction: prediction,
                onCollapse: () => setState(() => _expanded = false),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MatchInlineDetails extends StatelessWidget {
  const MatchInlineDetails({
    required this.match,
    required this.prediction,
    this.onCollapse,
    super.key,
  });

  final MatchEntry match;
  final Prediction prediction;
  final VoidCallback? onCollapse;

  @override
  Widget build(BuildContext context) {
    final home = SeedData.teamById(match.homeTeamId);
    final away = SeedData.teamById(match.awayTeamId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatusPill(
                    icon: Icons.event,
                    label: formatDateTime(match.kickoffUtc.toLocal()),
                  ),
                  StatusPill(label: 'Group ${match.group}'),
                  StatusPill(icon: Icons.stadium, label: match.city),
                ],
              ),
            ),
            if (onCollapse != null)
              Tooltip(
                message: 'Collapse details',
                child: IconButton(
                  icon: const Icon(Icons.close_fullscreen),
                  onPressed: onCollapse,
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        PredictionCard(
          match: match,
          prediction: prediction,
          enableDetails: false,
          framed: false,
        ),
        const SizedBox(height: 18),
        Text(
          'Last 5 matches',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        RecentComparison(home: home, away: away),
      ],
    );
  }
}

class TeamMatchPreviewSide extends StatelessWidget {
  const TeamMatchPreviewSide({
    required this.team,
    required this.winProbability,
    this.alignEnd = false,
    super.key,
  });

  final Team team;
  final int winProbability;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final badge = TeamBadge(team: team, alignEnd: alignEnd);
    final probability = StatusPill(
      icon: Icons.percent,
      label: '$winProbability%',
    );

    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [badge, const SizedBox(height: 6), probability],
    );
  }
}

class PredictionCard extends StatelessWidget {
  const PredictionCard({
    required this.match,
    required this.prediction,
    this.enableDetails = true,
    this.framed = true,
    super.key,
  });

  final MatchEntry match;
  final Prediction prediction;
  final bool enableDetails;
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final content = PredictionCardContent(match: match, prediction: prediction);

    if (!framed) return content;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: enableDetails ? () => showMatchDetails(context, match) : null,
        child: Padding(padding: const EdgeInsets.all(16), child: content),
      ),
    );
  }
}

class PredictionCardContent extends StatelessWidget {
  const PredictionCardContent({
    required this.match,
    required this.prediction,
    super.key,
  });

  final MatchEntry match;
  final Prediction prediction;

  @override
  Widget build(BuildContext context) {
    final home = SeedData.teamById(match.homeTeamId);
    final away = SeedData.teamById(match.awayTeamId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: TeamBadge(team: home)),
            Text(
              prediction.score,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            Expanded(child: TeamBadge(team: away, alignEnd: true)),
          ],
        ),
        const SizedBox(height: 14),
        ProbabilityBar(
          label: home.name,
          team: home,
          value: prediction.homeWin,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 8),
        ProbabilityBar(
          label: 'Draw',
          value: prediction.draw,
          color: FifaColors.muted,
        ),
        const SizedBox(height: 8),
        ProbabilityBar(
          label: away.name,
          team: away,
          value: prediction.awayWin,
          color: Theme.of(context).colorScheme.secondary,
        ),
        const SizedBox(height: 12),
        PredictionMetaStrip(prediction: prediction),
        if (prediction.factors.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            'Why this %?',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          FactorComparisonList(factors: prediction.factors.take(3).toList()),
        ],
        const SizedBox(height: 12),
        Text(prediction.explanation),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusPill(
              icon: Icons.percent,
              label:
                  '${confidenceLabel(prediction.confidence)} ${(prediction.confidence * 100).round()}%',
            ),
            StatusPill(icon: Icons.functions, label: prediction.sourceLabel),
            StatusPill(
              icon: Icons.dataset_outlined,
              label: 'Data ${(prediction.dataQuality * 100).round()}%',
            ),
            StatusPill(
              icon: Icons.event,
              label: formatDate(match.kickoffUtc.toLocal()),
            ),
          ],
        ),
      ],
    );
  }
}

class PredictionMetaStrip extends StatelessWidget {
  const PredictionMetaStrip({required this.prediction, super.key});

  final Prediction prediction;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        StatusPill(
          icon: Icons.analytics_outlined,
          label:
              'xG ${prediction.expectedHomeGoals.toStringAsFixed(2)}:${prediction.expectedAwayGoals.toStringAsFixed(2)}',
        ),
        StatusPill(
          icon: Icons.functions,
          label:
              'Model ${prediction.homeModelScore}:${prediction.awayModelScore}',
        ),
        StatusPill(
          icon: Icons.dataset_outlined,
          label: 'Quality ${(prediction.dataQuality * 100).round()}%',
        ),
      ],
    );
  }
}

class FactorComparisonList extends StatelessWidget {
  const FactorComparisonList({required this.factors, super.key});

  final List<PredictionFactor> factors;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final factor in factors) ...[
          FactorComparisonRow(factor: factor),
          if (factor != factors.last) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class FactorComparisonRow extends StatelessWidget {
  const FactorComparisonRow({required this.factor, super.key});

  final PredictionFactor factor;

  @override
  Widget build(BuildContext context) {
    final homeValue = factor.homeScore.clamp(0.0, 1.0).toDouble();
    final awayValue = factor.awayScore.clamp(0.0, 1.0).toDouble();

    return Tooltip(
      message: factor.description,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 112,
                child: Text(
                  factor.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Expanded(
                child: Text(
                  factor.homeValue,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  factor.awayValue,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: MetricMiniBar(
                  value: homeValue,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: MetricMiniBar(
                  value: awayValue,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MetricMiniBar extends StatelessWidget {
  const MetricMiniBar({required this.value, required this.color, super.key});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 7,
        color: color,
        backgroundColor: color.withValues(alpha: 0.12),
      ),
    );
  }
}

class ProbabilityBar extends StatelessWidget {
  const ProbabilityBar({
    required this.label,
    required this.value,
    required this.color,
    this.team,
    super.key,
  });

  final String label;
  final int value;
  final Color color;
  final Team? team;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 112,
          child: team == null
              ? Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)
              : InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => openTeamPage(context, team!),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: value / 100,
              minHeight: 9,
              color: color,
              backgroundColor: color.withValues(alpha: 0.14),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 42,
          child: Text(
            '$value%',
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class GroupCard extends StatelessWidget {
  const GroupCard({required this.group, required this.fixtures, super.key});

  final String group;
  final List<MatchEntry> fixtures;

  @override
  Widget build(BuildContext context) {
    final rows = StandingsCalculator.rowsForGroup(group, fixtures: fixtures);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Group $group',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Text(
                  '${rows.length} teams',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 36,
                dataRowMinHeight: 42,
                dataRowMaxHeight: 46,
                columns: const [
                  DataColumn(label: Text('Team')),
                  DataColumn(numeric: true, label: Text('P')),
                  DataColumn(numeric: true, label: Text('W')),
                  DataColumn(numeric: true, label: Text('D')),
                  DataColumn(numeric: true, label: Text('L')),
                  DataColumn(numeric: true, label: Text('GD')),
                  DataColumn(numeric: true, label: Text('Pts')),
                ],
                rows: [
                  for (final row in rows)
                    DataRow(
                      cells: [
                        DataCell(
                          SizedBox(
                            width: 210,
                            child: TeamBadge(team: row.team),
                          ),
                        ),
                        DataCell(Text('${row.played}')),
                        DataCell(Text('${row.wins}')),
                        DataCell(Text('${row.draws}')),
                        DataCell(Text('${row.losses}')),
                        DataCell(Text('${row.goalDifference}')),
                        DataCell(Text('${row.points}')),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TeamCard extends StatelessWidget {
  const TeamCard({required this.team, super.key});

  final Team team;

  @override
  Widget build(BuildContext context) {
    final recent = SeedData.recentMatchesFor(team, count: 5);
    final points = recent.fold<int>(0, (sum, match) => sum + match.points);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => openTeamPage(context, team),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TeamBadge(team: team),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatusPill(label: 'Group ${team.group}'),
                  StatusPill(
                    icon: Icons.leaderboard,
                    label: 'FIFA #${team.fifaRanking}',
                  ),
                  StatusPill(
                    icon: Icons.trending_up,
                    label: '$points pts / 5 matches',
                  ),
                  StatusPill(
                    icon: Icons.groups,
                    label: '${team.squad.length} players',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Coach: ${team.coach}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TeamBadge extends StatelessWidget {
  const TeamBadge({
    required this.team,
    this.alignEnd = false,
    this.enableLink = true,
    super.key,
  });

  final Team team;
  final bool alignEnd;
  final bool enableLink;

  @override
  Widget build(BuildContext context) {
    final children = [
      FlagMark(value: team.flag),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          team.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    ];

    final badge = Row(
      mainAxisAlignment: alignEnd
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: alignEnd ? children.reversed.toList() : children,
    );

    if (!enableLink) return badge;

    return Tooltip(
      message: 'Open ${team.name}',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => openTeamPage(context, team),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: badge,
        ),
      ),
    );
  }
}

class FlagMark extends StatelessWidget {
  const FlagMark({required this.value, super.key});

  final String value;

  @override
  Widget build(BuildContext context) {
    final isCode = value.length == 3;
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isCode ? FifaColors.surface : FifaColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FifaColors.border),
      ),
      child: Text(
        value,
        style: TextStyle(
          fontSize: isCode ? 11 : 22,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({required this.label, this.icon, super.key});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.body,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              Icon(
                icon,
                size: 36,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 10),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(body, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

void showMatchDetails(BuildContext context, MatchEntry match) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => MatchDetailSheet(match: match),
  );
}

Prediction predictionForMatch(BuildContext context, MatchEntry match) {
  final localPrediction = PredictionModel().predict(match);
  final apiPrediction = WorldCupDataScope.of(context).predictionFor(match);
  return apiPrediction?.toPrediction(match, localPrediction) ?? localPrediction;
}

void openTeamPage(BuildContext context, Team team) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => TeamDetailPage(team: team)));
}

class TeamDetailPage extends StatelessWidget {
  const TeamDetailPage({required this.team, super.key});

  final Team team;

  @override
  Widget build(BuildContext context) {
    final model = PredictionModel();
    final outlook = model.tournamentOutlook(team);
    final profile = model.teamProfile(team);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: TeamBadge(team: team, enableLink: false),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: [
              Tab(icon: Icon(Icons.shield_outlined), text: 'Team'),
              Tab(icon: Icon(Icons.event_outlined), text: 'Matches'),
              Tab(icon: Icon(Icons.history_outlined), text: 'Form'),
              Tab(icon: Icon(Icons.star_outline), text: 'Players'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            TeamOverviewTab(team: team, outlook: outlook, profile: profile),
            TeamMatchesTab(team: team, outlook: outlook, profile: profile),
            TeamFormTab(team: team, outlook: outlook, profile: profile),
            TeamPlayersTab(team: team, outlook: outlook, profile: profile),
          ],
        ),
      ),
    );
  }
}

class TeamTabFrame extends StatelessWidget {
  const TeamTabFrame({
    required this.team,
    required this.outlook,
    required this.profile,
    required this.children,
    super.key,
  });

  final Team team;
  final TeamTournamentOutlook outlook;
  final TeamModelProfile profile;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TeamPageHeader(team: team, outlook: outlook, profile: profile),
            TeamWorldCupRecordBand(team: team),
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: children,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TeamPageHeader extends StatelessWidget {
  const TeamPageHeader({
    required this.team,
    required this.outlook,
    required this.profile,
    super.key,
  });

  final Team team;
  final TeamTournamentOutlook outlook;
  final TeamModelProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [FifaColors.navy, FifaColors.navyAlt, FifaColors.deepBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 22),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 720;
              final identity = Row(
                children: [
                  SizedBox(
                    width: compact ? 62 : 76,
                    height: compact ? 62 : 76,
                    child: FittedBox(child: FlagMark(value: team.flag)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          team.name,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: FifaColors.white,
                                fontWeight: FontWeight.w900,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            TeamHeroPill(label: 'Group ${team.group}'),
                            TeamHeroPill(
                              icon: Icons.leaderboard,
                              label: 'FIFA #${team.fifaRanking}',
                            ),
                            TeamHeroPill(icon: Icons.person, label: team.coach),
                            TeamHeroPill(
                              icon: Icons.groups,
                              label: '${team.squad.length} players',
                            ),
                            TeamHeroPill(
                              icon: Icons.functions,
                              label: 'Model ${profile.modelScore}/100',
                            ),
                            TeamHeroPill(
                              icon: Icons.dataset_outlined,
                              label: 'Data ${profile.dataQualityPercent}%',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
              final chance = Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: FifaColors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: FifaColors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: CupChancePanel(outlook: outlook, onDark: true),
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [identity, const SizedBox(height: 16), chance],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: identity),
                  const SizedBox(width: 24),
                  SizedBox(width: 390, child: chance),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class TeamWorldCupRecordBand extends StatelessWidget {
  const TeamWorldCupRecordBand({required this.team, super.key});

  final Team team;

  @override
  Widget build(BuildContext context) {
    final record = teamWorldCupRecords[team.id];
    if (record == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: FifaColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: FifaColors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: FifaColors.border),
              boxShadow: [
                BoxShadow(
                  color: FifaColors.navy.withValues(alpha: 0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 760;
                final topStats = [
                  _WorldCupInfoMetric(
                    label: 'First WC',
                    value: '${record.firstWorldCup}',
                  ),
                  _WorldCupInfoMetric(
                    label: 'Participations',
                    value: record.isDebut
                        ? 'Debut'
                        : '${record.participationsBefore2026}',
                    note: '${ordinal(record.participationIn2026)} in 2026',
                  ),
                  _WorldCupInfoMetric(label: 'Coach', value: team.coach),
                ];
                final recordMetrics = [
                  _WorldCupRecordMetric(
                    label: 'Played',
                    value: record.played,
                    color: FifaColors.navyAlt,
                  ),
                  _WorldCupRecordMetric(
                    label: 'Wins',
                    value: record.wins,
                    color: const Color(0xFF23A96F),
                  ),
                  _WorldCupRecordMetric(
                    label: 'Draws',
                    value: record.draws,
                    color: const Color(0xFFF4A32C),
                  ),
                  _WorldCupRecordMetric(
                    label: 'Losses',
                    value: record.losses,
                    color: const Color(0xFFE95263),
                  ),
                  _WorldCupRecordMetric(
                    label: 'Goals scored',
                    value: record.goalsScored,
                    color: FifaColors.orange,
                  ),
                  _WorldCupRecordMetric(
                    label: 'Goals conceded',
                    value: record.goalsConceded,
                    color: FifaColors.muted,
                  ),
                ];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: const [
                        StatusPill(
                          icon: Icons.public,
                          label: 'World Cup history',
                        ),
                        Tooltip(
                          message: teamWorldCupRecordSourceName,
                          child: StatusPill(
                            icon: Icons.verified_outlined,
                            label: 'API-Football cards',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (compact)
                      Column(
                        children: [
                          for (final stat in topStats) ...[
                            _WorldCupInfoTile(metric: stat, compact: true),
                            if (stat != topStats.last)
                              const SizedBox(height: 10),
                          ],
                        ],
                      )
                    else
                      IntrinsicHeight(
                        child: Row(
                          children: [
                            for (final stat in topStats) ...[
                              Expanded(child: _WorldCupInfoTile(metric: stat)),
                              if (stat != topStats.last)
                                const VerticalDivider(
                                  width: 24,
                                  color: FifaColors.border,
                                ),
                            ],
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: FifaColors.border),
                    const SizedBox(height: 16),
                    Text(
                      'World Cup record',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: FifaColors.muted,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, metricConstraints) {
                        final columns = metricConstraints.maxWidth >= 980
                            ? 6
                            : metricConstraints.maxWidth >= 680
                            ? 3
                            : 2;
                        final width =
                            (metricConstraints.maxWidth - (columns - 1) * 10) /
                            columns;

                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final metric in recordMetrics)
                              SizedBox(
                                width: width,
                                child: _WorldCupRecordTile(metric: metric),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _WorldCupInfoMetric {
  const _WorldCupInfoMetric({
    required this.label,
    required this.value,
    this.note,
  });

  final String label;
  final String value;
  final String? note;
}

class _WorldCupInfoTile extends StatelessWidget {
  const _WorldCupInfoTile({required this.metric, this.compact = false});

  final _WorldCupInfoMetric metric;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: compact
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Text(
            metric.label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: FifaColors.muted,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            metric.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: compact ? TextAlign.start : TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: FifaColors.navyAlt,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (metric.note case final note?) ...[
            const SizedBox(height: 2),
            Text(
              note,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: FifaColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WorldCupRecordMetric {
  const _WorldCupRecordMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;
}

class _WorldCupRecordTile extends StatelessWidget {
  const _WorldCupRecordTile({required this.metric});

  final _WorldCupRecordMetric metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FifaColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FifaColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metric.label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: FifaColors.muted,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${metric.value}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: metric.color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class TeamHeroPill extends StatelessWidget {
  const TeamHeroPill({required this.label, this.icon, super.key});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: FifaColors.blue.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FifaColors.blue.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: FifaColors.blue),
            const SizedBox(width: 5),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: FifaColors.border,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CupChancePanel extends StatelessWidget {
  const CupChancePanel({required this.outlook, this.onDark = false, super.key});

  final TeamTournamentOutlook outlook;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final color = onDark
        ? FifaColors.blue
        : Theme.of(context).colorScheme.secondary;
    final textColor = onDark ? FifaColors.white : FifaColors.navyAlt;
    final mutedColor = onDark ? FifaColors.border : FifaColors.muted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.emoji_events, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Title chance',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '${outlook.trophy}%',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 10,
            value: outlook.trophy / 100,
            color: color,
            backgroundColor: color.withValues(alpha: 0.14),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${TournamentPowerData.sourceLabel}. Local simulations fill the bracket path between stages.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: mutedColor),
        ),
        const SizedBox(height: 10),
        TournamentStageLadder(outlook: outlook, compact: true, onDark: onDark),
      ],
    );
  }
}

class TournamentStageLadder extends StatelessWidget {
  const TournamentStageLadder({
    required this.outlook,
    this.compact = false,
    this.onDark = false,
    super.key,
  });

  final TeamTournamentOutlook outlook;
  final bool compact;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final stages = [
      ('R32', outlook.round32),
      ('R16', outlook.round16),
      ('1/4', outlook.quarterFinal),
      ('1/2', outlook.semiFinal),
      ('Final', outlook.finalChance),
      ('Title', outlook.trophy),
    ];

    return Column(
      children: [
        for (final stage in stages) ...[
          StageProbabilityRow(
            label: stage.$1,
            value: stage.$2,
            compact: compact,
            onDark: onDark,
          ),
          if (stage != stages.last) SizedBox(height: compact ? 5 : 8),
        ],
      ],
    );
  }
}

class StageProbabilityRow extends StatelessWidget {
  const StageProbabilityRow({
    required this.label,
    required this.value,
    required this.compact,
    required this.onDark,
    super.key,
  });

  final String label;
  final int value;
  final bool compact;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final color = onDark
        ? FifaColors.blue
        : Theme.of(context).colorScheme.primary;
    final textColor = onDark ? FifaColors.white : FifaColors.navyAlt;
    return Row(
      children: [
        SizedBox(
          width: compact ? 48 : 64,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: textColor, fontWeight: FontWeight.w800),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: value / 100,
              minHeight: compact ? 6 : 9,
              color: color,
              backgroundColor: color.withValues(alpha: 0.13),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 42,
          child: Text(
            '$value%',
            textAlign: TextAlign.end,
            style: TextStyle(color: textColor, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class TeamModelBreakdown extends StatelessWidget {
  const TeamModelBreakdown({required this.profile, super.key});

  final TeamModelProfile profile;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _TeamMetric('FIFA/Elo', '${profile.fifaElo}', profile.fifaScore),
      _TeamMetric('Form', '${profile.last10Points}/30', profile.formScore),
      _TeamMetric(
        'Attack',
        profile.goalsForPerMatch.toStringAsFixed(1),
        profile.attackScore,
      ),
      _TeamMetric(
        'Defense',
        profile.goalsAgainstPerMatch.toStringAsFixed(1),
        profile.defenseScore,
      ),
      _TeamMetric(
        'Squad',
        '${(profile.squadScore * 100).round()}',
        profile.squadScore,
      ),
      _TeamMetric(
        'Experience',
        '${(profile.experienceScore * 100).round()}',
        profile.experienceScore,
      ),
      _TeamMetric(
        'Depth',
        '${(profile.depthScore * 100).round()}',
        profile.depthScore,
      ),
      _TeamMetric(
        'Data',
        '${profile.dataQualityPercent}%',
        profile.dataQuality,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 620
            ? 2
            : 1;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: (constraints.maxWidth - (columns - 1) * 12) / columns,
                child: _ModelMetricCard(metric: metric),
              ),
          ],
        );
      },
    );
  }
}

class _ModelMetricCard extends StatelessWidget {
  const _ModelMetricCard({required this.metric});

  final _TeamMetric metric;

  @override
  Widget build(BuildContext context) {
    final value = metric.score.clamp(0.0, 1.0).toDouble();
    final color = Theme.of(context).colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    metric.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  metric.value,
                  style: TextStyle(color: color, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 10),
            MetricMiniBar(value: value, color: color),
          ],
        ),
      ),
    );
  }
}

class _TeamMetric {
  const _TeamMetric(this.label, this.value, this.score);

  final String label;
  final String value;
  final double score;
}

class TeamOverviewTab extends StatelessWidget {
  const TeamOverviewTab({
    required this.team,
    required this.outlook,
    required this.profile,
    super.key,
  });

  final Team team;
  final TeamTournamentOutlook outlook;
  final TeamModelProfile profile;

  @override
  Widget build(BuildContext context) {
    final worldCupData = WorldCupDataScope.of(context);
    final model = PredictionModel();
    final famous = model.famousPlayers(team, limit: 4);
    final recent = SeedData.recentMatchesFor(team, count: 10);
    final points = recent.fold<int>(0, (sum, match) => sum + match.points);
    final goalsFor = recent.fold<int>(0, (sum, match) => sum + match.goalsFor);
    final goalsAgainst = recent.fold<int>(
      0,
      (sum, match) => sum + match.goalsAgainst,
    );
    final upcoming = worldCupData.fixtures.where((match) {
      final includesTeam =
          match.homeTeamId == team.id || match.awayTeamId == team.id;
      return includesTeam && match.status != MatchStatus.finished;
    }).toList()..sort((a, b) => a.kickoffUtc.compareTo(b.kickoffUtc));
    final nextMatch = upcoming.isEmpty ? null : upcoming.first;

    return TeamTabFrame(
      team: team,
      outlook: outlook,
      profile: profile,
      children: [
        SectionHeader(
          title: '${team.name} • profile',
          subtitle: 'Overview, team strength and key players',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            StatCard(
              label: 'Title chance',
              value: '${outlook.trophy}%',
              icon: Icons.emoji_events,
            ),
            StatCard(
              label: 'Round of 32',
              value: '${outlook.round32}%',
              icon: Icons.account_tree_outlined,
            ),
            StatCard(
              label: 'Model score',
              value: '${profile.modelScore}',
              icon: Icons.functions,
            ),
            StatCard(
              label: 'Form points',
              value: '$points/30',
              icon: Icons.trending_up,
            ),
            StatCard(
              label: 'Goals',
              value: '$goalsFor:$goalsAgainst',
              icon: Icons.sports_score,
            ),
            StatCard(
              label: 'Squad',
              value: '${team.squad.length}',
              icon: Icons.groups,
            ),
          ],
        ),
        const SizedBox(height: 24),
        const SectionHeader(
          title: 'Tournament path',
          subtitle: 'Elo-calibrated group and knockout outlook',
        ),
        const SizedBox(height: 12),
        TournamentStageLadder(outlook: outlook),
        const SizedBox(height: 24),
        const SectionHeader(
          title: 'Model profile',
          subtitle: 'Algorithm v2 factors on the available seed data',
        ),
        const SizedBox(height: 12),
        TeamModelBreakdown(profile: profile),
        if (nextMatch != null) ...[
          const SizedBox(height: 24),
          const SectionHeader(
            title: 'Next match',
            subtitle: 'Preview probabilities before opening details',
          ),
          const SizedBox(height: 12),
          MatchCard(match: nextMatch, showDetails: true),
        ],
        const SizedBox(height: 24),
        const SectionHeader(
          title: 'Most notable players',
          subtitle: 'Sorted by caps, goals and squad role',
        ),
        const SizedBox(height: 12),
        FamousPlayersGrid(players: famous),
      ],
    );
  }
}

class TeamMatchesTab extends StatelessWidget {
  const TeamMatchesTab({
    required this.team,
    required this.outlook,
    required this.profile,
    super.key,
  });

  final Team team;
  final TeamTournamentOutlook outlook;
  final TeamModelProfile profile;

  @override
  Widget build(BuildContext context) {
    final worldCupData = WorldCupDataScope.of(context);
    final matches = worldCupData.fixtures.where((match) {
      final includesTeam =
          match.homeTeamId == team.id || match.awayTeamId == team.id;
      return includesTeam;
    }).toList()..sort((a, b) => a.kickoffUtc.compareTo(b.kickoffUtc));

    return TeamTabFrame(
      team: team,
      outlook: outlook,
      profile: profile,
      children: [
        SectionHeader(
          title: 'Matches',
          subtitle: 'Tournament fixtures and results for ${team.name}',
        ),
        const SizedBox(height: 12),
        ResultsMatchList(matches: matches),
      ],
    );
  }
}

class TeamFormTab extends StatelessWidget {
  const TeamFormTab({
    required this.team,
    required this.outlook,
    required this.profile,
    super.key,
  });

  final Team team;
  final TeamTournamentOutlook outlook;
  final TeamModelProfile profile;

  @override
  Widget build(BuildContext context) {
    final recent10 = SeedData.recentMatchesFor(team, count: 10);
    final model20 = SeedData.recentMatchesFor(team, count: 20);
    final goalsFor = model20.fold<int>(0, (sum, match) => sum + match.goalsFor);
    final goalsAgainst = model20.fold<int>(
      0,
      (sum, match) => sum + match.goalsAgainst,
    );

    return TeamTabFrame(
      team: team,
      outlook: outlook,
      profile: profile,
      children: [
        const SectionHeader(
          title: 'Recent matches',
          subtitle: 'Last 10 are shown; last 20 feed the model',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusPill(icon: Icons.visibility, label: '10 form matches'),
            StatusPill(icon: Icons.functions, label: '20 model matches'),
            StatusPill(icon: Icons.sports_score, label: '$goalsFor scored'),
            StatusPill(icon: Icons.shield, label: '$goalsAgainst allowed'),
          ],
        ),
        const SizedBox(height: 12),
        RecentFormList(matches: recent10),
      ],
    );
  }
}

class RecentFormList extends StatelessWidget {
  const RecentFormList({required this.matches, super.key});

  final List<RecentMatch> matches;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < matches.length; index += 1) ...[
            RecentFormRow(match: matches[index]),
            if (index != matches.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class RecentFormRow extends StatelessWidget {
  const RecentFormRow({required this.match, super.key});

  final RecentMatch match;

  @override
  Widget build(BuildContext context) {
    final opponent = SeedData.teamByNameOrNull(match.opponent);
    final score = '${match.goalsFor}:${match.goalsAgainst}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            child: Text(
              formatDate(match.date),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: FifaColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          StatusPill(label: match.resultLabel),
          const SizedBox(width: 10),
          Container(
            width: 50,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              score,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: opponent == null
                ? Text(
                    match.opponent,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : TeamBadge(team: opponent),
          ),
          const SizedBox(width: 10),
          Text(
            match.competition,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: FifaColors.muted),
          ),
        ],
      ),
    );
  }
}

class RecentMatchText extends StatelessWidget {
  const RecentMatchText({required this.match, this.overflow, super.key});

  final RecentMatch match;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final opponent = SeedData.teamByNameOrNull(match.opponent);
    if (opponent == null) {
      return Text(
        '${match.goalsFor}:${match.goalsAgainst} vs ${match.opponent}',
        overflow: overflow,
      );
    }

    return Row(
      children: [
        Text('${match.goalsFor}:${match.goalsAgainst} vs '),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => openTeamPage(context, opponent),
            child: Text(
              opponent.name,
              maxLines: 1,
              overflow: overflow ?? TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class TeamPlayersTab extends StatelessWidget {
  const TeamPlayersTab({
    required this.team,
    required this.outlook,
    required this.profile,
    super.key,
  });

  final Team team;
  final TeamTournamentOutlook outlook;
  final TeamModelProfile profile;

  @override
  Widget build(BuildContext context) {
    final displayPlayers = [...team.squad]..sort(compareSquadPlayers);
    final famous = PredictionModel().famousPlayers(team, limit: 6);
    final sourceLabel = '$squadDataSourceName • $squadDataRetrievedAt';

    return TeamTabFrame(
      team: team,
      outlook: outlook,
      profile: profile,
      children: [
        SquadSnapshotPanel(team: team, playerCount: displayPlayers.length),
        const SizedBox(height: 16),
        SquadPositionSummary(players: displayPlayers),
        const SizedBox(height: 24),
        const SectionHeader(
          title: 'Most notable players',
          subtitle: 'Local ranking by caps, goals and position',
        ),
        const SizedBox(height: 12),
        FamousPlayersGrid(players: famous),
        const SizedBox(height: 24),
        SectionHeader(
          title: 'Squad by position (${displayPlayers.length})',
          subtitle: sourceLabel,
        ),
        const SizedBox(height: 12),
        PositionSquadBoard(players: displayPlayers),
      ],
    );
  }
}

class SquadSnapshotPanel extends StatelessWidget {
  const SquadSnapshotPanel({
    required this.team,
    required this.playerCount,
    super.key,
  });

  final Team team;
  final int playerCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FifaColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FifaColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.verified_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Coach: ${team.coach}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  '$playerCount-player squad snapshot from API-Football lineups. Local metadata is retained where names matched.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: FifaColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SquadPositionSummary extends StatelessWidget {
  const SquadPositionSummary({required this.players, super.key});

  final List<Player> players;

  @override
  Widget build(BuildContext context) {
    final groups = playersByPosition(players);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final entry in groups.entries)
          SquadPositionTile(position: entry.key, count: entry.value.length),
      ],
    );
  }
}

class SquadPositionTile extends StatelessWidget {
  const SquadPositionTile({
    required this.position,
    required this.count,
    super.key,
  });

  final String position;
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: 184,
      height: 104,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: FifaColors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: FifaColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(positionIcon(position), color: color),
            const Spacer(),
            Text(
              '$count',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            Text(position, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class PositionSquadBoard extends StatelessWidget {
  const PositionSquadBoard({required this.players, super.key});

  final List<Player> players;

  @override
  Widget build(BuildContext context) {
    final groups = playersByPosition(players);
    return Column(
      children: [
        for (final entry in groups.entries) ...[
          PositionSquadSection(position: entry.key, players: entry.value),
          if (entry.key != groups.keys.last) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class PositionSquadSection extends StatelessWidget {
  const PositionSquadSection({
    required this.position,
    required this.players,
    super.key,
  });

  final String position;
  final List<Player> players;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FifaColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FifaColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                positionIcon(position),
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  position,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              StatusPill(label: '${players.length} players'),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 940
                  ? 3
                  : constraints.maxWidth >= 620
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * 10) / columns;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final player in players)
                    SizedBox(
                      width: width,
                      child: PlayerSquadChip(player: player),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class PlayerSquadChip extends StatelessWidget {
  const PlayerSquadChip({required this.player, super.key});

  final Player player;

  @override
  Widget build(BuildContext context) {
    final meta = [
      player.club,
      if (player.age != null) '${player.age} yrs',
    ].whereType<String>().join(' • ');

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: FifaColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FifaColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${player.number ?? '-'}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: FifaColors.muted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FamousPlayersGrid extends StatelessWidget {
  const FamousPlayersGrid({required this.players, super.key});

  final List<Player> players;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 620
            ? 2
            : 1;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final player in players)
              SizedBox(
                width: (constraints.maxWidth - (columns - 1) * 12) / columns,
                child: Card(
                  child: PlayerListTile(player: player, compact: true),
                ),
              ),
          ],
        );
      },
    );
  }
}

class PlayerListTile extends StatelessWidget {
  const PlayerListTile({
    required this.player,
    required this.compact,
    super.key,
  });

  final Player player;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final meta = [
      displayPosition(player.position),
      player.club,
      if (player.caps != null) '${player.caps} caps',
      if (player.goals != null) '${player.goals} goals',
      if (player.age != null) '${player.age} yrs',
    ].whereType<String>().join(' • ');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      leading: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: FifaColors.border),
        ),
        child: Text(
          '${player.number ?? '-'}',
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      title: Text(
        player.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        meta,
        maxLines: compact ? 2 : 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class MatchDetailSheet extends StatelessWidget {
  const MatchDetailSheet({required this.match, super.key});

  final MatchEntry match;

  @override
  Widget build(BuildContext context) {
    final home = SeedData.teamById(match.homeTeamId);
    final away = SeedData.teamById(match.awayTeamId);
    final prediction = predictionForMatch(context, match);

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.86,
        minChildSize: 0.48,
        builder: (context, controller) {
          return ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Row(
                children: [
                  Expanded(child: TeamBadge(team: home)),
                  Text(
                    prediction.score,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Expanded(child: TeamBadge(team: away, alignEnd: true)),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatusPill(
                    icon: Icons.event,
                    label: formatDateTime(match.kickoffUtc.toLocal()),
                  ),
                  StatusPill(label: 'Group ${match.group}'),
                  StatusPill(icon: Icons.stadium, label: match.city),
                ],
              ),
              const SizedBox(height: 18),
              PredictionCard(
                match: match,
                prediction: prediction,
                enableDetails: false,
              ),
              const SizedBox(height: 18),
              Text(
                'Last 5 matches',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              RecentComparison(home: home, away: away),
            ],
          );
        },
      ),
    );
  }
}

class RecentComparison extends StatelessWidget {
  const RecentComparison({required this.home, required this.away, super.key});

  final Team home;
  final Team away;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 720;
        final children = [
          RecentMatchColumn(team: home),
          RecentMatchColumn(team: away),
        ];
        if (narrow) {
          return Column(
            children: [children[0], const SizedBox(height: 12), children[1]],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: children[0]),
            const SizedBox(width: 12),
            Expanded(child: children[1]),
          ],
        );
      },
    );
  }
}

class RecentMatchColumn extends StatelessWidget {
  const RecentMatchColumn({required this.team, super.key});

  final Team team;

  @override
  Widget build(BuildContext context) {
    final recent = SeedData.recentMatchesFor(team, count: 5);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TeamBadge(team: team),
            const SizedBox(height: 12),
            for (final match in recent)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    StatusPill(label: match.resultLabel),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RecentMatchText(
                        match: match,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

void showTeamDetails(BuildContext context, Team team) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => TeamDetailSheet(team: team),
  );
}

class TeamDetailSheet extends StatelessWidget {
  const TeamDetailSheet({required this.team, super.key});

  final Team team;

  @override
  Widget build(BuildContext context) {
    final recent10 = SeedData.recentMatchesFor(team, count: 10);
    final model20 = SeedData.recentMatchesFor(team, count: 20);
    final goalsFor = model20.fold<int>(0, (sum, match) => sum + match.goalsFor);
    final goalsAgainst = model20.fold<int>(
      0,
      (sum, match) => sum + match.goalsAgainst,
    );

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        minChildSize: 0.5,
        builder: (context, controller) {
          return ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              TeamBadge(team: team),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatusPill(label: 'Group ${team.group}'),
                  StatusPill(
                    icon: Icons.leaderboard,
                    label: 'FIFA #${team.fifaRanking}',
                  ),
                  StatusPill(icon: Icons.person, label: team.coach),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Squad (${team.squad.length})',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  StatusPill(icon: Icons.verified, label: squadDataSourceName),
                  StatusPill(
                    icon: Icons.event_available,
                    label: squadDataRetrievedAt,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (team.squad.isEmpty)
                const EmptyState(
                  icon: Icons.groups,
                  title: 'Official squad pending',
                  body:
                      'The seed profile keeps space for players, club, position and number.',
                )
              else
                Card(
                  child: Column(
                    children: [
                      for (final player in team.squad)
                        ListTile(
                          leading: CircleAvatar(
                            child: Text('${player.number ?? '-'}'),
                          ),
                          title: Text(player.name),
                          subtitle: Text(
                            [
                              displayPosition(player.position),
                              player.club,
                              player.age == null ? null : '${player.age} yrs',
                            ].whereType<String>().join(' • '),
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              Text(
                'Form and model',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatusPill(
                    icon: Icons.sports_score,
                    label: '$goalsFor scored / 20',
                  ),
                  StatusPill(
                    icon: Icons.shield,
                    label: '$goalsAgainst allowed / 20',
                  ),
                  StatusPill(icon: Icons.visibility, label: '10 UI matches'),
                  StatusPill(icon: Icons.functions, label: '20 model matches'),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      for (final match in recent10)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 54,
                                child: Text(formatDate(match.date)),
                              ),
                              StatusPill(label: match.resultLabel),
                              const SizedBox(width: 8),
                              Expanded(
                                child: RecentMatchText(
                                  match: match,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String confidenceLabel(double value) {
  if (value >= 0.52) return 'High';
  if (value >= 0.34) return 'Medium';
  return 'Low';
}

String displayPosition(String value) {
  return switch (value) {
    'Вратар' => 'Goalkeeper',
    'Защитник' => 'Defender',
    'Полузащитник' => 'Midfielder',
    'Нападател' => 'Forward',
    'Attacker' => 'Forward',
    _ => value,
  };
}

int compareSquadPlayers(Player a, Player b) {
  final positionCompare = positionRank(
    displayPosition(a.position),
  ).compareTo(positionRank(displayPosition(b.position)));
  if (positionCompare != 0) return positionCompare;
  final numberCompare = (a.number ?? 99).compareTo(b.number ?? 99);
  if (numberCompare != 0) return numberCompare;
  return a.name.compareTo(b.name);
}

Map<String, List<Player>> playersByPosition(List<Player> players) {
  final groups = <String, List<Player>>{};
  for (final player in players) {
    final position = displayPosition(player.position);
    groups.putIfAbsent(position, () => <Player>[]).add(player);
  }
  for (final group in groups.values) {
    group.sort(compareSquadPlayers);
  }
  final entries = groups.entries.toList()
    ..sort((a, b) {
      final rankCompare = positionRank(a.key).compareTo(positionRank(b.key));
      if (rankCompare != 0) return rankCompare;
      return a.key.compareTo(b.key);
    });
  return {for (final entry in entries) entry.key: entry.value};
}

int positionRank(String position) {
  return switch (position) {
    'Goalkeeper' => 0,
    'Defender' => 1,
    'Midfielder' => 2,
    'Forward' => 3,
    _ => 4,
  };
}

IconData positionIcon(String position) {
  return switch (position) {
    'Goalkeeper' => Icons.sports_handball,
    'Defender' => Icons.shield_outlined,
    'Midfielder' => Icons.hub,
    'Forward' => Icons.sports_soccer,
    _ => Icons.person_outline,
  };
}

String newsDisplayTitle(NewsArticle item) {
  final title = _normalizeNewsText(item.title);
  final rebuilt = _titleFromNewsLink(item.link);
  if ((title.isEmpty || title.contains('...')) &&
      rebuilt != null &&
      rebuilt.length > title.replaceAll('...', '').length) {
    return rebuilt;
  }
  return title;
}

String newsQuickTake(NewsArticle item) {
  final summary = _normalizeNewsText(item.summary);
  final source = _normalizeNewsText(item.source).isEmpty
      ? 'the source'
      : _normalizeNewsText(item.source);
  final title = newsDisplayTitle(item);
  final sentences = <String>[
    if (title.isNotEmpty) 'The story focuses on "$title".',
  ];

  final summarySentences = _newsSummarySentences(summary);
  for (
    var index = 0;
    index < summarySentences.length && index < 2;
    index += 1
  ) {
    sentences.add(_newsSummaryLine(source, summarySentences[index], index));
  }

  for (final context in _newsContextSentences(
    title: title,
    summary: summary,
    source: source,
  )) {
    if (sentences.length >= 5) break;
    if (!sentences.contains(context)) sentences.add(context);
  }

  return sentences.join(' ');
}

List<String> _newsSummarySentences(String value) {
  if (value.isEmpty) return const [];
  return RegExp(r'[^.!?]+[.!?]?')
      .allMatches(value)
      .map((match) => _ensureEndingPunctuation(match.group(0) ?? ''))
      .map(_normalizeNewsText)
      .where((sentence) => sentence.length > 3)
      .take(3)
      .toList(growable: false);
}

String _newsSummaryLine(String source, String sentence, int index) {
  final clean = _ensureEndingPunctuation(sentence);
  final startsAsQuestion = RegExp(
    r'^(who|what|where|when|why|how)\b',
    caseSensitive: false,
  ).hasMatch(clean);
  final isQuestion = startsAsQuestion || clean.endsWith('?');

  if (isQuestion) {
    return index == 0
        ? '$source frames the story around this question: $clean'
        : 'It also leaves this question open: $clean';
  }

  return index == 0
      ? 'According to $source, ${_lowerFirstForIntro(clean)}'
      : 'It also notes that ${_lowerFirstForIntro(clean)}';
}

List<String> _newsContextSentences({
  required String title,
  required String summary,
  required String source,
}) {
  final haystack = '$title $summary'.toLowerCase();
  final sentences = <String>[];

  if (_containsAny(haystack, [
    'predict',
    'prediction',
    'simulate',
    'simulating',
    'winner',
    'odds',
    'chance',
    'pick',
  ])) {
    sentences.add(
      'The available wording presents it as analysis or prediction, not as a confirmed result.',
    );
  }
  if (_containsAny(haystack, ['world cup', 'fifa', '2026', 'wc '])) {
    sentences.add(
      'It belongs to the World Cup coverage available in the $source RSS feed.',
    );
  }
  if (_containsAny(haystack, [
    'ban',
    'revers',
    'backlash',
    'decision',
    'rule',
  ])) {
    sentences.add('The preview frames it as a tournament operations update.');
  }
  if (sentences.length < 2) {
    sentences.add(
      'The card stays close to the RSS preview and leaves the full reporting to $source.',
    );
  }

  return sentences;
}

bool _containsAny(String value, List<String> needles) {
  return needles.any(value.contains);
}

String _normalizeNewsText(String value) {
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _ensureEndingPunctuation(String value) {
  if (value.isEmpty || RegExp(r'[.!?]$').hasMatch(value)) return value;
  return '$value.';
}

String _lowerFirstForIntro(String value) {
  if (value.isEmpty) return value;
  final firstWord = RegExp(r'^[A-Za-z]+').firstMatch(value)?.group(0);
  if (firstWord != null &&
      firstWord.length > 1 &&
      firstWord == firstWord.toUpperCase()) {
    return value;
  }
  return value[0].toLowerCase() + value.substring(1);
}

String? _titleFromNewsLink(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || uri.pathSegments.isEmpty) return null;

  final slug = uri.pathSegments.reversed.firstWhere((segment) {
    final normalized = segment.trim().toLowerCase();
    return normalized.length > 8 &&
        !RegExp(r'^\d+$').hasMatch(normalized) &&
        normalized != 'story' &&
        normalized != 'news';
  }, orElse: () => '');
  if (slug.isEmpty) return null;

  final cleaned = Uri.decodeComponent(slug)
      .replaceAll(RegExp(r'\.(html?|xml)$', caseSensitive: false), '')
      .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '-');
  final words = cleaned
      .split(RegExp(r'[-_]+'))
      .where((word) => word.isNotEmpty)
      .toList(growable: false);
  if (words.length < 4) return null;

  return [
    for (var index = 0; index < words.length; index += 1)
      _displaySlugWord(words[index], index == 0),
  ].join(' ');
}

String _displaySlugWord(String word, bool first) {
  final lower = word.toLowerCase();
  const acronyms = {
    'ea': 'EA',
    'fifa': 'FIFA',
    'mls': 'MLS',
    'uefa': 'UEFA',
    'usa': 'USA',
    'usmnt': 'USMNT',
    'var': 'VAR',
    'wc': 'WC',
  };
  final acronym = acronyms[lower];
  if (acronym != null) return acronym;

  const smallWords = {
    'a',
    'an',
    'and',
    'as',
    'at',
    'but',
    'by',
    'for',
    'from',
    'in',
    'of',
    'on',
    'or',
    'the',
    'to',
    'with',
  };
  if (!first && smallWords.contains(lower)) return lower;
  return lower[0].toUpperCase() + lower.substring(1);
}

String formatDateTime(DateTime value) {
  return '${_two(value.day)}.${_two(value.month)} ${_two(value.hour)}:${_two(value.minute)}';
}

String formatDate(DateTime value) {
  return '${_two(value.day)}.${_two(value.month)}';
}

String ordinal(int value) {
  final mod100 = value % 100;
  if (mod100 >= 11 && mod100 <= 13) return '${value}th';
  return switch (value % 10) {
    1 => '${value}st',
    2 => '${value}nd',
    3 => '${value}rd',
    _ => '${value}th',
  };
}

String _two(int value) => value.toString().padLeft(2, '0');

Future<void> openExternalUrl(String value) async {
  final uri = Uri.tryParse(value);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
