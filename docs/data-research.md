# World Cup 2026 data research and QA notes

Дата на проверка: 2026-06-06  
Роля: QA/research worker. Не са правени промени по app код.

## Обхват на данните за MVP

MVP трябва да раздели данните на стабилни tournament data и променливи live/model data:

- Турнир: 48 отбора, 12 групи, 104 мача, домакини САЩ/Канада/Мексико, старт 2026-06-11 и финал 2026-07-19.
- Отбори: stable provider ID, FIFA/API име, ISO/FIFA code, флаг/лого, група, треньор, FIFA ranking snapshot, дата на последна актуализация.
- Групи: група A-L, отбори, точки, победи, равенства, загуби, голове, голова разлика, ranking/tie-break state.
- Програма/мачове: stable match ID, дата/час в UTC, локален час за потребителя, домакин/гост според API, град, стадион, група/фаза, статус, резултат, lastUpdatedAt, source.
- Играчи: финален squad list, позиция, номер, клуб, възраст/дата на раждане, капитан/треньор ако има. Да се пази `isOfficial`/`source`.
- Последни мачове: минимум последни 20 A-international мача на всеки отбор, с тип турнир/приятелски, дата, резултат, домакинство/неутрален терен, противник, опционално FIFA ranking/strength snapshot.
- Прогнози: `modelVersion`, входни данни към момента на генериране, W/D/L вероятности, predicted goals/score, confidence, explainability text, generatedAt.

## Reliable sources and API options

Приоритет за truth data:

1. FIFA official pages за groups, fixtures, squads, regulations и rankings:
   - Groups/tie-breakers: https://www.fifa.com/en/articles/groups-how-teams-qualify-tie-breakers
   - Fixtures/results/stadiums: https://www.fifa.com/en/tournaments/mens/worldcup/canadamexicousa2026/articles/match-schedule-fixtures-results-teams-stadiums
   - Squad rules/dates: https://www.fifa.com/en/tournaments/mens/worldcup/canadamexicousa2026/articles/squad-lists-number-date
   - FIFA ranking: https://inside.fifa.com/en/fifa-world-ranking/men
2. Paid/operational API candidates:
   - Sportmonks World Cup 2026: fixtures, live scores, standings, squads, bracket, player details, stats; public FAQ lists WC plans and notes live data starts from 2026-06-11. Docs expose livescore, fixture, standings, lineup/event includes.
     - https://www.sportmonks.com/faq/
     - https://docs.sportmonks.com/v3/world-cup-2026/live-matches-livescores-and-events
     - https://docs.sportmonks.com/v3/endpoints-and-entities/endpoints
   - API-Football/API-SPORTS: World Cup guide uses `league=1`, `season=2026`; supports fixtures, teams, standings, events, lineups, player stats, injuries, predictions/odds when coverage flags are enabled. Important: coverage may vary by match.
     - https://www.api-football.com/news/post/fifa-world-cup-2026-guide-to-using-data-with-api-sports
     - https://www.api-football.com/documentation-v3
   - football-data.org: simpler JSON API with WC competition code, matches, teams and team match history. Lower complexity, likely weaker for squads/live/player stats.
     - https://www.football-data.org/documentation/quickstart
     - https://docs.football-data.org/general/v4/competition.html
3. Open/reference data for local seeding or tests, not as the production live source:
   - OpenFootball worldcup JSON: useful for fixtures/seed data and offline fixtures, but community-maintained and must be cross-checked with FIFA/API.
     - https://github.com/openfootball/worldcup.json
   - StatsBomb open data: useful for historical analytics examples and model research, not a live WC 2026 feed.
     - https://github.com/statsbomb/open-data

Recommendation: choose one paid operational API for production MVP, then cross-check immutable tournament data against FIFA and keep a small local seed fixture for offline/tests. Do not put API keys in Flutter; use backend/cache only.

## Unstable data as of 2026-06-06

- Match statuses, results, live events, group standings and knockout paths are unstable until matches finish.
- Official lineups are not stable until shortly before kick-off. Sportmonks notes lineups are typically confirmed around 60-75 minutes before kick-off.
- Squads are recently official, but replacements/injury updates can still affect UX expectations. Store squad `lastUpdatedAt` and source.
- FIFA ranking is a snapshot. The FIFA ranking page checked showed last official update 2026-04-01 and next official update 2026-06-11, so rankings should be versioned by ranking date.
- Friendly matches and final warm-up matches before 2026-06-11 can change model inputs daily.
- Provider IDs, team names, venue names and local kickoff times can differ between APIs. Backend needs mapping tables and source audit fields.
- Predictions from a provider should not be mixed silently with the app's own model. If external predictions are used, label provider/model separately.

## QA criteria for first local MVP

- App starts on web/mobile emulator with no real API key by using a local seed dataset.
- Home screen shows upcoming matches, latest results area, groups/teams shortcuts, predictions area, and `last updated`.
- All 48 teams render with names, flags/logos and group labels from the same normalized dataset.
- Groups A-L render 4 teams each; standings are deterministic and recalculate from match results.
- Match list supports date/team/group/status filters and handles user's local timezone without changing stored UTC times.
- Match detail shows both teams, date/time, venue/city, status, result if finished, recent form for both teams and prediction.
- Team detail shows squad state even if squad fields are partial; missing coach/club/age must not break layout.
- Last 10 and last 20 matches are visibly separated: last 10 for UI, last 20 for model input.
- Prediction probabilities always sum to 100% after display rounding, or UI explains rounding.
- Prediction explanation is framed as probability analysis, never guaranteed result.
- Loading, empty, error, offline/stale-cache and retry states are implemented for every data screen.
- Pull-to-refresh or manual refresh updates `lastUpdatedAt` and handles provider failures without clearing cached data.
- API key or token is absent from Flutter source, web build output and committed config.
- Provider rate-limit or 5xx response produces a user-friendly state and a logged backend error.
- Basic widget/golden sanity checks cover home, match list, group table, team detail and match detail with seed data.

## Data/API risk list

- Paid API cost and plan limits can block live data, especially squads, player stats, predictions, odds and xG.
- Live event latency and provider update cadence may not meet user expectations during match windows.
- Coverage flags may say a feature exists but individual fixtures can still have missing lineups/events/stats.
- Team/player identity mapping can drift across providers; avoid matching by display name only.
- Knockout bracket logic for the 48-team format is error-prone, especially best third-placed teams and round-of-32 mapping.
- Timezone bugs are high risk because fixtures span 16 host cities and multiple time zones.
- FIFA official pages are reliable but not always convenient as machine-readable APIs; avoid scraping as the primary backend path unless licensed/approved.
- Historical "last 20 matches" quality depends on whether the provider includes friendlies, qualifiers and neutral venue metadata consistently.
- Betting/odds/prediction data may trigger legal/compliance constraints. MVP copy should avoid betting language unless explicitly approved.

## First QA pass: initial project inspection

Files present during the first QA pass:

- `zadanie-world-cup-app.md`
- `docs/data-research.md`

No Flutter project, source code, tests, `pubspec.yaml`, backend code or Git repository were present in `/Users/macbookpro/Documents/Sport AP` at inspection time. Obvious implementation risks therefore are project-level:

- Architecture/API choice is not fixed yet.
- No seed data contract exists yet.
- No test harness exists yet.
- No backend/cache layer exists yet.
- QA cannot run Flutter tests until the implementation project is created.

## Second QA pass: local Flutter MVP

Дата на проверка: 2026-06-06

Flutter проектът вече съществува с локален seed MVP:

- Основни файлове: `lib/main.dart`, `lib/models.dart`, `lib/seed_data.dart`, `lib/prediction_model.dart`, `test/widget_test.dart`.
- Навигация: Начало, Мачове, Прогнози, Групи, Отбори.
- Seed scope: 48 отбора, 12 групи, 28 seed мача, локално генерирани recent matches за форма/модел.
- Проверки: `flutter test` мина успешно; `flutter analyze` мина успешно след разрешение за Flutter SDK cache извън workspace.

Approval note: приложението е годно като локален seed prototype, но не е пълен local MVP по заданието, докато програмата не покрива всички 104 мача и докато няма backend/API/cache договор.

## Squad data update: 2026-06-06

Added local squad data from the structured 2026 FIFA World Cup squads table, cross-checked against FIFA's squad publication context and current squad reporting for late discrepancies.

- The app stores player name, position, club, shirt number and age where available.
- Jordan was cross-checked after the structured table had 25 rows; Ibrahim Sabra was added from current Jordan final-squad reporting.
- Canada and Austria currently remain at 25 rows in local data because post-announcement injury reporting indicates Marcelo Flores and Christoph Baumgartner are out and no replacement was confirmed in the checked sources at update time.
- These lists should be refreshed again before kickoff and whenever FIFA publishes injury replacements.

## Follow-ups

- Decide the paid API candidate and verify exact plan coverage for World Cup 2026, international friendlies, squads, lineups, injuries and historical team matches.
- Define normalized backend DTOs before Flutter screens consume data.
- Create a small checked-in seed JSON for 48 teams, groups and a subset/full fixture list for local development.
- Add provider contract tests against recorded sample responses.
- Add a data freshness policy: e.g. static data daily, pre-match data hourly, live matches 10-30s through backend polling/websocket depending on API limits.
